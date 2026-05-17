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
# Apex hang time + fast fall (Celeste / Hollow Knight feel)
@export var apex_threshold: float = 80.0
@export var apex_gravity_scale: float = 0.55
@export var fall_gravity_scale: float = 1.25
@export var max_fall_speed: float = 600.0

# Jetpack (hold jump after the double-jump to thrust upward for a few seconds)
@export var jetpack_duration: float = 3.0
@export var jetpack_thrust: float = -260.0   # target vertical velocity while thrusting
@export var jetpack_max_up: float = -340.0   # clamp so it doesn't accelerate forever

# Combat
@export var max_health: int = 10
@export var attack_damage: int = 2
@export var attack_duration: float = 0.22
@export var invincibility_time: float = 1.0
@export var knockback_force: float = 300.0

# 3-hit melee combo: Cleave → Smash → Stab. Repeated attack presses chain
# within combo_window. Each stage has its own duration, damage multiplier,
# and axe animation. The axe itself is only visible during an active swing.
@export var combo_window: float = 0.32
const ATTACK_STAGE_NAMES := ["IDLE", "CLEAVE", "SMASH", "STAB"]
var attack_stage: int = 0
var _combo_window_timer: float = 0.0
var _attack_buffered: bool = false
var _axe: Node2D
var _axe_pivot: Node2D
var _arm_front: Line2D
var _arm_back: Line2D
var _hand_front: ColorRect
var _hand_back: ColorRect
var _attack_swing_origin_rot: float = 0.0
var _attack_swing_origin_thrust: float = 0.0

# Slide
@export var slide_speed: float = 270.0
@export var slide_duration: float = 0.38
@export var slide_cooldown: float = 0.65
@export var slide_threshold: float = 85.0

# Slide dash (dedicated key — works in air & ground, full i-frames)
@export var dash_speed: float = 540.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.7

# Roll (ground dodge, i-frames, on cooldown)
@export var roll_speed: float = 340.0
@export var roll_duration: float = 0.42
@export var roll_cooldown: float = 0.95

# Sprint
@export var sprint_multiplier: float = 1.65

# Shooting — rifle
@export var bullet_speed: float = 500.0
@export var bullet_range: float = 640.0
@export var shoot_cooldown: float = 0.18
@export var bullet_damage: int = 1

# Shooting — double-barrel shotgun
# Each pull fires a 2×2 grid of rifle-style pellets traveling in parallel.
@export var shotgun_grid_lateral: float = 6.0      # perpendicular spread (px)
@export var shotgun_grid_depth: float = 7.0        # along-axis stagger (px)
@export var shotgun_pellet_speed: float = 500.0
@export var shotgun_pellet_range: float = 480.0
@export var shotgun_capacity: int = 2              # double-barrel
@export var shotgun_barrel_interval: float = 0.18  # fast follow-up between barrels
@export var shotgun_reload_time: float = 0.85      # crack-and-reload after both barrels
@export var shotgun_damage_mult: int = 2

enum Weapon { RIFLE, SHOTGUN }
const WEAPON_NAMES := ["RIFLE", "SHOTGUN"]
var weapon: int = Weapon.RIFLE
var _shotgun_shells: int = 0

signal weapon_changed(name: String)
signal shotgun_shells_changed(shells: int, max_shells: int)

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
var is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: float = 1.0
var is_rolling: bool = false
var _roll_timer: float = 0.0
var _roll_cd: float = 0.0
var _roll_dir: float = 1.0
var _jetpack_armed: bool = false
var _jetpack_fuel: float = 0.0
var _is_jetpacking: bool = false
var _jet_flame: Polygon2D
var _cam: Camera2D
var _shake_amount: float = 0.0
var _shake_decay: float = 12.0

signal health_changed(new_health: int, max: int)
signal died()
signal score_changed(new_score: int)
signal grenade_changed(type_name: String, count: int)
signal jetpack_changed(fuel: float, max: float)

var score: int = 0

const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")
const PLAYER_BULLET_SCENE := preload("res://scenes/PlayerBullet.tscn")
const GRENADE_NAMES := ["Explosive", "Incendiary", "Electric"]
const GRENADE_MAX: int = 3
@export var throw_force: float = 310.0

var grenade_type: int = 0
var grenade_count: int = 3
var grenade_cooldown_base: float = 0.85
var _grenade_cooldown: float = 0.0
var _shoot_timer: float = 0.0

