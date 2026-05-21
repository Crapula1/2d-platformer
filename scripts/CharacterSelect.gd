extends Control

# Drives the character-select screen. Cards, preview panel, and player slots
# are all built procedurally from CharacterDB and Lobby state so adding a
# character is a pure data edit (no scene work).

const GAME_SCENE := "res://scenes/Main.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var grid: GridContainer = $Layout/Center/Grid
@onready var preview_sprite: TextureRect = $Layout/Preview/Margin/VBox/Sprite
@onready var preview_name: Label = $Layout/Preview/Margin/VBox/Name
@onready var preview_blurb: Label = $Layout/Preview/Margin/VBox/Blurb
@onready var preview_stats: Label = $Layout/Preview/Margin/VBox/Stats
@onready var preview_lock: Label = $Layout/Preview/Margin/VBox/LockHint
@onready var slots_box: HBoxContainer = $Layout/Slots/HBox
@onready var ready_button: Button = $Layout/Buttons/Ready
@onready var random_button: Button = $Layout/Buttons/Random
@onready var back_button: Button = $Layout/Buttons/Back
@onready var status_label: Label = $Layout/Status

const CARD_SIZE := Vector2(96, 112)
const CARD_NORMAL := Color(0.10, 0.14, 0.22)
const CARD_HOVER  := Color(0.22, 0.30, 0.45)
const CARD_PICKED := Color(0.30, 0.55, 0.40)
const CARD_LOCKED := Color(0.08, 0.08, 0.10)

var _cards: Array = []  # parallel to CharacterDB.CHARACTERS
var _hovered_index: int = -1
var _focused_index: int = 0

func _ready() -> void:
	# Always have a lobby — singleplayer is just a 1-slot offline lobby.
	if Lobby.slots.is_empty():
		Lobby.start_offline()

	_build_cards()
	_build_slots()

	random_button.pressed.connect(_on_random)
	ready_button.pressed.connect(_on_ready_pressed)
	back_button.pressed.connect(_on_back)

	Lobby.slots_changed.connect(_on_slots_changed)
	Lobby.start_game.connect(_on_start_game)

	_focus_card(0)
	_refresh_preview()
	_refresh_slots()
	_refresh_status()

func _build_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	_cards.clear()
	grid.columns = mini(CharacterDB.count(), 4)

	for i in CharacterDB.count():
		var data: Dictionary = CharacterDB.CHARACTERS[i]
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.toggle_mode = false
		card.focus_mode = Control.FOCUS_ALL
		card.disabled = data["locked"]
		card.add_theme_stylebox_override("normal", _stylebox(CARD_LOCKED if data["locked"] else CARD_NORMAL))
		card.add_theme_stylebox_override("hover", _stylebox(CARD_HOVER))
		card.add_theme_stylebox_override("focus", _stylebox(CARD_HOVER))
		card.add_theme_stylebox_override("pressed", _stylebox(CARD_PICKED))
		card.add_theme_stylebox_override("disabled", _stylebox(CARD_LOCKED))
		card.add_theme_font_size_override("font_size", 11)

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(v)

		var portrait := TextureRect.new()
		portrait.texture = data["sprite"]
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.modulate = data["tint"] if not data["locked"] else Color(0.25, 0.25, 0.30)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(portrait)

		var name_label := Label.new()
		name_label.text = data["name"] if not data["locked"] else "???"
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0) if not data["locked"] else Color(0.5, 0.5, 0.55))
		v.add_child(name_label)

		if data["locked"]:
			var lock := Label.new()
			lock.text = "[ LOCKED ]"
			lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock.add_theme_font_size_override("font_size", 14)
			v.add_child(lock)

		var idx := i
		card.mouse_entered.connect(func() -> void: _on_card_hovered(idx))
		card.mouse_exited.connect(func() -> void: _on_card_unhovered(idx))
		card.focus_entered.connect(func() -> void: _on_card_hovered(idx))
		card.pressed.connect(func() -> void: _on_card_pressed(idx))

		grid.add_child(card)
		_cards.append(card)

func _build_slots() -> void:
	for child in slots_box.get_children():
		child.queue_free()

	for i in Lobby.slots.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(120, 72)
		panel.add_theme_stylebox_override("panel", _stylebox(Color(0.06, 0.09, 0.15)))

		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)

		var header := Label.new()
		header.text = "PLAYER %d" % (i + 1)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_theme_font_size_override("font_size", 11)
		header.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
		header.name = "Header"
		v.add_child(header)

		var pick := Label.new()
		pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pick.add_theme_font_size_override("font_size", 13)
		pick.name = "Pick"
		v.add_child(pick)

		var ready_state := Label.new()
		ready_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ready_state.add_theme_font_size_override("font_size", 10)
		ready_state.name = "Ready"
		v.add_child(ready_state)

		slots_box.add_child(panel)

func _on_card_hovered(idx: int) -> void:
	_hovered_index = idx
	_focused_index = idx
	_refresh_preview()

func _on_card_unhovered(_idx: int) -> void:
	_hovered_index = -1
	_refresh_preview()

