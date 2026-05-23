extends CharacterBody2D
class_name GreaterDemon

# Greater Demon — heavy flying mini-boss. Slower than WingedDemon but
# hits like a truck. Signature attack is a wide CLEAVE telegraphed by a
# lunge wind-up; sprite animations carry the visuals.

enum State { PATROL, ALERT, CHASE, WINDUP, CLEAVE, RECOVER, STAGGER, DEAD }

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
@export var dive_boost: float = 1.4

# --- Cleave -----------------------------------------------------------------
# Slash anim is 4 frames at speed 12 → ~0.333s. Stab (windup) is 5 frames at
# speed 9 → ~0.555s; windup_time is slightly longer so the last stab frame
# *holds* for ~0.10s as anticipation before the cleave fires.
@export var cleave_cooldown: float = 1.6
@export var windup_time: float = 0.65
@export var cleave_time: float = 0.34
# Active hit window aligned to slash frames 1–2 (the swing + impact frames).
@export var cleave_active_start: float = 0.08
@export var cleave_active_end: float = 0.25
@export var recover_time: float = 0.32
# Hit-stop and recoil on cleave contact.
@export var hit_stop_time: float = 0.06
@export var cleave_recoil: float = 180.0
@export var cleave_shake: float = 6.0

# Walk ↔ run hysteresis so the anim doesn't strobe when speed oscillates.
@export var walk_to_run_speed: float = 130.0
@export var run_to_walk_speed: float = 90.0

# --- Patrol -----------------------------------------------------------------
@export var patrol_width: float = 380.0
@export var patrol_height: float = 100.0
@export var patrol_speed: float = 0.35

@export var alert_time: float = 0.5
@export var stagger_time: float = 0.35

# Cheap variant tinting over the shared sprite sheet (e.g. Abyssal indigo).
@export var sprite_tint: Color = Color.WHITE

const EXPLOSIVE_EFFECT_SCENE = preload("res://scenes/ExplosiveEffect.tscn")

# Forward offset of the cleave hitbox (relative to body center) when active.
const CLEAVE_HIT_OFFSET_X: float = 34.0

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
var bob_phase: float = 0.0
var patrol_phase: float = 0.0
var breath_phase: float = 0.0
var _hit_this_swing: bool = false
var _hit_stop_timer: float = 0.0
# Locked at _ready from the scene's sprite scale so idle aliveness can layer
# subtle scale/offset on top without losing the base pose.
var _base_scale: Vector2 = Vector2.ONE
var _base_offset: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var alert_indicator: Node2D = $AlertIndicator
@onready var sight_ray: RayCast2D = $SightRay
@onready var cleave_hitbox: Area2D = $CleaveHitbox
@onready var cleave_hitbox_shape: CollisionShape2D = $CleaveHitbox/CollisionShape2D

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	bob_phase = randf() * TAU
	breath_phase = randf() * TAU
	add_to_group("enemy")
	_find_player()
	cleave_hitbox_shape.set_deferred("disabled", true)
	cleave_hitbox.body_entered.connect(_on_sword_hit)
	cleave_hitbox.area_entered.connect(_on_sword_area)
	_base_scale = sprite.scale
	_base_offset = sprite.offset
	sprite.modulate = sprite_tint
	sprite.play(&"idle")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _physics_process(delta: float) -> void:
	if not Net.is_solo() and not is_multiplayer_authority():
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
	bob_phase += delta * 2.4
	breath_phase += delta * 1.6  # slower than bob; chest-rise cadence
	patrol_phase += delta * patrol_speed * TAU
	if alert_timer > 0: alert_timer -= delta
	if stagger_timer > 0: stagger_timer -= delta
	if cleave_cd_timer > 0: cleave_cd_timer -= delta
	if _hit_stop_timer > 0: _hit_stop_timer -= delta
	state_timer += delta

func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_timer = 0.0
	match state:
		State.PATROL:
			alert_indicator.visible = false
			_play(&"idle")
		State.ALERT:
			alert_timer = alert_time
			alert_indicator.visible = true
			_play(&"idle")
		State.CHASE:
			alert_indicator.visible = false
			_play(&"walk")
		State.WINDUP:
			_hit_this_swing = false
			_play(&"stab")
		State.CLEAVE:
			cleave_hitbox_shape.set_deferred("disabled", false)
			_play(&"slash")
		State.RECOVER:
			cleave_hitbox_shape.set_deferred("disabled", true)
			cleave_cd_timer = cleave_cooldown
			# Follow-through: kick velocity backward off the swing so the demon
			# recoils rather than just stopping dead.
			velocity = Vector2(-float(direction) * cleave_recoil, -40.0)
			_play(&"idle")
		State.STAGGER:
			cleave_hitbox_shape.set_deferred("disabled", true)
			_play(&"hurt")
		State.DEAD:
			_play(&"die")
		_:
			pass

