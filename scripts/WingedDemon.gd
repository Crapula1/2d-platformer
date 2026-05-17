extends CharacterBody2D
class_name WingedDemon

# Winged demonic mini-boss — flaps wings to fly, dive-bombs the player,
# and swings a sword in a wide arc. Lighter HP than JetTrooper but more
# aggressive. Color is set per-instance via the `tint` exports so the
# same scene yields several visually distinct variants.

enum State { PATROL, ALERT, CHASE, WINDUP, SWING, RECOVER, STAGGER, DEAD }

# --- Color variant -----------------------------------------------------------
@export var tint: Color = Color(0.85, 0.20, 0.20)         # body
@export var wing_color: Color = Color(0.55, 0.08, 0.10)   # primary wing
@export var wing_edge_color: Color = Color(0.20, 0.02, 0.02)
@export var horn_color: Color = Color(0.10, 0.05, 0.05)
@export var sword_color: Color = Color(0.90, 0.92, 0.96)
@export var eye_color: Color = Color(1.0, 0.95, 0.4)

# --- Combat ------------------------------------------------------------------
@export var max_health: int = 12
@export var contact_damage: int = 1
@export var sword_damage: int = 2
@export var sight_range: float = 380.0
@export var engage_range: float = 200.0     # close to swing distance
@export var attack_range: float = 60.0      # swing if within this
@export var preferred_altitude: float = -28.0

# --- Flight ------------------------------------------------------------------
@export var max_speed: float = 240.0
@export var thrust_force: float = 820.0
@export var damping: float = 4.5
@export var flap_speed: float = 6.0
@export var dive_boost: float = 1.5         # speed multiplier on attack lunge

# --- Sword swing -------------------------------------------------------------
@export var swing_cooldown: float = 1.1
@export var swing_windup: float = 0.18      # raise sword
@export var swing_duration: float = 0.22    # swing arc length
@export var swing_active_start: float = 0.04
@export var swing_active_end: float = 0.18

# --- Patrol ------------------------------------------------------------------
@export var patrol_width: float = 320.0
@export var patrol_height: float = 80.0
@export var patrol_speed: float = 0.4

@export var alert_time: float = 0.35
@export var stagger_time: float = 0.30

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
var swing_cd_timer: float = 0.0
var state_timer: float = 0.0     # time spent in current attack sub-state
var bob_phase: float = 0.0
var patrol_phase: float = 0.0
var flap_phase: float = 0.0
var _hit_this_swing: bool = false

@onready var body_visual: Node2D = $Body
@onready var torso: ColorRect = $Body/Torso
@onready var head: ColorRect = $Body/Head
@onready var horn_l: Polygon2D = $Body/HornL
@onready var horn_r: Polygon2D = $Body/HornR
@onready var eye: ColorRect = $Body/Eye
@onready var wing_l: Polygon2D = $Body/WingL
@onready var wing_r: Polygon2D = $Body/WingR
@onready var sword_pivot: Node2D = $Body/SwordPivot
@onready var sword: Polygon2D = $Body/SwordPivot/Sword
@onready var sword_glow: Polygon2D = $Body/SwordPivot/SwordGlow
@onready var sword_hitbox: Area2D = $Body/SwordPivot/Hitbox
@onready var sword_hitbox_shape: CollisionShape2D = $Body/SwordPivot/Hitbox/CollisionShape2D
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	bob_phase = randf() * TAU
	flap_phase = randf() * TAU
	add_to_group("enemy")
	_find_player()
	_apply_tint()
	sword_hitbox_shape.set_deferred("disabled", true)
	sword_hitbox.body_entered.connect(_on_sword_hit)
	sword_hitbox.area_entered.connect(_on_sword_area)
	sword_pivot.rotation = -PI / 2.5

func _apply_tint() -> void:
	torso.color = tint
	head.color = tint.darkened(0.15)
	horn_l.color = horn_color
	horn_r.color = horn_color
	wing_l.color = wing_color
	wing_r.color = wing_color
	eye.color = eye_color
	sword.color = sword_color
	sword_glow.color = Color(sword_color.r, sword_color.g, sword_color.b, 0.35)

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
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

func _update_timers(delta: float) -> void:
	bob_phase += delta * 3.0
	patrol_phase += delta * patrol_speed * TAU
	flap_phase += delta * flap_speed
	if alert_timer > 0: alert_timer -= delta
	if stagger_timer > 0: stagger_timer -= delta
	if swing_cd_timer > 0: swing_cd_timer -= delta
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
		State.SWING:
			# enable sword hitbox for the active frames
			sword_hitbox_shape.set_deferred("disabled", false)
		State.RECOVER:
			sword_hitbox_shape.set_deferred("disabled", true)
			swing_cd_timer = swing_cooldown
		State.STAGGER:
			sword_hitbox_shape.set_deferred("disabled", true)
		_:
			pass

