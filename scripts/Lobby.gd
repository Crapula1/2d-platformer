extends Control
# Lobby: name + character + ready per player, host-only Start button.
# Shows the host's LAN IPs so others know what to type into Join.

const CHAR_COLORS := {
	"marine":        Color(0.55, 0.92, 1.0),
	"demon":         Color(0.95, 0.35, 0.30),
	"greater_demon": Color(1.0, 0.55, 0.15),
	"squirrel":      Color(0.85, 0.55, 0.22),
	"warden":        Color(0.85, 0.95, 0.65),
}
const CHAR_DESCRIPTIONS := {
	"marine":        "Standard kit:\nrifle + shotgun + axe combo",
	"demon":         "Flame-tinted bruiser:\nmelee hitbox only (no axe yet)",
	"greater_demon": "Caped warlord:\ntwin horns, armored melee",
	"squirrel":      "Quick scrapper:\nslash / stab / slide kit",
	"warden":        "Disciplined veteran:\nidentity TBD",
}
const MARINE_ICON_PATH := "res://assets/sprites/frames/idle_0.png"
const GREATER_DEMON_ICON_PATH := "res://assets/sprites/greater_demon/idle_0.png"

var list_box: VBoxContainer
var ready_btn: Button
var start_btn: Button
var status_label: Label
var count_label: Label
var address_label: Label
var char_tiles: Dictionary = {}  # character_name -> { panel, accent }

func _ready() -> void:
	MenuBackground.show()
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

	# Margins tuned for the 640×360 design viewport — content stretches to
	# fill whatever window size canvas_items mode scales us to.
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 8
	root.offset_right = -20
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var title := Label.new()
	title.text = "LOBBY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)

	# Combined address + player count line keeps the header compact.
	address_label = Label.new()
	address_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	address_label.add_theme_font_size_override("font_size", 10)
	address_label.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	root.add_child(address_label)

	count_label = Label.new()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 10)
	count_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(count_label)
	_update_address_label()

	var list_frame := PanelContainer.new()
	list_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_frame.custom_minimum_size = Vector2(0, 60)
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
	pick_header.add_theme_font_size_override("font_size", 10)
	pick_header.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	root.add_child(pick_header)

	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.add_theme_constant_override("separation", 10)
	root.add_child(picker)
	for c in Net.CHARACTERS:
		picker.add_child(_build_character_tile(c))
	_refresh_tile_selection()

	# --- Action buttons --------------------------------------------------
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)

	var random_btn := Button.new()
	random_btn.text = "Random"
	random_btn.custom_minimum_size = Vector2(90, 28)
	random_btn.add_theme_font_size_override("font_size", 13)
	random_btn.pressed.connect(_on_random_pressed)
	controls.add_child(random_btn)

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
	# Render MAX_PLAYERS fixed slots so players see all P1..P4 boxes whether
	# or not they're filled. Slot order: host first, then remaining peers in
	# join order (ascending peer id).
	var keys := Net.players.keys()
	keys.sort()
	# Pull the host (id 1) to the front so they're always P1.
	if 1 in keys:
		keys.erase(1)
		keys.push_front(1)
	for slot in Net.MAX_PLAYERS:
		if slot < keys.size():
			var id: int = keys[slot]
			list_box.add_child(_make_row(slot + 1, id, Net.players[id], id == my_id))
		else:
			list_box.add_child(_make_empty_row(slot + 1))

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

func _make_row(slot: int, id: int, p: Dictionary, is_me: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 22)

	var slot_lbl := Label.new()
	slot_lbl.text = "P%d" % slot
	slot_lbl.custom_minimum_size = Vector2(28, 0)
	slot_lbl.add_theme_font_size_override("font_size", 12)
	slot_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.95, 0.6) if is_me else Color(0.55, 0.7, 0.85))
	row.add_child(slot_lbl)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 16)
	swatch.color = CHAR_COLORS.get(String(p.character), Color(0.6, 0.85, 1.0))
	row.add_child(swatch)

	var name_lbl := Label.new()
	var marker := " (host)" if id == 1 else ""
	var you := "  [you]" if is_me else ""
	name_lbl.text = "%s%s%s" % [p.name, marker, you]
	name_lbl.custom_minimum_size = Vector2(200, 0)
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

func _make_empty_row(slot: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 22)

	var slot_lbl := Label.new()
	slot_lbl.text = "P%d" % slot
	slot_lbl.custom_minimum_size = Vector2(28, 0)
	slot_lbl.add_theme_font_size_override("font_size", 12)
	slot_lbl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50))
	row.add_child(slot_lbl)

	var status := Label.new()
	status.text = "— open slot —"
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", Color(0.40, 0.45, 0.55))
	row.add_child(status)

	return row

