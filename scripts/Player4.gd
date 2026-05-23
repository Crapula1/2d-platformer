extends Player
class_name Squirrel

# Squirrel avatar controller. Three attacks layered over the base Player:
#
#   * Acorn gun     - "rifle" channel, single fat acorn projectile
#   * Acorn shotgun - "shotgun" channel, cone spread of small acorn pellets
#   * Mallet smash  - "attack" button, big overhead wooden mallet with an
#                     oversized hitbox. Single-stage (no Cleave/Stab combo).
#
# Visuals are still driven by squirrel_frames.tres for the body; the mallet
# rig is built from Polygon2D shapes by this script.

# --- Acorn gun -------------------------------------------------------------
@export var acorn_speed: float = 480.0
@export var acorn_range: float = 1100.0
@export var acorn_damage_mult: int = 2          # baseline acorn vs rifle bullet
@export var acorn_visual_scale: float = 2.0

# --- Acorn shotgun ---------------------------------------------------------
@export var acorn_shotgun_pellet_count: int = 6
@export var acorn_shotgun_pellet_speed: float = 460.0
@export var acorn_shotgun_pellet_range: float = 520.0
@export var acorn_shotgun_spread: float = 0.45  # half-cone in radians
@export var acorn_shotgun_pellet_scale: float = 1.4

# --- Mallet smash ----------------------------------------------------------
@export var mallet_duration: float = 0.42
@export var mallet_damage_mult: float = 2.4
@export var mallet_reach: float = 36.0
@export var mallet_hitbox_size: Vector2 = Vector2(58.0, 44.0)
@export var mallet_shake: float = 6.0

const ACORN_COLOR := Color(0.55, 0.32, 0.10)
const ACORN_CAP_COLOR := Color(0.28, 0.16, 0.06)

var _mallet: Node2D
var _mallet_pivot: Node2D
var _attack_shape_default_size: Vector2 = Vector2.ZERO
var _shake_fired_this_swing: bool = false
var _mallet_buffered: bool = false


func get_character_id() -> String:
	return "squirrel"


func current_weapon_label() -> String:
	# Acorn-flavored labels so the HUD reads "ACORN GUN" / "ACORN SHOTGUN".
	if not can_shoot():
		return "MELEE"
	match weapon:
		Weapon.SHOTGUN: return "ACORN SHOTGUN"
		_: return "ACORN GUN"


# ----------------------------------------------------------------------------
#  Visual rig
# ----------------------------------------------------------------------------
func _build_character_visuals() -> void:
	# Give the squirrel its own attack hitbox shape so we can swap it to the
	# mallet's larger footprint without mutating a shared resource that other
	# characters also reference.
	if attack_shape.shape is RectangleShape2D:
		var dup: RectangleShape2D = (attack_shape.shape as RectangleShape2D).duplicate()
		attack_shape.shape = dup
		_attack_shape_default_size = dup.size
	_build_mallet()


func _build_mallet() -> void:
	# Wooden mallet drawn from polygons. Pivot sits at the squirrel's grip so
	# rotation around the pivot reads as swinging the handle, not the head.
	_mallet = Node2D.new()
	_mallet.z_index = 2
	_mallet.visible = false
	add_child(_mallet)

	_mallet_pivot = Node2D.new()
	_mallet.add_child(_mallet_pivot)

	# Handle — long wooden shaft above the grip.
	var shaft := Polygon2D.new()
	shaft.color = Color(0.42, 0.27, 0.13)
	shaft.polygon = PackedVector2Array([
		Vector2(-1.6,  1.0), Vector2(1.6,  1.0),
		Vector2(1.6, -28.0), Vector2(-1.6, -28.0),
	])
	_mallet_pivot.add_child(shaft)

	# Grip wrap.
	var grip := Polygon2D.new()
	grip.color = Color(0.18, 0.11, 0.06)
	grip.polygon = PackedVector2Array([
		Vector2(-2.2, -2.0), Vector2(2.2, -2.0),
		Vector2(2.2,  3.0), Vector2(-2.2, 3.0),
	])
	_mallet_pivot.add_child(grip)

	# Mallet head — chunky wooden block, wider than the marine axe.
	var head := Polygon2D.new()
	head.color = Color(0.58, 0.38, 0.18)
	head.polygon = PackedVector2Array([
		Vector2(-11.0, -36.0), Vector2(11.0, -36.0),
		Vector2(13.0, -30.0), Vector2(13.0, -22.0),
		Vector2(11.0, -16.0), Vector2(-11.0, -16.0),
		Vector2(-13.0, -22.0), Vector2(-13.0, -30.0),
	])
	_mallet_pivot.add_child(head)

	# Head wood-grain band.
	var band := Polygon2D.new()
	band.color = Color(0.34, 0.20, 0.09)
	band.polygon = PackedVector2Array([
		Vector2(-13.0, -27.0), Vector2(13.0, -27.0),
		Vector2(13.0, -24.0), Vector2(-13.0, -24.0),
	])
	_mallet_pivot.add_child(band)

	# Iron rings at each end of the head.
	var ring_a := Polygon2D.new()
	ring_a.color = Color(0.30, 0.30, 0.34)
	ring_a.polygon = PackedVector2Array([
		Vector2(-13.0, -34.0), Vector2(-10.0, -34.0),
		Vector2(-10.0, -18.0), Vector2(-13.0, -18.0),
	])
	_mallet_pivot.add_child(ring_a)
	var ring_b := Polygon2D.new()
	ring_b.color = Color(0.30, 0.30, 0.34)
	ring_b.polygon = PackedVector2Array([
		Vector2(10.0, -34.0), Vector2(13.0, -34.0),
		Vector2(13.0, -18.0), Vector2(10.0, -18.0),
	])
	_mallet_pivot.add_child(ring_b)


