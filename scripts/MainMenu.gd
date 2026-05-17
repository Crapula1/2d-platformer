extends Control

const GAME_SCENE := "res://scenes/Main.tscn"
const OPTIONS_SCENE := "res://scenes/OptionsMenu.tscn"
const LOBBY_SCENE := "res://scenes/Lobby.tscn"

@onready var start_button: Button = $VBox/StartButton
@onready var options_button: Button = $VBox/OptionsButton
@onready var quit_button: Button = $VBox/QuitButton
@onready var vbox: VBoxContainer = $VBox

var host_button: Button
var join_button: Button
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	_build_multiplayer_ui()
	start_button.grab_focus()
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected.connect(_on_disconnected)

func _build_multiplayer_ui() -> void:
	# Append host/join controls under the existing VBox so the styled main
	# menu layout is preserved.
	host_button = Button.new()
	host_button.custom_minimum_size = Vector2(140, 26)
	host_button.text = "HOST"
	host_button.add_theme_font_size_override("font_size", 14)
	host_button.pressed.connect(_on_host_pressed)
	vbox.add_child(host_button)

	join_button = Button.new()
	join_button.custom_minimum_size = Vector2(140, 26)
	join_button.text = "JOIN"
	join_button.add_theme_font_size_override("font_size", 14)
	join_button.pressed.connect(_on_join_pressed)
	vbox.add_child(join_button)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "name"
	name_edit.text = "Player"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(140, 22)
	vbox.add_child(name_edit)

	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "host ip (join only)"
	ip_edit.text = "127.0.0.1"
	ip_edit.custom_minimum_size = Vector2(140, 22)
	vbox.add_child(ip_edit)

	port_edit = LineEdit.new()
	port_edit.placeholder_text = "port"
	port_edit.text = str(Net.DEFAULT_PORT)
	port_edit.custom_minimum_size = Vector2(140, 22)
	vbox.add_child(port_edit)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	vbox.add_child(status_label)

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
		status_label.text = "Failed to host on port %d" % _port_value()

func _on_join_pressed() -> void:
	status_label.text = "Connecting..."
	if Net.join(ip_edit.text.strip_edges(), _port_value(), _player_name()):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		status_label.text = "Failed to start client"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"

func _on_disconnected() -> void:
	status_label.text = "Disconnected from host"