func _on_card_pressed(idx: int) -> void:
	var data: Dictionary = CharacterDB.CHARACTERS[idx]
	if data["locked"]:
		return
	Lobby.request_select(data["id"])

func _on_random() -> void:
	var id := CharacterDB.random_unlocked_id()
	Lobby.request_select(id)
	_focused_index = CharacterDB.index_of(id)
	_cards[_focused_index].grab_focus()

func _on_ready_pressed() -> void:
	var idx := Lobby.local_slot_index()
	if idx < 0:
		return
	var currently_ready: bool = Lobby.slots[idx]["ready"]
	Lobby.request_ready(not currently_ready)

func _on_back() -> void:
	Lobby.leave()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_slots_changed() -> void:
	_refresh_slots()
	_refresh_status()
	_refresh_card_marks()

func _on_start_game() -> void:
	var idx := Lobby.local_slot_index()
	if idx >= 0:
		RunState.selected_character_id = Lobby.slots[idx]["character_id"]
	RunState.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE)

func _focus_card(idx: int) -> void:
	if idx >= 0 and idx < _cards.size():
		_cards[idx].grab_focus()

func _refresh_preview() -> void:
	var idx := _hovered_index if _hovered_index >= 0 else _focused_index
	if idx < 0 or idx >= CharacterDB.count():
		return
	var data: Dictionary = CharacterDB.CHARACTERS[idx]
	preview_sprite.texture = data["sprite"]
	preview_sprite.modulate = data["tint"] if not data["locked"] else Color(0.3, 0.3, 0.35)
	preview_name.text = data["name"] if not data["locked"] else "??? (LOCKED)"
	preview_blurb.text = data["blurb"]
	preview_stats.text = "SPD x%.2f   HP %s%d   ATK %s%d" % [
		data["speed_mult"],
		"+" if data["hp_bonus"] >= 0 else "",
		data["hp_bonus"],
		"+" if data["attack_bonus"] >= 0 else "",
		data["attack_bonus"],
	]
	if data["locked"]:
		preview_lock.text = "LOCKED — " + data["unlock_hint"]
		preview_lock.visible = true
	else:
		preview_lock.visible = false

func _refresh_slots() -> void:
	# Slot count can change when the host configures max_players, so rebuild
	# if the count is off; otherwise just update labels.
	if slots_box.get_child_count() != Lobby.slots.size():
		_build_slots()

	var local_idx := Lobby.local_slot_index()
	for i in Lobby.slots.size():
		var slot: Dictionary = Lobby.slots[i]
		var panel := slots_box.get_child(i) as PanelContainer
		var v := panel.get_child(0) as VBoxContainer
		var head_lbl := v.get_node("Header") as Label
		var pick_lbl := v.get_node("Pick") as Label
		var ready_lbl := v.get_node("Ready") as Label

		var border := CARD_HOVER if i == local_idx else Color(0.20, 0.25, 0.35)
		panel.add_theme_stylebox_override("panel", _stylebox(Color(0.06, 0.09, 0.15), border))

		head_lbl.text = "> PLAYER %d <" % (i + 1) if i == local_idx else "PLAYER %d" % (i + 1)

		if slot["peer_id"] == 0:
			pick_lbl.text = "(open)"
			pick_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55))
			ready_lbl.text = ""
		else:
			var data: Dictionary = CharacterDB.get_character(slot["character_id"])
			pick_lbl.text = data["name"]
			pick_lbl.add_theme_color_override("font_color", data["tint"])
			ready_lbl.text = "READY" if slot["ready"] else "picking..."
			ready_lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.45) if slot["ready"] else Color(0.85, 0.75, 0.35))

func _refresh_card_marks() -> void:
	var local_idx := Lobby.local_slot_index()
	if local_idx < 0:
		return
	var picked_id: String = Lobby.slots[local_idx]["character_id"]
	for i in _cards.size():
		var data: Dictionary = CharacterDB.CHARACTERS[i]
		if data["locked"]:
			continue
		var base := CARD_PICKED if data["id"] == picked_id else CARD_NORMAL
		_cards[i].add_theme_stylebox_override("normal", _stylebox(base))

func _refresh_status() -> void:
	var idx := Lobby.local_slot_index()
	if idx < 0:
		status_label.text = "Connecting..."
		ready_button.disabled = true
		return
	ready_button.disabled = false
	ready_button.text = "UNREADY" if Lobby.slots[idx]["ready"] else "READY"

	var filled := 0
	for s in Lobby.slots:
		if s["peer_id"] != 0:
			filled += 1
	if Lobby.mode == Lobby.Mode.OFFLINE:
		status_label.text = "Singleplayer"
	elif Lobby.mode == Lobby.Mode.HOST:
		status_label.text = "Hosting — %d/%d players" % [filled, Lobby.slots.size()]
	else:
		status_label.text = "Connected — %d/%d players" % [filled, Lobby.slots.size()]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()

func _stylebox(bg: Color, border: Color = Color(0.40, 0.52, 0.68)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = border
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb
