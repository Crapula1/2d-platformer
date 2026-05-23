extends CharacterBody2D
class_name JetTrooper

# Jetpack mini-boss. Hovers, chases the player in 2D, leads shots, and only
# falls under gravity once it dies.

enum State { IDLE, ALERT, CHASE, ATTACK, STAGGER, DEAD }

@export var max_health: int = 9
@export var contact_damage: int = 1
@export var bullet_damage: int = 1
@export var bullet_speed: float = 340.0

@export var sight_range: float = 360.0
@export var attack_range: float = 300.0
@export var preferred_distance: float = 180.0
@export var preferred_altitude: float = -60.0  # hover above the player's head

@export var thrust_force: float = 720.0
@export var max_speed: float = 200.0
@export var damping: float = 4.5
@export var hover_bob_amp: float = 6.0

@export var fire_rate: float = 1.4
@export var burst_count: int = 3
@export var burst_interval: float = 0.12
@export var burst_cooldown: float = 0.9
@export var spread: float = 0.06
@export var missile_every: int = 2   # fire a missile once every N bullet bursts
@export var missile_cooldown: float = 2.0

@export var alert_time: float = 0.45
@export var stagger_time: float = 0.35

# Patrol — even when not engaging, fly a slow horizontal sweep around
# start_position so the trooper is always roaming the airspace.
@export var patrol_width: float = 280.0
@export var patrol_height: float = 60.0
@export var patrol_speed: float = 0.45  # cycles per second along the sweep

const BULLET_SCENE = preload("res://scenes/Bullet.tscn")
const MISSILE_SCENE = preload("res://scenes/HomingMissile.tscn")
const EXPLOSIVE_EFFECT_SCENE = preload("res://scenes/ExplosiveEffect.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var state: State = State.IDLE
var current_health: int
var is_dead: bool = false
var direction: int = 1
var start_position: Vector2
var player: Player = null
var fire_timer: float = 0.0
var alert_timer: float = 0.0
var stagger_timer: float = 0.0
var burst_left: int = 0
var burst_timer: float = 0.0
var bob_phase: float = 0.0
var patrol_phase: float = 0.0
var bursts_fired: int = 0
var missile_timer: float = 0.0

@onready var body_visual: Node2D = $Body
@onready var visor: ColorRect = $Body/Visor
@onready var gun_muzzle: Marker2D = $Body/GunMuzzle
@onready var thrust_flame: Polygon2D = $Body/ThrustFlame
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	bob_phase = randf() * TAU
	add_to_group("enemy")
	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if not Net.is_solo() and not is_multiplayer_authority():
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
	velocity.x = clampf(velocity.x, -max_speed, max_speed)
	velocity.y = clampf(velocity.y, -max_speed, max_speed)
	move_and_slide()
	_update_visuals(delta)

func _update_timers(delta: float) -> void:
	bob_phase += delta * 3.2
	patrol_phase += delta * patrol_speed * TAU
	if fire_timer > 0: fire_timer -= delta
	if alert_timer > 0: alert_timer -= delta
	if stagger_timer > 0: stagger_timer -= delta
	if burst_timer > 0: burst_timer -= delta
	if missile_timer > 0: missile_timer -= delta

func _update_state() -> void:
	if stagger_timer > 0:
		_set_state(State.STAGGER)
		return
	if player == null or player.is_dead:
		_set_state(State.IDLE)
		return

	var dist: float = global_position.distance_to(player.global_position)
	var can_see: bool = _has_line_of_sight(dist)

	match state:
		State.IDLE:
			if can_see and dist <= sight_range:
				_set_state(State.ALERT)
		State.ALERT:
			if alert_timer <= 0:
				_set_state(State.CHASE)
		State.CHASE:
			if dist > sight_range * 1.4:
				_set_state(State.IDLE)
			elif can_see and dist <= attack_range:
				_set_state(State.ATTACK)
		State.ATTACK:
			if not can_see or dist > attack_range * 1.2:
				_set_state(State.CHASE)
		State.STAGGER:
			if stagger_timer <= 0:
				_set_state(State.CHASE)
		_:
			pass

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		State.IDLE:
			alert_indicator.visible = false
		State.ALERT:
			alert_timer = alert_time
			alert_indicator.visible = true
			fire_timer = alert_time + 0.1
		State.CHASE:
			alert_indicator.visible = false
		State.ATTACK:
			alert_indicator.visible = false
		State.STAGGER:
			alert_indicator.visible = false

func _run_state(delta: float) -> void:
	match state:
		State.IDLE:
			_patrol(delta)
		State.ALERT:
			# Brace + face the player while the alert plays out.
			if player:
				direction = int(sign(player.global_position.x - global_position.x))
				if direction == 0: direction = 1
			_hover_to(global_position, delta, 0.9)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)
		State.STAGGER:
			# Cut thrust briefly — the trooper sags.
			velocity.y = move_toward(velocity.y, 80.0, thrust_force * 0.5 * delta)
			velocity.x = move_toward(velocity.x, 0, thrust_force * delta)

