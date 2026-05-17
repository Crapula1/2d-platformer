extends CharacterBody2D
class_name RangeSoldier

enum State { PATROL, ALERT, COMBAT, SUPPRESSED }

@export var patrol_distance: float = 320.0
@export var patrol_speed: float = 60.0
@export var advance_speed: float = 110.0
@export var charge_speed: float = 170.0
@export var sight_range: float = 320.0
@export var close_range: float = 56.0
@export var ideal_range: float = 140.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var charge_damage: int = 2
@export var bullet_damage: int = 1
@export var bullet_speed: float = 380.0
@export var fire_rate: float = 2.2
@export var burst_count: int = 3
@export var burst_interval: float = 0.08
@export var alert_time: float = 0.2
@export var memory_time: float = 1.5

const BULLET_SCENE = preload("res://scenes/Bullet.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var state: State = State.PATROL
var current_health: int
var is_dead: bool = false
var direction: int = 1
var start_position: Vector2
var player: Player = null
var fire_timer: float = 0.0
var alert_timer: float = 0.0
var stunned_timer: float = 0.0
var burst_remaining: int = 0
var burst_gap_timer: float = 0.0
var memory_timer: float = 0.0
var last_seen_pos: Vector2 = Vector2.ZERO
var visor_flash_timer: float = 0.0
var walk_phase: float = 0.0
var recoil: float = 0.0
var flash_timer: float = 0.0
var _gun_base_left: float = 0.0
var _gun_base_right: float = 0.0
var _muzzle_base_x: float = 0.0
var _legl_base_y: float = 0.0
var _legr_base_y: float = 0.0
var _body_base_y: float = 0.0

@onready var body_visual: Node2D = $Body
@onready var visor: ColorRect = $Body/Visor
@onready var gun_muzzle: Marker2D = $Body/GunMuzzle
@onready var gun_visual: ColorRect = $Body/Gun
@onready var muzzle_flash: Polygon2D = $Body/MuzzleFlash
@onready var leg_l: ColorRect = $Body/LegL
@onready var leg_r: ColorRect = $Body/LegR
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	add_to_group("enemy")
	_find_player()
	_gun_base_left = gun_visual.offset_left
	_gun_base_right = gun_visual.offset_right
	_muzzle_base_x = muzzle_flash.position.x
	_legl_base_y = leg_l.offset_top
	_legr_base_y = leg_r.offset_top
	_body_base_y = body_visual.position.y

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, 300 * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	if player == null:
		_find_player()

	_apply_gravity(delta)
	_update_timers(delta)
	_update_state()
	_run_state(delta)
	move_and_slide()
	_update_visuals(delta)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, 600)

func _update_timers(delta: float) -> void:
	if stunned_timer > 0:
		stunned_timer -= delta
	if fire_timer > 0:
		fire_timer -= delta
	if burst_gap_timer > 0:
		burst_gap_timer -= delta
	if memory_timer > 0:
		memory_timer -= delta
	if visor_flash_timer > 0:
		visor_flash_timer -= delta
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			muzzle_flash.visible = false
	# Recoil decays smoothly
	recoil = move_toward(recoil, 0.0, 30.0 * delta)
	# Walk cycle phase advances with horizontal speed
	walk_phase += delta * (absf(velocity.x) / 8.0 + 1.0)

func _update_state() -> void:
	if player == null or player.is_dead:
		_set_state(State.PATROL)
		return

	var dist := global_position.distance_to(player.global_position)
	var can_see := _has_line_of_sight(dist)
	if can_see:
		last_seen_pos = player.global_position
		memory_timer = memory_time

	var aware := can_see or memory_timer > 0

	match state:
		State.PATROL:
			if can_see:
				_set_state(State.ALERT)
		State.ALERT:
			if not aware:
				_set_state(State.PATROL)
			elif alert_timer <= 0:
				_set_state(State.COMBAT)
		State.COMBAT:
			if not aware:
				_set_state(State.PATROL)
			elif can_see and dist <= close_range:
				_set_state(State.SUPPRESSED)
		State.SUPPRESSED:
			if not aware:
				_set_state(State.PATROL)
			elif dist > close_range * 2.0:
				_set_state(State.COMBAT)

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	burst_remaining = 0
	burst_gap_timer = 0.0
	match state:
		State.PATROL:
			alert_indicator.visible = false
		State.ALERT:
			alert_timer = alert_time
			alert_indicator.visible = true
			fire_timer = alert_time + 0.05
		State.COMBAT:
			alert_indicator.visible = false
		State.SUPPRESSED:
			alert_indicator.visible = false

