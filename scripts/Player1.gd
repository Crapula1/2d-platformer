extends Player
class_name Marine

# Marine avatar controller. Owns the marine-specific visuals (jet flame,
# 2-handed battle axe rig with 2-bone IK arms, swing animation) that used
# to live in Player.gd. Everything else (movement, jump, dash, slide,
# shooting, damage, networking) is inherited from the base Player class.

var _axe: Node2D
var _axe_pivot: Node2D
var _arm_front: Line2D
var _arm_back: Line2D
var _hand_front: ColorRect
var _hand_back: ColorRect
var _attack_swing_origin_rot: float = 0.0
var _attack_swing_origin_thrust: float = 0.0
var _jet_flame: Polygon2D

func get_character_id() -> String:
	return "marine"

func _is_attack_chaining() -> bool:
	return _axe != null and _axe.visible

func _build_character_visuals() -> void:
	_jet_flame = Polygon2D.new()
	_jet_flame.color = Color(1.0, 0.55, 0.12, 0.95)
	_jet_flame.polygon = PackedVector2Array([
		Vector2(-5.0, 8.0), Vector2(5.0, 8.0),
		Vector2(3.0, 18.0), Vector2(0.0, 26.0), Vector2(-3.0, 18.0)
	])
	_jet_flame.z_index = -1
	_jet_flame.visible = false
	add_child(_jet_flame)
	# The axe rig is sized for the marine sprite (AnimatedSprite2D). Skip
	# it if the marine scene ever ships without one — defensive only.
	if _anim_sprite != null:
		_build_axe()

func _update_jetpack_visual(active: bool) -> void:
	if _jet_flame == null:
		return
	_jet_flame.visible = active
	if active:
		_jet_flame.scale = Vector2(1.0, 0.85 + 0.3 * sin(Time.get_ticks_msec() * 0.04))

func _on_attack_start(_stage: int, chaining: bool, cfg: Dictionary) -> void:
	if _axe == null:
		return
	if chaining:
		_attack_swing_origin_rot = _axe_pivot.rotation
		_attack_swing_origin_thrust = _axe_pivot.position.x
	else:
		_attack_swing_origin_rot = float(cfg["rot_start"])
		_attack_swing_origin_thrust = float(cfg["thrust_start"])
		_axe_pivot.rotation = _attack_swing_origin_rot
		_axe_pivot.position = Vector2(_attack_swing_origin_thrust, 0.0)
	_axe.visible = true
	_arm_front.visible = true
	_arm_back.visible = true
	_hand_front.visible = true
	_hand_back.visible = true

func _on_attack_end() -> void:
	if _axe == null:
		return
	_axe.visible = false
	_arm_front.visible = false
	_arm_back.visible = false
	_hand_front.visible = false
	_hand_back.visible = false

func _update_attack_visuals(delta: float) -> void:
	if _axe == null:
		return
	var cfg: Dictionary = _stage_config(attack_stage)
	var dur: float = float(cfg["duration"])
	var swing_t: float = 1.0 - clampf(attack_timer / maxf(dur, 0.001), 0.0, 1.0)
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
	if swing_t < WINDUP and attack_stage != 3:
		var u: float = swing_t / WINDUP
		var ue: float = u * u * (3.0 - 2.0 * u)
		rot_now = lerpf(_attack_swing_origin_rot, r_start, ue)
		thrust_now = lerpf(_attack_swing_origin_thrust, th_start, ue)
	else:
		var u2: float = clampf((swing_t - WINDUP) / (1.0 - WINDUP), 0.0, 1.0) if attack_stage != 3 else swing_t
		var ue2: float = 1.0 - pow(1.0 - u2, 3.0)
		rot_now = lerpf(r_start, r_end, ue2)
		thrust_now = lerpf(th_start, th_end, ue2)

	_axe_pivot.rotation = rot_now
	_axe_pivot.position = Vector2(thrust_now, 0.0)

	var face_dir: float = 1.0 if facing_right else -1.0
	_axe.position = Vector2(2.0 * face_dir, -2.0)
	_axe.scale.x = face_dir

	# Arms — 2-bone IK from shoulder to hand at the axe grip.
	var front_shoulder: Vector2 = Vector2(3.0 * face_dir, -4.0)
	var back_shoulder:  Vector2 = Vector2(-3.0 * face_dir, -4.0)
	var front_grip_local := Vector2(0.0, 0.5)
	var back_grip_local  := Vector2(0.0, -14.0)
	var front_grip: Vector2 = to_local(_axe_pivot.to_global(front_grip_local))
	var back_grip:  Vector2 = to_local(_axe_pivot.to_global(back_grip_local))

	var front_elbow: Vector2 = _solve_ik(front_shoulder, front_grip, 7.0, 8.0, 1.0)
	var back_elbow:  Vector2 = _solve_ik(back_shoulder, back_grip, 6.5, 7.5, 1.0)

	_arm_front.points = PackedVector2Array([front_shoulder, front_elbow, front_grip])
	_arm_back.points  = PackedVector2Array([back_shoulder, back_elbow, back_grip])
	_hand_front.position = front_grip - Vector2(2.0, 2.0)
	_hand_back.position  = back_grip - Vector2(2.0, 2.0)

	# Lean into the swing during the strike phase.
	var lean_amount: float = 0.0
	if attack_stage == 1:
		lean_amount = 0.18
	elif attack_stage == 2:
		lean_amount = 0.25
	elif attack_stage == 3:
		lean_amount = 0.05
	var lean_t: float = clampf((swing_t - 0.30) / 0.50, 0.0, 1.0)
	var lean_decay: float = clampf((swing_t - 0.80) / 0.20, 0.0, 1.0)
	var lean_now: float = lean_amount * lean_t * (1.0 - lean_decay * 0.6) * face_dir
	sprite.rotation = lerpf(sprite.rotation, lean_now, minf(delta * 26.0, 1.0))

	# Stab step-forward
	var step_offset: float = 0.0
	if attack_stage == 3:
		var step_t: float = clampf((swing_t - 0.15) / 0.45, 0.0, 1.0)
		var step_back: float = clampf((swing_t - 0.70) / 0.30, 0.0, 1.0)
		step_offset = 3.0 * step_t * (1.0 - step_back)
	sprite.position.x = lerpf(sprite.position.x, step_offset * face_dir, minf(delta * 26.0, 1.0))

