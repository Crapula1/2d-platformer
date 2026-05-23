extends CanvasLayer
class_name TouchHUD

# Screen-edge buttons for mobile / touch play. Each button forwards
# press/release to an input action already defined in the input map,
# so Player.gd's existing Input.is_action_* checks keep working.

const BTN_SIZE := Vector2(96, 96)
const SMALL_BTN_SIZE := Vector2(76, 76)
const PAD := 18.0

# (action_name, label, size, anchor_corner, offset_from_corner)
# anchor_corner: 0=BL, 1=BR
const LAYOUT := [
	["move_left",     "<",   BTN_SIZE,       0, Vector2(PAD,               -PAD - 96.0)],
	["move_right",    ">",   BTN_SIZE,       0, Vector2(PAD + 96.0 + 12.0, -PAD - 96.0)],
	["crouch",        "v",   SMALL_BTN_SIZE, 0, Vector2(PAD + 48.0,        -PAD - 96.0 - 76.0 - 8.0)],
	["jump",          "JUMP",  BTN_SIZE,       1, Vector2(-PAD - 96.0,                 -PAD - 96.0)],
	["attack",        "ATK",   BTN_SIZE,       1, Vector2(-PAD - 96.0 * 2 - 12.0,      -PAD - 96.0)],
	["shoot",         "FIRE",  BTN_SIZE,       1, Vector2(-PAD - 96.0,                 -PAD - 96.0 * 2 - 12.0)],
	["dash",          "DASH",  SMALL_BTN_SIZE, 1, Vector2(-PAD - 76.0 - 96.0 - 12.0,   -PAD - 96.0 - 76.0 - 8.0)],
	["throw_grenade", "NADE",  SMALL_BTN_SIZE, 1, Vector2(-PAD - 76.0,                 -PAD - 96.0 * 2 - 12.0 - 76.0 - 8.0)],
	["interact",      "USE",   SMALL_BTN_SIZE, 1, Vector2(-PAD - 76.0,                 -PAD - 76.0)],
	["pause",         "II",    SMALL_BTN_SIZE, 1, Vector2(-PAD - 76.0,                 PAD)],
]

func _ready() -> void:
	layer = 50
	for entry in LAYOUT:
		_make_button(entry[0], entry[1], entry[2], entry[3], entry[4])

func _make_button(action: String, label: String, size: Vector2, corner: int, offset: Vector2) -> void:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.modulate = Color(1, 1, 1, 0.55)
	b.custom_minimum_size = size
	b.size = size
	# Anchor to bottom-left (0) or bottom-right (1). For BR, also anchor top
	# pause button (corner 1 with positive Y offset) — handled by the sign of offset.y.
	if corner == 0:
		b.anchor_left = 0.0
		b.anchor_right = 0.0
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
	else:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		if offset.y > 0:
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