# Visual: $Sprite is an AnimatedSprite2D for marine, a Node2D wrapping a
# Facing child for demon. _anim_sprite stays null for non-animated avatars,
# _facing_node is what gets flipped. base_scale scales the squash/stretch
# math from the marine baseline (0.3) to whatever the avatar wants.
@export var base_scale: Vector2 = Vector2(0.3, 0.3)
@onready var sprite: Node2D = $Sprite
var _anim_sprite: AnimatedSprite2D = null
var _facing_node: Node2D = null
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
	# Resolve visual structure (AnimatedSprite2D vs Node2D wrapper).
	if sprite is AnimatedSprite2D:
		_anim_sprite = sprite as AnimatedSprite2D
		_facing_node = sprite
	else:
		_facing_node = sprite.get_node_or_null("Facing") as Node2D
		if _facing_node == null:
			_facing_node = sprite
	# Hit-detection only fires on the local authority's player so damage
	# doesn't double-apply across peers.
	if _is_local_authority():
		attack_area.body_entered.connect(_on_attack_hit)
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	health_changed.emit(current_health, max_health)
	score_changed.emit(score)
	grenade_changed.emit(GRENADE_NAMES[grenade_type], grenade_count)
	jetpack_changed.emit(_jetpack_fuel, jetpack_duration)
	_shotgun_shells = shotgun_capacity
	weapon_changed.emit(WEAPON_NAMES[weapon])
	shotgun_shells_changed.emit(_shotgun_shells, shotgun_capacity)
	_cam = get_node_or_null("Camera2D") as Camera2D
	if _cam != null:
		if _is_local_authority():
			_cam.make_current()
		else:
			_cam.enabled = false
	_jet_flame = Polygon2D.new()
	_jet_flame.color = Color(1.0, 0.55, 0.12, 0.95)
	_jet_flame.polygon = PackedVector2Array([
		Vector2(-5.0, 8.0), Vector2(5.0, 8.0),
		Vector2(3.0, 18.0), Vector2(0.0, 26.0), Vector2(-3.0, 18.0)
	])
	_jet_flame.z_index = -1
	_jet_flame.visible = false
	add_child(_jet_flame)
	# The axe rig is sized for the marine sprite; skip it for other avatars
	# until they get their own weapon visuals.
	if _anim_sprite != null:
		_build_axe()

func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		# Non-local players: state arrives via MultiplayerSynchronizer.
		# Visuals still need to update from synced flags (animations,
		# attack pose, etc.) so the other player doesn't look frozen.
		_update_sprite(delta)
		return
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	_update_timers(delta)
	_handle_dash_input()
	_handle_roll_input()
	_handle_gravity(delta)
	_handle_jump_input()
	_handle_crouch_input()
	_handle_horizontal_movement(delta)
	_handle_attack_input()
	_handle_grenade_input()
	_handle_shoot_input()
	_handle_jump_logic()
	_handle_jetpack(delta)

	move_and_slide()
	_update_wall_slide()

	if is_on_floor():
		jumps_remaining = max_jumps
		coyote_timer = coyote_time
		is_wall_sliding = false
		_jetpack_armed = false
		if _jetpack_fuel != jetpack_duration:
			_jetpack_fuel = jetpack_duration
			jetpack_changed.emit(_jetpack_fuel, jetpack_duration)

	_update_sprite(delta)
	_update_camera_shake(delta)

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
	if _dash_cd > 0:
		_dash_cd -= delta
	if _roll_cd > 0:
		_roll_cd -= delta
	if is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0:
			_end_dash()
	if is_rolling:
		_roll_timer -= delta
		if _roll_timer <= 0:
			_end_roll()
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			_end_slide()
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			_end_attack()
	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			attack_stage = 0
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
	if is_dashing:
		velocity.y = 0.0
		return
	if is_on_floor():
		return
	if is_wall_sliding:
		velocity.y = minf(velocity.y + gravity * wall_slide_gravity_scale * delta, wall_slide_max_fall)
		return
	if _is_jetpacking:
		# Jetpack thrust manages vertical velocity itself.
		return
	var g_scale := 1.0
	if absf(velocity.y) < apex_threshold and Input.is_action_pressed("jump"):
		g_scale = apex_gravity_scale
	elif velocity.y > 0.0:
		g_scale = fall_gravity_scale
	velocity.y += gravity * g_scale * delta
	velocity.y = minf(velocity.y, max_fall_speed)

func _handle_jetpack(delta: float) -> void:
	var holding := Input.is_action_pressed("jump")
	var can_thrust := _jetpack_armed and holding and not is_on_floor() and _jetpack_fuel > 0.0 and not is_dead
	if can_thrust:
		# Smoothly drive vertical velocity toward the thrust target.
		velocity.y = move_toward(velocity.y, jetpack_thrust, 1400.0 * delta)
		velocity.y = maxf(velocity.y, jetpack_max_up)
		_jetpack_fuel = maxf(_jetpack_fuel - delta, 0.0)
		_is_jetpacking = true
		_jet_flame.visible = true
		_jet_flame.scale = Vector2(1.0, 0.85 + 0.3 * sin(Time.get_ticks_msec() * 0.04))
		jetpack_changed.emit(_jetpack_fuel, jetpack_duration)
		_apply_shake(0.6)
	else:
		if _is_jetpacking:
			jetpack_changed.emit(_jetpack_fuel, jetpack_duration)
		_is_jetpacking = false
		_jet_flame.visible = false