func _patrol(delta: float) -> void:
	# Figure-8 over the patrol box centered on start_position. Always moving.
	var target: Vector2 = start_position + Vector2(
		sin(patrol_phase) * patrol_width * 0.5,
		sin(patrol_phase * 2.0) * patrol_height * 0.5
	)
	_thrust_toward(target, delta, 0.6)
	# Face the direction we're moving so animations read.
	if absf(velocity.x) > 8.0:
		direction = int(sign(velocity.x))

func _chase(delta: float) -> void:
	if player == null: return
	var target: Vector2 = player.global_position + Vector2(0, preferred_altitude)
	_thrust_toward(target, delta)
	direction = int(sign(player.global_position.x - global_position.x))
	if direction == 0: direction = 1

func _attack(delta: float) -> void:
	if player == null: return
	# Hold preferred distance off the player's flank at altitude.
	var side: int = -1 if global_position.x < player.global_position.x else 1
	# If we are very close, side flips to push us back out; if far, stay close.
	var target: Vector2 = player.global_position + Vector2(side * preferred_distance, preferred_altitude)
	# Add a bob so we don't sit perfectly still and become trivial.
	target.y += sin(bob_phase) * hover_bob_amp
	_thrust_toward(target, delta, 0.85)
	direction = int(sign(player.global_position.x - global_position.x))
	if direction == 0: direction = 1
	_try_fire()

func _hover_to(target: Vector2, delta: float, strength: float = 0.6) -> void:
	_thrust_toward(target + Vector2(0, sin(bob_phase) * hover_bob_amp), delta, strength)

func _thrust_toward(target: Vector2, delta: float, strength: float = 1.0) -> void:
	var to_target: Vector2 = target - global_position
	var desired: Vector2 = to_target.limit_length(max_speed)
	# Steer current velocity toward desired (seek behavior with damping).
	var steer: Vector2 = (desired - velocity) * strength
	velocity += steer.limit_length(thrust_force * delta)
	# Damping so we settle instead of overshooting forever.
	velocity = velocity.move_toward(Vector2.ZERO, damping * delta)
	# Always counter gravity since we're a jetpack unit.
	# (No additional gravity applied — we ignore it while alive.)

func _try_fire() -> void:
	# Prefer a missile when ready — it's the showy attack.
	if missile_timer <= 0 and burst_left == 0 and fire_timer <= 0 and bursts_fired > 0 and bursts_fired % missile_every == 0:
		_fire_missile()
		missile_timer = missile_cooldown
		fire_timer = burst_cooldown * 0.6
		return
	if burst_left > 0 and burst_timer <= 0:
		_shoot()
		burst_left -= 1
		burst_timer = burst_interval
		if burst_left == 0:
			fire_timer = burst_cooldown
			bursts_fired += 1
	elif burst_left == 0 and fire_timer <= 0:
		burst_left = burst_count
		burst_timer = 0.0

