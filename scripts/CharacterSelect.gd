extends Control

# Character + difficulty picker shown between MainMenu and the actual run.
# Writes the selection into RunState then starts the run by changing to
# Main.tscn. BACK returns to MainMenu without consuming a run.

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Main.tscn"

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "marine",
		"name": "MARINE",
		"desc": "Versatile rifle + shotgun + axe loadout.\nBalanced HP and mobility.",
		"tint": Color(0.35, 0.85, 1.0),
	},
	{
		"id": "demon",
		"name": "DEMON",
		"desc": "Lithe demonic brawler. Light frame,\nquick swings, single pair of horns.",
		"tint": Color(0.95, 0.30, 0.30),
	},
	{
		"id": "greater_demon",
		"name": "GREATER DEMON",
		"desc": "Heavy demonic warlord. Caped, twin\nhorn pairs, claws — armored melee.",
		"tint": Color(1.0, 0.55, 0.15),
	},
	{
		"id": "squirrel",
		"name": "SQUIRREL",
		"desc": "Humanoid squirrel with animated\nidle / walk / run / crouch / slide /\nslash / stab frames.",
		"tint": Color(0.85, 0.55, 0.22),
	},
]

var _selected_character: int = 0
var _selected_difficulty: int = RunState.DIFF_MEDIUM

var _char_buttons: Array[Button] = []
var _diff_buttons: Array[Button] = []
var _char_desc_label: Label = null
var _diff_summary_label: Label = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected_character = _char_index_from_id(RunState.character)
	_selected_difficulty = RunState.difficulty
	_build()
	_refresh_selection()

func _char_index_from_id(id: String) -> int:
	for i in CHARACTERS.size():
		if String(CHARACTERS[i]["id"]) == id:
			return i
	return 0

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.12, 1.0)
	add_child(bg)

	var title := Label.new()
	title.text = "SELECT CHARACTER & DIFFICULTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 5)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 28.0
	title.offset_bottom = 60.0
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	# --- Character row ---
	var char_label := Label.new()
	char_label.text = "CHARACTER"
	char_label.add_theme_font_size_override("font_size", 14)
	char_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vb.add_child(char_label)

	var char_row := HBoxContainer.new()
	char_row.add_theme_constant_override("separation", 10)
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(char_row)

	for i in CHARACTERS.size():
		var c: Dictionary = CHARACTERS[i]
		var btn := Button.new()
		btn.text = String(c["name"])
		btn.custom_minimum_size = Vector2(118, 56)
		btn.add_theme_font_size_override("font_size", 13)
		btn.toggle_mode = true
		btn.pressed.connect(_on_character_picked.bind(i))
		char_row.add_child(btn)
		_char_buttons.append(btn)

	_char_desc_label = Label.new()
	_char_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_desc_label.add_theme_font_size_override("font_size", 12)
	_char_desc_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	vb.add_child(_char_desc_label)

	# --- Difficulty row ---
	var diff_label := Label.new()
	diff_label.text = "DIFFICULTY"
	diff_label.add_theme_font_size_override("font_size", 14)
	diff_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vb.add_child(diff_label)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(diff_row)

	for i in RunState.DIFFICULTY_NAMES.size():
		var btn := Button.new()
		btn.text = RunState.DIFFICULTY_NAMES[i]
		btn.custom_minimum_size = Vector2(108, 40)
		btn.add_theme_font_size_override("font_size", 15)
		btn.toggle_mode = true
		btn.pressed.connect(_on_difficulty_picked.bind(i))
		diff_row.add_child(btn)
		_diff_buttons.append(btn)

	_diff_summary_label = Label.new()
	_diff_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diff_summary_label.add_theme_font_size_override("font_size", 12)
	_diff_summary_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	vb.add_child(_diff_summary_label)

	# --- Bottom buttons ---
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(120, 36)
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(_on_back)
	btn_row.add_child(back)

	var start := Button.new()
	start.text = "START RUN"
	start.custom_minimum_size = Vector2(160, 36)
	start.add_theme_font_size_override("font_size", 16)
	start.pressed.connect(_on_start)
	btn_row.add_child(start)
	start.grab_focus()

func _on_character_picked(i: int) -> void:
	_selected_character = i
	_refresh_selection()

func _on_difficulty_picked(i: int) -> void:
	_selected_difficulty = i
	_refresh_selection()

func _refresh_selection() -> void:
	for i in _char_buttons.size():
		_char_buttons[i].button_pressed = (i == _selected_character)
	for i in _diff_buttons.size():
		_diff_buttons[i].button_pressed = (i == _selected_difficulty)
	if _char_desc_label != null:
		_char_desc_label.text = String(CHARACTERS[_selected_character]["desc"])
	if _diff_summary_label != null:
		_diff_summary_label.text = _difficulty_summary(_selected_difficulty)

func _difficulty_summary(d: int) -> String:
	var t: Dictionary = RunState.DIFFICULTY_TABLE[d]
	return "Player HP x%.2f   |   Enemy HP x%.2f   |   Enemy Speed x%.2f" % [
		float(t["player_max_hp_mult"]),
		float(t["enemy_hp_mult"]),
		float(t["enemy_speed_mult"]),
	]

func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_start() -> void:
	RunState.character = String(CHARACTERS[_selected_character]["id"])
	RunState.set_difficulty(_selected_difficulty)
	RunState.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE)
