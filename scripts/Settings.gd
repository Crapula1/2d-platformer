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

# Actions that the player can rebind. Anything else (ui_*) is left alone.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_left", "move_right", "jump", "crouch", "sprint",
	"attack", "shoot", "throw_grenade", "cycle_grenade",
	"cycle_weapon", "select_rifle", "select_shotgun",
	"dash", "roll", "interact", "restart", "pause",
]

# Snapshot of the default (project-defined) binding for each action, captured
# on first launch so the user can always restore them.
var _default_bindings: Dictionary = {}

# User overrides loaded from disk: action -> Array of serialised events.
# Empty entry means "use the project default".
var _binding_overrides: Dictionary = {}

func _ready() -> void:
	_snapshot_default_bindings()
	load_settings()
	apply()
	_apply_bindings()

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

	# Load any custom bindings the user has saved.
	_binding_overrides.clear()
	for action in REBINDABLE_ACTIONS:
		var raw: Variant = cfg.get_value("bindings", action, null)
		if raw is Array:
			_binding_overrides[action] = raw

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "res_w", resolution.x)
	cfg.set_value("display", "res_h", resolution.y)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "vsync", vsync_enabled)
	cfg.set_value("display", "msaa", msaa_index)
	cfg.set_value("display", "fps_limit", fps_index)
	cfg.set_value("audio", "master_volume", master_volume)
	for action in REBINDABLE_ACTIONS:
		if _binding_overrides.has(action):
			cfg.set_value("bindings", action, _binding_overrides[action])
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
	@warning_ignore("integer_division")
	DisplayServer.window_set_position(screen_pos + (screen_size - win_size) / 2)

# -----------------------------------------------------------------------------
# Input bindings (rebindable controls)
# -----------------------------------------------------------------------------
func _snapshot_default_bindings() -> void:
	_default_bindings.clear()
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			events.append(ev.duplicate())
		_default_bindings[action] = events

func _apply_bindings() -> void:
	# Rebuild every rebindable action from either the user override (if any)
	# or the project default.
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		if _binding_overrides.has(action):
			for raw in _binding_overrides[action]:
				var ev := _deserialise_event(raw)
				if ev != null:
					InputMap.action_add_event(action, ev)
		else:
			for ev in _default_bindings.get(action, []):
				InputMap.action_add_event(action, ev.duplicate())

func get_primary_event_for(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton:
			return ev
	return null

func describe_event(ev: InputEvent) -> String:
	if ev == null:
		return "—"
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
		return OS.get_keycode_string(code)
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT: return "Mouse Left"
			MOUSE_BUTTON_RIGHT: return "Mouse Right"
			MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse %d" % mb.button_index
	if ev is InputEventJoypadButton:
		return "Pad %d" % (ev as InputEventJoypadButton).button_index
	return "?"

func set_binding(action: String, ev: InputEvent) -> void:
	# Replace the primary binding for this action with the given event.
	# Keeps any secondary bindings (e.g. arrow-key fallbacks) intact.
	if not InputMap.has_action(action):
		return
	var keep: Array = []
	var existing := InputMap.action_get_events(action)
	# Drop the first key/mouse/joybutton event — that's the slot we're
	# replacing. Other event types (joy axes, etc.) are preserved.
	var replaced := false
	for e in existing:
		if not replaced and (e is InputEventKey or e is InputEventMouseButton or e is InputEventJoypadButton):
			replaced = true
			continue
		keep.append(e)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for e in keep:
		InputMap.action_add_event(action, e)
	_binding_overrides[action] = _serialise_events(InputMap.action_get_events(action))
	save_settings()
	settings_changed.emit()

func reset_binding(action: String) -> void:
	_binding_overrides.erase(action)
	InputMap.action_erase_events(action)
	for ev in _default_bindings.get(action, []):
		InputMap.action_add_event(action, ev.duplicate())
	save_settings()
	settings_changed.emit()

func reset_all_bindings() -> void:
	_binding_overrides.clear()
	_apply_bindings()
	save_settings()
	settings_changed.emit()

func _serialise_events(events: Array) -> Array:
	var out: Array = []
	for ev in events:
		var d := _serialise_event(ev)
		if not d.is_empty():
			out.append(d)
	return out

func _serialise_event(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return {
			"type": "key",
			"keycode": k.keycode,
			"physical_keycode": k.physical_keycode,
		}
	if ev is InputEventMouseButton:
		return {
			"type": "mouse",
			"button_index": (ev as InputEventMouseButton).button_index,
		}
	if ev is InputEventJoypadButton:
		return {
			"type": "joybtn",
			"button_index": (ev as InputEventJoypadButton).button_index,
		}
	return {}

func _deserialise_event(raw: Variant) -> InputEvent:
	if not (raw is Dictionary):
		return null
	var d := raw as Dictionary
	match String(d.get("type", "")):
		"key":
			var k := InputEventKey.new()
			k.keycode = int(d.get("keycode", 0)) as Key
			k.physical_keycode = int(d.get("physical_keycode", 0)) as Key
			return k
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(d.get("button_index", MOUSE_BUTTON_LEFT)) as MouseButton
			return m
		"joybtn":
			var j := InputEventJoypadButton.new()
			j.button_index = int(d.get("button_index", 0)) as JoyButton
			return j
	return null
