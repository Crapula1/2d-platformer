extends Node

const PREFS_PATH := "user://run_prefs.cfg"

# Difficulty tiers — index into DIFFICULTY_TABLE.
const DIFF_EASY := 0
const DIFF_MEDIUM := 1
const DIFF_HARD := 2
const DIFF_NIGHTMARE := 3
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard", "Nightmare"]

# Starting-level picks for the CharacterSelect screen. Index lines up with
# the depth Main.gd uses to choose a level scene:
#   0 → Level.tscn (jungle)
#   1 → Level2.tscn (industrial)
#   2 → Level3.tscn (castle)
#   3 → Level4.tscn (catacombs — metroidvania map)
#   4 → ProceduralLevel.tscn (procedural loop starts here)
const LEVEL_NAMES: Array[String] = ["Jungle", "Industrial", "Castle", "Catacombs", "Procedural"]
const LEVEL_DESCS: Array[String] = [
	"Hand-built jungle ruins. The intro level.",
	"Hand-built industrial complex. Tougher patrols.",
	"Hand-built medieval castle. Moats, braziers, banners.",
	"Catacombs metroidvania — locked rooms, save crystals, warps, relic abilities, mini-map.",
	"Endless procedural runs. Scaling difficulty.",
]

# Per-tier multipliers. player_max_hp_mult scales the starting HP cap
# (default 10), enemy_hp_mult scales every enemy's max_health on spawn,
# enemy_speed_mult scales patrol/charge speed. Damage taken by the player
# is hard-capped at 1 in Player.take_damage, so the difficulty fights HP
# pools instead of raw damage numbers.
const DIFFICULTY_TABLE: Array[Dictionary] = [
	{"player_max_hp_mult": 1.5, "enemy_hp_mult": 0.75, "enemy_speed_mult": 0.90},  # Easy
	{"player_max_hp_mult": 1.0, "enemy_hp_mult": 1.00, "enemy_speed_mult": 1.00},  # Medium
	{"player_max_hp_mult": 0.7, "enemy_hp_mult": 1.40, "enemy_speed_mult": 1.10},  # Hard
	{"player_max_hp_mult": 0.5, "enemy_hp_mult": 1.90, "enemy_speed_mult": 1.25},  # Nightmare
]

var is_run_active: bool = false
var depth: int = 0
var saved_health: int = 10
var saved_max_health: int = 10
var saved_score: int = 0
var saved_grenade_type: int = 0
var saved_grenade_count: int = 3
var attack_bonus: int = 0
var speed_mult: float = 1.0
var grenade_cd_mult: float = 1.0
var invincibility_bonus: float = 0.0

# Per-character tuning. max_health is the absolute starting HP cap
# *before* difficulty scaling. speed/jump/attack mults stack on top of
# the Player.gd defaults. allowed_weapons is the set of weapon IDs the
# character can actually fire (others stay locked).
const CHARACTER_STATS: Dictionary = {
	"marine": {
		"display_name": "MARINE",
		"tint": Color(0.35, 0.85, 1.0),
		"max_health": 10,
		"speed_mult": 1.0,
		"jump_mult": 1.0,
		"attack_mult": 1.0,
		"max_jumps": 2,
		"jetpack_duration": 3.0,
		"allowed_weapons": ["rifle", "shotgun"],
		"desc": "Versatile rifle + shotgun + axe loadout.\nBalanced HP and mobility.",
		"scene": "res://scenes/Player.tscn",
	},
	"demon": {
		"display_name": "DEMON",
		"tint": Color(0.95, 0.30, 0.30),
		"max_health": 8,
		"speed_mult": 1.15,
		"jump_mult": 1.05,
		"attack_mult": 1.10,
		"max_jumps": 2,
		"jetpack_duration": 2.5,
		"allowed_weapons": ["melee"],
		"desc": "Lithe demonic brawler. Light frame,\nquick swings, single pair of horns.",
		"scene": "res://scenes/PlayerDemon.tscn",
	},
	"greater_demon": {
		"display_name": "GREATER DEMON",
		"tint": Color(1.0, 0.55, 0.15),
		"max_health": 14,
		"speed_mult": 0.85,
		"jump_mult": 0.90,
		"attack_mult": 1.40,
		"max_jumps": 1,
		"jetpack_duration": 2.0,
		"allowed_weapons": ["melee"],
		"desc": "Heavy demonic warlord. Caped, twin\nhorn pairs, claws — armored melee.",
		"scene": "res://scenes/PlayerGreaterDemon.tscn",
	},
	"squirrel": {
		"display_name": "SQUIRREL",
		"tint": Color(0.85, 0.55, 0.22),
		"max_health": 7,
		"speed_mult": 1.25,
		"jump_mult": 1.15,
		"attack_mult": 0.90,
		"max_jumps": 3,
		"jetpack_duration": 2.5,
		"allowed_weapons": ["rifle", "shotgun"],
		"desc": "Acorn gun, acorn shotgun, and a\nbig wooden mallet smash. Light,\nfast, triple-jump mobility.",
		"scene": "res://scenes/Player4.tscn",
	},
}

