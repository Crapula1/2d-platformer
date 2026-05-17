extends Node2D

# Atmospheric critter. Scampers along the ground, periodically picks a nearby
# palm tree, runs to it, climbs to a random height, perches, then climbs back
# down and picks a new target. Purely cosmetic — no collision, no hitbox.

enum State { SCAMPER, CLIMB, PERCH, DESCEND }

@export var ground_y: float = 400.0
@export var min_x: float = 0.0
@export var max_x: float = 6000.0
@export var run_speed: float = 70.0
@export var climb_speed: float = 50.0

var state: State = State.SCAMPER
var direction: int = 1
var target_x: float = 0.0
var target_tree: Node2D = null
var climb_height_remaining: float = 0.0
var perch_timer: float = 0.0
var hop_phase: float = 0.0
var idle_timer: float = 0.0

var _body: Polygon2D
var _tail: Polygon2D
var _eye: ColorRect

func _ready() -> void:
	hop_phase = randf() * TAU
	_build_sprite()
	position.y = ground_y - 5.0
	_pick_new_ground_target()

func _build_sprite() -> void:
	# Body — small reddish-brown blob
	_body = Polygon2D.new()
	_body.color = Color(0.55, 0.28, 0.12)
	_body.polygon = PackedVector2Array([
		Vector2(-4, -3), Vector2(3, -4), Vector2(5, -1),
		Vector2(4, 2),   Vector2(-3, 2), Vector2(-5, 0),
	])
	add_child(_body)

	# Tail — curls up and back
	_tail = Polygon2D.new()
	_tail.color = Color(0.62, 0.34, 0.16)
	_tail.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(-9, -4), Vector2(-10, -8),
		Vector2(-7, -10), Vector2(-5, -7), Vector2(-7, -3),
	])
	add_child(_tail)

	# Eye
	_eye = ColorRect.new()
	_eye.color = Color(0.05, 0.04, 0.03)
	_eye.offset_left = 2.0; _eye.offset_top = -2.0
	_eye.offset_right = 3.0; _eye.offset_bottom = -1.0
	add_child(_eye)

func _process(delta: float) -> void:
	match state:
		State.SCAMPER:  _scamper(delta)
		State.CLIMB:    _climb(delta)
		State.PERCH:    _perch(delta)
		State.DESCEND:  _descend(delta)

	scale.x = float(direction)

func _scamper(delta: float) -> void:
	var dx: float = target_x - position.x
	if absf(dx) < 4.0:
		# If we were heading to a tree, _physics_process handles the transition
		# into CLIMB on its next tick. Don't re-pick targets in the meantime.
		if target_tree != null and is_instance_valid(target_tree):
			return
		idle_timer -= delta
		if idle_timer <= 0.0:
			if randf() < 0.45:
				_try_pick_tree()
			else:
				_pick_new_ground_target()
		return

	direction = int(sign(dx)) if dx != 0 else direction
	position.x += float(direction) * run_speed * delta
	hop_phase += delta * 18.0
	position.y = ground_y - 5.0 + sin(hop_phase) * 0.8

func _try_pick_tree() -> void:
	var trees := get_tree().get_nodes_in_group("palm_tree")
	if trees.is_empty():
		_pick_new_ground_target()
		return
	# Find a tree within a reasonable scamper distance
	var candidates: Array = []
	for t in trees:
		if not (t is Node2D):
			continue
		var d: float = absf((t as Node2D).global_position.x - global_position.x)
		if d < 600.0:
			candidates.append(t)
	if candidates.is_empty():
		_pick_new_ground_target()
		return
	target_tree = candidates[randi() % candidates.size()]
	target_x = (target_tree as Node2D).global_position.x

	# Walk there first; switch to climbing once we arrive
	state = State.SCAMPER
	idle_timer = -1.0   # force movement until close, then climb
	# When we arrive, _scamper hits the dx<4 branch and we re-pick — fix that:
	# Use a quick poll loop via _on_arrived check inside _scamper instead.
	# Simplest: set a flag here, and on arrival switch to CLIMB.

func _pick_new_ground_target() -> void:
	target_tree = null
	# Wander 80..260 px in a random horizontal direction, clamped to bounds.
	var span: float = randf_range(80.0, 260.0) * (1.0 if randf() < 0.5 else -1.0)
	target_x = clampf(position.x + span, min_x + 12.0, max_x - 12.0)
	idle_timer = randf_range(0.6, 1.6)

func _climb(delta: float) -> void:
	if target_tree == null or not is_instance_valid(target_tree):
		state = State.SCAMPER
		_pick_new_ground_target()
		return
	var step: float = climb_speed * delta
	position.y -= step
	climb_height_remaining -= step
	# Face up the trunk — flip orientation so tail trails downward visually
	rotation = -PI * 0.5 if direction > 0 else PI * 0.5
	if climb_height_remaining <= 0.0:
		state = State.PERCH
		perch_timer = randf_range(1.8, 4.0)

func _perch(delta: float) -> void:
	rotation = -PI * 0.5 if direction > 0 else PI * 0.5
	hop_phase += delta * 4.0
	# Little tail twitch via subtle rotation jitter
	_tail.rotation = sin(hop_phase * 2.0) * 0.15
	perch_timer -= delta
	if perch_timer <= 0.0:
		state = State.DESCEND

func _descend(delta: float) -> void:
	var step: float = climb_speed * delta
	position.y += step
	rotation = -PI * 0.5 if direction > 0 else PI * 0.5
	if position.y >= ground_y - 5.0:
		position.y = ground_y - 5.0
		rotation = 0.0
		_tail.rotation = 0.0
		# Skitter away from the trunk
		direction = -direction
		state = State.SCAMPER
		_pick_new_ground_target()
		target_tree = null

func _physics_process(_delta: float) -> void:
	# Check arrival at a tree mid-scamper.
	if state == State.SCAMPER and target_tree != null and is_instance_valid(target_tree):
		if absf(position.x - target_x) < 4.0:
			state = State.CLIMB
			var th: float = 60.0
			if target_tree.has_method("get_climb_height"):
				th = target_tree.get_climb_height()
			climb_height_remaining = randf_range(th * 0.4, th * 0.85)
