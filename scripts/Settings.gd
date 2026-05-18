extends Node

# Autoload. Owns persistent display + audio prefs and applies them
# to the running game. UI scripts call apply() + save_settings() after
# changing a field — keep this small and direct.

const CONFIG_PATH := "user://settings.cfg"

signal settings_changed

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

const WINDOW_MODE_NAMES: Array[String] = ["Windowed", "Borderless", "Fullscreen"]
const MODE_WINDOWED := 0
const MODE_BORDERLESS := 1
const MODE_FULLSCREEN := 2

const MSAA_NAMES: Array[String] = ["Off", "2x", "4x", "8x"]
const MSAA_VALUES: Array[int] = [
	Viewport.MSAA_DISABLED,
	Viewport.MSAA_2X,
	Viewport.MSAA_4X,
	Viewport.MSAA_8X,
]

const FPS_NAMES: Array[String] = ["Unlimited", "30", "60", "120", "144", "240"]
const FPS_VALUES: Array[int] = [0, 30, 60, 120, 144, 240]

var resolution: Vector2i = Vector2i(1280, 720)
var window_mode: int = MODE_WINDOWED
var vsync_enabled: bool = true
var msaa_index: int = 0      # index into MSAA_NAMES
var fps_index: int = 2       # index into FPS_NAMES — default 60
var master_volume: float = 1.0

func _ready() -> void:
	load_settings()
	apply()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	var w := int(cfg.get_value("display", "res_w", resolution.x))
	var h := int(cfg.get_value("display", "res_h", resolution.y))
	resolution = Vector2i(w, h)
	window_mode = int(cfg.get_value("display", "window_mode", window_mode))
	vsync_enabled = bool(cfg.get_value("display", "vsync", vsync_enabled))
	msaa_index = clampi(int(cfg.get_value("display", "msaa", msaa_index)), 0, MSAA_NAMES.size() - 1)
	fps_index = clampi(int(cfg.get_value("display", "fps_limit", fps_index)), 0, FPS_NAMES.size() - 1)
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "res_w", resolution.x)
	cfg.set_value("display", "res_h", resolution.y)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("display", "msaa", msaa_index)
	cfg.set_value("display", "fps_limit", fps_index)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(CONFIG_PATH)

func apply() -> void:
	match window_mode:
		MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, window_mode == MODE_BORDERLESS)
			DisplayServer.window_set_size(resolution)
			_center_window()

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

	var root := get_tree().root if is_inside_tree() else null
	if root != null:
		root.msaa_2d = MSAA_VALUES[msaa_index] as Viewport.MSAA

	Engine.max_fps = FPS_VALUES[fps_index]

	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		# linear_to_db handles 0.0 → -INF cleanly.
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, master_volume <= 0.0)

	settings_changed.emit()

func _center_window() -> void:
	if window_mode == MODE_FULLSCREEN:
		return
	var screen := DisplayServer.window_get_current_screen()
	var screen_size := DisplayServer.screen_get_size(screen)
	var screen_pos := DisplayServer.screen_get_position(screen)
	var win_size := DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_pos + (screen_size - win_size) / 2)
