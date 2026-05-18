extends CharacterBody2D
class_name GreaterDemon

# Greater Demon — heavy flying mini-boss. Slower than WingedDemon but
# hits like a truck. Signature attack is a wide 180-degree CLEAVE that
# arcs from overhead to forward-down through a single ease-out sweep,
# leaving a motion-trail of fading sword ghosts so the player can read
# the danger zone.

enum State { PATROL, ALERT, CHASE, WINDUP, CLEAVE, RECOVER, STAGGER, DEAD }

# --- Color variant ----------------------------------------------------------
@export var tint: Color = Color(0.55, 0.10, 0.12)
@export var tint_dark: Color = Color(0.28, 0.05, 0.08)
@export var wing_color: Color = Color(0.18, 0.04, 0.08)
@export var wing_edge_color: Color = Color(0.05, 0.01, 0.03)
@export var horn_color: Color = Color(0.08, 0.04, 0.04)
@export var rune_color: Color = Color(1.0, 0.55, 0.15)
@export var eye_color: Color = Color(1.0, 0.85, 0.30)
@export var sword_color: Color = Color(0.92, 0.94, 1.0)
@export var cape_color: Color = Color(0.10, 0.04, 0.04, 0.85)

# --- Combat -----------------------------------------------------------------
@export var max_health: int = 24
@export var contact_damage: int = 2
@export var cleave_damage: int = 3
@export var sight_range: float = 460.0
@export var attack_range: float = 90.0
@export var preferred_altitude: float = -40.0

# --- Flight -----------------------------------------------------------------
@export var max_speed: float = 200.0
@export var thrust_force: float = 700.0
@export var damping: float = 5.0
@export var flap_speed: float = 4.5
@export var dive_boost: float = 1.4

# --- Cleave -----------------------------------------------------------------
@export var cleave_cooldown: float = 1.6
@export var windup_time: float = 0.55     # long, telegraphed
@export var cleave_time: float = 0.34     # sweep duration
@export var cleave_active_start: float = 0.05
@export var cleave_active_end: float = 0.30
@export var trail_interval: float = 0.035
@export var trail_lifetime: float = 0.28

# --- Patrol -----------------------------------------------------------------
@export var patrol_width: float = 380.0
@export var patrol_height: float = 100.0
@export var patrol_speed: float = 0.35

@export var alert_time: float = 0.5
@export var stagger_time: float = 0.35