func _handle_jump_input() -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_multiplier

func _handle_crouch_input() -> void:
	if is_sliding or is_dashing or is_rolling:
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

func _handle_dash_input() -> void:
	if Input.is_action_just_pressed("dash") and _dash_cd <= 0 and not is_dashing and not is_rolling and not is_dead:
		_start_dash()

func _handle_roll_input() -> void:
	if Input.is_action_just_pressed("roll") and _roll_cd <= 0 and not is_rolling and not is_dashing and is_on_floor() and not is_dead:
		_start_roll()

func _start_dash() -> void:
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cd = dash_cooldown
	var input_dir: float = Input.get_axis("move_left", "move_right")
	_dash_dir = input_dir if input_dir != 0.0 else (1.0 if facing_right else -1.0)
	facing_right = _dash_dir > 0.0
	velocity.x = _dash_dir * dash_speed
	velocity.y = 0.0
	is_invincible = true
	invincibility_timer = maxf(invincibility_timer, dash_duration + 0.05)
	if is_sliding:
		_end_slide()

func _end_dash() -> void:
	is_dashing = false
	# Preserve a chunk of momentum so it feels fluid rather than a hard stop.
	velocity.x = _dash_dir * dash_speed * 0.55

func _start_roll() -> void:
	is_rolling = true
	_roll_timer = roll_duration
	_roll_cd = roll_cooldown
	var input_dir: float = Input.get_axis("move_left", "move_right")
	_roll_dir = input_dir if input_dir != 0.0 else (1.0 if facing_right else -1.0)
	facing_right = _roll_dir > 0.0
	velocity.x = _roll_dir * roll_speed
	_set_crouching(true)
	is_invincible = true
	invincibility_timer = maxf(invincibility_timer, roll_duration + 0.05)
	if is_sliding:
		_end_slide()

func _end_roll() -> void:
	is_rolling = false
	if not Input.is_action_pressed("crouch") and _can_stand():
		_set_crouching(false)

func _set_crouching(value: bool) -> void:
	is_crouching = value
	stand_shape.set_deferred("disabled", value)
	crouch_shape.set_deferred("disabled", not value)

func _can_stand() -> bool:
	return not ceiling_ray.is_colliding()

func _handle_horizontal_movement(delta: float) -> void:
	if is_dashing:
		velocity.x = _dash_dir * dash_speed
		return
	if is_rolling:
		velocity.x = _roll_dir * roll_speed
		return
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
	if is_on_floor() or is_crouching or is_sliding or is_dashing or is_rolling:
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
	if is_dashing or is_rolling:
		return
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
			_jetpack_armed = true

func _handle_grenade_input() -> void:
	if Input.is_action_just_pressed("cycle_grenade"):
		grenade_type = (grenade_type + 1) % 3
		grenade_changed.emit(GRENADE_NAMES[grenade_type], grenade_count)
	if Input.is_action_just_pressed("throw_grenade") and _grenade_cooldown <= 0 and not is_dead and grenade_count > 0:
		_throw_grenade()
		grenade_count -= 1
		_grenade_cooldown = grenade_cooldown_base
		grenade_changed.emit(GRENADE_NAMES[grenade_type], grenade_count)

func _throw_grenade() -> void:
	var g := GRENADE_SCENE.instantiate() as Grenade
	get_tree().current_scene.add_child(g)
	var spawn_pos: Vector2 = global_position + Vector2(0, -10)
	g.global_position = spawn_pos

	# Aim from the spawn point toward the mouse cursor. Apply a slight upward
	# loft so close-range throws still arc, and clamp the angle so straight-down
	# throws don't slam the grenade into the floor instantly.
	var aim: Vector2 = get_global_mouse_position() - spawn_pos
	if aim.length_squared() < 1.0:
		aim = Vector2(1.0 if facing_right else -1.0, -0.55)
	var dir: Vector2 = aim.normalized()
	# Loft: add a touch of upward bias for shorter horizontal throws
	dir.y -= 0.18
	dir = dir.normalized()
	# Update facing so the player turns to match the throw
	facing_right = dir.x >= 0.0
	g.setup(Grenade.Type.values()[grenade_type], dir * throw_force)

func add_grenade(type: int) -> bool:
	if grenade_count >= GRENADE_MAX:
		return false
	grenade_count += 1
	grenade_type = type
	grenade_changed.emit(GRENADE_NAMES[grenade_type], grenade_count)
	return true

