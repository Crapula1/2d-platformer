extends Control

var list_box: VBoxContainer
var ready_btn: Button
var char_btn: Button
var start_btn: Button
var status_label: Label

func _ready() -> void:
	Net.player_list_changed.connect(_refresh)
	Net.disconnected.connect(_on_disconnected)
	Net.game_started.connect(_on_game_started)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.13)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_top = 40
	root.offset_right = -60
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "LOBBY"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	root.add_child(title)

	var info := Label.new()
	info.text = "Host port: %d  |  Your peer id: %d" % [Net.DEFAULT_PORT, multiplayer.get_unique_id()]
	info.add_theme_color_override("font_color", Color(0.6, 0.75, 0.95))
	root.add_child(info)

	var list_frame := PanelContainer.new()
	list_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list_frame)

	var scroll := ScrollContainer.new()
	list_frame.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)

	char_btn = Button.new()
	char_btn.text = "Character: %s" % Net.local_character
	char_btn.pressed.connect(_on_cycle_character)
	controls.add_child(char_btn)

	ready_btn = Button.new()
	ready_btn.text = "Ready"
	ready_btn.toggle_mode = true
	ready_btn.toggled.connect(_on_ready_toggled)
	controls.add_child(ready_btn)

	start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.disabled = true
	start_btn.pressed.connect(_on_start_pressed)
	controls.add_child(start_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.pressed.connect(_on_leave_pressed)
	controls.add_child(leave_btn)

	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	root.add_child(status_label)

func _refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()

	var my_id := multiplayer.get_unique_id()
	var keys := Net.players.keys()
	keys.sort()
	for id in keys:
		var p: Dictionary = Net.players[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var name_lbl := Label.new()
		var marker := " (host)" if id == 1 else ""
		var you := "  [you]" if id == my_id else ""
		name_lbl.text = "%s%s%s" % [p.name, marker, you]
		name_lbl.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_lbl)

		var char_lbl := Label.new()
		char_lbl.text = p.character
		char_lbl.custom_minimum_size = Vector2(120, 0)
		char_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
		row.add_child(char_lbl)

		var ready_lbl := Label.new()
		ready_lbl.text = "READY" if p.ready else "..."
		ready_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if p.ready else Color(0.7, 0.7, 0.7))
		row.add_child(ready_lbl)

		list_box.add_child(row)

	if Net.is_host:
		start_btn.disabled = not Net.can_start()
		start_btn.visible = true
	else:
		start_btn.visible = false

	if not Net.is_host and Net.players.size() <= 1:
		status_label.text = "Connecting..."
	elif Net.is_host and Net.players.size() < 2:
		status_label.text = "Waiting for players to join..."
	else:
		status_label.text = ""

func _on_cycle_character() -> void:
	var idx := Net.CHARACTERS.find(Net.local_character)
	idx = (idx + 1) % Net.CHARACTERS.size()
	Net.set_local_character(Net.CHARACTERS[idx])
	char_btn.text = "Character: %s" % Net.local_character

func _on_ready_toggled(pressed: bool) -> void:
	Net.set_local_ready(pressed)
	ready_btn.text = "Unready" if pressed else "Ready"

func _on_start_pressed() -> void:
	Net.start_game()

func _on_leave_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file(Net.MENU_SCENE_PATH)

func _on_disconnected() -> void:
	get_tree().change_scene_to_file(Net.MENU_SCENE_PATH)

func _on_game_started() -> void:
	pass  # change_scene happens inside Net._start_game_rpc
