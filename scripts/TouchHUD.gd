extends CanvasLayer
class_name TouchHUD

# Mobile control overlay: virtual joystick (movement + crouch) on the left,
# action buttons on the right. Joystick is its own Control (Joystick.gd);
# action buttons forward press/release to the matching input action.

const BTN_SIZE := Vector2(108, 108)
const SMALL_BTN_SIZE := Vector2(84, 84)
const PAD := 22.0

# (action_name, label, size, anchor_corner, offset_from_corner)
# corner: 1=BR (bottom-right cluster), 2=TR (top-right pause)
const LAYOUT := [
	["jump",          "JUMP",  BTN_SIZE,       1, Vector2(-PAD - 108.0,                 -PAD - 108.0)],
	["attack",        "ATK",   BTN_SIZE,       1, Vector2(-PAD - 108.0 * 2 - 14.0,      -PAD - 108.0)],
	["shoot",         "FIRE",  BTN_SIZE,       1, Vector2(-PAD - 108.0,                 -PAD - 108.0 * 2 - 14.0)],
	["dash",          "DASH",  SMALL_BTN_SIZE, 1, Vector2(-PAD - 84.0 - 108.0 - 14.0,   -PAD - 108.0 - 84.0 - 10.0)],
	["throw_grenade", "NADE",  SMALL_BTN_SIZE, 1, Vector2(-PAD - 84.0,                  -PAD - 108.0 * 2 - 14.0 - 84.0 - 10.0)],
	["interact",      "USE",   SMALL_BTN_SIZE, 1, Vector2(-PAD - 84.0 - 108.0 - 14.0,   -PAD - 108.0 * 2 - 14.0)],
	["pause",         "II",    Vector2(64, 64), 2, Vector2(-PAD - 64.0,                  PAD)],
]

var _btn_style: StyleBoxFlat
var _btn_style_pressed: StyleBoxFlat

func _ready() -> void:
	layer = 50
	_btn_style = _make_style(Color(0.08, 0.10, 0.14, 0.55), Color(1, 1, 1, 0.55))
	_btn_style_pressed = _make_style(Color(0.85, 0.55, 0.15, 0.75), Color(1, 1, 1, 0.85))

	# Left-side analog joystick for movement (drives move_left/right/crouch).
	var stick := Joystick.new()
	stick.anchor_left = 0.0
	stick.anchor_top = 1.0
	stick.anchor_right = 0.0
	stick.anchor_bottom = 1.0
	var stick_size := stick.base_radius * 2.4
	stick.offset_left = PAD
	stick.offset_top = -PAD - stick_size
	stick.offset_right = PAD + stick_size
	stick.offset_bottom = -PAD
	add_child(stick)

	for entry in LAYOUT:
		_make_button(entry[0], entry[1], entry[2], entry[3], entry[4])

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	return sb

func _make_button(action: String, label: String, size: Vector2, corner: int, offset: Vector2) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_stylebox_override("normal",   _btn_style)
	b.add_theme_stylebox_override("hover",    _btn_style)
	b.add_theme_stylebox_override("focus",    _btn_style)
	b.add_theme_stylebox_override("pressed",  _btn_style_pressed)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	# Anchor to one of: BR (1) or TR (2).
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	if corner == 2:
		b.anchor_top = 0.0
		b.anchor_bottom = 0.0
	else:
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
	b.offset_left = offset.x
	b.offset_top = offset.y
	b.offset_right = offset.x + size.x
	b.offset_bottom = offset.y + size.y
	b.button_down.connect(_on_press.bind(action))
	b.button_up.connect(_on_release.bind(action))
	add_child(b)

func _on_press(action: String) -> void:
	if InputMap.has_action(action):
		Input.action_press(action)

func _on_release(action: String) -> void:
	if InputMap.has_action(action):
		Input.action_release(action)
