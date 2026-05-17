extends Node2D

# Atmospheric critter. Hops along the ground between bush positions, pauses to
# twitch ears, occasionally darts behind a bush and "hides" (fades briefly).
# Purely cosmetic — no collision.

enum State { IDLE, HOP, HIDE }

@export var ground_y: float = 400.0
@export var min_x: float = 0.0
@export var max_x: float = 6000.0
@export var hop_distance: float = 32.0
@export var hop_duration: float = 0.35
@export var hop_height: float = 14.0

var state: State = State.IDLE
var direction: int = 1
var idle_timer: float = 0.0
var hop_timer: float = 0.0
var hop_from: Vector2 = Vector2.ZERO
var hop_to: Vector2 = Vector2.ZERO
var hide_timer: float = 0.0
var ear_phase: float = 0.0

var _body: Polygon2D
var _head: ColorRect
var _ear_l: Polygon2D
var _ear_r: Polygon2D
var _tail: ColorRect

func _ready() -> void:
	ear_phase = randf() * TAU
	idle_timer = randf_range(0.4, 1.2)
	_build_sprite()
	position.y = ground_y - 4.0

func _build_sprite() -> void:
	_body = Polygon2D.new()
	_body.color = Color(0.82, 0.80, 0.74)
	_body.polygon = PackedVector2Array([
		Vector2(-5, -2), Vector2(3, -3), Vector2(5, -1),
		Vector2(4, 2), Vector2(-4, 2), Vector2(-6, 0),
	])
	add_child(_body)

	_head = ColorRect.new()
	_head.color = Color(0.90, 0.88, 0.82)
	_head.offset_left = 3.0; _head.offset_top = -5.0
	_head.offset_right = 7.0; _head.offset_bottom = -1.0
	add_child(_head)

	_ear_l = Polygon2D.new()
	_ear_l.color = Color(0.86, 0.82, 0.76)
	_ear_l.polygon = PackedVector2Array([
		Vector2(4, -5), Vector2(5, -10), Vector2(6, -5),
	])
	add_child(_ear_l)

	_ear_r = Polygon2D.new()
	_ear_r.color = Color(0.86, 0.82, 0.76)
	_ear_r.polygon = PackedVector2Array([
		Vector2(6, -5), Vector2(7, -10), Vector2(8, -5),
	])
	add_child(_ear_r)

	_tail = ColorRect.new()
	_tail.color = Color(0.98, 0.96, 0.92)
	_tail.offset_left = -7.0; _tail.offset_top = -1.0
	_tail.offset_right = -5.0; _tail.offset_bottom = 1.0
	add_child(_tail)

func _process(delta: float) -> void:
	ear_phase += delta * 6.0
	# Subtle ear twitch when idle, locked-back during hops
	if state == State.IDLE:
		_ear_l.rotation = sin(ear_phase) * 0.10
		_ear_r.rotation = sin(ear_phase + 1.1) * 0.12
	else:
		_ear_l.rotation = lerpf(_ear_l.rotation, -0.25, minf(delta * 12.0, 1.0))
		_ear_r.rotation = lerpf(_ear_r.rotation, -0.25, minf(delta * 12.0, 1.0))

	match state:
		State.IDLE: _idle(delta)
		State.HOP:  _hop(delta)
		State.HIDE: _hide(delta)

	scale.x = float(direction)

func _idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		# Maybe hide near a bush, otherwise hop
		if randf() < 0.20:
			_try_hide_at_bush()
		else:
			_start_hop()

func _start_hop() -> void:
	# Pick a direction with a bias toward staying within bounds
	var d: int = direction
	if randf() < 0.35:
		d = -d
	# Look-ahead bounds nudge
	var ahead: float = position.x + float(d) * hop_distance
	if ahead < min_x + 16.0 or ahead > max_x - 16.0:
		d = -d
	direction = d
	hop_from = position
	hop_to = Vector2(clampf(position.x + float(d) * hop_distance, min_x + 12.0, max_x - 12.0), ground_y - 4.0)
	hop_timer = 0.0
	state = State.HOP

func _hop(delta: float) -> void:
	hop_timer += delta
	var t: float = clampf(hop_timer / hop_duration, 0.0, 1.0)
	position.x = lerpf(hop_from.x, hop_to.x, t)
	# Parabolic arc
	var arc: float = sin(t * PI) * hop_height
	position.y = (ground_y - 4.0) - arc
	if t >= 1.0:
		position = hop_to
		state = State.IDLE
		idle_timer = randf_range(0.25, 0.9)

func _try_hide_at_bush() -> void:
	var bushes := get_tree().get_nodes_in_group("bush")
	if bushes.is_empty():
		_start_hop()
		return
	var nearest: Node2D = null
	var best: float = 999999.0
	for b in bushes:
		if not (b is Node2D):
			continue
		var d: float = absf((b as Node2D).global_position.x - global_position.x)
		if d < best:
			best = d
			nearest = b
	if nearest == null or best > 220.0:
		_start_hop()
		return
	# Hop toward the bush, then hide
	direction = int(sign(nearest.global_position.x - global_position.x)) if nearest.global_position.x != global_position.x else direction
	hop_from = position
	hop_to = Vector2(nearest.global_position.x, ground_y - 4.0)
	hop_timer = 0.0
	state = State.HOP
	# When hop completes, _hop will go IDLE — flip to HIDE next idle frame:
	hide_timer = randf_range(0.8, 2.2)
	call_deferred("_queue_hide_after_hop")

func _queue_hide_after_hop() -> void:
	# Wait until we land, then enter HIDE.
	await get_tree().create_timer(hop_duration + 0.02).timeout
	if not is_instance_valid(self):
		return
	state = State.HIDE
	modulate.a = 0.3

func _hide(delta: float) -> void:
	hide_timer -= delta
	if hide_timer <= 0.0:
		modulate.a = 1.0
		state = State.IDLE
		idle_timer = randf_range(0.3, 0.9)
		# Bolt away from the bush
		direction = -direction