func _update_state() -> void:
	if stagger_timer > 0 and state != State.STAGGER:
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
			elif dist <= attack_range and swing_cd_timer <= 0:
				_set_state(State.WINDUP)
		State.WINDUP:
			if state_timer >= swing_windup:
				_set_state(State.SWING)
		State.SWING:
			if state_timer >= swing_duration:
				_set_state(State.RECOVER)
		State.RECOVER:
			if state_timer >= 0.18:
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
			# Hover, brace, face the player
			if player:
				direction = int(sign(player.global_position.x - global_position.x))
				if direction == 0: direction = 1
			_thrust_toward(global_position + Vector2(0, sin(bob_phase) * 4.0), delta, 0.9)
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			# Slow as we wind up
			velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
			if player:
				direction = int(sign(player.global_position.x - global_position.x))
				if direction == 0: direction = 1
		State.SWING:
			# Dive forward through the swing
			var fwd := Vector2(float(direction) * 180.0, 30.0)
			velocity = velocity.move_toward(fwd, 1500 * delta)
		State.RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0, 500 * delta)
			velocity.y = move_toward(velocity.y, 80.0, 600 * delta)
		_:
			pass

func _patrol(delta: float) -> void:
	var target: Vector2 = start_position + Vector2(
		sin(patrol_phase) * patrol_width * 0.5,
		sin(patrol_phase * 2.0) * patrol_height * 0.5
	)
	_thrust_toward(target, delta, 0.6)
	if absf(velocity.x) > 8.0:
		direction = int(sign(velocity.x))

func _chase(delta: float) -> void:
	if player == null: return
	# Dive at the player from above
	var target: Vector2 = player.global_position + Vector2(0, preferred_altitude)
	_thrust_toward(target, delta, 1.1)
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
	stagger_timer = stagger_time
	var knockback: Vector2 = (global_position - source_pos).normalized() * 200.0
	velocity = velocity * 0.4 + knockback
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
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self): queue_free()
	)

func _on_sword_hit(body: Node) -> void:
	if _hit_this_swing: return
	if body is Player and body.has_method("request_damage"):
		body.request_damage.rpc_id(body.get_multiplayer_authority(), sword_damage, global_position)
		_hit_this_swing = true

func _on_sword_area(area: Area2D) -> void:
	# Player Hurtbox is an Area2D — route through it the same way.
	if _hit_this_swing: return
	var p := area.get_parent()
	if p is Player and p.has_method("request_damage"):
		p.request_damage.rpc_id(p.get_multiplayer_authority(), sword_damage, global_position)
		_hit_this_swing = true

func _update_visuals(delta: float) -> void:
	# Face flip (smooth) — also flips the sword pivot side.
	var target_facing := float(direction)
	body_visual.scale.x = lerpf(body_visual.scale.x, target_facing, minf(delta * 14.0, 1.0))

	if is_dead:
		return

	# Wing flap — rotate each wing around its root for a flap.
	var flap: float = sin(flap_phase) * 0.55
	wing_l.rotation = -flap
	wing_r.rotation = flap
	# Vertical bob synced loosely to flap
	body_visual.position.y = sin(flap_phase) * -1.5

	# Eye glow shifts color by state
	match state:
		State.PATROL:
			eye.color = eye_color.darkened(0.25)
		State.ALERT:
			eye.color = Color(1.0, 0.65, 0.1)
		State.CHASE:
			eye.color = Color(1.0, 0.25, 0.10)
		State.WINDUP:
			eye.color = Color(1.0, 0.95, 0.45)
		State.SWING:
			eye.color = Color(1.0, 1.0, 0.85)
		State.STAGGER:
			eye.color = Color(0.4, 0.5, 0.6)
		_:
			pass

	# Sword animation — drive sword_pivot rotation through the swing arc.
	# Sword rests behind, raises on WINDUP, swings forward fast on SWING.
	var rest_rot := -PI / 2.5   # raised behind shoulder, ready
	var raised_rot := -PI * 0.85
	var end_rot := PI / 2.2
	var target_rot := rest_rot
	match state:
		State.WINDUP:
			var t := clampf(state_timer / swing_windup, 0.0, 1.0)
			target_rot = lerpf(rest_rot, raised_rot, t)
		State.SWING:
			var t2 := clampf(state_timer / swing_duration, 0.0, 1.0)
			# ease-out cubic
			t2 = 1.0 - pow(1.0 - t2, 3.0)
			target_rot = lerpf(raised_rot, end_rot, t2)
			# Active hitbox window — leave the polygon enabling to the state setter
			if state_timer < swing_active_start or state_timer > swing_active_end:
				sword_hitbox_shape.set_deferred("disabled", true)
			else:
				sword_hitbox_shape.set_deferred("disabled", false)
		State.RECOVER:
			var t3 := clampf(state_timer / 0.18, 0.0, 1.0)
			target_rot = lerpf(end_rot, rest_rot, t3)
	sword_pivot.rotation = lerpf(sword_pivot.rotation, target_rot, minf(delta * 22.0, 1.0))

	# Sword glow pulses brighter during the active swing for readability
	var glow_a := 0.25
	if state == State.WINDUP:
		glow_a = 0.45
	elif state == State.SWING:
		glow_a = 0.85
	sword_glow.modulate.a = lerpf(sword_glow.modulate.a, glow_a, minf(delta * 18.0, 1.0))
