extends Player
# class_name removed — collided with the GreaterDemon enemy in scripts/GreaterDemon.gd.

# Greater Demon avatar controller. Heavy melee — the visual rig is a single
# AnimatedSprite2D in PlayerGreaterDemon.tscn carrying the full greater_demon
# frameset (idle / walk / run / stab / lunge_impact / slash / hurt / die).
#
# The base Player only drives idle/walk/run/slide/crouch/slash/stab. This
# subclass layers on the greater-demon-specific clips: a brief `hurt` flash
# on damage, a `lunge_impact` tail at the end of a Stab, and a `die`
# animation on death (instead of freezing the current frame).

const HURT_FLASH_TIME: float = 0.30
# Heavy lunge has a longer windup → match the impact tail to its longer
# duration so the impact pose holds proportionally to the base stab.
const LUNGE_IMPACT_TAIL: float = 0.15

# --- Wing flight tuning ------------------------------------------------------
# Each press of jump in mid-air costs FLAP_COST stamina and snaps vertical
# velocity to FLAP_IMPULSE (a hard set, not additive — gives a punchy beat
# rather than a soft additive bump). Holding jump while airborne reduces
# gravity to GLIDE_GRAVITY_SCALE so the demon coasts down slowly with wings
# spread. Stamina drains while gliding and refills on the ground.
@export var flap_impulse: float = -340.0
@export var flap_horiz_kick: float = 110.0        # forward boost on each flap
@export var flap_cost: float = 0.18               # stamina per flap (~33 flaps from full)
@export var flap_cooldown: float = 0.13           # min seconds between flaps
@export var glide_gravity_scale: float = 0.22
@export var glide_drain_rate: float = 0.18        # stamina/sec while gliding
@export var glide_max_fall: float = 95.0          # capped descent while gliding
@export var max_flight_stamina: float = 6.0       # ~33 flaps or ~33s of gliding
@export var flight_recharge_rate: float = 3.0     # stamina/sec on ground (full refill ≈2s)

var _flight_stamina: float = 0.0
var _flap_cd: float = 0.0
var _is_gliding: bool = false
var _flap_anim_timer: float = 0.0  # how long to keep flapping anim after a flap
var _hitstop_consumed: bool = false  # one hit-stop per swing — multi-hits don't stack freeze

# Hit-stop tuning. Engine.time_scale is restored on an unscaled timer so the
# freeze duration is real wall-time, not affected by the scale we just set.
const HITSTOP_SCALE: float = 0.06
const HITSTOP_TIME:  float = 0.07

# Lifesteal: heal a fraction of the damage dealt on every melee connect, with
# a floor so chip hits still feed the demon. Only the local authority heals;
# the result replicates back through `current_health`.
@export var lifesteal_pct: float = 0.30
@export var lifesteal_min: int = 1

func get_character_id() -> String:
	return "greater_demon"

func _ready() -> void:
	super._ready()
	_flight_stamina = max_flight_stamina
	# The base jetpack system arms on double-jump; flight replaces it.
	jetpack_duration = 0.0
	# Duplicate the attack shape so per-stage resizes in _start_attack stay
	# local to this player and don't leak across other PlayerGreaterDemon
	# instances spawned in the same level (multiplayer / split-screen).
	if attack_shape != null and attack_shape.shape != null:
		attack_shape.shape = attack_shape.shape.duplicate()

func _physics_process(delta: float) -> void:
	# Tick flight-only timers before the base step so _handle_gravity /
	# _handle_jump_logic (both overridden below) see fresh values.
	if _is_local_authority() and not is_dead:
		if _flap_cd > 0.0:
			_flap_cd -= delta
		if _flap_anim_timer > 0.0:
			_flap_anim_timer -= delta
		if is_on_floor():
			_flight_stamina = minf(_flight_stamina + flight_recharge_rate * delta, max_flight_stamina)
	super._physics_process(delta)

func _handle_gravity(delta: float) -> void:
	# Glide: holding jump while airborne with stamina left → reduced gravity
	# and a capped descent. Drains stamina; when empty, fall normally.
	if not is_dead and not is_on_floor() and not is_dashing and not is_wall_sliding \
			and Input.is_action_pressed("jump") and _flight_stamina > 0.0 \
			and velocity.y > -40.0:
		_is_gliding = true
		velocity.y += gravity * glide_gravity_scale * delta
		velocity.y = minf(velocity.y, glide_max_fall)
		_flight_stamina = maxf(_flight_stamina - glide_drain_rate * delta, 0.0)
		return
	_is_gliding = false
	super._handle_gravity(delta)

