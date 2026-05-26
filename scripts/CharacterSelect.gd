extends Control

# Character + difficulty picker shown between MainMenu and the actual run.
# Writes the selection into RunState then starts the run by changing to
# Main.tscn. BACK returns to MainMenu without consuming a run.
#
# The character section supports locked entries (visible but unpickable),
# explicit hover highlighting, a live preview panel (sprite + stats + lock
# hint), and a Random button that picks from the unlocked pool.

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const GAME_SCENE := "res://scenes/Main.tscn"
const MARINE_ICON_PATH := "res://assets/sprites/frames/idle_0.png"
const GREATER_DEMON_ICON_PATH := "res://assets/sprites/greater_demon/idle_0.png"

# Roster mirrors Net.CHARACTERS order. Add `locked = true` + an unlock_hint
# entry in Net.UNLOCK_HINTS to gate a character behind a future condition.
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
	{
		"id": "warden",
		"name": "WARDEN",
		"desc": "Disciplined veteran warden.\nIdentity TBD.",
		"tint": Color(0.85, 0.95, 0.65),
	},
]

const COL_HOVER  := Color(0.22, 0.30, 0.45)
const COL_PICKED := Color(0.30, 0.55, 0.40)
const COL_NORMAL := Color(0.10, 0.14, 0.22)
const COL_LOCKED := Color(0.08, 0.08, 0.10)

var _selected_character: int = 0
var _hovered_character: int = -1
var _selected_difficulty: int = RunState.DIFF_MEDIUM
var _selected_level: int = 0

var _char_buttons: Array[Button] = []
var _diff_buttons: Array[Button] = []
var _level_buttons: Array[Button] = []
var _level_summary_label: Label = null
var _preview_sprite: Control = null
var _preview_name: Label = null
var _preview_desc: Label = null
var _preview_stats: Label = null
var _preview_lock: Label = null
var _diff_summary_label: Label = null

func _ready() -> void:
	MenuBackground.show_scene("character_select")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected_character = _char_index_from_id(RunState.character)
	# If the saved pref points at a now-locked character, fall back to marine
	# so the picker doesn't start in an unselectable state.
	if Net.is_locked(CHARACTERS[_selected_character]["id"]):
		_selected_character = _char_index_from_id("marine")
		RunState.character = "marine"
	_selected_difficulty = RunState.difficulty
	_selected_level = clampi(RunState.start_level, 0, RunState.LEVEL_NAMES.size() - 1)
	_build()
	_refresh_selection()
	MobileUI.scale_menu(self)

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
	panel.custom_minimum_size = Vector2(620, 0)
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

	# Two columns: button grid on the left, live preview panel on the right.
	var pick_split := HBoxContainer.new()
	pick_split.add_theme_constant_override("separation", 14)
	vb.add_child(pick_split)

	var char_col := VBoxContainer.new()
	char_col.add_theme_constant_override("separation", 6)
	char_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_split.add_child(char_col)

	var char_grid := GridContainer.new()
	char_grid.columns = 3
	char_grid.add_theme_constant_override("h_separation", 8)
	char_grid.add_theme_constant_override("v_separation", 8)
	char_col.add_child(char_grid)

	for i in CHARACTERS.size():
		var c: Dictionary = CHARACTERS[i]
		var locked: bool = Net.is_locked(String(c["id"]))
		var btn := Button.new()
		btn.text = String(c["name"]) if not locked else "[ LOCKED ]"
		btn.custom_minimum_size = Vector2(140, 52)
		btn.add_theme_font_size_override("font_size", 12)
		btn.toggle_mode = true
		btn.disabled = locked
		_style_button(btn, locked)
		# Bind the index explicitly. Lambda capture of a loop-local var here
		# silently routed every press to the last iteration's index (warden,
		# locked), which made every pick fall back to marine.
		btn.pressed.connect(_on_character_picked.bind(i))
		btn.mouse_entered.connect(_on_character_hover.bind(i))
		btn.mouse_exited.connect(_on_character_hover.bind(-1))
		btn.focus_entered.connect(_on_character_hover.bind(i))
		char_grid.add_child(btn)
		_char_buttons.append(btn)

	var random_btn := Button.new()
	random_btn.text = "RANDOM"
	random_btn.custom_minimum_size = Vector2(140, 30)
	random_btn.add_theme_font_size_override("font_size", 13)
	random_btn.pressed.connect(_on_random_pressed)
	char_col.add_child(random_btn)

	# Preview panel
	pick_split.add_child(_build_preview_panel())

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

	# --- Starting level row ---
	var level_label := Label.new()
	level_label.text = "STARTING LEVEL"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	vb.add_child(level_label)

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(level_row)

	for i in RunState.LEVEL_NAMES.size():
		var btn := Button.new()
		btn.text = RunState.LEVEL_NAMES[i]
		btn.custom_minimum_size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", 15)
		btn.toggle_mode = true
		_style_button(btn, false)
		btn.pressed.connect(_on_level_picked.bind(i))
		level_row.add_child(btn)
		_level_buttons.append(btn)

	_level_summary_label = Label.new()
	_level_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_summary_label.add_theme_font_size_override("font_size", 12)
	_level_summary_label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	vb.add_child(_level_summary_label)

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

