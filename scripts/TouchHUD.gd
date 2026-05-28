extends CanvasLayer
class_name TouchHUD

# Mobile control overlay: virtual joystick (movement + crouch) on the left,
# action buttons on the right. Joystick is its own Control (Joystick.gd);
# action buttons forward press/release to the matching input action.

const BTN_SIZE := Vector2(108, 108)
const SMALL_BTN_SIZE := Vector2(84, 84)
const PAD := 22.0

# Per-attack tints make each action recognizable at a glance instead of
# reading the label mid-combat. Movement (JUMP) stays neutral; pause is muted.
# (action_name, label, size, anchor_corner, offset_from_corner, tint)
# corner: 1=BR (bottom-right cluster), 2=TR (top-right pause)
const C_JUMP   := Color(0.20, 0.55, 0.95)  # blue   — mobility
const C_ATTACK := Color(0.90, 0.25, 0.25)  # red    — melee
const C_SHOOT  := Color(0.95, 0.75, 0.15)  # yellow — ranged
const C_DASH   := Color(0.30, 0.80, 0.95)  # cyan   — mobility burst
const C_NADE   := Color(0.45, 0.85, 0.35)  # green  — grenade
const C_USE    := Color(0.75, 0.55, 0.95)  # purple — interact
const C_PAUSE  := Color(0.55, 0.55, 0.60)  # gray   — system

const LAYOUT := [
	["jump",          "JUMP", BTN_SIZE,        1, Vector2(-PAD - 108.0,                 -PAD - 108.0),                        C_JUMP],
	["attack",        "ATK",  BTN_SIZE,        1, Vector2(-PAD - 108.0 * 2 - 14.0,      -PAD - 108.0),                        C_ATTACK],
	["shoot",         "FIRE", BTN_SIZE,        1, Vector2(-PAD - 108.0,                 -PAD - 108.0 * 2 - 14.0),             C_SHOOT],
	["dash",          "DASH", SMALL_BTN_SIZE,  1, Vector2(-PAD - 84.0 - 108.0 - 14.0,   -PAD - 108.0 - 84.0 - 10.0),          C_DASH],
	["throw_grenade", "NADE", SMALL_BTN_SIZE,  1, Vector2(-PAD - 84.0,                  -PAD - 108.0 * 2 - 14.0 - 84.0 - 10.0), C_NADE],
	["interact",      "USE",  SMALL_BTN_SIZE,  1, Vector2(-PAD - 84.0 - 108.0 - 14.0,   -PAD - 108.0 * 2 - 14.0 - 84.0 - 10.0), C_USE],
	["pause",         "II",   Vector2(64, 64), 2, Vector2(-PAD - 64.0,                   PAD),                                 C_PAUSE],
]

func _ready() -> void:
	layer = 50

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
		_make_button(entry[0], entry[1], entry[2], entry[3], entry[4], entry[5])

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

# Tinted bg uses the action color at low alpha so the button still reads as a
# translucent HUD element; pressed state pops to ~85% alpha of the same hue.
func _styles_for(tint: Color) -> Array:
	var bg_normal := Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35, 0.55)
	var border_normal := Color(tint.r, tint.g, tint.b, 0.75)
	var bg_pressed := Color(tint.r, tint.g, tint.b, 0.85)
	var border_pressed := Color(1, 1, 1, 0.95)
	return [
		_make_style(bg_normal, border_normal),
		_make_style(bg_pressed, border_pressed),
	]

func _make_button(action: String, label: String, size: Vector2, corner: int, offset: Vector2, tint: Color) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = size
	b.size = size
	var styles := _styles_for(tint)
	var s_normal: StyleBoxFlat = styles[0]
	var s_pressed: StyleBoxFlat = styles[1]
	b.add_theme_stylebox_override("normal",   s_normal)
	b.add_theme_stylebox_override("hover",    s_normal)
	b.add_theme_stylebox_override("focus",    s_normal)
	b.add_theme_stylebox_override("pressed",  s_pressed)
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