func _handle_jump_logic() -> void:
	# Ground / wall / coyote jumps still go through the base path. The
	# mid-air branch (where the base does a double-jump + arms the jetpack)
	# is replaced with a wing flap: stamina-gated, no jump count consumed,
	# repeatable as long as stamina lasts.
	if is_dashing or is_rolling:
		return
	if jump_buffer_timer <= 0.0:
		return
	if is_wall_sliding or is_on_floor() or coyote_timer > 0.0:
		super._handle_jump_logic()
		return
	if _flap_cd > 0.0 or _flight_stamina < flap_cost:
		return
	velocity.y = flap_impulse
	if absf(velocity.x) < speed:
		# Snap a touch of horizontal momentum in the facing direction so the
		# flap feels like a wingbeat, not a pure vertical hop.
		var dir := 1.0 if facing_right else -1.0
		velocity.x = move_toward(velocity.x, dir * (speed * 0.6), flap_horiz_kick)
	_flight_stamina = maxf(_flight_stamina - flap_cost, 0.0)
	_flap_cd = flap_cooldown
	_flap_anim_timer = 0.28
	jump_buffer_timer = 0.0
	_apply_shake(1.5)
	_spawn_double_jump_effect()
	# Snap the wing animation to a fresh down-stroke so the visible flap
	# syncs with the impulse. Without this, .play("walk") is a no-op when
	# walk is already the current animation, and the wings just keep
	# coasting through whatever frame they were on.
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(&"walk"):
		_anim_sprite.play(&"walk")
		_anim_sprite.frame = 0
		_anim_sprite.speed_scale = 2.0  # punchy wingbeat, decays in _update_sprite

# Map air state to the walk frames (wings flap) so flight reads visually,
# instead of the base's airborne→idle fallback. We stay on "walk" the whole
# time so .play() is a no-op between flaps — that lets the explicit
# frame=0 reset on each flap actually trigger a fresh wingbeat, and lets
# the cycle loop smoothly during glide.
func _pick_anim_name() -> StringName:
	if not is_dead and not is_on_floor() and not is_attacking and not is_wall_sliding:
		if _flap_anim_timer > 0.0 or _is_gliding:
			return &"walk"
	return super._pick_anim_name()

# --- Attack mapping ----------------------------------------------------------
# LMB ("attack") chains the light cleave combo capped at stage 2 (Cleave →
# Smash, both rendered as the "slash" clip since the greater demon has no
# distinct smash art). RMB ("heavy_attack") is a standalone heavy lunge that
# always fires stage 3, which the base `_pick_anim_name` plays as "stab"
# and `_pick_greater_demon_anim` caps off with `lunge_impact`.
const LMB_COMBO_CAP: int = 2

func _handle_attack_input() -> void:
	if is_dead:
		return
	if Input.is_action_just_pressed("heavy_attack"):
		if not is_attacking:
			_start_attack(3)
			_apply_shake(4.0)
		return
	if not Input.is_action_just_pressed("attack"):
		return
	if is_attacking:
		# Only buffer if we'd still be inside the LMB cap; otherwise the
		# press is a no-op so it can't sneak past Smash into Stab.
		if attack_stage < LMB_COMBO_CAP:
			_attack_buffered = true
		return
	var next_stage: int = 1
	if _combo_window_timer > 0.0 and attack_stage > 0 and attack_stage < LMB_COMBO_CAP:
		next_stage = attack_stage + 1
	_start_attack(next_stage)

func _on_attack_start(_stage: int, _chaining: bool, cfg: Dictionary) -> void:
	# Tighten the swing: force the attack clip to restart from frame 0 (so a
	# Cleave → Smash chain doesn't continue mid-cycle, since both map to the
	# same "slash" anim and _play_anim skips .play() when the name matches),
	# and stretch speed_scale so the clip's runtime matches the stage's actual
	# gameplay duration instead of running long or short.
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	var anim: StringName = &"stab" if attack_stage == 3 else &"slash"
	var frames := _anim_sprite.sprite_frames
	if not frames.has_animation(anim):
		return
	var frame_count := frames.get_frame_count(anim)
	var base_fps := frames.get_animation_speed(anim)
	if frame_count <= 0 or base_fps <= 0.0:
		return
	# Stage 3 ends in a lunge_impact pose for LUNGE_IMPACT_TAIL seconds — fit
	# the stab frames into the remaining window so the impact lands on time.
	var anim_window := float(cfg.get("duration", 0.25))
	if attack_stage == 3:
		anim_window = maxf(anim_window - LUNGE_IMPACT_TAIL, 0.05)
	var desired_fps := float(frame_count) / anim_window
	_anim_sprite.play(anim)
	_anim_sprite.frame = 0
	_anim_sprite.speed_scale = desired_fps / base_fps