func _build_preview_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_theme_stylebox_override("panel", _stylebox(Color(0.06, 0.09, 0.15), Color(0.30, 0.40, 0.55)))

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 10)
	pm.add_theme_constant_override("margin_right", 10)
	pm.add_theme_constant_override("margin_top", 10)
	pm.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(pm)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	pm.add_child(vb)

	# Sprite holder — swapped out each refresh so the visual matches the
	# character class. Uses the same builders as the multiplayer Lobby.
	_preview_sprite = Control.new()
	_preview_sprite.custom_minimum_size = Vector2(96, 96)
	_preview_sprite.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_preview_sprite)

	_preview_name = Label.new()
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.add_theme_font_size_override("font_size", 14)
	vb.add_child(_preview_name)

	_preview_desc = Label.new()
	_preview_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_desc.add_theme_font_size_override("font_size", 10)
	_preview_desc.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0))
	vb.add_child(_preview_desc)

	_preview_stats = Label.new()
	_preview_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_stats.add_theme_font_size_override("font_size", 10)
	_preview_stats.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	vb.add_child(_preview_stats)

	_preview_lock = Label.new()
	_preview_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_lock.add_theme_font_size_override("font_size", 10)
	_preview_lock.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35))
	vb.add_child(_preview_lock)

	return panel

func _on_character_picked(i: int) -> void:
	if Net.is_locked(String(CHARACTERS[i]["id"])):
		return
	_selected_character = i
	_refresh_selection()

func _on_character_hover(i: int) -> void:
	_hovered_character = i
	_refresh_preview()

func _on_difficulty_picked(i: int) -> void:
	_selected_difficulty = i
	_refresh_selection()

func _on_level_picked(i: int) -> void:
	_selected_level = i
	_refresh_selection()

func _on_random_pressed() -> void:
	# Pick from unlocked pool only.
	var pool: Array[int] = []
	for i in CHARACTERS.size():
		if not Net.is_locked(String(CHARACTERS[i]["id"])):
			pool.append(i)
	if pool.is_empty():
		return
	_selected_character = pool[randi() % pool.size()]
	_refresh_selection()

func _refresh_selection() -> void:
	for i in _char_buttons.size():
		var locked: bool = Net.is_locked(String(CHARACTERS[i]["id"]))
		_char_buttons[i].button_pressed = (i == _selected_character) and not locked
	for i in _diff_buttons.size():
		_diff_buttons[i].button_pressed = (i == _selected_difficulty)
	if _diff_summary_label != null:
		_diff_summary_label.text = _difficulty_summary(_selected_difficulty)
	for i in _level_buttons.size():
		_level_buttons[i].button_pressed = (i == _selected_level)
	if _level_summary_label != null:
		_level_summary_label.text = RunState.LEVEL_DESCS[_selected_level]
	_refresh_preview()

func _refresh_preview() -> void:
	if _preview_name == null:
		return
	var idx: int = _hovered_character if _hovered_character >= 0 else _selected_character
	if idx < 0 or idx >= CHARACTERS.size():
		return
	var c: Dictionary = CHARACTERS[idx]
	var id := String(c["id"])
	var locked: bool = Net.is_locked(id)

	# Rebuild the sprite preview holder.
	for child in _preview_sprite.get_children():
		child.queue_free()
	var inner := _build_preview_visual(id, c["tint"] as Color)
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.modulate = Color(0.35, 0.35, 0.40) if locked else Color.WHITE
	_preview_sprite.add_child(inner)

	_preview_name.text = String(c["name"]) if not locked else "??? (LOCKED)"
	_preview_name.add_theme_color_override("font_color", c["tint"] if not locked else Color(0.6, 0.6, 0.65))
	_preview_desc.text = String(c["desc"])

	var stats: Dictionary = RunState.CHARACTER_STATS.get(id, {})
	if stats.is_empty():
		_preview_stats.text = ""
	else:
		_preview_stats.text = "HP %d   SPD x%.2f   ATK x%.2f" % [
			int(stats.get("max_health", 10)),
			float(stats.get("speed_mult", 1.0)),
			float(stats.get("attack_mult", 1.0)),
		]

	if locked:
		_preview_lock.text = "LOCKED — " + String(Net.UNLOCK_HINTS.get(id, ""))
		_preview_lock.visible = true
	else:
		_preview_lock.visible = false

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
	var id := String(CHARACTERS[_selected_character]["id"])
	if Net.is_locked(id):
		return
	RunState.character = id
	RunState.set_difficulty(_selected_difficulty)
	RunState.start_level = _selected_level
	RunState.save_prefs()
	RunState.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE)

