extends Node

const PREFS_PATH := "user://run_prefs.cfg"

# Difficulty tiers — index into DIFFICULTY_TABLE.
const DIFF_EASY := 0
const DIFF_MEDIUM := 1
const DIFF_HARD := 2
const DIFF_NIGHTMARE := 3
const DIFFICULTY_NAMES: Array[String] = ["Easy", "Medium", "Hard", "Nightmare"]

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

# Run-wide selections set on the character-select screen.
var character: String = "marine"  # "marine" or "demon"
var difficulty: int = DIFF_MEDIUM
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

func save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "character", character)
	cfg.set_value("run", "difficulty", difficulty)
	cfg.save(PREFS_PATH)

func start_new_run() -> void:
	is_run_active = true
	depth = 0
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
	player.attack_damage = 2 + attack_bonus
	player.speed = 180.0 * speed_mult
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
