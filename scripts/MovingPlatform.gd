extends AnimatableBody2D

var _speed: float = 55.0
var _travel: float = 80.0
var _origin_x: float = 0.0
var _dir: float = 1.0

func setup(x: float, y: float, w: float, color: Color) -> void:
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	_speed = randf_range(38.0, 68.0)
	_travel = randf_range(60.0, 110.0)
	_origin_x = x + w * 0.5
	position = Vector2(_origin_x, y + 7.0)

	var cr := ColorRect.new()
	cr.color = color
	cr.offset_left = -w * 0.5
	cr.offset_top = -7.0
	cr.offset_right = w * 0.5
	cr.offset_bottom = 7.0
	add_child(cr)

	var hl := ColorRect.new()
	hl.color = Color(color.r + 0.10, color.g + 0.10, color.b + 0.10)
	hl.offset_left = -w * 0.5
	hl.offset_top = -7.0
	hl.offset_right = w * 0.5
	hl.offset_bottom = -4.0
	add_child(hl)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 14.0)
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	position.x += _dir * _speed * delta
	if absf(position.x - _origin_x) >= _travel * 0.5:
		_dir *= -1.0