func _handle_attack_input() -> void:
	if not Input.is_action_just_pressed("attack") or is_dead:
		return
	if is_attacking:
		# Queue the next combo step; it'll fire as soon as the current swing ends.
		_attack_buffered = true
		return
	# Not currently attacking — choose the next stage based on combo window.
	var next_stage: int = 1
	if _combo_window_timer > 0.0 and attack_stage > 0 and attack_stage < 3:
		next_stage = attack_stage + 1
	_start_attack(next_stage)

func _start_attack(stage: int) -> void:
	_slide_bash = is_sliding
	if is_sliding:
		_end_slide()
	var chaining: bool = _axe.visible
	attack_stage = stage
	is_attacking = true
	var cfg: Dictionary = _stage_config(stage)
	attack_timer = float(cfg["duration"])
	attack_shape.disabled = false
	var reach: float = 28.0 if stage == 3 else 20.0
	attack_area.position.x = reach if facing_right else -reach
	var tint: Color = cfg["tint"]
	if _slide_bash:
		tint = Color(1.0, 0.38, 0.08)
	tint.a = sprite.modulate.a
	sprite.modulate = tint

	# Anchor the axe at the marine's front hand. The first phase of each
	# attack eases from the swing's origin pose to rot_start (the windup),
	# the second phase eases through to rot_end (the strike).
	if chaining:
		_attack_swing_origin_rot = _axe_pivot.rotation
		_attack_swing_origin_thrust = _axe_pivot.position.x
	else:
		# Fresh attack: drop in already at rot_start so there's no jump.
		_attack_swing_origin_rot = float(cfg["rot_start"])
		_attack_swing_origin_thrust = float(cfg["thrust_start"])
		_axe_pivot.rotation = _attack_swing_origin_rot
		_axe_pivot.position = Vector2(_attack_swing_origin_thrust, 0.0)

	_axe.visible = true
	_arm_front.visible = true
	_arm_back.visible = true
	_hand_front.visible = true
	_hand_back.visible = true

func _end_attack() -> void:
	is_attacking = false
	_slide_bash = false
	attack_shape.disabled = true
	sprite.modulate = _get_base_modulate()
	# Chain into the next stage if buffered and we haven't reached the finisher
	if _attack_buffered and attack_stage < 3:
		_attack_buffered = false
		_start_attack(attack_stage + 1)
		return
	# End of swing — start (or refresh) the combo window. If the player
	# pulls the trigger again within it, they continue the combo.
	_attack_buffered = false
	_combo_window_timer = combo_window
	# Hide the axe + arms between swings
	_axe.visible = false
	_arm_front.visible = false
	_arm_back.visible = false
	_hand_front.visible = false
	_hand_back.visible = false

