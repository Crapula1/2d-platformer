extends CharacterBody2D
class_name Player

# Movement
@export var speed: float = 180.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var air_friction: float = 200.0
@export var crouch_speed_mult: float = 0.45

# Jumping
@export var jump_velocity: float = -380.0
@export var double_jump_velocity: float = -340.0
@export var max_jumps: int = 2
@export var jump_cut_multiplier: float = 0.4
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# Combat
@export var max_health: int = 5
@export var attack_damage: int = 2
@export var attack_duration: float = 0.22
@export var invincibility_time: float = 1.0
@export var knockback_force: float = 300.0

# Slide
@export var slide_speed: float = 270.0
@export var slide_duration: float = 0.38
@export var slide_cooldown: float = 0.65
@export var slide_threshold: float = 85.0

# Sprint
@export var sprint_multiplier: float = 1.65

# Shooting
@export var bullet_speed: float = 500.0
@export var shoot_cooldown: float = 0.18
@export var bullet_damage: int = 1

# Wall run
@export var wall_slide_gravity_scale: float = 0.08
@export var wall_slide_max_fall: float = 55.0
@export var wall_jump_vel_x: float = 220.0
@export var wall_jump_vel_y: float = -350.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var jumps_remaining: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var is_attacking: bool = false
var attack_timer: float = 0.0
var current_health: int
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var facing_right: bool = true
var is_dead: bool = false
var is_crouching: bool = false
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_dir: float = 1.0
var _slide_bash: bool = false
var active_buffs: Dictionary = {}
var is_wall_sliding: bool = false

signal health_changed(new_health: int, max: int)
signal died()
signal score_changed(new_score: int)
signal grenade_changed(type_name: String)

var score: int = 0

const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/PlayerBullet.tscn")
const GRENADE_NAMES := ["Explosive", "Incendiary", "Electric"]
@export var throw_force: float = 310.0

var grenade_type: int = 0
var grenade_cooldown_base: float = 0.85
var _grenade_cooldown: float = 0.0
var _shoot_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var stand_shape: CollisionShape2D = $CollisionShape2D
@onready var crouch_shape: CollisionShape2D = $CrouchShape
@onready var ceiling_ray: RayCast2D = $CeilingRay
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	current_health = max_health
	jumps_remaining = max_jumps
	attack_shape.disabled = true
	crouch_shape.disabled = true
	add_to_group("player")
	attack_area.body_entered.connect(_on_attack_hit)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	emit_signal("health_changed", current_health, max_health)
	emit_signal("score_changed", score)
	emit_signal("grenade_changed", GRENADE_NAMES[grenade_type])

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	_update_timers(delta)
	_handle_gravity(delta)
	_handle_jump_input()
	_handle_crouch_input()
	_handle_horizontal_movement(delta)
	_handle_attack_input()
	_handle_grenade_input()
	_handle_shoot_input()
	_handle_jump_logic()

	move_and_slide()
	_update_wall_slide()

	if is_on_floor():
		jumps_remaining = max_jumps
		coyote_timer = coyote_time
		is_wall_sliding = false

	_update_sprite(delta)

func _update_timers(delta: float) -> void:
	if not is_on_floor():
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if slide_cooldown_timer > 0:
		slide_cooldown_timer -= delta
	if _grenade_cooldown > 0:
		_grenade_cooldown -= delta
	if _shoot_timer > 0:
		_shoot_timer -= delta
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			_end_slide()
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			sprite.modulate.a = 1.0
		else:
			sprite.modulate.a = 0.3 if int(invincibility_timer * 20) % 2 == 0 else 1.0
	_update_buffs(delta)

func _update_buffs(delta: float) -> void:
	var expired: Array[String] = []
	for key in active_buffs:
		active_buffs[key].timer -= delta
		if active_buffs[key].timer <= 0:
			expired.append(key)
	for key in expired:
		active_buffs.erase(key)

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y = minf(velocity.y + gravity * wall_slide_gravity_scale * delta, wall_slide_max_fall)
		else:
			velocity.y += gravity * delta
			velocity.y = min(velocity.y, 600)

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func _handle_crouch_input() -> void:
	if is_sliding:
		return

	if Input.is_action_just_pressed("crouch") and is_on_floor():
		if abs(velocity.x) >= slide_threshold and slide_cooldown_timer <= 0:
			_start_slide()
			return

	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	if wants_crouch and not is_crouching:
		_set_crouching(true)
	elif not wants_crouch and is_crouching and _can_stand():
		_set_crouching(false)

