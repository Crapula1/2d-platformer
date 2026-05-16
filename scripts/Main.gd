extends Node2D

@onready var player: Player = $Level/Player
@onready var camera: Camera2D = $Level/Player/Camera2D
@onready var health_label: Label = $HUD/MarginContainer/VBoxContainer/HealthLabel
@onready var score_label: Label = $HUD/MarginContainer/VBoxContainer/ScoreLabel
@onready var message_label: Label = $HUD/CenterContainer/MessageLabel
@onready var hint_label: Label = $HUD/HintLabel
@onready var grenade_label: Label = $HUD/MarginContainer/VBoxContainer/GrenadeLabel

const GRENADE_COLORS := [
	Color(1.0, 0.72, 0.2),   # Explosive - gold
	Color(1.0, 0.42, 0.08),  # Incendiary - orange
	Color(0.35, 0.88, 1.0),  # Electric - cyan
]

var spawn_position: Vector2

func _ready() -> void:
	spawn_position = player.global_position
	player.health_changed.connect(_on_health_changed)
	player.score_changed.connect(_on_score_changed)
	player.died.connect(_on_player_died)
	player.grenade_changed.connect(_on_grenade_changed)

	# Connect all goals
	for goal in get_tree().get_nodes_in_group("goal"):
		goal.reached.connect(_on_goal_reached)

	message_label.text = ""
	hint_label.text = "WASD/Arrows: Move  |  SPACE/W: Jump (double jump!)  |  J/Click: Attack  |  R: Restart"

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	# Respawn if player falls into the void
	if player.global_position.y > 800 and not player.is_dead:
		player.take_damage(99, player.global_position)

func _on_health_changed(new_health: int, max_health: int) -> void:
	var hearts = ""
	for i in range(max_health):
		hearts += "♥" if i < new_health else "♡"
	health_label.text = "HP: " + hearts

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Coins: " + str(new_score)

func _on_player_died() -> void:
	message_label.text = "YOU DIED\nPress R to restart"
	message_label.modulate = Color(1, 0.3, 0.3)

func _on_grenade_changed(type_name: String) -> void:
	grenade_label.text = "[ " + type_name + " ]"
	var idx := player.grenade_type
	grenade_label.add_theme_color_override("font_color", GRENADE_COLORS[idx])

func _on_goal_reached() -> void:
	message_label.text = "LEVEL COMPLETE!\nPress R to play again"
	message_label.modulate = Color(0.3, 1, 0.3)
	player.set_physics_process(false)
