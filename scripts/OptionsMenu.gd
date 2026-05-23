extends Control

signal closed

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

# When true, BACK closes this instance and emits `closed` instead of
# changing scenes — used by the in-game pause menu.
var is_overlay: bool = false

@onready var res_option: OptionButton = $Panel/VBox/ResRow/ResOption
@onready var mode_option: OptionButton = $Panel/VBox/ModeRow/ModeOption
@onready var vsync_check: CheckButton = $Panel/VBox/VsyncRow/VsyncCheck
@onready var fps_option: OptionButton = $Panel/VBox/FpsRow/FpsOption
@onready var msaa_option: OptionButton = $Panel/VBox/MsaaRow/MsaaOption
@onready var volume_slider: HSlider = $Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Panel/VBox/VolumeRow/VolumeValue
@onready var auto_aim_check: CheckButton = $Panel/VBox/AutoAimRow/AutoAimCheck
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	MenuBackground.show()
	for r in Settings.RESOLUTIONS:
		res_option.add_item("%d x %d" % [r.x, r.y])
	for name in Settings.WINDOW_MODE_NAMES:
		mode_option.add_item(name)
	for name in Settings.FPS_NAMES:
		fps_option.add_item(name)
	for name in Settings.MSAA_NAMES:
		msaa_option.add_item(name)

	var idx := Settings.RESOLUTIONS.find(Settings.resolution)
	res_option.selected = max(idx, 0)
	mode_option.selected = Settings.window_mode
	vsync_check.button_pressed = Settings.vsync_enabled
	fps_option.selected = Settings.fps_index
	msaa_option.selected = Settings.msaa_index
	volume_slider.value = Settings.master_volume
	auto_aim_check.button_pressed = Settings.auto_aim
	_refresh_volume_label()

	res_option.item_selected.connect(_on_res)
	mode_option.item_selected.connect(_on_mode)
	vsync_check.toggled.connect(_on_vsync)
	fps_option.item_selected.connect(_on_fps)
	msaa_option.item_selected.connect(_on_msaa)
	volume_slider.value_changed.connect(_on_volume)
	auto_aim_check.toggled.connect(_on_auto_aim)
	back_button.pressed.connect(_on_back)
	back_button.grab_focus()
	MobileUI.scale_menu(self)

func _refresh_volume_label() -> void:
	volume_value.text = "%d%%" % int(round(Settings.master_volume * 100.0))

func _on_res(i: int) -> void:
	Settings.resolution = Settings.RESOLUTIONS[i]
	Settings.apply()
	Settings.save_settings()

func _on_mode(i: int) -> void:
	Settings.window_mode = i
	# Lock resolution picker in fullscreen — the OS picks it.
	res_option.disabled = (i == Settings.MODE_FULLSCREEN)
	Settings.apply()
	Settings.save_settings()

func _on_vsync(pressed: bool) -> void:
	Settings.vsync_enabled = pressed
	Settings.apply()
	Settings.save_settings()

func _on_fps(i: int) -> void:
	Settings.fps_index = i
	Settings.apply()
	Settings.save_settings()

func _on_msaa(i: int) -> void:
	Settings.msaa_index = i
	Settings.apply()
	Settings.save_settings()

func _on_volume(v: float) -> void:
	Settings.master_volume = v
	_refresh_volume_label()
	Settings.apply()
	Settings.save_settings()

func _on_auto_aim(pressed: bool) -> void:
	Settings.auto_aim = pressed
	Settings.save_settings()

func _on_back() -> void:
	if is_overlay:
		closed.emit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