func _start_slide() -> void:
	is_sliding = true
	slide_timer = slide_duration
	slide_dir = sign(velocity.x) if abs(velocity.x) > 1.0 else (1.0 if facing_right else -1.0)
	velocity.x = slide_dir * slide_speed
	_set_crouching(true)
	if not is_invincible:
		is_invincible = true
		invincibility_timer = 0.22

func _end_slide() -> void:
	is_sliding = false
	slide_cooldown_timer = slide_cooldown
	if not Input.is_action_pressed("crouch") and _can_stand():
		_set_crouching(false)

func _set_crouching(value: bool) -> void:
	is_crouching = value
	stand_shape.set_deferred("disabled", value)
	crouch_shape.set_deferred("disabled", not value)

func _can_stand() -> bool:
	return not ceiling_ray.is_colliding()

func _handle_horizontal_movement(delta: float) -> void:
	if is_sliding:
		# Decelerate smoothly through the slide
		velocity.x = move_toward(velocity.x, slide_dir * (slide_speed * 0.4), 110.0 * delta)
		return

	var direction: float = Input.get_axis("move_left", "move_right")
	var eff_speed: float = speed * (active_buffs["speed"].magnitude if "speed" in active_buffs else 1.0)
	if Input.is_action_pressed("sprint") and not is_crouching and not is_sliding:
		eff_speed *= sprint_multiplier
	if is_crouching:
		eff_speed *= crouch_speed_mult

	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * eff_speed, acceleration * delta)
		facing_right = direction > 0
	else:
		var f := friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0, f * delta)

func _update_wall_slide() -> void:
	if is_on_floor() or is_crouching or is_sliding:
		is_wall_sliding = false
		return
	if not is_on_wall() or velocity.y <= 0:
		is_wall_sliding = false
		return
	var wn := get_wall_normal()
	var dir := Input.get_axis("move_left", "move_right")
	var pushing_into_wall := (wn.x < 0.0 and dir > 0.0) or (wn.x > 0.0 and dir < 0.0)
	is_wall_sliding = pushing_into_wall
	if is_wall_sliding:
		facing_right = wn.x < 0.0

func _handle_jump_logic() -> void:
	if jump_buffer_timer > 0:
		if is_wall_sliding:
			var wn := get_wall_normal()
			velocity.x = wn.x * wall_jump_vel_x
			velocity.y = wall_jump_vel_y
			jumps_remaining = max_jumps - 1
			is_wall_sliding = false
			jump_buffer_timer = 0
		elif is_on_floor() or coyote_timer > 0:
			if is_sliding:
				_end_slide()
			velocity.y = jump_velocity
			jumps_remaining = max_jumps - 1
			jump_buffer_timer = 0
			coyote_timer = 0
		elif jumps_remaining > 0:
			velocity.y = double_jump_velocity
			jumps_remaining -= 1
			jump_buffer_timer = 0
			_spawn_double_jump_effect()

func _handle_grenade_input() -> void:
	if Input.is_action_just_pressed("cycle_grenade"):
		grenade_type = (grenade_type + 1) % 3
		emit_signal("grenade_changed", GRENADE_NAMES[grenade_type])
	if Input.is_action_just_pressed("throw_grenade") and _grenade_cooldown <= 0 and not is_dead:
		_throw_grenade()
		_grenade_cooldown = grenade_cooldown_base

func _throw_grenade() -> void:
	var g := GRENADE_SCENE.instantiate() as Grenade
	get_parent().add_child(g)
	g.global_position = global_position + Vector2(0, -10)
	var dir: float = 1.0 if facing_right else -1.0
	g.setup(Grenade.Type.values()[grenade_type], Vector2(dir * throw_force, -throw_force * 0.65))

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

func _start_attack() -> void:
	_slide_bash = is_sliding
	if is_sliding:
		_end_slide()
	is_attacking = true
	attack_timer = attack_duration
	attack_shape.disabled = false
	attack_area.position.x = 20 if facing_right else -20
	var tint := Color(1.0, 0.38, 0.08) if _slide_bash else Color(1.0, 0.85, 0.2)
	tint.a = sprite.modulate.a
	sprite.modulate = tint

