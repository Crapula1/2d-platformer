extends Control

# Rebindable controls menu. Works both as a standalone scene (from the
# main menu — back returns to main menu) and as an overlay (from the
# pause menu — back emits `closed` and the host frees us).

signal closed

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

const ACTION_LABELS: Array[Array] = [
	["move_left",      "Move Left"],
	["move_right",     "Move Right"],
	["jump",           "Jump"],
	["crouch",         "Crouch"],
	["sprint",         "Sprint"],
	["attack",         "Bash / Attack"],
	["shoot",          "Shoot"],
	["throw_grenade",  "Throw Grenade"],
	["cycle_grenade",  "Cycle Grenade"],
	["cycle_weapon",   "Cycle Weapon"],
	["select_rifle",   "Select Rifle"],
	["select_shotgun", "Select Shotgun"],
	["dash",           "Dash"],
	["roll",           "Roll"],
	["interact",       "Interact"],
	["restart",        "Restart Run"],
	["pause",          "Pause Menu"],
]

var is_overlay: bool = false

var _waiting_action: String = ""
var _waiting_button: Button = null
var _row_buttons: Dictionary = {}  # action -> Button
var _hint: Label = null

func _ready() -> void:
	MenuBackground.show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	MobileUI.scale_menu(self)

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.95)
	add_child(bg)

	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 5)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24.0
	title.offset_bottom = 56.0
	add_child(title)

	_hint = Label.new()
	_hint.text = "Click a binding, then press any key or mouse button. Esc cancels."
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.6, 0.78, 0.95))
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 60.0
	_hint.offset_bottom = 80.0
	add_child(_hint)

	# Centered panel containing the scrolling list + bottom buttons.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 480)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -200
	panel.offset_bottom = 280
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for entry in ACTION_LABELS:
		_add_row(list, String(entry[0]), String(entry[1]))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btn_row)

	var reset_all := Button.new()
	reset_all.text = "RESET ALL"
	reset_all.custom_minimum_size = Vector2(110, 28)
	reset_all.pressed.connect(_on_reset_all)
	btn_row.add_child(reset_all)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(110, 28)
	back.pressed.connect(_on_back)
	btn_row.add_child(back)
	back.grab_focus()

func _add_row(parent: Node, action: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	row.add_child(label)

	var bind_btn := Button.new()
	bind_btn.custom_minimum_size = Vector2(150, 24)
	bind_btn.add_theme_font_size_override("font_size", 13)
	bind_btn.text = Settings.describe_event(Settings.get_primary_event_for(action))
	bind_btn.pressed.connect(_on_bind_pressed.bind(action, bind_btn))
	row.add_child(bind_btn)
	_row_buttons[action] = bind_btn

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.custom_minimum_size = Vector2(28, 24)
	reset_btn.pressed.connect(_on_reset_one.bind(action))
	row.add_child(reset_btn)

func _on_bind_pressed(action: String, btn: Button) -> void:
	if _waiting_action != "":
		_cancel_wait()
	_waiting_action = action
	_waiting_button = btn
	btn.text = "press a key…"
	btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

func _cancel_wait() -> void:
	if _waiting_button != null and is_instance_valid(_waiting_button):
		_waiting_button.text = Settings.describe_event(Settings.get_primary_event_for(_waiting_action))
		_waiting_button.remove_theme_color_override("font_color")
	_waiting_action = ""
	_waiting_button = null

func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	# Escape cancels a pending rebind without consuming the key.
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_ESCAPE:
			accept_event()
			_cancel_wait()
			return
		if k.pressed and not k.echo:
			_finish_bind(event)
			accept_event()
			return
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_finish_bind(event)
			accept_event()
			return
	elif event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if jb.pressed:
			_finish_bind(event)
			accept_event()
			return

func _finish_bind(ev: InputEvent) -> void:
	var action := _waiting_action
	var btn := _waiting_button
	Settings.set_binding(action, ev)
	_waiting_action = ""
	_waiting_button = null
	if btn != null and is_instance_valid(btn):
		btn.text = Settings.describe_event(Settings.get_primary_event_for(action))
		btn.remove_theme_color_override("font_color")
	_refresh_all_labels()

func _refresh_all_labels() -> void:
	for action in _row_buttons.keys():
		var btn: Button = _row_buttons[action]
		if is_instance_valid(btn):
			btn.text = Settings.describe_event(Settings.get_primary_event_for(action))

func _on_reset_one(action: String) -> void:
	if _waiting_action != "":
		_cancel_wait()
	Settings.reset_binding(action)
	_refresh_all_labels()

func _on_reset_all() -> void:
	if _waiting_action != "":
		_cancel_wait()
	Settings.reset_all_bindings()
	_refresh_all_labels()

func _on_back() -> void:
	if _waiting_action != "":
		_cancel_wait()
		return
	if is_overlay:
		closed.emit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