const EXPLOSIVE_EFFECT_SCENE = preload("res://scenes/ExplosiveEffect.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var state: State = State.PATROL
var current_health: int
var is_dead: bool = false
var direction: int = 1
var start_position: Vector2
var player: Player = null

var alert_timer: float = 0.0
var stagger_timer: float = 0.0
var cleave_cd_timer: float = 0.0
var state_timer: float = 0.0
var trail_timer: float = 0.0
var bob_phase: float = 0.0
var patrol_phase: float = 0.0
var flap_phase: float = 0.0
var cape_phase: float = 0.0
var _hit_this_swing: bool = false

@onready var body_visual: Node2D = $Body
@onready var torso: ColorRect = $Body/Torso
@onready var head: ColorRect = $Body/Head
@onready var horn_l: Polygon2D = $Body/HornL
@onready var horn_r: Polygon2D = $Body/HornR
@onready var horn_l2: Polygon2D = $Body/HornL2
@onready var horn_r2: Polygon2D = $Body/HornR2
@onready var rune: Polygon2D = $Body/ChestRune
@onready var eye: ColorRect = $Body/Eye
@onready var wing_l: Polygon2D = $Body/WingL
@onready var wing_r: Polygon2D = $Body/WingR
@onready var cape: Polygon2D = $Body/Cape
@onready var sword_pivot: Node2D = $Body/SwordPivot
@onready var sword: Polygon2D = $Body/SwordPivot/Sword
@onready var sword_glow: Polygon2D = $Body/SwordPivot/SwordGlow
@onready var sword_edge: Polygon2D = $Body/SwordPivot/SwordEdge
@onready var sword_hitbox: Area2D = $Body/SwordPivot/Hitbox
@onready var sword_hitbox_shape: CollisionShape2D = $Body/SwordPivot/Hitbox/CollisionShape2D
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay

static var SWORD_POLY: PackedVector2Array = PackedVector2Array([
	Vector2(0, -3), Vector2(10, -5), Vector2(24, -6), Vector2(40, -4),
	Vector2(50, 0), Vector2(40, 4), Vector2(24, 4), Vector2(10, 2), Vector2(0, 3),
])

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	bob_phase = randf() * TAU
	flap_phase = randf() * TAU
	cape_phase = randf() * TAU
	add_to_group("enemy")
	_find_player()
	_apply_tint()
	sword_hitbox_shape.set_deferred("disabled", true)
	sword_hitbox.body_entered.connect(_on_sword_hit)
	sword_hitbox.area_entered.connect(_on_sword_area)
	sword_pivot.rotation = -PI / 2.2

func _apply_tint() -> void:
	torso.color = tint
	head.color = tint_dark
	horn_l.color = horn_color
	horn_r.color = horn_color
	horn_l2.color = horn_color
	horn_r2.color = horn_color
	rune.color = rune_color
	eye.color = eye_color
	wing_l.color = wing_color
	wing_r.color = wing_color
	cape.color = cape_color
	sword.color = sword_color
	sword_edge.color = Color(rune_color.r, rune_color.g, rune_color.b, 0.85)
	sword_glow.color = Color(sword_color.r, sword_color.g, sword_color.b, 0.35)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		if has_method("_update_visuals"):
			_update_visuals(delta)
		return
	if is_dead:
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, 200 * delta)
		move_and_slide()
		return

	if player == null or not is_instance_valid(player):
		_find_player()

	_update_timers(delta)
	_update_state()
	_run_state(delta)
	velocity.x = clampf(velocity.x, -max_speed * dive_boost, max_speed * dive_boost)
	velocity.y = clampf(velocity.y, -max_speed * dive_boost, max_speed * dive_boost)
	move_and_slide()
	_update_visuals(delta)
	_update_trail(delta)

func _update_timers(delta: float) -> void:
	bob_phase += delta * 2.4
	patrol_phase += delta * patrol_speed * TAU
	flap_phase += delta * flap_speed
	cape_phase += delta * 3.0
	if alert_timer > 0: alert_timer -= delta
	if stagger_timer > 0: stagger_timer -= delta
	if cleave_cd_timer > 0: cleave_cd_timer -= delta
	state_timer += delta

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_timer = 0.0
	match state:
		State.PATROL:
			alert_indicator.visible = false
		State.ALERT:
			alert_timer = alert_time
			alert_indicator.visible = true
		State.CHASE:
			alert_indicator.visible = false
		State.WINDUP:
			_hit_this_swing = false
		State.CLEAVE:
			sword_hitbox_shape.set_deferred("disabled", false)
			trail_timer = 0.0
		State.RECOVER:
			sword_hitbox_shape.set_deferred("disabled", true)
			cleave_cd_timer = cleave_cooldown
		State.STAGGER:
			sword_hitbox_shape.set_deferred("disabled", true)
		_:
			pass

func _update_state() -> void:
	if stagger_timer > 0 and state != State.STAGGER and state not in [State.WINDUP, State.CLEAVE]:
		_set_state(State.STAGGER)
		return
	if player == null or player.is_dead:
		_set_state(State.PATROL)
		return

	var dist: float = global_position.distance_to(player.global_position)
	var can_see: bool = _has_line_of_sight(dist)

	match state:
		State.PATROL:
			if can_see and dist <= sight_range:
				_set_state(State.ALERT)
		State.ALERT:
			if alert_timer <= 0:
				_set_state(State.CHASE)
		State.CHASE:
			if dist > sight_range * 1.4:
				_set_state(State.PATROL)
			elif dist <= attack_range and cleave_cd_timer <= 0:
				_set_state(State.WINDUP)
		State.WINDUP:
			if state_timer >= windup_time:
				_set_state(State.CLEAVE)
		State.CLEAVE:
			if state_timer >= cleave_time:
				_set_state(State.RECOVER)
		State.RECOVER:
			if state_timer >= 0.32:
				_set_state(State.CHASE)
		State.STAGGER:
			if stagger_timer <= 0:
				_set_state(State.CHASE)
		_:
			pass