func _run_state(delta: float) -> void:
	if stunned_timer > 0:
		velocity.x = move_toward(velocity.x, 0, 700 * delta)
		return
	match state:
		State.PATROL:
			_patrol(delta)
		State.ALERT:
			_alert(delta)
			alert_timer -= delta
		State.COMBAT:
			_combat(delta)
		State.SUPPRESSED:
			_suppressed(delta)

func _patrol(delta: float) -> void:
	if stunned_timer > 0:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		return

	velocity.x = direction * patrol_speed
	wall_check.target_position = Vector2(20 * direction, 0)
	floor_check.position.x = 16 * direction

	var dist_from_start: float = absf(global_position.x - start_position.x)
	if dist_from_start > patrol_distance or wall_check.is_colliding() \
			or (is_on_floor() and not floor_check.is_colliding()):
		direction *= -1

func _alert(_delta: float) -> void:
	# Lean in immediately — soldiers commit fast.
	var target_pos: Vector2 = last_seen_pos
	if player and memory_timer > 0:
		target_pos = last_seen_pos
	direction = int(sign(target_pos.x - global_position.x))
	if direction == 0:
		direction = 1
	velocity.x = move_toward(velocity.x, direction * advance_speed * 0.5, 800 * _delta)

func _combat(delta: float) -> void:
	var target_pos: Vector2 = last_seen_pos
	if player and memory_timer > 0:
		target_pos = last_seen_pos
	var dx: float = target_pos.x - global_position.x
	direction = int(sign(dx)) if absf(dx) > 1.0 else direction
	var dist_x: float = absf(dx)

	# Advance toward ideal_range, then strafe in place to keep pressure on.
	var desired: float = 0.0
	if dist_x > ideal_range + 12.0:
		desired = float(direction) * advance_speed
	elif dist_x < ideal_range - 24.0:
		desired = -float(direction) * advance_speed * 0.6
	else:
		desired = sin(Time.get_ticks_msec() * 0.006) * advance_speed * 0.7
	velocity.x = move_toward(velocity.x, desired, 600 * delta)

	# Only fire if we actually have eyes on the player.
	if player and _has_line_of_sight(global_position.distance_to(player.global_position)):
		_try_burst()

func _suppressed(delta: float) -> void:
	# Charge — close the distance and trample.
	if player:
		direction = int(sign(player.global_position.x - global_position.x))
		if direction == 0:
			direction = 1
	velocity.x = move_toward(velocity.x, direction * charge_speed, 900 * delta)

	# Wild close-range fire while charging.
	if fire_timer <= 0:
		_shoot(0.25)
		fire_timer = 1.0 / (fire_rate * 1.4)

func _try_burst() -> void:
	if burst_remaining > 0:
		if burst_gap_timer <= 0:
			_shoot(0.04)
			burst_remaining -= 1
			burst_gap_timer = burst_interval
			if burst_remaining == 0:
				fire_timer = 1.0 / fire_rate
	elif fire_timer <= 0:
		burst_remaining = burst_count
		burst_gap_timer = 0.0