# ----------------------------------------------------------------------------
#  Attack input — bypass the 3-hit combo; every press is a mallet smash
# ----------------------------------------------------------------------------
func _handle_attack_input() -> void:
	if not Input.is_action_just_pressed("attack") or is_dead:
		return
	if is_attacking:
		# Buffer the press so a tap during the swing's tail still fires the
		# next smash. Squirrel uses its own flag instead of the base class's
		# _attack_buffered because that one chains to attack_stage + 1 (stage
		# 3 = stab), and squirrel only has the single stage-2 mallet smash.
		_mallet_buffered = true
		return
	_start_attack(2)  # stage 2 is the mallet smash configuration below


func _stage_config(stage: int) -> Dictionary:
	if stage == 2:
		# Squirrel mallet smash — heavy overhead chop, big reach, big damage.
		return {
			"duration": mallet_duration,
			"damage_mult": mallet_damage_mult,
			"rot_start":  -1.85,
			"rot_end":     2.55,
			"thrust_start": 0.0,
			"thrust_end":   4.0,
			"tint": Color(0.95, 0.78, 0.42),
		}
	return super._stage_config(stage)


func _on_attack_start(stage: int, _chaining: bool, _cfg: Dictionary) -> void:
	if stage != 2 or _mallet == null:
		return
	# Swap the hitbox to mallet dimensions. attack_area.rotation is already
	# aligned with the aim direction by the base class.
	if attack_shape.shape is RectangleShape2D:
		(attack_shape.shape as RectangleShape2D).size = mallet_hitbox_size
	# Reach the hitbox further out — base class set it at 28px for non-stab.
	var aim: Vector2 = Vector2.RIGHT.rotated(attack_area.rotation)
	attack_area.position = aim * mallet_reach

	_mallet.visible = true
	_mallet_pivot.rotation = -1.85
	_mallet_pivot.position = Vector2.ZERO
	_shake_fired_this_swing = false


func _on_attack_end() -> void:
	# Reset the attack shape back to the base size in case some other code
	# path (powerup, etc.) inspects it.
	if attack_shape.shape is RectangleShape2D and _attack_shape_default_size != Vector2.ZERO:
		(attack_shape.shape as RectangleShape2D).size = _attack_shape_default_size
	if _mallet:
		_mallet.visible = false
	if _mallet_buffered:
		_mallet_buffered = false
		_start_attack(2)


func _update_attack_visuals(delta: float) -> void:
	if attack_stage != 2 or _mallet == null:
		return
	var cfg: Dictionary = _stage_config(attack_stage)
	var dur: float = float(cfg["duration"])
	var swing_t: float = 1.0 - clampf(attack_timer / maxf(dur, 0.001), 0.0, 1.0)
	var r_start: float = float(cfg["rot_start"])
	var r_end:   float = float(cfg["rot_end"])

	# Windup (first ~30%) eases into the rear pose, the strike (rest) eases
	# out fast — gives the smash a heavy "wind back, then crash" feel.
	const WINDUP: float = 0.30
	var rot_now: float
	if swing_t < WINDUP:
		var u: float = swing_t / WINDUP
		var ue: float = u * u * (3.0 - 2.0 * u)
		rot_now = lerpf(0.0, r_start, ue)
	else:
		var u2: float = clampf((swing_t - WINDUP) / (1.0 - WINDUP), 0.0, 1.0)
		var ue2: float = 1.0 - pow(1.0 - u2, 3.5)
		rot_now = lerpf(r_start, r_end, ue2)

	_mallet_pivot.rotation = rot_now

	var face_dir: float = 1.0 if facing_right else -1.0
	_mallet.position = Vector2(3.0 * face_dir, -3.0)
	_mallet.scale.x = face_dir

	# Lean into the smash.
	var lean_t: float = clampf((swing_t - 0.32) / 0.40, 0.0, 1.0)
	var lean_decay: float = clampf((swing_t - 0.82) / 0.18, 0.0, 1.0)
	var lean_now: float = 0.28 * lean_t * (1.0 - lean_decay * 0.6) * face_dir
	sprite.rotation = lerpf(sprite.rotation, lean_now, minf(delta * 24.0, 1.0))

	# Fire camera shake once, at the moment the mallet head crosses vertical
	# on the way down (peak impact).
	if not _shake_fired_this_swing and swing_t > 0.55:
		_apply_shake(mallet_shake)
		_shake_fired_this_swing = true