func _play(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

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
			if state_timer >= recover_time:
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
	sprite.modulate = Color(0.45, 0.85, 2.0)
	get_tree().create_timer(0.12).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_dead:
			sprite.modulate = sprite_tint
	)

func _flash_hit() -> void:
	sprite.modulate = Color(2.5, 2.5, 2.5)
	get_tree().create_timer(0.07).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_dead:
			sprite.modulate = sprite_tint
	)

func _die() -> void:
	is_dead = true
	_set_state(State.DEAD)
	sprite.modulate = Color(0.85, 0.85, 0.85)
	alert_indicator.visible = false
	cleave_hitbox_shape.set_deferred("disabled", true)
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 1
	var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	# Position via local (parent's frame) so we don't need the node in the
	# tree to resolve global_position; add deferred because _die() can be
	# invoked mid physics-shape query (Player3 immediate-hit pathway), and
	# ExplosiveEffect._ready toggles monitoring which is forbidden mid-flush.
	fx.position = global_position
	get_parent().call_deferred("add_child", fx)
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
		_deal_damage(body, cleave_damage)
		_hit_this_swing = true
		_on_cleave_landed(body)

func _on_sword_area(area: Area2D) -> void:
	if _hit_this_swing: return
	var p := area.get_parent()
	if p is Player and p.has_method("request_damage"):
		_deal_damage(p, cleave_damage)
		_hit_this_swing = true
		_on_cleave_landed(p)

func _deal_damage(target: Node, dmg: int) -> void:
	if multiplayer.has_multiplayer_peer():
		target.request_damage.rpc_id(target.get_multiplayer_authority(), dmg, global_position)
	elif target.has_method("take_damage"):
		target.take_damage(dmg, global_position)

func _on_cleave_landed(victim: Node) -> void:
	# Brief hit-stop pause and a camera kick when the cleave actually connects.
	_hit_stop_timer = hit_stop_time
	if victim and victim.has_method("_apply_shake"):
		victim.call("_apply_shake", cleave_shake)

func _update_visuals(_delta: float) -> void:
	# Facing — sheet draws the demon facing right by default; mirror when
	# moving left. The cleave hitbox always extends in the direction of motion.
	sprite.flip_h = direction < 0
	cleave_hitbox_shape.position.x = CLEAVE_HIT_OFFSET_X * float(direction)

	if is_dead:
		return

	# Hit-stop: freeze the sprite animation for a beat after a cleave lands.
	sprite.speed_scale = 0.0 if _hit_stop_timer > 0.0 else 1.0

	# Gate the cleave hitbox to the active window of the swing.
	if state == State.CLEAVE:
		var active: bool = state_timer >= cleave_active_start and state_timer <= cleave_active_end
		cleave_hitbox_shape.set_deferred("disabled", not active)

	# Walk ↔ run hysteresis — only swap when speed crosses the *opposite*
	# threshold, so a demon hovering at ~110 px/s doesn't strobe anims.
	if state == State.CHASE:
		var speed: float = velocity.length()
		if sprite.animation == &"run":
			if speed < run_to_walk_speed: _play(&"walk")
		else:
			if speed >= walk_to_run_speed: _play(&"run")

	# Idle aliveness — layer code-driven breathing/sway on top of the static
	# idle frames during "calm" states. Skipped during attacks and stagger so
	# their hand-drawn motion reads cleanly.
	var alive_states: bool = state == State.PATROL or state == State.ALERT or state == State.RECOVER
	if alive_states:
		var breath: float = sin(breath_phase) * 0.012        # ±1.2% chest rise
		var bob_y: float = sin(bob_phase) * 1.4              # subtle vertical drift
		var sway_x: float = sin(bob_phase * 0.5) * 0.6       # weight shift side-to-side
		sprite.scale = Vector2(_base_scale.x, _base_scale.y * (1.0 + breath))
		sprite.offset = _base_offset + Vector2(sway_x, bob_y)
	else:
		sprite.scale = _base_scale
		sprite.offset = _base_offset