func _run_state(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol(delta)
		State.ALERT:
			if player:
				direction = int(sign(player.global_position.x - global_position.x))
				if direction == 0: direction = 1
			_thrust_toward(global_position + Vector2(0, sin(bob_phase) * 4.0), delta, 0.9)
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			# Pull up slightly and stop — the demon braces overhead.
			var brace := global_position + Vector2(0, -18)
			_thrust_toward(brace, delta, 1.2)
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
			if player:
				direction = int(sign(player.global_position.x - global_position.x))
				if direction == 0: direction = 1
		State.CLEAVE:
			# Plunge forward + down through the swing.
			var fwd := Vector2(float(direction) * 220.0, 60.0)
			velocity = velocity.move_toward(fwd, 1800 * delta)
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 900 * delta)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0, 500 * delta)
			velocity.y = move_toward(velocity.y, 60.0, 600 * delta)
		_:
			pass

func _patrol(delta: float) -> void:
	var target: Vector2 = start_position + Vector2(
		sin(patrol_phase) * patrol_width * 0.5,
		sin(patrol_phase * 2.0) * patrol_height * 0.5
	)
	_thrust_toward(target, delta, 0.55)
	if absf(velocity.x) > 8.0:
		direction = int(sign(velocity.x))

func _chase(delta: float) -> void:
	if player == null: return
	var target: Vector2 = player.global_position + Vector2(0, preferred_altitude)
	_thrust_toward(target, delta, 1.0)
	direction = int(sign(player.global_position.x - global_position.x))
	if direction == 0: direction = 1

func _thrust_toward(target: Vector2, delta: float, strength: float = 1.0) -> void:
	var to_target: Vector2 = target - global_position
	var desired: Vector2 = to_target.limit_length(max_speed)
	var steer: Vector2 = (desired - velocity) * strength
	velocity += steer.limit_length(thrust_force * delta)
	velocity = velocity.move_toward(Vector2.ZERO, damping * delta)

func _has_line_of_sight(dist: float) -> bool:
	if player == null or dist > sight_range:
		return false
	sight_ray.target_position = to_local(player.global_position)
	sight_ray.force_raycast_update()
	if not sight_ray.is_colliding():
		return true
	return sight_ray.get_collider() == player

func get_damage() -> int:
	return contact_damage

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_dead:
		return
	current_health -= amount
	# Greater demons commit to their swing — small flinch, no full stagger
	# while cleaving (so the attack still lands).
	if state != State.CLEAVE and state != State.WINDUP:
		stagger_timer = stagger_time
	var knockback: Vector2 = (global_position - source_pos).normalized() * 120.0
	velocity = velocity * 0.65 + knockback
	net_flash.rpc()
	if current_health <= 0:
		_net_kill.rpc()

@rpc("any_peer", "call_local", "reliable")
func request_damage(amount: int, source_pos: Vector2) -> void:
	if is_multiplayer_authority():
		take_damage(amount, source_pos)

@rpc("authority", "call_local", "reliable")
func _net_kill() -> void:
	if not is_dead:
		_die()

@rpc("authority", "call_local", "reliable")
func net_flash() -> void:
	_flash_hit()

func stun(duration: float) -> void:
	if is_dead: return
	stagger_timer = maxf(stagger_timer, duration)
	body_visual.modulate = Color(0.45, 0.85, 2.0)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_dead:
			body_visual.modulate = Color.WHITE
	)

func _flash_hit() -> void:
	body_visual.modulate = Color(2.5, 2.5, 2.5)
	get_tree().create_timer(0.07).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_dead:
			body_visual.modulate = Color.WHITE
	)

func _die() -> void:
	is_dead = true
	body_visual.modulate = Color(0.4, 0.4, 0.4)
	alert_indicator.visible = false
	sword_hitbox_shape.set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 1
	var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	get_parent().add_child(fx)
	fx.global_position = global_position
	# Second explosion staggered for "big enemy" feel
	get_tree().create_timer(0.2).timeout.connect(func() -> void:
		if not is_instance_valid(self): return
		var fx2 := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
		get_parent().add_child(fx2)
		fx2.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-8, 8))
	)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(self): queue_free()
	)