func _on_attack_hit(body: Node) -> void:
	var cfg: Dictionary = _stage_config(attack_stage)
	var mult: float = float(cfg.get("damage_mult", 1.0))
	var dmg: int = int(attack_damage * mult * (active_buffs["damage"].magnitude if "damage" in active_buffs else 1.0))
	if _slide_bash:
		dmg = int(dmg * 1.6)
	if body.has_method("request_damage"):
		body.request_damage.rpc_id(body.get_multiplayer_authority(), dmg, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(dmg, global_position)

func _stage_config(stage: int) -> Dictionary:
	# Per-attack tuning. Rotation 0 = axe shaft straight up. Positive rot is
	# clockwise in screen-space (with y-down), so +π/2 lays the shaft forward.
	# Thrust = forward offset of the pivot (used by Stab to lunge).
	match stage:
		1:  # CLEAVE — wide diagonal slash from up-and-back to down-and-forward
			return {
				"duration": 0.28,
				"damage_mult": 1.0,
				"rot_start":  -0.55,
				"rot_end":     2.10,
				"thrust_start": 0.0,
				"thrust_end":   0.0,
				"tint": Color(1.0, 0.85, 0.2),
			}
		2:  # SMASH — full overhead chop; big windup, heavy slam
			return {
				"duration": 0.38,
				"damage_mult": 1.6,
				"rot_start":  -1.65,
				"rot_end":     2.45,
				"thrust_start": 0.0,
				"thrust_end":   3.0,
				"tint": Color(1.0, 0.55, 0.10),
			}
		3:  # STAB — pivot stays horizontal forward; lunge with thrust offset
			return {
				"duration": 0.22,
				"damage_mult": 0.9,
				"rot_start":  1.55,
				"rot_end":    1.55,
				"thrust_start": 0.0,
				"thrust_end":  22.0,
				"tint": Color(1.0, 0.95, 0.55),
			}
		_:
			return {
				"duration": attack_duration,
				"damage_mult": 1.0,
				"rot_start":  -0.55,
				"rot_end":     2.10,
				"thrust_start": 0.0,
				"thrust_end":   0.0,
				"tint": Color(1.0, 0.85, 0.2),
			}

func _solve_ik(shoulder: Vector2, hand: Vector2, upper: float, fore: float, bend_sign: float) -> Vector2:
	# Classic 2-bone IK: place an elbow so |shoulder→elbow|=upper and
	# |elbow→hand|=fore. bend_sign picks which of the two solutions to use
	# (positive = elbow bends "below" the shoulder→hand line in screen space).
	var to_hand: Vector2 = hand - shoulder
	var d: float = to_hand.length()
	if d <= 0.0001:
		return shoulder + Vector2(0.0, upper)
	# If the target is out of reach, fully extend toward it.
	if d >= upper + fore:
		return shoulder + to_hand.normalized() * upper
	# If the target is closer than the difference, collapse the elbow outward.
	if d <= absf(upper - fore):
		var sign_dir: float = 1.0 if upper >= fore else -1.0
		return shoulder + to_hand.normalized() * upper * sign_dir
	var a: float = (upper * upper - fore * fore + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(upper * upper - a * a, 0.0))
	var axis: Vector2 = to_hand / d
	var perp: Vector2 = Vector2(-axis.y, axis.x)
	return shoulder + axis * a + perp * h * bend_sign

func _build_axe() -> void:
	# A 2-handed battle axe drawn from polygons. Pivot sits at the front
	# (lower) hand grip so rotation visually pivots around the marine's hand.
	# Shaft extends UP from the pivot; the head sits at the top.
	_axe = Node2D.new()
	_axe.z_index = 2
	_axe.visible = false
	add_child(_axe)

	_axe_pivot = Node2D.new()
	_axe.add_child(_axe_pivot)

	# Shaft (haft) — goes from grip (y=0) up to head (y=-26)
	var shaft := Polygon2D.new()
	shaft.color = Color(0.34, 0.22, 0.12)
	shaft.polygon = PackedVector2Array([
		Vector2(-1.4,   0.0), Vector2(1.4,  0.0),
		Vector2(1.4, -26.0), Vector2(-1.4, -26.0),
	])
	_axe_pivot.add_child(shaft)

	# Grip wrap at the bottom (where the front hand grabs)
	var grip := Polygon2D.new()
	grip.color = Color(0.10, 0.08, 0.06)
	grip.polygon = PackedVector2Array([
		Vector2(-2.0, -2.0), Vector2(2.0, -2.0),
		Vector2(2.0,  3.0), Vector2(-2.0, 3.0),
	])
	_axe_pivot.add_child(grip)

	# Upper shaft wrap (where the back hand grabs)
	var grip2 := Polygon2D.new()
	grip2.color = Color(0.10, 0.08, 0.06)
	grip2.polygon = PackedVector2Array([
		Vector2(-2.0, -16.0), Vector2(2.0, -16.0),
		Vector2(2.0, -12.0), Vector2(-2.0, -12.0),
	])
	_axe_pivot.add_child(grip2)

	# Pommel below the grip
	var pommel := Polygon2D.new()
	pommel.color = Color(0.55, 0.55, 0.60)
	pommel.polygon = PackedVector2Array([
		Vector2(-2.4, 3.0), Vector2(2.4, 3.0),
		Vector2(2.0, 6.0), Vector2(-2.0, 6.0),
	])
	_axe_pivot.add_child(pommel)

	# Axe head — asymmetric so the "primary" blade leans forward
	var head := Polygon2D.new()
	head.color = Color(0.72, 0.74, 0.80)
	head.polygon = PackedVector2Array([
		Vector2(-6.0, -22.0), Vector2(0.0, -29.0),
		Vector2(13.0, -30.0), Vector2(16.0, -25.0),
		Vector2(13.0, -19.0), Vector2(0.0, -20.0),
		Vector2(-6.0, -23.0),
	])
	_axe_pivot.add_child(head)

	# Edge highlight on the bit
	var edge := Polygon2D.new()
	edge.color = Color(0.92, 0.95, 1.0)
	edge.polygon = PackedVector2Array([
		Vector2(11.0, -30.0), Vector2(16.0, -25.0), Vector2(13.0, -19.0),
	])
	_axe_pivot.add_child(edge)

	# Back spike (small) opposite the bit
	var spike := Polygon2D.new()
	spike.color = Color(0.55, 0.55, 0.60)
	spike.polygon = PackedVector2Array([
		Vector2(-6.0, -23.0), Vector2(-6.0, -22.0),
		Vector2(-10.0, -25.0),
	])
	_axe_pivot.add_child(spike)

	# Trim band where head meets shaft
	var trim := Polygon2D.new()
	trim.color = Color(0.42, 0.32, 0.18)
	trim.polygon = PackedVector2Array([
		Vector2(-2.5, -22.0), Vector2(2.5, -22.0),
		Vector2(2.5, -18.0), Vector2(-2.5, -18.0),
	])
	_axe_pivot.add_child(trim)

	# --- Arms — 2-bone IK (shoulder → elbow → hand). Line2D's joint mode
	# rounds the elbow corner; we recompute the elbow each frame so the
	# arms bend naturally as the marine reaches through the swing.
	_arm_back = Line2D.new()
	_arm_back.width = 3.2
	_arm_back.default_color = Color(0.20, 0.34, 0.12)
	_arm_back.z_index = 1
	_arm_back.visible = false
	_arm_back.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_arm_back.end_cap_mode = Line2D.LINE_CAP_ROUND
	_arm_back.joint_mode = Line2D.LINE_JOINT_ROUND
	_arm_back.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	add_child(_arm_back)

	_arm_front = Line2D.new()
	_arm_front.width = 3.4
	_arm_front.default_color = Color(0.36, 0.56, 0.20)
	_arm_front.z_index = 3
	_arm_front.visible = false
	_arm_front.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_arm_front.end_cap_mode = Line2D.LINE_CAP_ROUND
	_arm_front.joint_mode = Line2D.LINE_JOINT_ROUND
	_arm_front.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	add_child(_arm_front)

	# Small hand rects at the grip points so the joint reads
	_hand_back = ColorRect.new()
	_hand_back.color = Color(0.90, 0.78, 0.62)
	_hand_back.offset_left = -2.0; _hand_back.offset_top = -2.0
	_hand_back.offset_right = 2.0; _hand_back.offset_bottom = 2.0
	_hand_back.z_index = 3
	_hand_back.visible = false
	_hand_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_back)

	_hand_front = ColorRect.new()
	_hand_front.color = Color(0.95, 0.82, 0.66)
	_hand_front.offset_left = -2.0; _hand_front.offset_top = -2.0
	_hand_front.offset_right = 2.0; _hand_front.offset_bottom = 2.0
	_hand_front.z_index = 4
	_hand_front.visible = false
	_hand_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hand_front)


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
		score_changed.emit(score)