func _end_attack() -> void:
	is_attacking = false
	_slide_bash = false
	attack_shape.disabled = true
	sprite.modulate = _get_base_modulate()

func _on_attack_hit(body: Node) -> void:
	if body.has_method("take_damage"):
		var dmg: int = int(attack_damage * (active_buffs["damage"].magnitude if "damage" in active_buffs else 1.0))
		if _slide_bash:
			dmg = int(dmg * 1.6)
		body.take_damage(dmg, global_position)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hazard"):
		var dmg: int = area.get_damage() if area.has_method("get_damage") else 1
		take_damage(dmg, area.global_position)
	elif area.is_in_group("collectible"):
		_collect(area)

func _on_hurtbox_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("get_damage"):
		take_damage(body.get_damage(), body.global_position)

func _collect(item: Area2D) -> void:
	if item.has_method("apply_effect"):
		item.apply_effect(self)
	elif item.has_method("collect"):
		var value = item.collect()
		score += value
		emit_signal("score_changed", score)

func apply_powerup(type: String, duration: float, magnitude: float = 1.0) -> void:
	active_buffs[type] = {"timer": duration, "magnitude": magnitude}
	if type == "shield":
		is_invincible = true
		invincibility_timer = duration
	sprite.modulate = _get_base_modulate()

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_invincible or is_dead:
		return
	current_health -= amount
	is_invincible = true
	invincibility_timer = invincibility_time
	if is_sliding:
		_end_slide()
	emit_signal("health_changed", current_health, max_health)
	var knockback_dir := (global_position - source_pos).normalized()
	velocity.x = knockback_dir.x * knockback_force
	velocity.y = -200
	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	sprite.stop()
	sprite.modulate = Color(0.5, 0.5, 0.5)
	emit_signal("died")

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

func _get_base_modulate() -> Color:
	if "damage" in active_buffs: return Color(1.0, 0.55, 0.1)
	if "speed"  in active_buffs: return Color(0.3, 0.6, 1.0)
	if "shield" in active_buffs: return Color(0.65, 0.3, 1.0)
	return Color.WHITE

func _update_sprite(delta: float) -> void:
	if not is_attacking:
		var base := _get_base_modulate()
		base.a = sprite.modulate.a
		sprite.modulate = base

	sprite.flip_h = not facing_right

	var anim := &"walk" if is_on_floor() and absf(velocity.x) > 10.0 else &"idle"
	if sprite.animation != anim:
		sprite.play(anim)

	var target_scale: Vector2
	var target_y: float

	if is_sliding:
		target_scale = Vector2(0.405, 0.12)
		target_y = 8.4
	elif is_crouching:
		target_scale = Vector2(0.336, 0.156)
		target_y = 6.7
	elif is_attacking:
		target_scale = Vector2(0.384, 0.3)
		target_y = 0.0
	elif is_wall_sliding:
		target_scale = Vector2(0.345, 0.27)
		target_y = 0.0
	elif not is_on_floor():
		target_scale = Vector2(0.264, 0.345) if velocity.y < 0 else Vector2(0.336, 0.264)
		target_y = 0.0
	else:
		target_scale = Vector2(0.3, 0.3)
		target_y = 0.0

	var t := minf(delta * 22.0, 1.0)
	sprite.scale = sprite.scale.lerp(target_scale, t)
	sprite.position.y = lerpf(sprite.position.y, target_y, t)

func _handle_shoot_input() -> void:
	if is_dead or _shoot_timer > 0:
		return
	if Input.is_action_pressed("shoot"):
		_shoot()
		_shoot_timer = shoot_cooldown

func _shoot() -> void:
	var mouse_pos := get_global_mouse_position()
	var muzzle := global_position + Vector2(18.0 if facing_right else -18.0, -8.0)
	var dir := (mouse_pos - muzzle).normalized()
	facing_right = dir.x >= 0.0

	var bullet := PLAYER_BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = muzzle
	bullet.setup(dir, bullet_speed, bullet_damage)
	sprite.scale = Vector2(0.26, 0.34)

func _spawn_double_jump_effect() -> void:
	sprite.scale = Vector2(0.39, 0.21)