func _fire_missile() -> void:
	if player == null: return
	var muzzle: Vector2 = gun_muzzle.global_position
	var to_p: Vector2 = (player.global_position - muzzle).normalized()
	var launch: Vector2 = (to_p + Vector2(0.0, -0.6)).normalized() * 140.0
	var main := get_tree().current_scene
	if main != null and main.has_method("spawn_projectile"):
		main.spawn_projectile({
			"kind": "missile",
			"x": muzzle.x, "y": muzzle.y,
			"vx": launch.x, "vy": launch.y,
			"target_peer": player.get_multiplayer_authority(),
			"damage": bullet_damage,
		})
	# Slight recoil + visor flash for "telegraph"
	velocity += -to_p * 60.0
	visor.color = Color(1.0, 0.9, 0.4)

func _shoot() -> void:
	if player == null: return
	var muzzle: Vector2 = gun_muzzle.global_position
	# Lead the target.
	var to_p: Vector2 = player.global_position - muzzle
	var t: float = clampf(to_p.length() / bullet_speed, 0.0, 0.7)
	var predicted: Vector2 = player.global_position + player.velocity * t
	var aim: Vector2 = (predicted - muzzle).normalized()
	if spread > 0.0:
		var ang: float = aim.angle() + randf_range(-spread, spread)
		aim = Vector2(cos(ang), sin(ang))
	var vel: Vector2 = aim * bullet_speed
	var main := get_tree().current_scene
	if main != null and main.has_method("spawn_projectile"):
		main.spawn_projectile({
			"kind": "bullet",
			"x": muzzle.x, "y": muzzle.y,
			"vx": vel.x, "vy": vel.y,
			"damage": bullet_damage,
		})

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

	var knockback: Vector2 = (global_position - source_pos).normalized() * 180.0
	velocity = velocity * 0.4 + knockback
	if multiplayer.has_multiplayer_peer():
		net_flash.rpc()
	else:
		net_flash()
	if current_health <= 0:
		if multiplayer.has_multiplayer_peer():
			_net_kill.rpc()
		else:
			_die()

@rpc("any_peer", "call_local", "reliable")
func request_damage(amount: int, source_pos: Vector2) -> void:
	if Net.is_solo() or is_multiplayer_authority():
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
	thrust_flame.visible = false
	alert_indicator.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 1
	# Spectacular finish — explosive effect on death.
	var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	# Deferred — _die() may be triggered mid physics-shape query and
	# ExplosiveEffect._ready toggles monitoring, which is forbidden then.
	fx.position = global_position
	get_parent().call_deferred("add_child", fx)
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(self): queue_free()
	)

func _update_visuals(delta: float) -> void:
	# Smoothly flip facing instead of snapping.
	var target_facing := float(direction)
	body_visual.scale.x = lerpf(body_visual.scale.x, target_facing, minf(delta * 12.0, 1.0))

	if is_dead:
		return

	# Banking: tilt body toward the direction of motion (Metroid-style).
	# When facing right, positive vx → nose forward (tilt slightly down). When
	# facing left, sign flips with body_visual.scale.x so the rotation reads.
	var bank: float = clampf(velocity.x * 0.0009, -0.28, 0.28)
	if direction < 0:
		bank = -bank
	# Add a touch of pitch from vertical velocity (climbing → nose up).
	var pitch: float = clampf(-velocity.y * 0.0006, -0.18, 0.18)
	body_visual.rotation = lerpf(body_visual.rotation, bank + pitch, minf(delta * 10.0, 1.0))

	# Thrust flame: longer when climbing hard, flickers when level/falling.
	var thrust_intensity: float = 0.7 + clampf(-velocity.y / 200.0, 0.0, 1.0) * 0.9
	var flicker: float = 0.85 + 0.35 * sin(Time.get_ticks_msec() * 0.045)
	thrust_flame.scale = Vector2(1.0, thrust_intensity * flicker)
	thrust_flame.visible = state != State.STAGGER

	match state:
		State.IDLE:
			visor.color = Color(0.10, 0.35, 0.55)
		State.ALERT:
			# Cyan blink
			var c: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.025)
			visor.color = Color(0.2, 0.6 + c * 0.4, 1.0)
		State.CHASE:
			visor.color = Color(1.0, 0.55, 0.15)
		State.ATTACK:
			visor.color = Color(1.0, 0.18, 0.12)
		State.STAGGER:
			visor.color = Color(0.4, 0.4, 0.4)
		_:
			pass