func _on_sword_hit(body: Node) -> void:
	if _hit_this_swing: return
	if body is Player and body.has_method("request_damage"):
		body.request_damage.rpc_id(body.get_multiplayer_authority(), cleave_damage, global_position)
		_hit_this_swing = true

func _on_sword_area(area: Area2D) -> void:
	if _hit_this_swing: return
	var p := area.get_parent()
	if p is Player and p.has_method("request_damage"):
		p.request_damage.rpc_id(p.get_multiplayer_authority(), cleave_damage, global_position)
		_hit_this_swing = true

func _update_visuals(delta: float) -> void:
	var target_facing := float(direction)
	body_visual.scale.x = lerpf(body_visual.scale.x, target_facing, minf(delta * 12.0, 1.0))

	if is_dead:
		return

	# Wing flap — slower and grander than WingedDemon
	var flap: float = sin(flap_phase) * 0.7
	wing_l.rotation = -flap
	wing_r.rotation = flap
	body_visual.position.y = sin(flap_phase) * -2.0
	# Cape sways with motion and bob
	cape.rotation = sin(cape_phase) * 0.10 + clampf(velocity.x * 0.001, -0.25, 0.25) * 0.4

	# Eye glow shifts by state
	match state:
		State.PATROL:    eye.color = eye_color.darkened(0.30)
		State.ALERT:     eye.color = Color(1.0, 0.55, 0.15)
		State.CHASE:     eye.color = Color(1.0, 0.30, 0.10)
		State.WINDUP:    eye.color = Color(1.0, 0.95, 0.45)
		State.CLEAVE:    eye.color = Color(1.0, 1.0, 0.85)
		State.STAGGER:   eye.color = Color(0.4, 0.5, 0.6)
		_:               pass

	# Sword animation — the cleave is the showcase: from way overhead
	# (-PI/2.2 ~ -82deg) through a wide arc to forward-down (+PI/3 ~ +60deg).
	var rest_rot: float = -PI / 2.2          # raised behind shoulder
	var raised_rot: float = -PI * 0.95       # straight up + slightly back
	var end_rot: float = PI / 3.0            # forward-down past horizontal
	var target_rot: float = rest_rot
	match state:
		State.WINDUP:
			var t: float = clampf(state_timer / windup_time, 0.0, 1.0)
			# Slow ease into raised
			t = t * t * (3.0 - 2.0 * t)   # smoothstep
			target_rot = lerpf(rest_rot, raised_rot, t)
		State.CLEAVE:
			var t2: float = clampf(state_timer / cleave_time, 0.0, 1.0)
			# Ease-out cubic for a heavy, fast sweep
			t2 = 1.0 - pow(1.0 - t2, 3.0)
			target_rot = lerpf(raised_rot, end_rot, t2)
			# Tighten the active-window gating
			if state_timer < cleave_active_start or state_timer > cleave_active_end:
				sword_hitbox_shape.set_deferred("disabled", true)
			else:
				sword_hitbox_shape.set_deferred("disabled", false)
		State.RECOVER:
			var t3: float = clampf(state_timer / 0.32, 0.0, 1.0)
			target_rot = lerpf(end_rot, rest_rot, t3)
	sword_pivot.rotation = lerpf(sword_pivot.rotation, target_rot, minf(delta * 24.0, 1.0))

	# Sword glow brightness by state for readability
	var glow_a := 0.25
	if state == State.WINDUP:    glow_a = 0.55
	elif state == State.CLEAVE:  glow_a = 0.95
	sword_glow.modulate.a = lerpf(sword_glow.modulate.a, glow_a, minf(delta * 18.0, 1.0))

func _update_trail(delta: float) -> void:
	# Spawn fading sword ghosts during the active cleave to read the sweep.
	if state != State.CLEAVE:
		return
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = trail_interval
	var ghost := Polygon2D.new()
	ghost.polygon = SWORD_POLY
	ghost.color = Color(sword_color.r, sword_color.g, sword_color.b, 0.55)
	ghost.global_position = sword_pivot.global_position
	ghost.rotation = sword_pivot.global_rotation
	ghost.scale = sword_pivot.global_scale
	ghost.z_index = -1
	get_parent().add_child(ghost)
	# Fade out + queue_free via a tween
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, trail_lifetime)
	tw.tween_callback(ghost.queue_free)
