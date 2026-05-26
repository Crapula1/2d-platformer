extends Area2D

# Slow horizontal "Mega Man boss" flame projectile. Hovers along at low
# altitude so the player has to time a jump to clear it.

const DAMAGE: int = 2
const LIFETIME: float = 6.5

var velocity: Vector2 = Vector2(-90.0, 0.0)
var arena_left: float = -INF
var arena_right: float = INF

var _life: float = LIFETIME
var _time: float = 0.0
var _core: ColorRect
var _glow: ColorRect
var _tongues: Array[ColorRect] = []

func setup(p_velocity: Vector2, p_arena_left: float, p_arena_right: float) -> void:
	velocity = p_velocity
	arena_left = p_arena_left
	arena_right = p_arena_right

func _ready() -> void:
	# Layer/mask: don't sit on any layer, only detect player body (layer 2).
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	shape.shape = circ
	add_child(shape)

	_glow = ColorRect.new()
	_glow.color = Color(1.0, 0.35, 0.05, 0.35)
	_glow.offset_left  = -28.0
	_glow.offset_top   = -28.0
	_glow.offset_right =  28.0
	_glow.offset_bottom =  28.0
	_glow.z_index = 5
	add_child(_glow)

	_core = ColorRect.new()
	_core.color = Color(1.0, 0.85, 0.30)
	_core.offset_left  = -8.0
	_core.offset_top   = -8.0
	_core.offset_right =  8.0
	_core.offset_bottom =  8.0
	_core.z_index = 7
	add_child(_core)

	for i in 5:
		var t := ColorRect.new()
		t.color = Color(1.0, 0.45, 0.10, 0.85)
		var w: float = randf_range(4.0, 7.0)
		var h: float = randf_range(8.0, 16.0)
		t.offset_left = -w * 0.5
		t.offset_right = w * 0.5
		t.offset_top = -h
		t.offset_bottom = 0.0
		t.position = Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))
		t.z_index = 6
		add_child(t)
		_tongues.append(t)

func _physics_process(delta: float) -> void:
	_time += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	# Slow horizontal drift with a gentle vertical bob — keeps the silhouette
	# readable but adds a little life to the flame.
	position += velocity * delta
	position.y += sin(_time * 4.0) * 18.0 * delta

	# Despawn when leaving the arena horizontally so flames don't pile up
	# against the outside walls forever.
	if position.x < arena_left - 40.0 or position.x > arena_right + 40.0:
		queue_free()
		return

	# Flicker visuals.
	var flick := 0.5 + 0.5 * sin(_time * 18.0)
	_core.modulate = Color(1.0, 0.85 + flick * 0.15, 0.30 + flick * 0.20)
	_glow.modulate.a = 0.75 + flick * 0.25
	for i in _tongues.size():
		var t := _tongues[i]
		var f := 0.5 + 0.5 * sin(_time * 22.0 + i * 1.7)
		t.scale.y = 0.65 + f * 0.7
		t.modulate.a = 0.6 + f * 0.4

	# Fade in last half second.
	if _life < 0.5:
		modulate.a = maxf(_life * 2.0, 0.0)

func _on_body_entered(body: Node) -> void:
	if body.has_method("request_damage") and multiplayer.has_multiplayer_peer():
		body.request_damage.rpc_id(body.get_multiplayer_authority(), DAMAGE, global_position)
		queue_free()
	elif body.has_method("take_damage"):
		body.take_damage(DAMAGE, global_position)
		queue_free()
