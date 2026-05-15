extends CharacterBody2D
class_name Player

# Movement
@export var speed: float = 180.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0
@export var air_friction: float = 200.0

# Jumping
@export var jump_velocity: float = -380.0
@export var double_jump_velocity: float = -340.0
@export var max_jumps: int = 2
@export var jump_cut_multiplier: float = 0.4
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.15

# Combat
@export var max_health: int = 5
@export var attack_damage: int = 1
@export var attack_duration: float = 0.25
@export var invincibility_time: float = 1.0
@export var knockback_force: float = 250.0

const BASE_SCALE := Vector2(0.33, 0.33)

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

signal health_changed(new_health: int, max: int)
signal died()
signal score_changed(new_score: int)

var score: int = 0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	current_health = max_health
	jumps_remaining = max_jumps
	attack_shape.disabled = true
	add_to_group("player")
	attack_area.body_entered.connect(_on_attack_hit)
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	emit_signal("health_changed", current_health, max_health)
	emit_signal("score_changed", score)

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
	_handle_horizontal_movement(delta)
	_handle_attack_input()
	_handle_jump_logic()

	move_and_slide()

	if is_on_floor():
		jumps_remaining = max_jumps
		coyote_timer = coyote_time

	_update_animation()
	_update_sprite()

func _update_timers(delta: float) -> void:
	if not is_on_floor():
		coyote_timer -= delta
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
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

func _handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, 600)

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func _handle_jump_logic() -> void:
	if jump_buffer_timer > 0:
		if is_on_floor() or coyote_timer > 0:
			velocity.y = jump_velocity
			jumps_remaining = max_jumps - 1
			jump_buffer_timer = 0
			coyote_timer = 0
		elif jumps_remaining > 0:
			velocity.y = double_jump_velocity
			jumps_remaining -= 1
			jump_buffer_timer = 0
			_spawn_double_jump_effect()

func _handle_horizontal_movement(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		facing_right = direction > 0
	else:
		var f = friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0, f * delta)

func _handle_attack_input() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		_start_attack()

func _start_attack() -> void:
	is_attacking = true
	attack_timer = attack_duration
	attack_shape.disabled = false
	attack_area.position.x = 18 if facing_right else -18
	sprite.modulate = Color(1.0, 0.9, 0.4, sprite.modulate.a)

func _end_attack() -> void:
	is_attacking = false
	attack_shape.disabled = true
	sprite.modulate = Color(1, 1, 1, sprite.modulate.a)

func _on_attack_hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage, global_position)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("hazard"):
		var dmg := area.get_damage() if area.has_method("get_damage") else 1
		take_damage(dmg, area.global_position)
	elif area.is_in_group("collectible"):
		_collect(area)

func _on_hurtbox_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") and body.has_method("get_damage"):
		take_damage(body.get_damage(), body.global_position)

func _collect(item: Area2D) -> void:
	if item.has_method("collect"):
		var value = item.collect()
		score += value
		emit_signal("score_changed", score)

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_invincible or is_dead:
		return
	current_health -= amount
	is_invincible = true
	invincibility_timer = invincibility_time
	emit_signal("health_changed", current_health, max_health)

	var knockback_dir = (global_position - source_pos).normalized()
	velocity.x = knockback_dir.x * knockback_force
	velocity.y = -200

	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	sprite.modulate = Color(0.5, 0.5, 0.5)
	emit_signal("died")

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)

func _update_animation() -> void:
	sprite.flip_h = not facing_right
	if is_on_floor() and abs(velocity.x) > 10.0:
		if sprite.animation != &"walk":
			sprite.play(&"walk")
	else:
		if sprite.animation != &"idle":
			sprite.play(&"idle")

func _update_sprite() -> void:
	if not is_on_floor():
		if velocity.y < 0:
			sprite.scale = BASE_SCALE * Vector2(0.9, 1.15)
		else:
			sprite.scale = BASE_SCALE * Vector2(1.1, 0.9)
	else:
		sprite.scale = sprite.scale.lerp(BASE_SCALE, 0.2)

func _spawn_double_jump_effect() -> void:
	sprite.scale = BASE_SCALE * Vector2(1.3, 0.7)