func _shoot(spread: float) -> void:
	var bullet := BULLET_SCENE.instantiate() as Area2D
	get_parent().add_child(bullet)
	bullet.global_position = gun_muzzle.global_position

	# Lead the target: aim at where the player will be in the bullet's flight time.
	var shoot_dir := Vector2(float(direction), 0)
	if player != null:
		var to_p: Vector2 = player.global_position - gun_muzzle.global_position
		var t: float = clampf(to_p.length() / bullet_speed, 0.0, 0.6)
		var predicted: Vector2 = player.global_position + player.velocity * t
		var aim: Vector2 = (predicted - gun_muzzle.global_position)
		if aim.length() > 1.0:
			shoot_dir = aim.normalized()
			# Don't fire backward — clamp to facing hemisphere.
			if sign(shoot_dir.x) != direction and direction != 0:
				shoot_dir.x = float(direction) * 0.35
				shoot_dir = shoot_dir.normalized()
	if spread > 0:
		var ang: float = shoot_dir.angle() + randf_range(-spread, spread)
		shoot_dir = Vector2(cos(ang), sin(ang))

	bullet.setup(shoot_dir, bullet_speed, bullet_damage)

	# Shooting animation: kick the gun back, flash the muzzle, jolt the body.
	recoil = 4.0
	muzzle_flash.visible = true
	muzzle_flash.scale = Vector2(1.0, randf_range(0.7, 1.3))
	flash_timer = 0.06
	velocity.x -= float(direction) * 30.0

func _has_line_of_sight(dist: float) -> bool:
	if player == null or dist > sight_range:
		return false
	sight_ray.target_position = to_local(player.global_position)
	sight_ray.force_raycast_update()
	if not sight_ray.is_colliding():
		return true
	return sight_ray.get_collider() == player

func get_damage() -> int:
	return charge_damage if state == State.SUPPRESSED else contact_damage

func stun(duration: float) -> void:
	if is_dead:
		return
	stunned_timer = maxf(stunned_timer, duration)
	EnemyFx.flash(body_visual, 0.12, Color(0.45, 0.85, 2.0))

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_dead:
		return
	current_health -= amount
	stunned_timer = 0.25

	var knockback_dir: float = sign(global_position.x - source_pos.x)
	velocity.x = knockback_dir * 160
	velocity.y = -100

	_flash_hit()

	if current_health <= 0:
		_die()

func _flash_hit() -> void:
	EnemyFx.flash(body_visual, 0.08, Color(2.5, 2.5, 2.5))

func _die() -> void:
	is_dead = true
	body_visual.modulate = Color(0.35, 0.35, 0.35)
	alert_indicator.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 1
	EnemyFx.free_after(self, 2.0)

func _update_visuals(delta: float) -> void:
	body_visual.scale.x = float(direction)

	# Walk cycle — alternate legs + slight body bob when moving on the ground.
	var moving := absf(velocity.x) > 6.0 and is_on_floor()
	if moving:
		var s := sin(walk_phase * 6.0)
		leg_l.offset_top = _legl_base_y - max(s, 0.0) * 3.0
		leg_r.offset_top = _legr_base_y - max(-s, 0.0) * 3.0
		body_visual.position.y = _body_base_y - absf(s) * 0.8
	else:
		leg_l.offset_top = lerpf(leg_l.offset_top, _legl_base_y, minf(delta * 15.0, 1.0))
		leg_r.offset_top = lerpf(leg_r.offset_top, _legr_base_y, minf(delta * 15.0, 1.0))
		body_visual.position.y = lerpf(body_visual.position.y, _body_base_y, minf(delta * 15.0, 1.0))

	# Gun recoil — slides back along the barrel axis (local +x of body).
	gun_visual.offset_left = _gun_base_left - recoil
	gun_visual.offset_right = _gun_base_right - recoil
	muzzle_flash.position.x = _muzzle_base_x - recoil

	match state:
		State.PATROL:
			visor.color = Color(0.35, 0.08, 0.05)
		State.ALERT:
			# Blink orange while alerting
			visor_flash_timer -= delta
			if visor_flash_timer <= 0:
				visor_flash_timer = 0.18
				visor.color = Color(1.0, 0.55, 0.0) if visor.color.r < 0.5 else Color(0.5, 0.25, 0.0)
		State.COMBAT:
			visor.color = Color(0.9, 0.1, 0.05)
		State.SUPPRESSED:
			# Rapid flash red when panicked
			visor_flash_timer -= delta
			if visor_flash_timer <= 0:
				visor_flash_timer = 0.08
				visor.color = Color(1.0, 0.1, 0.05) if visor.color.r < 0.5 else Color(0.2, 0.0, 0.0)
