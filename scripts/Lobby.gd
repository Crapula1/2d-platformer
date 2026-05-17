extends Control
# Lobby: name + character + ready per player, host-only Start button.
# Shows the host's LAN IPs so others know what to type into Join.

const CHAR_COLORS := {
	"marine": Color(0.55, 0.92, 1.0),
	"demon":  Color(0.95, 0.35, 0.30),
}
const CHAR_DESCRIPTIONS := {
	"marine": "Standard kit:\nrifle + shotgun + axe combo",
	"demon":  "Flame-tinted bruiser:\nmelee hitbox only (no axe yet)",
}
const MARINE_ICON_PATH := "res://assets/sprites/frames/idle_0.png"

var list_box: VBoxContainer
var ready_btn: Button
var start_btn: Button
var status_label: Label
var count_label: Label
var address_label: Label
var char_tiles: Dictionary = {}  # character_name -> { panel, accent }

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

	# --- Character select tiles -----------------------------------------
	var pick_header := Label.new()
	pick_header.text = "PICK YOUR CHARACTER"
	pick_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pick_header.add_theme_font_size_override("font_size", 12)
	pick_header.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(pick_header)

	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 16)
	root.add_child(picker)
	for c in Net.CHARACTERS:
		picker.add_child(_build_character_tile(c))
	_refresh_tile_selection()

	# --- Action buttons --------------------------------------------------
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)

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

func _build_character_tile(character: String) -> Control:
	var accent: Color = CHAR_COLORS.get(character, Color(0.6, 0.85, 1.0))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 170)
	panel.add_theme_stylebox_override("panel", _tile_style(accent, false))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select_character(character)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	# Preview area: marine uses the idle sprite, demon gets a polygon mock-up.
	var preview := _build_preview(character, accent)
	preview.custom_minimum_size = Vector2(64, 70)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(preview)

	var name_lbl := Label.new()
	name_lbl.text = character.to_upper()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", accent)
	vb.add_child(name_lbl)

	var desc := Label.new()
	desc.text = CHAR_DESCRIPTIONS.get(character, "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vb.add_child(desc)

	char_tiles[character] = { "panel": panel, "accent": accent }
	return panel

func _build_preview(character: String, accent: Color) -> Control:
	if character == "marine":
		var tex := Control.new()
		var rect := TextureRect.new()
		rect.texture = load(MARINE_ICON_PATH) as Texture2D
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		tex.add_child(rect)
		return tex
	# Demon preview — small stylized stand-in with the avatar's accent color.
	var holder := Control.new()
	var body := ColorRect.new()
	body.color = accent
	body.offset_left = 18; body.offset_top = 24
	body.offset_right = 46; body.offset_bottom = 60
	holder.add_child(body)
	var head := ColorRect.new()
	head.color = accent.darkened(0.15)
	head.offset_left = 22; head.offset_top = 8
	head.offset_right = 42; head.offset_bottom = 26
	holder.add_child(head)
	var horn_l := Polygon2D.new()
	horn_l.color = Color(0.10, 0.05, 0.05)
	horn_l.polygon = PackedVector2Array([Vector2(22, 8), Vector2(26, 8), Vector2(24, 0), Vector2(20, 4)])
	holder.add_child(horn_l)
	var horn_r := Polygon2D.new()
	horn_r.color = Color(0.10, 0.05, 0.05)
	horn_r.polygon = PackedVector2Array([Vector2(38, 8), Vector2(42, 8), Vector2(44, 4), Vector2(40, 0)])
	holder.add_child(horn_r)
	var eye := ColorRect.new()
	eye.color = Color(1.0, 0.95, 0.4)
	eye.offset_left = 28; eye.offset_top = 14
	eye.offset_right = 36; eye.offset_bottom = 20
	holder.add_child(eye)
	return holder

func _tile_style(accent: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.14, 0.22) if not selected else Color(0.18, 0.25, 0.38)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = accent if selected else Color(0.30, 0.38, 0.50)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _refresh_tile_selection() -> void:
	for c in char_tiles.keys():
		var entry: Dictionary = char_tiles[c]
		var panel := entry["panel"] as PanelContainer
		var selected := (c == Net.local_character)
		panel.add_theme_stylebox_override("panel", _tile_style(entry["accent"], selected))

func _select_character(character: String) -> void:
	if Net.local_character == character:
		return
	Net.set_local_character(character)
	_refresh_tile_selection()

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