func _solve_ik(shoulder: Vector2, hand: Vector2, upper: float, fore: float, bend_sign: float) -> Vector2:
	# Classic 2-bone IK: place an elbow so |shoulder→elbow|=upper and
	# |elbow→hand|=fore. bend_sign picks which of the two solutions to use.
	var to_hand: Vector2 = hand - shoulder
	var d: float = to_hand.length()
	if d <= 0.0001:
		return shoulder + Vector2(0.0, upper)
	if d >= upper + fore:
		return shoulder + to_hand.normalized() * upper
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
	_axe = Node2D.new()
	_axe.z_index = 2
	_axe.visible = false
	add_child(_axe)

	_axe_pivot = Node2D.new()
	_axe.add_child(_axe_pivot)

	var shaft := Polygon2D.new()
	shaft.color = Color(0.34, 0.22, 0.12)
	shaft.polygon = PackedVector2Array([
		Vector2(-1.4,   0.0), Vector2(1.4,  0.0),
		Vector2(1.4, -26.0), Vector2(-1.4, -26.0),
	])
	_axe_pivot.add_child(shaft)

	var grip := Polygon2D.new()
	grip.color = Color(0.10, 0.08, 0.06)
	grip.polygon = PackedVector2Array([
		Vector2(-2.0, -2.0), Vector2(2.0, -2.0),
		Vector2(2.0,  3.0), Vector2(-2.0, 3.0),
	])
	_axe_pivot.add_child(grip)

	var grip2 := Polygon2D.new()
	grip2.color = Color(0.10, 0.08, 0.06)
	grip2.polygon = PackedVector2Array([
		Vector2(-2.0, -16.0), Vector2(2.0, -16.0),
		Vector2(2.0, -12.0), Vector2(-2.0, -12.0),
	])
	_axe_pivot.add_child(grip2)

	var pommel := Polygon2D.new()
	pommel.color = Color(0.55, 0.55, 0.60)
	pommel.polygon = PackedVector2Array([
		Vector2(-2.4, 3.0), Vector2(2.4, 3.0),
		Vector2(2.0, 6.0), Vector2(-2.0, 6.0),
	])
	_axe_pivot.add_child(pommel)

	var head := Polygon2D.new()
	head.color = Color(0.72, 0.74, 0.80)
	head.polygon = PackedVector2Array([
		Vector2(-6.0, -22.0), Vector2(0.0, -29.0),
		Vector2(13.0, -30.0), Vector2(16.0, -25.0),
		Vector2(13.0, -19.0), Vector2(0.0, -20.0),
		Vector2(-6.0, -23.0),
	])
	_axe_pivot.add_child(head)

	var edge := Polygon2D.new()
	edge.color = Color(0.92, 0.95, 1.0)
	edge.polygon = PackedVector2Array([
		Vector2(11.0, -30.0), Vector2(16.0, -25.0), Vector2(13.0, -19.0),
	])
	_axe_pivot.add_child(edge)

	var spike := Polygon2D.new()
	spike.color = Color(0.55, 0.55, 0.60)
	spike.polygon = PackedVector2Array([
		Vector2(-6.0, -23.0), Vector2(-6.0, -22.0),
		Vector2(-10.0, -25.0),
	])
	_axe_pivot.add_child(spike)

	var trim := Polygon2D.new()
	trim.color = Color(0.42, 0.32, 0.18)
	trim.polygon = PackedVector2Array([
		Vector2(-2.5, -22.0), Vector2(2.5, -22.0),
		Vector2(2.5, -18.0), Vector2(-2.5, -18.0),
	])
	_axe_pivot.add_child(trim)

	# Arms — 2-bone IK (shoulder → elbow → hand).
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
