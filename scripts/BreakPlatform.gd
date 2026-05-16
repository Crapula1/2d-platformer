extends StaticBody2D

const BREAK_DELAY: float = 0.5
const FALL_SPEED: float = 220.0

var _timer: float = 0.0
var _triggered: bool = false
var _falling: bool = false
var _origin_x: float = 0.0

func setup(x: float, y: float, w: float, color: Color) -> void:
	collision_layer = 1
	collision_mask = 0
	_origin_x = x + w * 0.5
	position = Vector2(_origin_x, y)

	var cr := ColorRect.new()
	cr.color = color
	cr.offset_left = -w * 0.5
	cr.offset_top = 0.0
	cr.offset_right = w * 0.5
	cr.offset_bottom = 14.0
	add_child(cr)

	var hl := ColorRect.new()
	hl.color = Color(color.r + 0.08, color.g + 0.08, color.b + 0.08)
	hl.offset_left = -w * 0.5
	hl.offset_top = 0.0
	hl.offset_right = w * 0.5
	hl.offset_bottom = 3.0
	add_child(hl)

	# Crack marks so the player can visually identify these platforms
	var c1 := ColorRect.new()
	c1.color = Color(0.0, 0.0, 0.0, 0.30)
	c1.offset_left = -w * 0.25
	c1.offset_top = 2.0
	c1.offset_right = -w * 0.25 + 2.0
	c1.offset_bottom = 12.0
	add_child(c1)

	var c2 := ColorRect.new()
	c2.color = Color(0.0, 0.0, 0.0, 0.30)
	c2.offset_left = w * 0.10
	c2.offset_top = 3.0
	c2.offset_right = w * 0.10 + 2.0
	c2.offset_bottom = 11.0
	add_child(c2)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 14.0)
	shape.shape = rect
	shape.position = Vector2(0.0, 7.0)
	add_child(shape)

func _physics_process(delta: float) -> void:
	if _falling:
		position.y += FALL_SPEED * delta
		modulate.a = maxf(modulate.a - delta * 3.0, 0.0)
		if modulate.a == 0.0:
			queue_free()
		return

	if not _triggered:
		for p: Node in get_tree().get_nodes_in_group("player"):
			if p is CharacterBody2D and (p as CharacterBody2D).is_on_floor() \
					and (p as CharacterBody2D).get_floor_body() == self:
				_triggered = true
				_timer = BREAK_DELAY
				break
		return

	_timer -= delta
	var t := 1.0 - _timer / BREAK_DELAY
	position.x = _origin_x + sin(_timer * 80.0) * 2.5 * t

	if _timer <= 0.0:
		_falling = true
		for child: Node in get_children():
			if child is CollisionShape2D:
				(child as CollisionShape2D).set_deferred("disabled", true)
