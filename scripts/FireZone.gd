extends Area2D

const DAMAGE_PER_TICK := 1
const TICK_INTERVAL   := 0.5
const ZONE_DURATION   := 4.0

var _zone_timer: float = ZONE_DURATION
var _tick_timer: float = TICK_INTERVAL
var _bodies: Array[Node] = []
var _flames: Array[ColorRect] = []
var _time: float = 0.0

func _ready() -> void:
	collision_mask = 14
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_visuals()

func _build_visuals() -> void:
	# Semi-transparent base glow
	var base := ColorRect.new()
	base.color = Color(0.9, 0.35, 0.02, 0.30)
	base.offset_left  = -36; base.offset_top    = -8
	base.offset_right =  36; base.offset_bottom =  8
	add_child(base)

	# Flame tongues
	for i in 7:
		var flame := ColorRect.new()
		var w := randf_range(5, 10)
		var h := randf_range(10, 22)
		flame.offset_left  = -w * 0.5
		flame.offset_top   = -h
		flame.offset_right =  w * 0.5
		flame.offset_bottom = 0
		flame.position.x = randf_range(-28, 28)
		flame.color = Color(randf_range(0.85, 1.0), randf_range(0.2, 0.55), 0.0)
		add_child(flame)
		_flames.append(flame)

func _physics_process(delta: float) -> void:
	_time += delta
	_zone_timer -= delta
	_tick_timer -= delta

	# Animate flames
	for i in _flames.size():
		var flame := _flames[i]
		var flicker := sin(_time * 8.0 + i * 1.3) * 0.5 + 0.5
		flame.scale.y = 0.6 + flicker * 0.8
		flame.modulate.a = 0.7 + flicker * 0.3
		flame.color.g = lerpf(0.2, 0.6, flicker)

	# Fade out in last second
	if _zone_timer < 1.0:
		modulate.a = maxf(_zone_timer, 0.0)

	if _zone_timer <= 0.0:
		queue_free()
		return

	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		for body in _bodies:
			if not is_instance_valid(body):
				continue
			if body.has_method("request_damage") and multiplayer.has_multiplayer_peer():
				body.request_damage.rpc_id(body.get_multiplayer_authority(), DAMAGE_PER_TICK, global_position)
			elif body.has_method("take_damage"):
				body.take_damage(DAMAGE_PER_TICK, global_position)

func _on_body_entered(body: Node) -> void:
	if body.has_method("request_damage") or body.has_method("take_damage"):
		_bodies.append(body)

func _on_body_exited(body: Node) -> void:
	_bodies.erase(body)