# --- Preview builders (mirror the multiplayer Lobby visuals) ---------------

func _build_preview_visual(character: String, accent: Color) -> Control:
	match character:
		"marine":         return _marine_preview()
		"greater_demon":  return _greater_demon_preview(accent)
		"squirrel":       return _squirrel_preview(accent)
		"warden":         return _warden_preview(accent)
		_:                return _demon_preview(accent)

func _marine_preview() -> Control:
	var holder := Control.new()
	var rect := TextureRect.new()
	rect.texture = load(MARINE_ICON_PATH) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	holder.add_child(rect)
	return holder

func _demon_preview(accent: Color) -> Control:
	var holder := Control.new()
	var body := ColorRect.new()
	body.color = accent
	body.offset_left = 34; body.offset_top = 36
	body.offset_right = 74; body.offset_bottom = 92
	holder.add_child(body)
	var head := ColorRect.new()
	head.color = accent.darkened(0.15)
	head.offset_left = 38; head.offset_top = 12
	head.offset_right = 70; head.offset_bottom = 38
	holder.add_child(head)
	var eye := ColorRect.new()
	eye.color = Color(1.0, 0.95, 0.4)
	eye.offset_left = 46; eye.offset_top = 22
	eye.offset_right = 62; eye.offset_bottom = 30
	holder.add_child(eye)
	return holder

func _greater_demon_preview(_accent: Color) -> Control:
	var holder := Control.new()
	var rect := TextureRect.new()
	rect.texture = load(GREATER_DEMON_ICON_PATH) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	holder.add_child(rect)
	return holder

func _squirrel_preview(accent: Color) -> Control:
	var holder := Control.new()
	var tail := Polygon2D.new()
	tail.color = accent.darkened(0.10)
	tail.polygon = PackedVector2Array([
		Vector2(60, 84), Vector2(82, 76), Vector2(88, 48),
		Vector2(78, 26), Vector2(66, 38), Vector2(70, 62),
	])
	holder.add_child(tail)
	var body := ColorRect.new()
	body.color = accent
	body.offset_left = 34; body.offset_top = 44
	body.offset_right = 62; body.offset_bottom = 88
	holder.add_child(body)
	var head := ColorRect.new()
	head.color = accent.lightened(0.10)
	head.offset_left = 36; head.offset_top = 20
	head.offset_right = 60; head.offset_bottom = 44
	holder.add_child(head)
	return holder

func _warden_preview(accent: Color) -> Control:
	var holder := Control.new()
	var silhouette := Polygon2D.new()
	silhouette.color = accent.darkened(0.45)
	silhouette.polygon = PackedVector2Array([
		Vector2(38, 14), Vector2(58, 14), Vector2(64, 30),
		Vector2(70, 80), Vector2(26, 80), Vector2(32, 30),
	])
	holder.add_child(silhouette)
	var question := Label.new()
	question.text = "?"
	question.add_theme_font_size_override("font_size", 40)
	question.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65))
	question.anchor_right = 1.0
	question.anchor_bottom = 1.0
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(question)
	return holder

# --- Styling helpers -------------------------------------------------------

func _style_button(btn: Button, locked: bool) -> void:
	var base := COL_LOCKED if locked else COL_NORMAL
	btn.add_theme_stylebox_override("normal", _stylebox(base))
	btn.add_theme_stylebox_override("hover", _stylebox(COL_HOVER))
	btn.add_theme_stylebox_override("focus", _stylebox(COL_HOVER))
	btn.add_theme_stylebox_override("pressed", _stylebox(COL_PICKED))
	btn.add_theme_stylebox_override("disabled", _stylebox(COL_LOCKED, Color(0.20, 0.20, 0.22)))
	btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.50))

func _stylebox(bg: Color, border: Color = Color(0.40, 0.52, 0.68)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = border
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb
