extends CharacterBody2D
class_name RangeSoldier

enum State { PATROL, ALERT, COMBAT, SUPPRESSED }

@export var patrol_distance: float = 120.0
@export var patrol_speed: float = 50.0
@export var sight_range: float = 220.0
@export var close_range: float = 52.0
@export var max_health: int = 3
@export var contact_damage: int = 1
@export var bullet_damage: int = 1
@export var bullet_speed: float = 300.0
@export var fire_rate: float = 1.0
@export var alert_time: float = 0.55

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
var visor_flash_timer: float = 0.0

@onready var body_visual: Node2D = $Body
@onready var visor: ColorRect = $Body/Visor
@onready var gun_muzzle: Marker2D = $Body/GunMuzzle
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	add_to_group("enemy")
	_find_player()

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
	if visor_flash_timer > 0:
		visor_flash_timer -= delta

func _update_state() -> void:
	if player == null or player.is_dead:
		_set_state(State.PATROL)
		return

	var dist := global_position.distance_to(player.global_position)
	var can_see := _has_line_of_sight(dist)

	match state:
		State.PATROL:
			if can_see:
				_set_state(State.ALERT)
		State.ALERT:
			if not can_see:
				_set_state(State.PATROL)
			elif alert_timer <= 0:
				_set_state(State.COMBAT)
		State.COMBAT:
			if not can_see:
				_set_state(State.PATROL)
			elif dist <= close_range:
				_set_state(State.SUPPRESSED)
		State.SUPPRESSED:
			if not can_see:
				_set_state(State.PATROL)
			elif dist > close_range * 1.5:
				_set_state(State.COMBAT)

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		State.PATROL:
			alert_indicator.visible = false
		State.ALERT:
			alert_timer = alert_time
			alert_indicator.visible = true
			fire_timer = alert_time + 0.1
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
			_combat()
		State.SUPPRESSED:
			_suppressed(delta)

func _patrol(delta: float) -> void:
	if stunned_timer > 0:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		return

	velocity.x = direction * patrol_speed
	wall_check.target_position = Vector2(20 * direction, 0)
	floor_check.position.x = 16 * direction

	var dist_from_start := abs(global_position.x - start_position.x)
	if dist_from_start > patrol_distance or wall_check.is_colliding() \
			or (is_on_floor() and not floor_check.is_colliding()):
		direction *= -1

func _alert(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 600 * _delta)
	if player:
		direction = sign(player.global_position.x - global_position.x)

func _combat() -> void:
	velocity.x = move_toward(velocity.x, 0, 500)
	if player:
		direction = sign(player.global_position.x - global_position.x)
	if fire_timer <= 0:
		_shoot(0.0)
		fire_timer = 1.0 / fire_rate

func _suppressed(delta: float) -> void:
	if player:
		direction = -sign(player.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, direction * patrol_speed * 0.9, 700 * delta)

	# Faster, inaccurate panic fire
	if fire_timer <= 0:
		_shoot(0.35)
		fire_timer = 1.0 / (fire_rate * 2.5)

func _shoot(spread: float) -> void:
	var bullet := BULLET_SCENE.instantiate() as Area2D
	get_parent().add_child(bullet)
	bullet.global_position = gun_muzzle.global_position

	var shoot_dir := Vector2(float(direction), 0)
	if spread > 0:
		shoot_dir.y = randf_range(-spread, spread)
		shoot_dir = shoot_dir.normalized()

	bullet.setup(shoot_dir, bullet_speed, bullet_damage)

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

func stun(duration: float) -> void:
	if is_dead:
		return
	stunned_timer = maxf(stunned_timer, duration)
	body_visual.modulate = Color(0.45, 0.85, 2.0)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			body_visual.modulate = Color.WHITE
	)

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
	body_visual.modulate = Color(2.5, 2.5, 2.5)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			body_visual.modulate = Color.WHITE
	)

func _die() -> void:
	is_dead = true
	body_visual.modulate = Color(0.35, 0.35, 0.35)
	alert_indicator.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 1
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	)

func _update_visuals(delta: float) -> void:
	body_visual.scale.x = float(direction)

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
