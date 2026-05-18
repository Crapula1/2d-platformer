extends Control
# Main menu: solo Start / Multiplayer (host or join) / Options / Quit.
# The multiplayer flow is a sub-panel that swaps in when MULTIPLAYER is
# pressed, so the main screen stays clean.

const GAME_SCENE := "res://scenes/Main.tscn"
const OPTIONS_SCENE := "res://scenes/OptionsMenu.tscn"
const CONTROLS_SCENE := "res://scenes/ControlsMenu.tscn"
const LOBBY_SCENE := "res://scenes/Lobby.tscn"

@onready var center: CenterContainer = $Center
@onready var vbox: VBoxContainer = $Center/VBox
@onready var start_button: Button = $Center/VBox/StartButton
@onready var options_button: Button = $Center/VBox/OptionsButton
@onready var quit_button: Button = $Center/VBox/QuitButton

var mp_button: Button
var mp_panel: PanelContainer
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label
var host_button: Button
var join_button: Button
var back_button: Button

var _user_typed_ip: bool = false

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	_insert_multiplayer_button()
	_insert_controls_button()
	_build_multiplayer_panel()
	start_button.grab_focus()
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected.connect(_on_disconnected)
	Net.host_discovered.connect(_on_host_discovered)
	Net.start_discovery_listen()

func _exit_tree() -> void:
	Net.stop_discovery_listen()

func _insert_multiplayer_button() -> void:
	mp_button = Button.new()
	mp_button.custom_minimum_size = Vector2(140, 26)
	mp_button.text = "MULTIPLAYER"
	mp_button.add_theme_font_size_override("font_size", 14)
	mp_button.pressed.connect(_show_mp_panel)
	vbox.add_child(mp_button)
	# Slot it just under START so the order reads Start / MP / Options / Quit.
	vbox.move_child(mp_button, 1)

func _insert_controls_button() -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 26)
	btn.text = "CONTROLS"
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(_on_controls)
	vbox.add_child(btn)
	# Place right above OPTIONS for a clean Start / MP / Controls / Options / Quit list.
	var options_idx := options_button.get_index()
	vbox.move_child(btn, options_idx)

func _on_controls() -> void:
	get_tree().change_scene_to_file(CONTROLS_SCENE)

func _build_multiplayer_panel() -> void:
	# Put the panel inside its own CenterContainer so it stays centered on
	# the screen regardless of resolution and grows to fit its content.
	var mp_center := CenterContainer.new()
	mp_center.name = "MultiplayerCenter"
	mp_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	mp_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mp_center)

	mp_panel = PanelContainer.new()
	mp_panel.custom_minimum_size = Vector2(280, 0)
	mp_panel.visible = false
	mp_center.add_child(mp_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	mp_panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb.add_child(title)

	var hint := Label.new()
	hint.text = "Host opens a server on this port.\nJoin connects to host's IP:port."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.85))
	vb.add_child(hint)

	vb.add_child(_field_label("Name"))
	name_edit = LineEdit.new()
	name_edit.text = "Player"
	name_edit.max_length = 16
	vb.add_child(name_edit)

	vb.add_child(_field_label("Host IP or address (Join only)"))
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "127.0.0.1 or play.it.gg-style host"
	ip_edit.text = "127.0.0.1"
	ip_edit.text_changed.connect(func(_t: String) -> void: _user_typed_ip = true)
	vb.add_child(ip_edit)

	vb.add_child(_field_label("Port"))
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	vb.add_child(port_edit)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vb.add_child(row)

	host_button = Button.new()
	host_button.text = "HOST"
	host_button.custom_minimum_size = Vector2(80, 28)
	host_button.add_theme_font_size_override("font_size", 14)
	host_button.pressed.connect(_on_host_pressed)
	row.add_child(host_button)

	join_button = Button.new()
	join_button.text = "JOIN"
	join_button.custom_minimum_size = Vector2(80, 28)
	join_button.add_theme_font_size_override("font_size", 14)
	join_button.pressed.connect(_on_join_pressed)
	row.add_child(join_button)

	back_button = Button.new()
	back_button.text = "BACK"
	back_button.custom_minimum_size = Vector2(60, 28)
	back_button.add_theme_font_size_override("font_size", 14)
	back_button.pressed.connect(_hide_mp_panel)
	row.add_child(back_button)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
	vb.add_child(status_label)

func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return l

func _show_mp_panel() -> void:
	mp_panel.visible = true
	vbox.visible = false
	status_label.text = ""
	name_edit.grab_focus()
	name_edit.select_all()

func _hide_mp_panel() -> void:
	mp_panel.visible = false
	vbox.visible = true
	status_label.text = ""
	start_button.grab_focus()

func _input(event: InputEvent) -> void:
	# Esc from the MP panel pops back to the main menu, not out of the game.
	if mp_panel != null and mp_panel.visible and event.is_action_pressed("ui_cancel"):
		_hide_mp_panel()
		accept_event()

func _on_start() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)

func _on_quit() -> void:
	get_tree().quit()

func _player_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Player"

func _port_value() -> int:
	var p := int(port_edit.text)
	return p if p > 0 else Net.DEFAULT_PORT

func _on_host_pressed() -> void:
	if Net.host(_port_value(), _player_name()):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		status_label.text = Net.last_error if Net.last_error != "" else "Failed to host on port %d" % _port_value()

func _on_join_pressed() -> void:
	status_label.text = "Connecting..."
	if Net.join(ip_edit.text.strip_edges(), _port_value(), _player_name()):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		status_label.text = Net.last_error if Net.last_error != "" else "Failed to start client"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"

func _on_disconnected() -> void:
	status_label.text = "Disconnected from host"

func _on_host_discovered(ip: String, port: int) -> void:
	# Auto-fill the host IP unless the user has already typed something else.
	if not _user_typed_ip:
		ip_edit.text = ip
		port_edit.text = str(port)
	# Friendly status either way so people know a host is reachable.
	if status_label != null:
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		status_label.text = "Found host at %s:%d on the LAN" % [ip, port]