func apply_powerup(type: String, duration: float, magnitude: float = 1.0) -> void:
	active_buffs[type] = {"timer": duration, "magnitude": magnitude}
	if type == "shield":
		is_invincible = true
		invincibility_timer = duration
	sprite.modulate = _get_base_modulate()

func _is_local_authority() -> bool:
	# Solo (no multiplayer peer) → always local. Otherwise defer to the
	# usual multiplayer-authority check. Godot 4's get_unique_id() can
	# return 0 (not 1) when no peer is active, which breaks the default
	# authority=1 comparison and freezes the player in solo.
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()

@rpc("any_peer", "call_local", "reliable")
func request_damage(amount: int, source_pos: Vector2) -> void:
	# Route incoming damage through the player's owning peer.
	if _is_local_authority():
		take_damage(amount, source_pos)

func set_camera_limits(left: int, top: int, right: int, bottom: int) -> void:
	if _cam == null:
		return
	_cam.limit_left = left
	_cam.limit_top = top
	_cam.limit_right = right
	_cam.limit_bottom = bottom

func take_damage(amount: int, source_pos: Vector2) -> void:
	if not _is_local_authority():
		return
	if is_invincible or is_dead:
		return
	# All incoming attacks deal 1 damage. The kill-plane in Main.gd still
	# passes 99 to force-kill the player; preserve that as a special case.
	var dmg: int = 99 if amount >= 99 else 1
	current_health -= dmg
	is_invincible = true
	invincibility_timer = invincibility_time
	if is_sliding:
		_end_slide()
	health_changed.emit(current_health, max_health)
	var knockback_dir := (global_position - source_pos).normalized()
	velocity.x = knockback_dir.x * knockback_force
	velocity.y = -200
	_apply_shake(5.0)
	if current_health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	if _anim_sprite != null:
		_anim_sprite.stop()
	sprite.modulate = Color(0.5, 0.5, 0.5)
	_apply_shake(12.0)
	died.emit()

func _apply_shake(amount: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)