# Stable display order for any UI that iterates characters (select screen,
# HUDs, etc.). Keys-of a Dictionary keep insertion order in Godot 4, but
# this list makes the dependency explicit.
const CHARACTER_ORDER: Array[String] = ["marine", "demon", "greater_demon", "squirrel"]

func character_scene_path(id: String) -> String:
	var d: Dictionary = CHARACTER_STATS.get(id, CHARACTER_STATS["marine"])
	return String(d.get("scene", "res://scenes/Player.tscn"))

# Run-wide selections set on the character-select screen.
var character: String = "marine"  # see CHARACTER_STATS keys
var difficulty: int = DIFF_MEDIUM
# Starting level index into LEVEL_NAMES (also = starting `depth` in Main.gd).
# Persisted in prefs so a player who likes starting on procedural keeps that
# choice across launches.
var start_level: int = 0
var player_max_hp_mult: float = 1.0
var enemy_hp_mult: float = 1.0
var enemy_speed_mult: float = 1.0

func _ready() -> void:
	load_prefs()

func load_prefs() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) != OK:
		return
	character = String(cfg.get_value("run", "character", character))
	set_difficulty(int(cfg.get_value("run", "difficulty", difficulty)))
	start_level = clampi(int(cfg.get_value("run", "start_level", start_level)), 0, LEVEL_NAMES.size() - 1)

func get_character_stats() -> Dictionary:
	return CHARACTER_STATS.get(character, CHARACTER_STATS["marine"])

func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "character", character)
	cfg.set_value("run", "difficulty", difficulty)
	cfg.set_value("run", "start_level", start_level)
	cfg.save(PREFS_PATH)

func start_new_run() -> void:
	is_run_active = true
	# Honor the level picked on CharacterSelect. Restarts (R / death) also flow
	# through here, so the player keeps re-spawning into the level they chose.
	depth = clampi(start_level, 0, LEVEL_NAMES.size() - 1)
	# Use the difficulty-scaled hp cap so a fresh run starts with the right
	# max HP for the chosen tier.
	saved_max_health = maxi(int(round(10.0 * player_max_hp_mult)), 1)
	saved_health = saved_max_health
	saved_score = 0
	saved_grenade_type = 0
	saved_grenade_count = 3
	attack_bonus = 0
	speed_mult = 1.0
	grenade_cd_mult = 1.0
	invincibility_bonus = 0.0

func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, DIFFICULTY_TABLE.size() - 1)
	var t: Dictionary = DIFFICULTY_TABLE[difficulty]
	player_max_hp_mult = float(t["player_max_hp_mult"])
	enemy_hp_mult = float(t["enemy_hp_mult"])
	enemy_speed_mult = float(t["enemy_speed_mult"])

func save_from_player(player: Player) -> void:
	saved_health = player.current_health
	saved_max_health = player.max_health
	saved_score = player.score
	saved_grenade_type = player.grenade_type
	saved_grenade_count = player.grenade_count

func advance_depth() -> void:
	depth += 1

func apply_to_player(player: Player) -> void:
	player.max_health = saved_max_health
	player.current_health = saved_health
	player.score = saved_score
	player.grenade_type = saved_grenade_type
	player.grenade_count = saved_grenade_count
	player.attack_damage = player.character_base_attack + attack_bonus
	player.speed = player.character_base_speed * speed_mult
	player.invincibility_time = 1.0 + invincibility_bonus
	player.grenade_cooldown_base = 0.85 * grenade_cd_mult
	player.health_changed.emit(player.current_health, player.max_health)
	player.score_changed.emit(player.score)
	player.grenade_changed.emit(Player.GRENADE_NAMES[player.grenade_type], player.grenade_count)

func apply_upgrade(id: String) -> void:
	match id:
		"max_hp":
			saved_max_health += 2
			saved_health = saved_max_health
		"attack":
			attack_bonus += 1
		"speed":
			speed_mult += 0.2
		"heal_now":
			saved_health = mini(saved_health + 3, saved_max_health)
		"grenade_cd":
			grenade_cd_mult *= 0.75
		"invincibility":
			invincibility_bonus += 0.5
