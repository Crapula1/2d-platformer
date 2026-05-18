extends CanvasLayer

# In-game pause overlay. Pauses the tree while open. Settings opens the
# OptionsMenu as a sibling overlay so the run isn't lost.

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const OPTIONS_SCENE := preload("res://scenes/OptionsMenu.tscn")
const CONTROLS_SCENE := preload("res://scenes/ControlsMenu.tscn")

@onready var resume_button: Button = $Panel/VBox/ResumeButton
@onready var settings_button: Button = $Panel/VBox/SettingsButton
@onready var menu_button: Button = $Panel/VBox/MenuButton
@onready var quit_button: Button = $Panel/VBox/QuitButton

var _options_overlay: Control = null
var _controls_overlay: Control = null
var _controls_button: Button = null

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	menu_button.pressed.connect(_on_menu)
	quit_button.pressed.connect(_on_quit)
	_insert_controls_button()
	resume_button.grab_focus()
	get_tree().paused = true

func _insert_controls_button() -> void:
	_controls_button = Button.new()
	_controls_button.text = "CONTROLS"
	_controls_button.custom_minimum_size = settings_button.custom_minimum_size
	# Match the font size of the existing buttons so it doesn't stand out.
	var fs := settings_button.get_theme_font_size("font_size")
	if fs > 0:
		_controls_button.add_theme_font_size_override("font_size", fs)
	_controls_button.pressed.connect(_on_controls)
	var vb := settings_button.get_parent()
	vb.add_child(_controls_button)
	vb.move_child(_controls_button, settings_button.get_index() + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Esc backs out of overlays first, then closes the pause menu.
		if is_instance_valid(_controls_overlay):
			_close_controls()
		elif is_instance_valid(_options_overlay):
			_close_options()
		else:
			_on_resume()
		get_viewport().set_input_as_handled()

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()

func _on_settings() -> void:
	if is_instance_valid(_options_overlay):
		return
	_options_overlay = OPTIONS_SCENE.instantiate()
	_options_overlay.is_overlay = true
	_options_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_options_overlay.closed.connect(_close_options)
	add_child(_options_overlay)

func _close_options() -> void:
	if is_instance_valid(_options_overlay):
		_options_overlay.queue_free()
	_options_overlay = null
	settings_button.grab_focus()

func _on_controls() -> void:
	if is_instance_valid(_controls_overlay):
		return
	_controls_overlay = CONTROLS_SCENE.instantiate()
	_controls_overlay.is_overlay = true
	_controls_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_controls_overlay.closed.connect(_close_controls)
	add_child(_controls_overlay)

func _close_controls() -> void:
	if is_instance_valid(_controls_overlay):
		_controls_overlay.queue_free()
	_controls_overlay = null
	if _controls_button != null:
		_controls_button.grab_focus()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_quit() -> void:
	get_tree().quit()