func _update_camera_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake_amount > 0.01:
		_cam.offset = Vector2(randf_range(-_shake_amount, _shake_amount), randf_range(-_shake_amount, _shake_amount))
		_shake_amount = maxf(_shake_amount - _shake_decay * delta, 0.0)
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

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

	_set_facing(facing_right)

	# Animate the axe through its swing — windup back, then strike forward.
	# Only the marine has the axe rig; demon attacks still hit but without it.
	if is_attacking and _axe != null:
		var cfg: Dictionary = _stage_config(attack_stage)
		var dur: float = float(cfg["duration"])
		var t: float = 1.0 - clampf(attack_timer / maxf(dur, 0.001), 0.0, 1.0)
		var r_start: float = float(cfg["rot_start"])
		var r_end:   float = float(cfg["rot_end"])
		var th_start: float = float(cfg["thrust_start"])
		var th_end:   float = float(cfg["thrust_end"])

		# Phase split: first ~28% is windup (ease-in-out from origin → start
		# pose), the remaining ~72% is the strike (ease-out cubic from start
		# pose → end pose). Stab skips windup since both ends share rotation.
		const WINDUP: float = 0.28
		var rot_now: float
		var thrust_now: float
		if t < WINDUP and attack_stage != 3:
			var u: float = t / WINDUP
			var ue: float = u * u * (3.0 - 2.0 * u)   # smoothstep
			rot_now = lerpf(_attack_swing_origin_rot, r_start, ue)
			thrust_now = lerpf(_attack_swing_origin_thrust, th_start, ue)
		else:
			var u2: float = clampf((t - WINDUP) / (1.0 - WINDUP), 0.0, 1.0) if attack_stage != 3 else t
			var ue2: float = 1.0 - pow(1.0 - u2, 3.0)
			rot_now = lerpf(r_start, r_end, ue2)
			thrust_now = lerpf(th_start, th_end, ue2)

		_axe_pivot.rotation = rot_now
		_axe_pivot.position = Vector2(thrust_now, 0.0)

		# Anchor + flip — the axe is held at the marine's front hand. We keep
		# the axe rig in local space and flip the whole rig with facing.
		var face_dir: float = 1.0 if facing_right else -1.0
		_axe.position = Vector2(2.0 * face_dir, -2.0)
		_axe.scale.x = face_dir

		# --- Arms — 2-bone IK from shoulder to hand at the axe grip.
		var front_shoulder: Vector2 = Vector2(3.0 * face_dir, -4.0)
		var back_shoulder:  Vector2 = Vector2(-3.0 * face_dir, -4.0)
		var front_grip_local := Vector2(0.0, 0.5)
		var back_grip_local  := Vector2(0.0, -14.0)
		var front_grip: Vector2 = to_local(_axe_pivot.to_global(front_grip_local))
		var back_grip:  Vector2 = to_local(_axe_pivot.to_global(back_grip_local))

		# Anatomy: upper arm 7px, forearm 8px. Front arm reaches farther
		# (lead arm), back arm slightly shorter to keep elbow inside the
		# body silhouette.
		var front_elbow: Vector2 = _solve_ik(front_shoulder, front_grip, 7.0, 8.0, 1.0)
		var back_elbow:  Vector2 = _solve_ik(back_shoulder, back_grip, 6.5, 7.5, 1.0)

		_arm_front.points = PackedVector2Array([front_shoulder, front_elbow, front_grip])
		_arm_back.points  = PackedVector2Array([back_shoulder, back_elbow, back_grip])
		_hand_front.position = front_grip - Vector2(2.0, 2.0)
		_hand_back.position  = back_grip - Vector2(2.0, 2.0)

		# Body engagement: lean the marine sprite into the swing during the
		# strike phase. The lean is applied with facing direction so the
		# marine always tilts into the swing, not against it.
		var lean_amount: float = 0.0
		if attack_stage == 1:
			lean_amount = 0.18
		elif attack_stage == 2:
			lean_amount = 0.25
		elif attack_stage == 3:
			lean_amount = 0.05
		var lean_t: float = clampf((t - 0.30) / 0.50, 0.0, 1.0)
		var lean_decay: float = clampf((t - 0.80) / 0.20, 0.0, 1.0)
		var lean_now: float = lean_amount * lean_t * (1.0 - lean_decay * 0.6) * face_dir
		sprite.rotation = lerpf(sprite.rotation, lean_now, minf(delta * 26.0, 1.0))

		# Stab step-forward: shift the sprite slightly in facing direction
		var step_offset: float = 0.0
		if attack_stage == 3:
			var step_t: float = clampf((t - 0.15) / 0.45, 0.0, 1.0)
			var step_back: float = clampf((t - 0.70) / 0.30, 0.0, 1.0)
			step_offset = 3.0 * step_t * (1.0 - step_back)
		sprite.position.x = lerpf(sprite.position.x, step_offset * face_dir, minf(delta * 26.0, 1.0))
	else:
		# Settle the sprite back to its rest pose between swings.
		sprite.rotation = lerpf(sprite.rotation, 0.0, minf(delta * 18.0, 1.0))
		sprite.position.x = lerpf(sprite.position.x, 0.0, minf(delta * 18.0, 1.0))

	var anim: StringName = &"walk" if is_on_floor() and absf(velocity.x) > 10.0 else &"idle"
	_play_anim(anim)

	# Squash/stretch in units of the marine baseline (0.3). Scaling by
	# base_scale / 0.3 lets demon (base_scale 1.0) reuse the same multipliers.
	var ratio: Vector2 = base_scale / Vector2(0.3, 0.3)
	var target_scale: Vector2
	var target_y: float

	if is_sliding or is_rolling:
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

	target_scale *= ratio
	var t := minf(delta * 22.0, 1.0)
	sprite.scale = sprite.scale.lerp(target_scale, t)
	sprite.position.y = lerpf(sprite.position.y, target_y, t)

