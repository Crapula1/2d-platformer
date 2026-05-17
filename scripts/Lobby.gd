extends Control
# Lobby: name + character + ready per player, host-only Start button.
# Shows the host's LAN IPs so others know what to type into Join.

const CHAR_COLORS := {
	"marine": Color(0.55, 0.92, 1.0),
	"demon":  Color(0.95, 0.35, 0.30),
}

var list_box: VBoxContainer
var ready_btn: Button
var char_btn: Button
var start_btn: Button
var status_label: Label
var count_label: Label
var address_label: Label

func _ready() -> void:
	Net.player_list_changed.connect(_refresh)
	Net.disconnected.connect(_on_disconnected)
	Net.game_started.connect(_on_game_started)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_top = 32
	root.offset_right = -60
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)

	address_label = Label.new()
	address_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	address_label.add_theme_font_size_override("font_size", 11)
	address_label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	root.add_child(address_label)
	_update_address_label()

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(count_label)

	var list_frame := PanelContainer.new()
	list_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_frame.custom_minimum_size = Vector2(0, 140)
	root.add_child(list_frame)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_frame.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)

	char_btn = Button.new()
	char_btn.text = "Character: %s" % Net.local_character
	char_btn.custom_minimum_size = Vector2(150, 28)
	char_btn.add_theme_font_size_override("font_size", 13)
	char_btn.pressed.connect(_on_cycle_character)
	controls.add_child(char_btn)

	ready_btn = Button.new()
	ready_btn.text = "Ready"
	ready_btn.custom_minimum_size = Vector2(100, 28)
	ready_btn.add_theme_font_size_override("font_size", 13)
	ready_btn.toggle_mode = true
	ready_btn.toggled.connect(_on_ready_toggled)
	controls.add_child(ready_btn)

	start_btn = Button.new()
	start_btn.text = "START GAME"
	start_btn.custom_minimum_size = Vector2(140, 28)
	start_btn.add_theme_font_size_override("font_size", 13)
	start_btn.disabled = true
	start_btn.pressed.connect(_on_start_pressed)
	controls.add_child(start_btn)

	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(80, 28)
	leave_btn.add_theme_font_size_override("font_size", 13)
	leave_btn.pressed.connect(_on_leave_pressed)
	controls.add_child(leave_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.4))
	root.add_child(status_label)

func _update_address_label() -> void:
	if Net.is_host:
		var ips: Array = []
		for ip in IP.get_local_addresses():
			# Filter to IPv4 LAN-ish addresses for readability.
			if ":" in ip:
				continue
			if ip.begins_with("127."):
				continue
			ips.append(ip)
		var port := Net.DEFAULT_PORT
		if ips.is_empty():
			address_label.text = "Hosting on port %d  (have clients connect to your IP:%d)" % [port, port]
		else:
			address_label.text = "Hosting on  %s:%d" % [", ".join(ips), port]
	else:
		address_label.text = "Connected as peer %d" % multiplayer.get_unique_id()

func _refresh() -> void:
	for c in list_box.get_children():
		c.queue_free()

	var my_id := multiplayer.get_unique_id()
	var keys := Net.players.keys()
	keys.sort()
	for id in keys:
		list_box.add_child(_make_row(id, Net.players[id], id == my_id))

	# Header counts + status updates.
	count_label.text = "Players %d / %d" % [Net.players.size(), Net.MAX_PLAYERS]
	if Net.is_host:
		start_btn.disabled = not Net.can_start()
		start_btn.visible = true
	else:
		start_btn.visible = false
	if not Net.is_host and Net.players.size() <= 1:
		status_label.text = "Connecting..."
	elif Net.is_host and Net.players.size() < 2:
		status_label.text = "Waiting for players to join — share the IP shown above."
	elif Net.is_host and not Net.can_start():
		status_label.text = "Waiting for everyone to ready up..."
	else:
		status_label.text = ""

func _make_row(id: int, p: Dictionary, is_me: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 22)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 16)
	swatch.color = CHAR_COLORS.get(String(p.character), Color(0.6, 0.85, 1.0))
	row.add_child(swatch)

	var name_lbl := Label.new()
	var marker := " (host)" if id == 1 else ""
	var you := "  [you]" if is_me else ""
	name_lbl.text = "%s%s%s" % [p.name, marker, you]
	name_lbl.custom_minimum_size = Vector2(220, 0)
	if is_me:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	row.add_child(name_lbl)

	var char_lbl := Label.new()
	char_lbl.text = String(p.character).to_upper()
	char_lbl.custom_minimum_size = Vector2(100, 0)
	char_lbl.add_theme_color_override("font_color", swatch.color)
	row.add_child(char_lbl)

	var ready_lbl := Label.new()
	ready_lbl.text = "READY" if p.ready else "..."
	ready_lbl.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if p.ready else Color(0.7, 0.7, 0.7))
	row.add_child(ready_lbl)

	return row

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