func _end_attack() -> void:
	# Base `_end_attack` chains the buffered swing while `attack_stage < 3`.
	# We've already gated buffering at LMB_COMBO_CAP in our input handler, but
	# clear it here too as a belt-and-braces guard: a leftover buffer from a
	# stage-3 heavy must never auto-chain.
	if attack_stage >= LMB_COMBO_CAP:
		_attack_buffered = false
	# Release the per-stage speed_scale so idle/walk/run play at their authored
	# rate; the wingbeat decay in _update_sprite handles airborne cases.
	if _anim_sprite != null:
		_anim_sprite.speed_scale = 1.0
	super._end_attack()

func _stage_config(stage: int) -> Dictionary:
	var cfg: Dictionary = super._stage_config(stage)
	# Warlord-tier damage curve. Base cleave is already meaty after the
	# 2× boost in _ready; smash and heavy escalate from there.
	match stage:
		1: cfg["damage_mult"] = 1.8
		2: cfg["damage_mult"] = 3.0
		3:
			cfg["duration"] = 0.45
			cfg["damage_mult"] = 4.5
			cfg["thrust_end"] = 36.0
			cfg["tint"] = Color(1.0, 0.45, 0.08)
	return cfg

# Per-stage hit volumes. Sizes are in world pixels (the AttackArea sits
# under the root, not the scaled Sprite, so these are 1:1 with the
# CharacterBody collision box — body shape is 20×28 for reference).
#   • Cleave : short, wide arc — the sword sweeps sideways
#   • Smash  : tall vertical box — overhead chop bites a deep column
#   • Heavy  : long, narrow box — the lunge spears forward
const STAGE_HITS := {
	1: {"size": Vector2(56, 44), "reach": 38.0},
	2: {"size": Vector2(48, 60), "reach": 32.0},
	3: {"size": Vector2(78, 36), "reach": 60.0},
}

static func _hit_for(stage: int) -> Dictionary:
	return STAGE_HITS.get(stage, STAGE_HITS[1])

func _on_attack_hit(body: Node) -> void:
	# Dedup against the base list before we spend any per-hit budget on
	# vfx / freeze, so a multi-pass detection (Area2D signal + immediate
	# shape query + group sweep) only fires polish once per enemy.
	if body == null or body in _hit_this_swing:
		return
	super._on_attack_hit(body)
	_apply_lifesteal()
	# Spawn the burst at the enemy, not at the demon — the impact reads where
	# the blow actually lands, which sells the connection in a way that an
	# on-self flash can't.
	if body is Node2D:
		_spawn_impact_burst((body as Node2D).global_position)
	if not _hitstop_consumed:
		_hitstop_consumed = true
		_apply_hitstop()
	_apply_shake(3.0)

func _apply_lifesteal() -> void:
	# Only the local authority owns the HP value — remote peers will see the
	# heal through the replicated `current_health` field.
	if not _is_local_authority() or is_dead:
		return
	if current_health >= max_health:
		# Subtle nudge so the player still sees a "vampire" pulse when the
		# heal would have been pure overflow.
		_spawn_lifesteal_flash(0.5)
		return
	# Mirror Player._on_attack_hit's damage math so the leech scales with the
	# combo stage, slide-bash bonus, and the "damage" powerup buff.
	var cfg: Dictionary = _stage_config(attack_stage)
	var mult: float = float(cfg.get("damage_mult", 1.0))
	var dmg: int = int(attack_damage * mult \
			* (active_buffs["damage"].magnitude if "damage" in active_buffs else 1.0))
	if _slide_bash:
		dmg = int(dmg * 1.6)
	var heal_amt: int = maxi(int(ceil(float(dmg) * lifesteal_pct)), lifesteal_min)
	heal(heal_amt)
	_spawn_lifesteal_flash(1.0)