func _set_facing(face_right: bool) -> void:
	if _anim_sprite != null:
		_anim_sprite.flip_h = face_right
		return
	var s := absf(_facing_node.scale.x)
	if s == 0.0:
		s = 1.0
	_facing_node.scale.x = s if face_right else -s

func _play_anim(name: StringName) -> void:
	if _anim_sprite == null:
		return
	if _anim_sprite.animation != name:
		_anim_sprite.play(name)

func _handle_shoot_input() -> void:
	if is_dead:
		return
	if Input.is_action_just_pressed("select_rifle"):
		_set_weapon(Weapon.RIFLE)
	elif Input.is_action_just_pressed("select_shotgun"):
		_set_weapon(Weapon.SHOTGUN)
	elif Input.is_action_just_pressed("cycle_weapon"):
		_set_weapon((weapon + 1) % WEAPON_NAMES.size())
	if _shoot_timer > 0:
		return
	if Input.is_action_pressed("shoot"):
		_shoot()

func _set_weapon(new_weapon: int) -> void:
	if new_weapon == weapon:
		return
	weapon = new_weapon
	weapon_changed.emit(WEAPON_NAMES[weapon])
	# Holstering doesn't unload — but if shells were depleted, give a small
	# delay before they can be used on the swap-back so spamming Tab can't
	# bypass the reload.
	if weapon == Weapon.SHOTGUN and _shotgun_shells <= 0 and _shoot_timer <= 0:
		_shoot_timer = 0.25

func _shoot() -> void:
	var mouse_pos := get_global_mouse_position()
	var muzzle := global_position + Vector2(18.0 if facing_right else -18.0, -8.0)
	var dir := (mouse_pos - muzzle).normalized()
	facing_right = dir.x >= 0.0

	match weapon:
		Weapon.SHOTGUN:
			# Reload happens lazily — if the shoot timer expired and shells are
			# empty, the next trigger pull re-racks before firing.
			if _shotgun_shells <= 0:
				_shotgun_shells = shotgun_capacity
				shotgun_shells_changed.emit(_shotgun_shells, shotgun_capacity)
			_fire_shotgun(muzzle, dir)
			_shotgun_shells -= 1
			shotgun_shells_changed.emit(_shotgun_shells, shotgun_capacity)
			_shoot_timer = shotgun_reload_time if _shotgun_shells <= 0 else shotgun_barrel_interval
		_:
			_fire_rifle(muzzle, dir)
			_shoot_timer = shoot_cooldown
	sprite.scale = Vector2(0.26, 0.34)

func _fire_rifle(muzzle: Vector2, dir: Vector2) -> void:
	var bullet := PLAYER_BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle
	bullet.max_range = bullet_range
	bullet.setup(dir, bullet_speed, bullet_damage)

func _fire_shotgun(muzzle: Vector2, dir: Vector2) -> void:
	# 2x2 grid of parallel pellets. Lateral axis is perpendicular to the aim
	# direction; depth axis is along it. All pellets travel in `dir`, just
	# from staggered starting positions, so they form a rectangle moving
	# forward like a quad burst of rifles.
	var pellet_dmg: int = bullet_damage * shotgun_damage_mult
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var offsets := [
		Vector2(-shotgun_grid_depth, -shotgun_grid_lateral),
		Vector2(-shotgun_grid_depth,  shotgun_grid_lateral),
		Vector2( shotgun_grid_depth, -shotgun_grid_lateral),
		Vector2( shotgun_grid_depth,  shotgun_grid_lateral),
	]
	for off in offsets:
		var spawn_offset: Vector2 = dir * off.x + perp * off.y
		var pellet := PLAYER_BULLET_SCENE.instantiate()
		get_tree().current_scene.add_child(pellet)
		pellet.global_position = muzzle + spawn_offset
		pellet.max_range = shotgun_pellet_range
		pellet.setup(dir, shotgun_pellet_speed, pellet_dmg)
		pellet.modulate = Color(1.0, 0.72, 0.30)
	# A little knockback so the shotgun has weight
	velocity.x -= dir.x * 50.0
	_apply_shake(2.5)

func _spawn_double_jump_effect() -> void:
	sprite.scale = Vector2(0.39, 0.21)