# ----------------------------------------------------------------------------
#  Acorn gun + acorn shotgun
# ----------------------------------------------------------------------------
func _fire_rifle(muzzle: Vector2, dir: Vector2) -> void:
	_spawn_acorn(muzzle, dir, acorn_speed, acorn_range,
		bullet_damage * acorn_damage_mult, acorn_visual_scale)
	# Tiny recoil so the acorn gun has some weight.
	velocity.x -= dir.x * 30.0


func _fire_shotgun(muzzle: Vector2, dir: Vector2) -> void:
	# Cone spread of small acorns. Center-shot has zero offset; outer pellets
	# fan symmetrically out to ±acorn_shotgun_spread.
	var pellet_dmg: int = bullet_damage * shotgun_damage_mult
	var count: int = maxi(acorn_shotgun_pellet_count, 1)
	var base_angle: float = dir.angle()
	for i in count:
		var t: float = 0.0 if count == 1 else (float(i) / float(count - 1)) * 2.0 - 1.0
		var jitter: float = randf_range(-0.04, 0.04)
		var angle: float = base_angle + t * acorn_shotgun_spread + jitter
		var pellet_dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var spawn: Vector2 = muzzle + pellet_dir * 6.0
		_spawn_acorn(spawn, pellet_dir,
			acorn_shotgun_pellet_speed, acorn_shotgun_pellet_range,
			pellet_dmg, acorn_shotgun_pellet_scale)
	# Shotgun kick — more recoil than the single-shot acorn gun.
	velocity.x -= dir.x * 70.0
	_apply_shake(2.8)


func _spawn_acorn(pos: Vector2, dir: Vector2, speed: float, range: float, dmg: int, vis_scale: float) -> void:
	var acorn := PLAYER_BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(acorn)
	acorn.global_position = pos
	acorn.max_range = range
	acorn.setup(dir, speed, dmg)
	# Re-skin the PlayerBullet visual into something acorn-shaped: a darker
	# brown cap stacked on a lighter brown body. The base bullet sprite is a
	# 9x3 ColorRect — we hide it and add the acorn polygons in its place.
	var base_sprite: Node = acorn.get_node_or_null("Sprite")
	if base_sprite is CanvasItem:
		(base_sprite as CanvasItem).visible = false
	var body := Polygon2D.new()
	body.color = ACORN_COLOR
	body.polygon = PackedVector2Array([
		Vector2(-3.5, -2.2), Vector2(2.5, -2.6),
		Vector2(4.5, 0.0),   Vector2(2.5, 2.6),
		Vector2(-3.5, 2.2),
	])
	body.scale = Vector2(vis_scale, vis_scale)
	acorn.add_child(body)
	var cap := Polygon2D.new()
	cap.color = ACORN_CAP_COLOR
	cap.polygon = PackedVector2Array([
		Vector2(-4.0, -2.6), Vector2(-1.5, -3.4),
		Vector2(-1.0, -1.6), Vector2(-3.8, -0.8),
	])
	cap.scale = Vector2(vis_scale, vis_scale)
	acorn.add_child(cap)


# ----------------------------------------------------------------------------
#  Animation picking — match attack stage to the squirrel SpriteFrames.
# ----------------------------------------------------------------------------
func _update_sprite(delta: float) -> void:
	super._update_sprite(delta)
	if _anim_sprite == null:
		return
	var desired: StringName = _pick_animation()
	if desired != &"" and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(desired) \
			and _anim_sprite.animation != desired:
		_anim_sprite.play(desired)


func _pick_animation() -> StringName:
	if is_attacking:
		# Mallet smash reads as "slash" frames — wide overhead motion.
		return &"slash"
	if is_sliding:
		return &"slide"
	if is_crouching:
		return &"crouch"
	if is_on_floor() and absf(velocity.x) > 140.0:
		return &"run"
	return &""  # let the base "idle"/"walk" logic stand
