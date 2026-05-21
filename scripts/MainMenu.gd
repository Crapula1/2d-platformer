extends Control

const CHARACTER_SELECT_SCENE := "res://scenes/CharacterSelect.tscn"
const OPTIONS_SCENE := "res://scenes/OptionsMenu.tscn"

@onready var start_button: Button = $VBox/StartButton
@onready var host_button: Button = $VBox/HostButton
@onready var join_button: Button = $VBox/JoinButton
@onready var options_button: Button = $VBox/OptionsButton
@onready var quit_button: Button = $VBox/QuitButton
@onready var join_address: LineEdit = $VBox/JoinRow/JoinAddress

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()

func _on_start() -> void:
	Lobby.start_offline()
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_host() -> void:
	var err := Lobby.start_host()
	if err != OK:
		push_warning("Host failed: %s" % err)
		return
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_join() -> void:
	var addr := join_address.text.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	var err := Lobby.start_client(addr)
	if err != OK:
		push_warning("Join failed: %s" % err)
		return
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_options() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)

func _on_quit() -> void:
	get_tree().quit()
