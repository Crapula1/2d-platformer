extends Node2D

@onready var health_label: Label = $HUD/MarginContainer/VBoxContainer/HealthLabel
@onready var score_label: Label = $HUD/MarginContainer/VBoxContainer/ScoreLabel
@onready var grenade_label: Label = $HUD/MarginContainer/VBoxContainer/GrenadeLabel
@onready var message_label: Label = $HUD/CenterContainer/MessageLabel
@onready var hint_label: Label = $HUD/HintLabel

const LEVEL_SCENE := preload("res://scenes/Level.tscn")
const PROC_LEVEL_SCENE := preload("res://scenes/ProceduralLevel.tscn")

const UPGRADES := [
	{"id": "max_hp",      "name": "Combat Stims",  "desc": "+2 Max HP"},
	{"id": "attack",      "name": "AP Rounds",      "desc": "+1 Bash Damage"},
	{"id": "speed",       "name": "Servo Legs",     "desc": "+20% Speed"},
	{"id": "heal_now",    "name": "Field Medkit",   "desc": "Restore 3 HP"},
	{"id": "grenade_cd",  "name": "Fast Loader",    "desc": "Grenade CD -25%"},
	{"id": "invincibility","name": "Ceramic Plate", "desc": "+0.5s I-Frames"},
]

const GRENADE_COLORS := [
	Color(1.0, 0.72, 0.2),
	Color(1.0, 0.42, 0.08),
	Color(0.35, 0.88, 1.0),
]

var player: Player = null
var spawn_position: Vector2
var _level: Node = null

func _ready() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()

	if RunState.depth > 0:
		_level = PROC_LEVEL_SCENE.instantiate()
	else:
		_level = LEVEL_SCENE.instantiate()

	add_child(_level)
	move_child(_level, 0)

	await get_tree().process_frame

	player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	if RunState.depth > 0:
		RunState.apply_to_player(player)

	spawn_position = player.global_position

	player.health_changed.connect(_on_health_changed)
	player.score_changed.connect(_on_score_changed)
	player.died.connect(_on_player_died)
	player.grenade_changed.connect(_on_grenade_changed)

	for goal in get_tree().get_nodes_in_group("goal"):
		goal.reached.connect(_on_level_exit)

	for exit_node in get_tree().get_nodes_in_group("exit"):
		exit_node.exited.connect(_on_level_exit)

	message_label.text = ""
	hint_label.text = "WASD/Arrows: Move  |  SPACE/W: Jump (double jump!)  |  J/Click: Attack  |  G: Grenade  |  Tab: Cycle Grenade  |  R: Restart"

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		RunState.start_new_run()
		get_tree().reload_current_scene()
		return

	if player == null or player.is_dead:
		return

	if player.global_position.y > 700:
		player.take_damage(99, player.global_position)

func _on_health_changed(new_health: int, max_health: int) -> void:
	var hearts := ""
	for i in range(max_health):
		hearts += "♥" if i < new_health else "♡"
	health_label.text = "HP: " + hearts

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Coins: " + str(new_score)

func _on_grenade_changed(type_name: String) -> void:
	grenade_label.text = "[ " + type_name + " ]"
	if player != null:
		var idx: int = player.grenade_type
		grenade_label.add_theme_color_override("font_color", GRENADE_COLORS[idx])

func _on_player_died() -> void:
	message_label.text = "YOU DIED\nDepth %d | Score %d\nR to restart" % [RunState.depth, player.score if player else 0]
	message_label.modulate = Color(1.0, 0.3, 0.3)
	if player:
		player.set_physics_process(false)

func _on_level_exit() -> void:
	if player == null or player.is_dead:
		return
	RunState.save_from_player(player)
	RunState.advance_depth()
	player.set_physics_process(false)
	_show_upgrade_screen()

func _show_upgrade_screen() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.88)
	overlay.add_child(bg)

	var depth_label := Label.new()
	depth_label.text = "DEPTH %d  |  SCORE %d" % [RunState.depth, RunState.saved_score]
	depth_label.add_theme_font_size_override("font_size", 22)
	depth_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	depth_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	depth_label.add_theme_constant_override("outline_size", 4)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	depth_label.offset_top = 60.0
	depth_label.offset_bottom = 100.0
	overlay.add_child(depth_label)

	var title_label := Label.new()
	title_label.text = "CHOOSE AN UPGRADE"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 110.0
	title_label.offset_bottom = 160.0
	overlay.add_child(title_label)

	var shuffled: Array = UPGRADES.duplicate()
	shuffled.shuffle()
	var choices: Array = shuffled.slice(0, 3)

	var btn_w: float = 155.0
	var btn_h: float = 120.0
	var spacing: float = 20.0
	var total_w: float = btn_w * 3.0 + spacing * 2.0
	var start_x: float = (1152.0 - total_w) * 0.5
	var btn_y: float = 220.0

	for i in range(choices.size()):
		var upg: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = upg["name"] + "\n" + upg["desc"]
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.offset_left = start_x + float(i) * (btn_w + spacing)
		btn.offset_top = btn_y
		btn.offset_right = start_x + float(i) * (btn_w + spacing) + btn_w
		btn.offset_bottom = btn_y + btn_h

		var normal_style := _make_stylebox(Color(0.10, 0.14, 0.22))
		var hover_style := _make_stylebox(Color(0.22, 0.30, 0.45))
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_stylebox_override("focus", normal_style)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

		var upg_id: String = upg["id"]
		btn.pressed.connect(func():
			RunState.apply_upgrade(upg_id)
			overlay.queue_free()
			_fade_and_load()
		)
		overlay.add_child(btn)

func _fade_and_load() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)

	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0, 0, 0, 0)
	fade_layer.add_child(black)

	var tween := create_tween()
	tween.tween_property(black, "color", Color(0, 0, 0, 1), 0.4)
	tween.tween_callback(func():
		get_tree().reload_current_scene()
	)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.40, 0.52, 0.68)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb
