extends Control
class_name Joystick

# Analog virtual stick for touch play. Tracks a single finger that started
# inside the control, drives `move_left`/`move_right` actions with strength,
# and presses `crouch` when pulled down past `crouch_threshold`. Each frame
# the actions are released/re-pressed based on the current knob position so
# the platformer's existing input checks "just work".

@export var base_radius: float = 70.0
@export var knob_radius: float = 32.0
@export var deadzone: float = 0.18
@export var crouch_threshold: float = 0.6
@export var base_color: Color = Color(1, 1, 1, 0.18)
@export var knob_color: Color = Color(1, 1, 1, 0.55)

var _touch_index: int = -1
var _center: Vector2
var _knob: Vector2 = Vector2.ZERO  # normalized [-1..1]

func _ready() -> void:
	custom_minimum_size = Vector2(base_radius * 2.4, base_radius * 2.4)
	mouse_filter = MOUSE_FILTER_STOP
	_center = size * 0.5

func _process(_delta: float) -> void:
	_apply_axis("move_left",  "move_right", _knob.x)
	# Vertical down = crouch (only fully pressed past threshold so a small wobble
	# while running doesn't drop the player into a slide).
	if _knob.y > crouch_threshold:
		if not Input.is_action_pressed("crouch"):
			Input.action_press("crouch", _knob.y)
	else:
		if Input.is_action_pressed("crouch"):
			Input.action_release("crouch")

func _apply_axis(neg_action: String, pos_action: String, value: float) -> void:
	if value < -deadzone:
		if Input.is_action_pressed(pos_action):
			Input.action_release(pos_action)
		Input.action_press(neg_action, -value)
	elif value > deadzone:
		if Input.is_action_pressed(neg_action):
			Input.action_release(neg_action)
		Input.action_press(pos_action, value)
	else:
		if Input.is_action_pressed(neg_action):
			Input.action_release(neg_action)
		if Input.is_action_pressed(pos_action):
			Input.action_release(pos_action)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			_update_knob(t.position)
			accept_event()
		elif not t.pressed and t.index == _touch_index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _touch_index:
			_update_knob(d.position)
			accept_event()
	elif event is InputEventMouseButton:
		# Desktop fallback for testing in the editor.
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _touch_index == -1:
				_touch_index = -2
				_update_knob(mb.position)
				accept_event()
			elif not mb.pressed and _touch_index == -2:
				_release()
				accept_event()
	elif event is InputEventMouseMotion and _touch_index == -2:
		_update_knob((event as InputEventMouseMotion).position)
		accept_event()

func _update_knob(local_pos: Vector2) -> void:
	_center = size * 0.5
	var delta: Vector2 = local_pos - _center
	if delta.length() > base_radius:
		delta = delta.normalized() * base_radius
	_knob = delta / base_radius
	queue_redraw()

func _release() -> void:
	_touch_index = -1
	_knob = Vector2.ZERO
	# Release everything so the player doesn't keep walking after lift-off.
	for action in ["move_left", "move_right", "crouch"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_circle(c, base_radius, base_color)
	draw_arc(c, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	var knob_pos: Vector2 = c + _knob * base_radius
	draw_circle(knob_pos, knob_radius, knob_color)
