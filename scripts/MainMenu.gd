extends Control

const GAME_SCENE := "res://scenes/Main.tscn"
const OPTIONS_SCENE := "res://scenes/OptionsMenu.tscn"

@onready var start_button: Button = $VBox/StartButton
@onready var options_button: Button = $VBox/OptionsButton
@onready var quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()

func _on_start() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_options() -> void:
	get_tree().change_scene_to_file(OPTIONS_SCENE)

func _on_quit() -> void:
	get_tree().quit()