func _spawn_lifesteal_flash(intensity: float) -> void:
	# Brief blood-red pulse over the sprite so the lifesteal reads visually,
	# scaled down on overheal. Captures the current modulate as the restore
	# target so the attack tint (set in Player._start_attack) survives intact
	# after the pulse fades.
	if sprite == null:
		return
	var restore: Color = sprite.modulate
	var pulse: Color = Color(0.95, 0.15, 0.20).lerp(restore, 1.0 - intensity)
	pulse.a = restore.a
	sprite.modulate = pulse
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(sprite, "modulate", restore, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _apply_hitstop() -> void:
	# Tree-paused timers ignore Engine.time_scale, so the restore fires on
	# wall-clock time regardless of how slow we just made the world.
	Engine.time_scale = HITSTOP_SCALE
	var t := get_tree().create_timer(HITSTOP_TIME, true, false, true)
	t.timeout.connect(_clear_hitstop)

func _clear_hitstop() -> void:
	# Guard against a second swing landing and re-arming hitstop before this
	# restore fires — only reset to 1.0 if we're still in a slowed state.
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0

func _spawn_impact_burst(at: Vector2) -> void:
	# Cheap inline VFX: two stacked ColorRects (white core + orange ring)
	# parented to the level so they don't move with the player, scaled-up
	# and faded with a tween. Mirrors the look of ExplosiveEffect without
	# the area/damage payload.
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	var burst := Node2D.new()
	burst.global_position = at
	burst.z_index = 50
	parent.add_child(burst)

	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.55, 0.08, 0.95)
	ring.size = Vector2(28, 28)
	ring.position = Vector2(-14, -14)
	burst.add_child(ring)

	var core := ColorRect.new()
	core.color = Color(1.0, 0.98, 0.85, 1.0)
	core.size = Vector2(14, 14)
	core.position = Vector2(-7, -7)
	burst.add_child(core)

	# Faint angled streak in the swing direction — sells the slash arc.
	var aim_vec: Vector2 = at - global_position
	var streak := ColorRect.new()
	streak.color = Color(1.0, 0.75, 0.30, 0.85)
	streak.size = Vector2(46, 6)
	streak.position = Vector2(-23, -3)
	streak.rotation = aim_vec.angle()
	burst.add_child(streak)

	# Unscaled tween — VFX runs even during hit-stop so the burst pops
	# the instant the freeze kicks in instead of waiting it out.
	var tween := burst.create_tween().set_parallel(true)
	tween.set_ignore_time_scale(true)
	tween.tween_property(burst, "scale", Vector2(2.0, 2.0), 0.22) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(burst.queue_free)

func take_damage(amount: int, source_pos: Vector2) -> void:
	# Greater Demon is armored — take the damage, but lock velocity around
	# the call so the base's knockback assignment is undone immediately and
	# the demon never staggers. Invincibility / death / shake still apply.
	var pre_vel := velocity
	super.take_damage(amount, source_pos)
	if not is_dead:
		velocity = pre_vel

func _start_attack(stage: int) -> void:
	_hitstop_consumed = false
	var hit: Dictionary = _hit_for(stage)
	var size: Vector2 = hit["size"]
	var reach: float = hit["reach"]
	# Pre-size the hitbox BEFORE delegating to super. Super flips
	# attack_shape.disabled = false and then queues a deferred overlap
	# sweep; if we resized after, the sweep would still be operating on
	# the previous tick's collision data for the old 38×28 shape and
	# miss enemies that only sit inside the new larger volume.
	if attack_shape != null and attack_shape.shape is RectangleShape2D:
		(attack_shape.shape as RectangleShape2D).size = size
	super._start_attack(stage)
	if attack_area == null:
		return
	# Reposition along the aim vector at the demon's longer per-stage reach.
	# super positioned with its own (marine-sized) reach; override here.
	var aim_vec: Vector2 = get_global_mouse_position() - global_position
	var aim: Vector2 = aim_vec.normalized() if aim_vec.length_squared() > 0.0001 \
			else Vector2(1.0 if facing_right else -1.0, 0.0)
	attack_area.position = aim * reach
	# Belt-and-braces: do a direct shape query right now so we hit any
	# enemy already standing inside the volume on this exact frame, without
	# waiting for body_entered (which only fires on NEW overlaps) or the
	# deferred sweep (which can use stale collision state right after a
	# resize). Damages the first body found, then leaves the body_entered
	# signal to catch anyone we move INTO during the swing.
	_immediate_shape_hit(aim, reach, size)
	# Final fallback: walk the "enemy" group with an oriented-AABB check.
	# Independent of physics-server state, so it survives the case where the
	# Area2D's collider hasn't repopulated its overlap list yet after the
	# size/position change above and intersect_shape misses for any reason.
	_group_hit(aim, reach, size)

