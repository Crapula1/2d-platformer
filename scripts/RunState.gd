extends Node

var is_run_active: bool = false
var depth: int = 0
var saved_health: int = 5
var saved_max_health: int = 5
var saved_score: int = 0
var saved_grenade_type: int = 0
var attack_bonus: int = 0
var speed_mult: float = 1.0
var grenade_cd_mult: float = 1.0
var invincibility_bonus: float = 0.0

func start_new_run() -> void:
	is_run_active = true
	depth = 0
	saved_health = 5
	saved_max_health = 5
	saved_score = 0
	saved_grenade_type = 0
	attack_bonus = 0
	speed_mult = 1.0
	grenade_cd_mult = 1.0
	invincibility_bonus = 0.0

func save_from_player(player: Player) -> void:
	saved_health = player.current_health
	saved_max_health = player.max_health
	saved_score = player.score
	saved_grenade_type = player.grenade_type

func advance_depth() -> void:
	depth += 1

func apply_to_player(player: Player) -> void:
	player.max_health = saved_max_health
	player.current_health = saved_health
	player.score = saved_score
	player.grenade_type = saved_grenade_type
	player.attack_damage = 2 + attack_bonus
	player.speed = 180.0 * speed_mult
	player.invincibility_time = 1.0 + invincibility_bonus
	# Apply grenade cooldown mult via a stored property the grenade input reads
	# We patch _grenade_cooldown indirectly by adjusting through a signal chain
	player.emit_signal("health_changed", player.current_health, player.max_health)
	player.emit_signal("score_changed", player.score)
	player.emit_signal("grenade_changed", Player.GRENADE_NAMES[player.grenade_type])

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