func _build_character_tile(character: String) -> Control:
	var accent: Color = CHAR_COLORS.get(character, Color(0.6, 0.85, 1.0))
	var locked: bool = Net.is_locked(character)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 110)
	panel.add_theme_stylebox_override("panel", _tile_style(accent, false, false, locked))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Locked tiles still respond to hover so the lock hint is discoverable,
	# but clicks are dropped before reaching Net.set_local_character.
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_select_character(character)
	)
	panel.mouse_entered.connect(func() -> void: _on_tile_hover(character, true))
	panel.mouse_exited.connect(func() -> void: _on_tile_hover(character, false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)

	# Preview area: marine uses the idle sprite, demon gets a polygon mock-up.
	var preview := _build_preview(character, accent)
	preview.custom_minimum_size = Vector2(48, 48)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(preview)

	var name_lbl := Label.new()
	name_lbl.text = character.to_upper() if not locked else "[ LOCKED ]"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", accent if not locked else Color(0.55, 0.55, 0.60))
	vb.add_child(name_lbl)

	var desc_text: String = CHAR_DESCRIPTIONS.get(character, "")
	if locked:
		desc_text = "LOCKED\n" + String(Net.UNLOCK_HINTS.get(character, ""))
	var desc := Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 8)
	desc.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35) if locked else Color(0.7, 0.8, 0.9))
	vb.add_child(desc)

	if locked:
		preview.modulate = Color(0.35, 0.35, 0.40)

	char_tiles[character] = { "panel": panel, "accent": accent, "locked": locked }
	return panel

func _build_preview(character: String, accent: Color) -> Control:
	match character:
		"marine":         return _build_marine_preview()
		"greater_demon":  return _build_greater_demon_preview(accent)
		"squirrel":       return _build_squirrel_preview(accent)
		"warden":         return _build_warden_preview(accent)
		_:                return _build_demon_preview(accent)

func _build_warden_preview(accent: Color) -> Control:
	# Placeholder silhouette + "?" — warden has no Player scene yet, this just
	# fills the locked tile.
	var holder := Control.new()
	var silhouette := Polygon2D.new()
	silhouette.color = accent.darkened(0.45)
	silhouette.polygon = PackedVector2Array([
		Vector2(20, 6), Vector2(36, 6), Vector2(40, 16),
		Vector2(44, 56), Vector2(12, 56), Vector2(16, 16),
	])
	holder.add_child(silhouette)
	var question := Label.new()
	question.text = "?"
	question.add_theme_font_size_override("font_size", 28)
	question.add_theme_color_override("font_color", accent)
	question.anchor_right = 1.0
	question.anchor_bottom = 1.0
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(question)
	return holder

func _build_marine_preview() -> Control:
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

func _build_demon_preview(accent: Color) -> Control:
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

func _build_greater_demon_preview(_accent: Color) -> Control:
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

func _build_squirrel_preview(accent: Color) -> Control:
	# Small body + oversized bushy tail curling up behind it.
	var holder := Control.new()
	var tail := Polygon2D.new()
	tail.color = accent.darkened(0.10)
	tail.polygon = PackedVector2Array([
		Vector2(40, 56), Vector2(54, 50), Vector2(58, 32),
		Vector2(52, 18), Vector2(44, 26), Vector2(46, 42),
	])
	holder.add_child(tail)
	var body := ColorRect.new()
	body.color = accent
	body.offset_left = 22; body.offset_top = 30
	body.offset_right = 42; body.offset_bottom = 58
	holder.add_child(body)
	var head := ColorRect.new()
	head.color = accent.lightened(0.10)
	head.offset_left = 24; head.offset_top = 14
	head.offset_right = 40; head.offset_bottom = 30
	holder.add_child(head)
	var ear_l := Polygon2D.new()
	ear_l.color = accent.darkened(0.20)
	ear_l.polygon = PackedVector2Array([Vector2(24, 14), Vector2(28, 14), Vector2(26, 8)])
	holder.add_child(ear_l)
	var ear_r := Polygon2D.new()
	ear_r.color = accent.darkened(0.20)
	ear_r.polygon = PackedVector2Array([Vector2(36, 14), Vector2(40, 14), Vector2(38, 8)])
	holder.add_child(ear_r)
	var eye := ColorRect.new()
	eye.color = Color(0.05, 0.05, 0.05)
	eye.offset_left = 30; eye.offset_top = 19
	eye.offset_right = 34; eye.offset_bottom = 23
	holder.add_child(eye)
	return holder

func _tile_style(accent: Color, selected: bool, hovered: bool = false, locked: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if locked:
		sb.bg_color = Color(0.07, 0.08, 0.12)
	elif selected:
		sb.bg_color = Color(0.18, 0.25, 0.38)
	elif hovered:
		sb.bg_color = Color(0.14, 0.20, 0.32)
	else:
		sb.bg_color = Color(0.10, 0.14, 0.22)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	if locked:
		sb.border_color = Color(0.25, 0.25, 0.30)
	elif selected:
		sb.border_color = accent
	elif hovered:
		sb.border_color = accent.lerp(Color(0.9, 0.95, 1.0), 0.3)
	else:
		sb.border_color = Color(0.30, 0.38, 0.50)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb

func _refresh_tile_selection(hovered_char: String = "") -> void:
	for c: String in char_tiles.keys():
		var entry: Dictionary = char_tiles[c]
		var panel := entry["panel"] as PanelContainer
		var selected: bool = (c == Net.local_character)
		var hovered: bool = (c == hovered_char)
		var locked: bool = bool(entry.get("locked", false))
		panel.add_theme_stylebox_override("panel", _tile_style(entry["accent"], selected, hovered, locked))

func _on_tile_hover(character: String, hovered: bool) -> void:
	_refresh_tile_selection(character if hovered else "")

func _select_character(character: String) -> void:
	if Net.is_locked(character):
		return
	if Net.local_character == character:
		return
	Net.set_local_character(character)
	_refresh_tile_selection()

func _on_random_pressed() -> void:
	_select_character(Net.random_unlocked_character())

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