func _immediate_shape_hit(aim: Vector2, reach: float, size: Vector2) -> void:
	# PhysicsShapeQueryParameters2D + intersect_shape gives a synchronous
	# overlap test against the actual physics world, independent of the
	# Area2D's internal "what overlapped last tick" cache.
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = rect
	query.collision_mask = attack_area.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var xform := Transform2D(aim.angle(), global_position + aim * reach)
	query.transform = xform
	query.exclude = [get_rid()]
	var hits := space.intersect_shape(query, 16)
	for h in hits:
		var body = h.get("collider")
		if body != null:
			_on_attack_hit(body)

func _group_hit(aim: Vector2, reach: float, size: Vector2) -> void:
	# Project each enemy into the swing's local frame (rotate by -aim.angle()
	# about the player) and accept if it falls inside the size/2 box at
	# (reach, 0). Catches anyone the physics-server queries missed.
	var center: Vector2 = global_position + aim * reach
	var inv_basis := Transform2D(aim.angle(), center).affine_inverse()
	var half := size * 0.5
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == null or not (e is Node2D) or e in _hit_this_swing:
			continue
		var local := inv_basis * (e as Node2D).global_position
		if absf(local.x) <= half.x and absf(local.y) <= half.y:
			_on_attack_hit(e)

func _set_facing(face_right: bool) -> void:
	# Base Player assumes sprites face left at rest (flip_h when face_right).
	# The greater_demon sheet faces right, so invert the flip.
	if _anim_sprite != null:
		_anim_sprite.flip_h = not face_right
		return
	super._set_facing(face_right)

func _die() -> void:
	# Base class stops the AnimatedSprite on death, which freezes whatever
	# frame happened to be showing. Play the death clip instead so the
	# greater demon visibly collapses.
	is_dead = true
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(&"die"):
		_anim_sprite.play(&"die")
	elif _anim_sprite != null:
		_anim_sprite.stop()
	sprite.modulate = Color(0.5, 0.5, 0.5)
	_apply_shake(12.0)
	play_voice(&"die")
	died.emit()

func _update_sprite(delta: float) -> void:
	super._update_sprite(delta)
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	# Decay the post-flap speed boost back to 1.0 so the wing cycle settles
	# into a steady cruising flap between taps. Skipped during attacks so the
	# per-stage speed_scale set in _on_attack_start drives the swing cleanly.
	if not is_attacking and _anim_sprite.speed_scale != 1.0:
		var target := 2.0 if _flap_anim_timer > 0.0 else 1.0
		_anim_sprite.speed_scale = lerpf(_anim_sprite.speed_scale, target, minf(delta * 6.0, 1.0))
	var frames := _anim_sprite.sprite_frames
	var desired := _pick_greater_demon_anim(frames)
	if desired != &"" and _anim_sprite.animation != desired:
		_anim_sprite.play(desired)

func _pick_greater_demon_anim(frames: SpriteFrames) -> StringName:
	# Dying state takes priority — also covers non-local peers that learn
	# about the death through replicated `is_dead` rather than _die().
	if is_dead:
		if frames.has_animation(&"die"):
			return &"die"
		return &""
	# Tail end of a Stab swing: switch to the impact pose for the last
	# sliver so the lunge reads as connecting rather than just retracting.
	if is_attacking and attack_stage == 3 and attack_timer <= LUNGE_IMPACT_TAIL \
			and frames.has_animation(&"lunge_impact"):
		return &"lunge_impact"
	# Recently hit: invincibility_timer is reset to invincibility_time on
	# every damage event, so the first slice of the i-frame window is the
	# "just got hit" window for the flinch animation.
	if not is_attacking and is_invincible \
			and invincibility_timer > invincibility_time - HURT_FLASH_TIME \
			and frames.has_animation(&"hurt"):
		return &"hurt"
	return &""
