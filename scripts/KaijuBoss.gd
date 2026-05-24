extends CharacterBody2D
class_name KaijuBoss

# Procedurally-generated kaiju mini-boss locked to a castle arena. Behaviour
# is a Mega-Man-style state machine: paces back and forth, telegraphs with a
# roar, then either lobs a single slow flame or unloads a varied volley.
#
# The "insane" flavor comes from per-spawn proc-gen knobs (palette, spike
# count, volley size, aggressiveness, height jitter, pace distance) so two
# bosses placed in the same level read as different individuals.

enum State { IDLE, PACE, ROAR, FIRE, BURST, LEAP, SLAM_WINDUP, SLAM_CHARGE, STAGGER, DEAD }

@export var max_health: int = 400
@export var contact_damage: int = 3
@export var slam_damage: int = 5
@export var arena_left: float = 0.0
@export var arena_right: float = 0.0
@export var arena_floor: float = 400.0
@export var pace_speed: float = 170.0
@export var leap_vy: float = -440.0   # initial upward velocity for leaps
@export var leap_vx: float = 240.0    # horizontal leap thrust
@export var slam_speed: float = 380.0 # horizontal speed during body slam
@export var slam_windup_time: float = 0.45
@export var slam_max_time: float = 0.70
@export var proc_seed: int = 0     # 0 = randomize at _ready
# Health fraction at which the boss permanently enrages. Enrage compresses
# cooldowns, raises pace + slam speed, and ups volley counts so the back
# half of the fight escalates pressure instead of plateauing.
@export var enrage_threshold: float = 0.5
# Minimum distance the boss will keep from `arena_left` — protects the doorway
# the player uses to enter the arena. Pacing, position clamp, and target
# selection all respect this so the boss can't sit on the entrance.
@export var entrance_buffer: float = 220.0

const FLAME_SCRIPT := preload("res://scripts/KaijuFlame.gd")
const EXPLOSIVE_EFFECT_SCENE := preload("res://scenes/ExplosiveEffect.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var rng := RandomNumberGenerator.new()

# --- Proc-gen attributes (set in _gen_attrs) ---------------------------------
var scale_base: Color
var scale_dark: Color
var belly_color: Color
var spike_color: Color
var horn_color: Color
var eye_color: Color
var spike_count: int
var horn_count: int
var size_mult: float
var aggressiveness: float
var volley_size_max: int
var height_jitter: float
var pace_dist: float
var burst_period: float
var idle_time_min: float
var idle_time_max: float
var has_back_fin: bool

# --- AI state ----------------------------------------------------------------
var state: State = State.PACE
var state_timer: float = 0.0
var current_health: int = 0
var is_dead: bool = false
var direction: int = -1
var pace_target_x: float = 0.0
var player: Node = null
var volley_remaining: int = 0
var volley_delay: float = 0.0
var pending_fire_delay: float = 0.0
# Counts down while pacing; when it hits zero the boss commits to an attack
# (or occasionally a leap). Drives the "always moving, attacks on a beat"
# Mega Man cadence.
var attack_cd: float = 0.0
# Counts down while pacing too; when it hits zero the boss may leap to break
# up its horizontal pattern. Independent from attack_cd so leaps and attacks
# can interleave instead of competing for the same beat.
var leap_cd: float = 0.0
# Body slam cooldown — long enough that slams feel like committed reads, not
# a constant threat. Enrage compresses it.
var slam_cd: float = 0.0
var slam_dir: int = -1
var _slam_hit_this_charge: bool = false
# Enrage state — flips once when HP crosses the threshold and never resets.
var is_enraged: bool = false
var _slam_hitbox: Area2D
var _slam_hitbox_shape: CollisionShape2D
var _enrage_aura: ColorRect

# --- Adaptive brain ---------------------------------------------------------
# The boss samples the fight every brain_period seconds and asks five
# questions: is the player aggressive, healing, staying at range, repeating
# one tactic, am I losing badly? Each question becomes a boolean signal that
# steers attack selection, cooldown compression, and pace targeting. The
# signals are deliberately coarse — they're meant to bias behavior, not
# script it — so the kaiju still feels like a kaiju, just one that reads you.
var brain_period: float = 0.25
var _brain_t: float = 0.0
# Sampled player state from previous tick — used to detect deltas like heal
# events and inbound aggression.
var _player_prev_hp: int = -1
var _player_prev_pos: Vector2 = Vector2.ZERO
# Rolling counters (decayed each brain tick, not hard windows).
var _aggro_score: float = 0.0      # damage taken recently + player closing in
var _heal_score: float = 0.0       # spikes when player heals, decays out
var _range_score: float = 0.0      # accumulates while player stays far
var _close_score: float = 0.0      # accumulates while player stays near
# Recent player "tactic" tokens — distance band + grounded/airborne.
# Repetition in this list = the player has settled into one pattern.
var _player_tactic_log: Array[String] = []
# Recent boss attack kinds — used to avoid repeating ourselves when the
# repeating-tactic signal also says we should switch it up.
var _last_attack_kind: String = ""
# Final read-out signals — recomputed each brain tick and consumed by
# _begin_attack / _pick_pace_target / _run_state.
var sig_aggressive: bool = false
var sig_healing: bool = false
var sig_at_range: bool = false
var sig_repeating: bool = false
var sig_losing_badly: bool = false

# --- Animation phases --------------------------------------------------------
var bob_phase: float = 0.0
var tail_phase: float = 0.0
var eye_phase: float = 0.0
var _hurt_flash: float = 0.0
var _walk_anim: float = 0.0

# --- Built nodes -------------------------------------------------------------
var _visual_root: Node2D
var _body_root: Node2D
var _tail_root: Node2D
var _tail_segments: Array[Polygon2D] = []
var _head_root: Node2D
var _mouth_glow: ColorRect
var _eye_glow: ColorRect
var _arm_back: Node2D
var _arm_fore: Node2D
var _legs_root: Node2D
var _left_leg: Polygon2D
var _right_leg: Polygon2D
var _spikes: Array[Polygon2D] = []
var _scales: Array[Polygon2D] = []
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect

# --- Wings (skeletal, visible during LEAP) ---------------------------------
var _wing_left: Node2D
var _wing_right: Node2D
var _wing_phase: float = 0.0
var _wings_alpha: float = 0.0
# Death animation timer — drives the rear-up → collapse → fade sequence.
var _death_time: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	if proc_seed == 0:
		rng.randomize()
	else:
		rng.seed = proc_seed
	_gen_attrs()
	current_health = max_health
	_build_collision()
	_build_slam_hitbox()
	_build_visual()
	_build_enrage_aura()
	_build_hp_bar()
	if arena_right <= arena_left:
		arena_left  = global_position.x - 400.0
		arena_right = global_position.x + 400.0
	pace_target_x = clampf(global_position.x + rng.randf_range(-pace_dist, pace_dist),
		_combat_min_x(), arena_right - 60.0)
	state_timer = 0.0
	attack_cd = rng.randf_range(0.6, 1.2)
	leap_cd = rng.randf_range(1.8, 3.2)
	slam_cd = rng.randf_range(3.0, 5.0)

func _gen_attrs() -> void:
	# Pick a palette family — each is a coherent monster "species" tint.
	var fam := rng.randi() % 5
	match fam:
		0:  # toxic green
			scale_base = Color(0.18, 0.42, 0.20)
			scale_dark = Color(0.08, 0.22, 0.10)
			belly_color = Color(0.85, 0.78, 0.30)
			spike_color = Color(0.92, 0.95, 0.50)
		1:  # oxblood
			scale_base = Color(0.40, 0.10, 0.10)
			scale_dark = Color(0.18, 0.04, 0.04)
			belly_color = Color(0.85, 0.65, 0.40)
			spike_color = Color(0.95, 0.85, 0.55)
		2:  # cobalt
			scale_base = Color(0.18, 0.24, 0.55)
			scale_dark = Color(0.08, 0.10, 0.28)
			belly_color = Color(0.78, 0.82, 0.92)
			spike_color = Color(0.70, 0.90, 1.00)
		3:  # ash purple
			scale_base = Color(0.32, 0.18, 0.42)
			scale_dark = Color(0.14, 0.06, 0.20)
			belly_color = Color(0.78, 0.66, 0.85)
			spike_color = Color(0.95, 0.55, 0.95)
		_:  # bone/lava
			scale_base = Color(0.30, 0.16, 0.10)
			scale_dark = Color(0.14, 0.07, 0.04)
			belly_color = Color(0.95, 0.62, 0.20)
			spike_color = Color(1.00, 0.45, 0.10)

	horn_color = scale_dark.lightened(0.55)
	eye_color  = Color(
		clampf(spike_color.r * 1.10, 0.0, 1.0),
		clampf(spike_color.g * 1.10, 0.0, 1.0),
		clampf(spike_color.b * 1.10, 0.0, 1.0))

	spike_count  = rng.randi_range(4, 8)
	horn_count   = rng.randi_range(2, 5)
	size_mult    = rng.randf_range(0.95, 1.20)
	has_back_fin = rng.randf() < 0.5

	aggressiveness   = rng.randf_range(0.65, 0.92)
	volley_size_max  = rng.randi_range(3, 5)
	# Tighter vertical spread — flames now land in a compact, threatening
	# band the player has to commit to a single well-timed jump to clear.
	height_jitter    = rng.randf_range(0.0, 12.0)
	pace_dist        = rng.randf_range(200.0, 380.0)
	# Tighter burst cadence so a 3-flame volley arrives as a wall, not a
	# spread-out stream.
	burst_period     = rng.randf_range(0.13, 0.20)
	# Almost no idle — the kaiju is in motion essentially all the time.
	idle_time_min    = rng.randf_range(0.05, 0.12)
	idle_time_max    = idle_time_min + rng.randf_range(0.08, 0.18)

# -----------------------------------------------------------------------------
# Collision + hurtbox
# -----------------------------------------------------------------------------
func _build_collision() -> void:
	# Layer 3 (value 4) = enemy body; PlayerBullet masks this.
	collision_layer = 4
	collision_mask  = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = 70.0 * size_mult
	var h: float = 110.0 * size_mult
	rect.size = Vector2(w, h)
	shape.shape = rect
	# Center the rect so the bottom sits at y=0 (we'll place the boss with its
	# feet at arena_floor in Level2.gd).
	shape.position = Vector2(0.0, -h * 0.5)
	add_child(shape)

# Slam hitbox sits flush with the boss body and is only enabled during
# SLAM_CHARGE — outside of that the boss is non-damaging on contact, so the
# player can safely circle past at all other times.
func _build_slam_hitbox() -> void:
	_slam_hitbox = Area2D.new()
	_slam_hitbox.name = "SlamHitbox"
	_slam_hitbox.collision_layer = 0
	_slam_hitbox.collision_mask = 2  # player body
	_slam_hitbox.monitoring = true
	add_child(_slam_hitbox)

	_slam_hitbox_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var w: float = 90.0 * size_mult
	var h: float = 110.0 * size_mult
	rect.size = Vector2(w, h)
	_slam_hitbox_shape.shape = rect
	_slam_hitbox_shape.position = Vector2(0.0, -h * 0.5)
	_slam_hitbox.add_child(_slam_hitbox_shape)
	_slam_hitbox_shape.set_deferred("disabled", true)

	_slam_hitbox.body_entered.connect(_on_slam_body_entered)

# -----------------------------------------------------------------------------
# Procedural visual assembly — built once at _ready, animated each frame.
# -----------------------------------------------------------------------------
func _build_visual() -> void:
	_visual_root = Node2D.new()
	add_child(_visual_root)

	_tail_root = Node2D.new()
	_visual_root.add_child(_tail_root)
	_build_tail()

	# Wings sit behind the body so they read as coming out of the back.
	# Built before the body so tree order draws them under the torso.
	_build_wings()

	_legs_root = Node2D.new()
	_visual_root.add_child(_legs_root)
	_build_legs()

	_body_root = Node2D.new()
	_visual_root.add_child(_body_root)
	_build_body()

	_arm_back = _build_arm(true)
	_visual_root.add_child(_arm_back)
	_arm_back.position = Vector2(-14.0 * size_mult, -70.0 * size_mult)

	_head_root = Node2D.new()
	_visual_root.add_child(_head_root)
	_head_root.position = Vector2(-32.0 * size_mult, -110.0 * size_mult)
	_build_head()

	_arm_fore = _build_arm(false)
	_visual_root.add_child(_arm_fore)
	_arm_fore.position = Vector2(-6.0 * size_mult, -68.0 * size_mult)

# Body silhouette: hunched bipedal kaiju torso with belly plates and spikes.
func _build_body() -> void:
	var s: float = size_mult
	var hull := Polygon2D.new()
	hull.color = scale_base
	hull.polygon = PackedVector2Array([
		Vector2(-26.0 * s, -110.0 * s),
		Vector2( 14.0 * s, -106.0 * s),
		Vector2( 32.0 * s,  -70.0 * s),
		Vector2( 36.0 * s,  -30.0 * s),
		Vector2( 28.0 * s,    0.0),
		Vector2(-22.0 * s,    0.0),
		Vector2(-32.0 * s,  -40.0 * s),
		Vector2(-30.0 * s,  -80.0 * s),
	])
	_body_root.add_child(hull)

	# Belly plates
	for i in 4:
		var plate := Polygon2D.new()
		plate.color = belly_color
		var top: float = -90.0 + float(i) * 22.0
		var bot: float = top + 18.0
		plate.polygon = PackedVector2Array([
			Vector2(-8.0 * s, top * s),
			Vector2(14.0 * s, top * s),
			Vector2(18.0 * s, bot * s),
			Vector2(-10.0 * s, bot * s),
		])
		_body_root.add_child(plate)

	# Back spikes — count and size vary per spawn
	for i in spike_count:
		var t: float = float(i + 1) / float(spike_count + 1)
		# Back spine runs from (-26,-110) → (-22,-10).
		var bx: float = lerpf(-26.0, -28.0, t) * s
		var by: float = lerpf(-108.0, -20.0, t) * s
		var size: float = (12.0 + 8.0 * sin(t * PI)) * s
		var spike := Polygon2D.new()
		spike.color = spike_color
		spike.polygon = PackedVector2Array([
			Vector2(bx, by),
			Vector2(bx - size * 0.45, by - size * 0.8),
			Vector2(bx - size * 1.10, by - size * 0.2),
		])
		_body_root.add_child(spike)
		_spikes.append(spike)

	# Optional sail/fin running down the spine
	if has_back_fin:
		var fin := Polygon2D.new()
		fin.color = scale_dark
		fin.polygon = PackedVector2Array([
			Vector2(-28.0 * s, -108.0 * s),
			Vector2(-46.0 * s,  -80.0 * s),
			Vector2(-48.0 * s,  -50.0 * s),
			Vector2(-38.0 * s,  -30.0 * s),
			Vector2(-26.0 * s,  -22.0 * s),
		])
		_body_root.add_child(fin)

	# Scale highlights scattered on the back
	for i in 6:
		var sc := Polygon2D.new()
		sc.color = scale_dark
		var cx: float = rng.randf_range(-22.0, 10.0) * s
		var cy: float = rng.randf_range(-100.0, -20.0) * s
		var r: float = rng.randf_range(2.5, 4.5) * s
		sc.polygon = PackedVector2Array([
			Vector2(cx, cy - r),
			Vector2(cx + r, cy),
			Vector2(cx, cy + r),
			Vector2(cx - r, cy),
		])
		_body_root.add_child(sc)
		_scales.append(sc)

func _build_legs() -> void:
	var s: float = size_mult
	# Two stocky legs anchoring the body to the ground.
	for side in [-1, 1]:
		var leg := Polygon2D.new()
		leg.color = scale_dark
		var cx: float = float(side) * 12.0 * s
		leg.polygon = PackedVector2Array([
			Vector2(cx - 14.0 * s, -22.0 * s),
			Vector2(cx + 14.0 * s, -22.0 * s),
			Vector2(cx + 18.0 * s,   0.0),
			Vector2(cx - 16.0 * s,   0.0),
		])
		_legs_root.add_child(leg)
		if side == -1:
			_left_leg = leg
		else:
			_right_leg = leg

		# Claws
		for c in 3:
			var claw := Polygon2D.new()
			claw.color = horn_color
			var t: float = -1.0 + float(c)
			var fx: float = cx + t * 9.0 * s
			claw.polygon = PackedVector2Array([
				Vector2(fx - 2.0 * s,  -3.0 * s),
				Vector2(fx + 2.0 * s,  -3.0 * s),
				Vector2(fx,             4.0 * s),
			])
			_legs_root.add_child(claw)

func _build_arm(back: bool) -> Node2D:
	var s: float = size_mult
	var n := Node2D.new()
	var shoulder := Polygon2D.new()
	shoulder.color = scale_dark if back else scale_base
	shoulder.polygon = PackedVector2Array([
		Vector2( 0.0, -8.0 * s),
		Vector2(18.0 * s, -2.0 * s),
		Vector2(22.0 * s, 18.0 * s),
		Vector2(12.0 * s, 32.0 * s),
		Vector2(-4.0 * s, 22.0 * s),
		Vector2(-6.0 * s,  4.0 * s),
	])
	n.add_child(shoulder)
	# Clawed hand
	var hand := Polygon2D.new()
	hand.color = scale_dark if back else scale_base
	hand.polygon = PackedVector2Array([
		Vector2(  8.0 * s, 28.0 * s),
		Vector2( 22.0 * s, 36.0 * s),
		Vector2( 18.0 * s, 50.0 * s),
		Vector2(  4.0 * s, 44.0 * s),
	])
	n.add_child(hand)
	for c in 3:
		var claw := Polygon2D.new()
		claw.color = horn_color
		var fx: float = 8.0 + float(c) * 6.0
		claw.polygon = PackedVector2Array([
			Vector2(fx * s, 44.0 * s),
			Vector2((fx + 3.0) * s, 44.0 * s),
			Vector2((fx + 1.5) * s, 58.0 * s),
		])
		n.add_child(claw)
	return n

func _build_head() -> void:
	var s: float = size_mult
	# Skull silhouette — wide jaw, brow ridge.
	var skull := Polygon2D.new()
	skull.color = scale_base
	skull.polygon = PackedVector2Array([
		Vector2(-8.0 * s, -26.0 * s),
		Vector2(28.0 * s, -22.0 * s),
		Vector2(34.0 * s,  -6.0 * s),
		Vector2(30.0 * s,  12.0 * s),
		Vector2(  4.0 * s, 16.0 * s),
		Vector2(-10.0 * s,  6.0 * s),
		Vector2(-14.0 * s, -10.0 * s),
	])
	_head_root.add_child(skull)

	# Lower jaw — separate so the mouth glow reads as an opening.
	var jaw := Polygon2D.new()
	jaw.color = scale_dark
	jaw.polygon = PackedVector2Array([
		Vector2( 4.0 * s, 8.0 * s),
		Vector2(32.0 * s, 4.0 * s),
		Vector2(28.0 * s, 16.0 * s),
		Vector2( 6.0 * s, 18.0 * s),
	])
	_head_root.add_child(jaw)

	# Teeth row
	for i in 5:
		var tooth := Polygon2D.new()
		tooth.color = Color(0.95, 0.92, 0.82)
		var tx: float = (8.0 + float(i) * 5.0) * s
		tooth.polygon = PackedVector2Array([
			Vector2(tx, 8.0 * s),
			Vector2(tx + 3.0 * s, 8.0 * s),
			Vector2(tx + 1.5 * s, 14.0 * s),
		])
		_head_root.add_child(tooth)

	# Horns — count varies per spawn, evenly distributed along the brow.
	for i in horn_count:
		var t: float = float(i) / float(maxi(horn_count - 1, 1))
		var hx: float = lerpf(-6.0, 22.0, t) * s
		var hy: float = -22.0 * s + abs(t - 0.5) * 6.0 * s
		var horn := Polygon2D.new()
		horn.color = horn_color
		var hh: float = (14.0 + (1.0 - abs(t - 0.5) * 2.0) * 8.0) * s
		horn.polygon = PackedVector2Array([
			Vector2(hx - 3.0 * s, hy),
			Vector2(hx + 3.0 * s, hy),
			Vector2(hx + 1.0 * s, hy - hh),
		])
		_head_root.add_child(horn)

	# Eye socket
	var socket := ColorRect.new()
	socket.color = Color(0.04, 0.02, 0.02)
	socket.offset_left = 6.0 * s
	socket.offset_top  = -14.0 * s
	socket.offset_right = 18.0 * s
	socket.offset_bottom = -4.0 * s
	_head_root.add_child(socket)

	_eye_glow = ColorRect.new()
	_eye_glow.color = eye_color
	_eye_glow.offset_left = 9.0 * s
	_eye_glow.offset_top  = -12.0 * s
	_eye_glow.offset_right = 15.0 * s
	_eye_glow.offset_bottom = -6.0 * s
	_eye_glow.z_index = 1
	_head_root.add_child(_eye_glow)

	# Mouth glow — hidden by default; flares while charging/firing.
	_mouth_glow = ColorRect.new()
	_mouth_glow.color = Color(1.0, 0.55, 0.15, 0.0)
	_mouth_glow.offset_left = 12.0 * s
	_mouth_glow.offset_top  =  6.0 * s
	_mouth_glow.offset_right = 32.0 * s
	_mouth_glow.offset_bottom = 18.0 * s
	_mouth_glow.z_index = 2
	_head_root.add_child(_mouth_glow)

func _build_tail() -> void:
	var s: float = size_mult
	# Tail anchored behind the body (right side of sprite when facing left).
	var segs := 6
	for i in segs:
		var seg := Polygon2D.new()
		seg.color = scale_base.lerp(scale_dark, float(i) / float(segs))
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var len_base: float = 60.0
		var x0: float = 24.0 + lerpf(0.0, len_base, t0)
		var x1: float = 24.0 + lerpf(0.0, len_base, t1)
		var w0: float = lerpf(18.0, 4.0, t0)
		var w1: float = lerpf(18.0, 4.0, t1)
		var y0: float = lerpf(-30.0, -10.0, t0)
		var y1: float = lerpf(-30.0, -10.0, t1)
		seg.polygon = PackedVector2Array([
			Vector2(x0 * s, (y0 - w0) * s),
			Vector2(x1 * s, (y1 - w1) * s),
			Vector2(x1 * s, (y1 + w1) * s),
			Vector2(x0 * s, (y0 + w0) * s),
		])
		_tail_root.add_child(seg)
		_tail_segments.append(seg)

	# Tail-tip spike
	var tip := Polygon2D.new()
	tip.color = spike_color
	tip.polygon = PackedVector2Array([
		Vector2((24.0 + 60.0) * s, -10.0 * s),
		Vector2((24.0 + 80.0) * s, -18.0 * s),
		Vector2((24.0 + 60.0) * s,   0.0),
	])
	_tail_root.add_child(tip)
	_tail_segments.append(tip)

func _build_wings() -> void:
	# Two skeletal wings anchored just below the boss's shoulders. Each wing
	# is a Node2D pivot at the shoulder so it can rotate as one unit for the
	# flap; bones and membrane are children in local space.
	var s: float = size_mult
	# Wings only show during LEAP. Build hidden.
	_wing_left  = _build_single_wing(s, true)   # mirror=true → extends to screen-left
	_wing_left.position = Vector2(-24.0 * s, -96.0 * s)
	_wing_left.z_index = -1
	_wing_left.modulate.a = 0.0
	_visual_root.add_child(_wing_left)

	_wing_right = _build_single_wing(s, false)
	_wing_right.position = Vector2(10.0 * s, -96.0 * s)
	_wing_right.z_index = -1
	_wing_right.modulate.a = 0.0
	_visual_root.add_child(_wing_right)

func _build_single_wing(s: float, mirror: bool) -> Node2D:
	# Skeletal bat/gargoyle wing: a humerus from the shoulder out to an
	# elbow joint, then four "finger" bones radiating outward, with a
	# translucent leathery membrane stretched between them.
	var root := Node2D.new()
	var d: float = -1.0 if mirror else 1.0

	# Key joint positions in the wing's local space (relative to the
	# shoulder pivot at (0,0)).
	var elbow: Vector2 = Vector2(d * 40.0 * s, -28.0 * s)
	# Finger tips fan out from the elbow — upper tip is the longest (gargoyle
	# silhouette has a tall top spar), lower tips taper inward and down.
	var tip0: Vector2 = Vector2(d * 32.0 * s, -78.0 * s)   # top spar
	var tip1: Vector2 = Vector2(d * 72.0 * s, -52.0 * s)
	var tip2: Vector2 = Vector2(d * 84.0 * s, -10.0 * s)
	var tip3: Vector2 = Vector2(d * 74.0 * s,  28.0 * s)
	var tip4: Vector2 = Vector2(d * 50.0 * s,  46.0 * s)   # trailing edge anchor

	# --- Membrane (drawn first so bones overlay) -------------------------
	# Two membrane panels split at the elbow so the bend reads cleanly. The
	# upper panel connects shoulder → top spar → elbow; the lower panel
	# fans across the four lower finger tips.
	var membrane_col := Color(0.06, 0.04, 0.06, 0.78)
	var upper_panel := Polygon2D.new()
	upper_panel.color = membrane_col
	upper_panel.polygon = PackedVector2Array([
		Vector2.ZERO, tip0, elbow
	])
	root.add_child(upper_panel)

	var lower_panel := Polygon2D.new()
	lower_panel.color = membrane_col
	lower_panel.polygon = PackedVector2Array([
		elbow, tip0, tip1, tip2, tip3, tip4, Vector2.ZERO
	])
	root.add_child(lower_panel)

	# Subtle membrane veining — a thin darker line along each finger
	# baseline gives the leather a worn, sinewy look.
	for tip in [tip1, tip2, tip3, tip4]:
		var vein := Polygon2D.new()
		vein.color = Color(0.02, 0.0, 0.02, 0.55)
		var mid: Vector2 = elbow.lerp(tip, 0.55)
		var perp: Vector2 = (tip - elbow).normalized().orthogonal() * 0.6 * s
		vein.polygon = PackedVector2Array([
			elbow + perp, mid + perp * 0.4, tip, mid - perp * 0.4, elbow - perp
		])
		root.add_child(vein)

	# --- Bones (pale, drawn over the membrane) ---------------------------
	var bone_col := Color(0.92, 0.88, 0.78)
	var bone_dark := Color(0.55, 0.50, 0.42)

	# Humerus (shoulder → elbow), thickest
	root.add_child(_wing_bone(Vector2.ZERO, elbow, 4.0 * s, bone_col))
	# Top spar (shoulder → top tip), long and slightly tapered
	root.add_child(_wing_bone(Vector2.ZERO, tip0, 3.0 * s, bone_col))
	# Finger bones from elbow
	for tip in [tip1, tip2, tip3, tip4]:
		root.add_child(_wing_bone(elbow, tip, 2.4 * s, bone_col))

	# Joint nubs at shoulder, elbow, and finger tips — diamond shapes for
	# a bony look without needing curves.
	for p in [Vector2.ZERO, elbow, tip0, tip1, tip2, tip3, tip4]:
		var joint := Polygon2D.new()
		joint.color = bone_dark
		var r: float = 3.0 * s
		joint.polygon = PackedVector2Array([
			Vector2(p.x - r, p.y),
			Vector2(p.x, p.y - r),
			Vector2(p.x + r, p.y),
			Vector2(p.x, p.y + r),
		])
		root.add_child(joint)

	return root

func _wing_bone(a: Vector2, b: Vector2, thick: float, col: Color) -> Polygon2D:
	# A bone is a thin rectangle stretched between two joints. Built as a
	# Polygon2D quad so we don't need a Line2D resource.
	var dir: Vector2 = (b - a)
	if dir.length_squared() < 0.0001:
		dir = Vector2(1, 0)
	dir = dir.normalized()
	var perp: Vector2 = dir.orthogonal() * thick * 0.5
	var bone := Polygon2D.new()
	bone.color = col
	bone.polygon = PackedVector2Array([
		a + perp, b + perp, b - perp, a - perp
	])
	return bone

func _build_enrage_aura() -> void:
	# Red pulsing aura behind the body — invisible by default, fades in on
	# enrage. Drawn behind the visual root via z_index.
	_enrage_aura = ColorRect.new()
	_enrage_aura.color = Color(1.0, 0.20, 0.10, 0.0)
	var w: float = 180.0 * size_mult
	var h: float = 220.0 * size_mult
	_enrage_aura.offset_left  = -w * 0.5
	_enrage_aura.offset_top   = -h
	_enrage_aura.offset_right =  w * 0.5
	_enrage_aura.offset_bottom = 0.0
	_enrage_aura.z_index = -5
	add_child(_enrage_aura)

func _build_hp_bar() -> void:
	var w: float = 120.0 * size_mult
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0.05, 0.03, 0.03, 0.85)
	_hp_bar_bg.offset_left = -w * 0.5 - 2.0
	_hp_bar_bg.offset_top  = -150.0 * size_mult
	_hp_bar_bg.offset_right = w * 0.5 + 2.0
	_hp_bar_bg.offset_bottom = -140.0 * size_mult
	_hp_bar_bg.z_index = 10
	add_child(_hp_bar_bg)

	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.color = Color(0.95, 0.20, 0.20)
	_hp_bar_fill.offset_left = -w * 0.5
	_hp_bar_fill.offset_top  = -148.0 * size_mult
	_hp_bar_fill.offset_right = w * 0.5
	_hp_bar_fill.offset_bottom = -142.0 * size_mult
	_hp_bar_fill.z_index = 11
	add_child(_hp_bar_fill)

# -----------------------------------------------------------------------------
# Physics + AI
# -----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		_update_visuals(delta)
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 10.0)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	state_timer += delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta

	_brain_t += delta
	if _brain_t >= brain_period:
		_brain_tick(_brain_t)
		_brain_t = 0.0

	_run_state(delta)

	# Lock to arena. Clamp directly — boss can never leave even if it tries,
	# and entrance_buffer keeps it off the player's doorway.
	move_and_slide()
	global_position.x = clampf(global_position.x, _combat_min_x(), arena_right - 36.0)

	_update_visuals(delta)

func _run_state(delta: float) -> void:
	# Global cooldowns tick down whenever the boss is "free" (moving) — they
	# don't run during a committed attack or stagger.
	if state == State.PACE or state == State.IDLE:
		attack_cd = maxf(attack_cd - delta, 0.0)
		leap_cd = maxf(leap_cd - delta, 0.0)
		slam_cd = maxf(slam_cd - delta, 0.0)

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			_face_player()
			if state_timer >= rng.randf_range(idle_time_min, idle_time_max):
				_pick_next_action()
		State.PACE:
			var to_target: float = pace_target_x - global_position.x
			direction = -1 if to_target < 0.0 else 1
			# Accelerate toward pace speed instead of snapping — feels heavy
			# but stays mobile.
			var desired: float = float(direction) * pace_speed
			velocity.x = move_toward(velocity.x, desired, 900.0 * delta)
			# Reached target, or paced long enough → pick a new behavior right
			# away. No detour through IDLE → kaiju is in motion essentially
			# every frame.
			if absf(to_target) < 12.0 or state_timer > 1.4:
				_pick_next_action()
			# Mid-pace body slam — committed read, only fires when grounded
			# and the player is roughly in front of the boss so the slam has
			# a chance to actually connect.
			elif slam_cd <= 0.0 and is_on_floor() and _slam_makes_sense():
				_begin_slam()
			# Mid-pace attack: when the cooldown elapses, commit to the roar
			# without waiting to finish the pace. Boss attacks on the move.
			elif attack_cd <= 0.0:
				_begin_attack()
			# Mid-pace leap to break up its horizontal silhouette. Repeating-
			# tactic signal shortens the implicit cooldown by letting any
			# half-charged leap fire — the boss deliberately changes axis
			# when the player has locked into one position.
			elif leap_cd <= 0.0 and is_on_floor():
				_begin_leap()
			elif sig_repeating and leap_cd < 0.6 and is_on_floor() \
					and rng.randf() < 0.04:
				_begin_leap()
		State.ROAR:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_face_player()
			# Mouth glows brighter as the roar peaks. Shorter telegraph than
			# before so the high-mobility pattern reads as aggressive.
			var t: float = clampf(state_timer / 0.40, 0.0, 1.0)
			_mouth_glow.modulate.a = t
			if state_timer >= 0.40:
				if volley_remaining > 1:
					_enter_state(State.BURST)
				else:
					_enter_state(State.FIRE)
		State.FIRE:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			_spawn_flame(rng.randf_range(-height_jitter, height_jitter))
			volley_remaining = 0
			# Straight back to pacing — no idle beat.
			_post_attack()
		State.BURST:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
			volley_delay -= delta
			if volley_delay <= 0.0 and volley_remaining > 0:
				var jitter: float = rng.randf_range(-height_jitter, height_jitter)
				_spawn_flame(jitter)
				volley_remaining -= 1
				volley_delay = burst_period
			if volley_remaining <= 0:
				_post_attack()
		State.LEAP:
			# In the air: keep horizontal thrust, let gravity work.
			var leap_dir: float = signf(velocity.x)
			if leap_dir == 0.0:
				leap_dir = float(direction)
			velocity.x = leap_dir * leap_vx
			# Resolve when we land OR if we're hung against a wall.
			if is_on_floor() and state_timer >= 0.15:
				_post_attack()
		State.SLAM_WINDUP:
			# Rear back: brief reverse-creep telegraphs the lunge direction.
			velocity.x = move_toward(velocity.x, float(-slam_dir) * 60.0, 600.0 * delta)
			_face_player()
			# Re-aim direction at the last moment so the slam tracks the
			# player's current side — but only during the first half of
			# the windup, so a quick juke past the boss commits it the
			# wrong way (player skill check).
			if state_timer < slam_windup_time * 0.5 and player is Node2D:
				var dx: float = (player as Node2D).global_position.x - global_position.x
				slam_dir = -1 if dx < 0.0 else 1
				direction = slam_dir
			if state_timer >= slam_windup_time:
				_enter_state(State.SLAM_CHARGE)
		State.SLAM_CHARGE:
			velocity.x = float(slam_dir) * slam_speed
			# Resolve when: max charge time elapsed, ran into a wall, or hit
			# the entrance buffer / combat wall.
			var hit_wall: bool = is_on_wall() or absf(velocity.x) < slam_speed * 0.4
			var at_edge: bool = (slam_dir < 0 and global_position.x <= _combat_min_x() + 8.0) \
				or (slam_dir > 0 and global_position.x >= arena_right - 44.0)
			if state_timer >= slam_max_time or hit_wall or at_edge:
				# Recovery burst — kick a small backward velocity so the
				# stop reads as a body brake, then exit through STAGGER
				# for a beat of vulnerability after the commit.
				velocity.x = float(-slam_dir) * 120.0
				_end_slam()
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if state_timer >= 0.20:
				_enter_state(State.PACE)
		_:
			pass

func _enter_state(s: State) -> void:
	state = s
	state_timer = 0.0
	# Slam hitbox is only ever live during SLAM_CHARGE — make every other
	# state transition implicitly disable it so STAGGER / damage interrupts
	# can't leave a stray hurtbox on the player.
	if _slam_hitbox_shape and s != State.SLAM_CHARGE:
		_slam_hitbox_shape.set_deferred("disabled", true)
	match s:
		State.IDLE:
			_mouth_glow.modulate.a = 0.0
		State.PACE:
			_pick_pace_target()
			_mouth_glow.modulate.a = 0.0
		State.ROAR:
			pending_fire_delay = 0.0
			_mouth_glow.modulate.a = 0.0
		State.FIRE:
			pass
		State.BURST:
			volley_delay = 0.0
		State.LEAP:
			_mouth_glow.modulate.a = 0.0
		State.SLAM_WINDUP:
			_mouth_glow.modulate.a = 0.0
			_slam_hit_this_charge = false
			if _slam_hitbox_shape:
				_slam_hitbox_shape.set_deferred("disabled", true)
		State.SLAM_CHARGE:
			# Enable the contact hurtbox for the duration of the lunge.
			if _slam_hitbox_shape:
				_slam_hitbox_shape.set_deferred("disabled", false)
		_:
			pass

func _pick_next_action() -> void:
	# High-mobility loop: by default the boss keeps pacing. Attack and leap
	# fire on their own cooldowns from inside PACE, so this only needs to
	# pick a new pace target and pass control back.
	_enter_state(State.PACE)

# -----------------------------------------------------------------------------
# Adaptive brain — observes the player and sets the five behavioral signals.
# -----------------------------------------------------------------------------
func _brain_tick(dt: float) -> void:
	# Decay all rolling scores first so old behavior fades naturally.
	_aggro_score = maxf(_aggro_score - 0.6 * dt, 0.0)
	_heal_score  = maxf(_heal_score  - 0.4 * dt, 0.0)
	_range_score = maxf(_range_score - 0.5 * dt, 0.0)
	_close_score = maxf(_close_score - 0.5 * dt, 0.0)

	if not (player is Node2D):
		sig_aggressive = false
		sig_healing = false
		sig_at_range = false
		sig_repeating = false
		sig_losing_badly = false
		return
	var p := player as Node2D
	var dx_abs: float = absf(p.global_position.x - global_position.x)

	# --- Question 1: is the player aggressive? ---------------------------
	# Aggressive = closing distance AND/OR pressing into our face. We don't
	# need to measure damage directly here — take_damage() already bumped
	# _aggro_score on the hit; this just adds a smaller pressure term for
	# being in our face even between hits.
	if _player_prev_pos != Vector2.ZERO:
		var closed: float = (_player_prev_pos - global_position).length() - (p.global_position - global_position).length()
		if closed > 4.0 and dx_abs < 260.0:
			_aggro_score += 0.35
	if dx_abs < 140.0:
		_close_score += 1.0
	sig_aggressive = _aggro_score > 1.0 or _close_score > 2.5

	# --- Question 2: are they healing? -----------------------------------
	# Look for current_health going up between ticks. Spike the heal score
	# on detection and let it decay so the boss only "reacts" briefly.
	var hp_now: int = int(p.get("current_health")) if "current_health" in p else -1
	if hp_now >= 0 and _player_prev_hp >= 0 and hp_now > _player_prev_hp:
		_heal_score += 2.0
	_player_prev_hp = hp_now
	sig_healing = _heal_score > 0.8

	# --- Question 3: are they staying at range? --------------------------
	if dx_abs > 360.0:
		_range_score += 1.0
	sig_at_range = _range_score > 2.0 and _close_score < 1.0

	# --- Question 4: are they repeating one tactic? ----------------------
	# A tactic = distance band + airborne/grounded. If the same token
	# dominates the last 6 samples, the player is locked into a pattern.
	var band: String = "near" if dx_abs < 160.0 else ("mid" if dx_abs < 360.0 else "far")
	var aerial: String = "air" if not _player_on_floor() else "ground"
	var tactic: String = band + "_" + aerial
	_player_tactic_log.append(tactic)
	if _player_tactic_log.size() > 6:
		_player_tactic_log.pop_front()
	var dominant: int = 0
	for t in _player_tactic_log:
		if t == tactic:
			dominant += 1
	sig_repeating = _player_tactic_log.size() >= 4 and dominant >= 4

	# --- Question 5: am I losing badly? ----------------------------------
	# Compare HP fractions. "Badly" = boss < 35% while player > 60%, OR
	# boss < 20% regardless — at that point survival matters more than
	# pressure.
	var boss_frac: float = float(current_health) / float(max_health)
	var p_max: int = int(p.get("max_health")) if "max_health" in p else 0
	var p_frac: float = float(hp_now) / float(maxi(p_max, 1)) if p_max > 0 else 1.0
	sig_losing_badly = boss_frac < 0.20 or (boss_frac < 0.35 and p_frac > 0.60)

	# --- Same-tick reactions (cooldown nudges) ---------------------------
	# Healing interrupts: yank the slam cooldown so the boss can punish a
	# heal animation before it completes. Only do this once per spike — the
	# heal score has to be fresh.
	if sig_healing and slam_cd > 0.20 and _slam_makes_sense():
		slam_cd = 0.10
	# Range punishment: if the player is camping far, pull the attack
	# cooldown in so the boss starts a volley sooner.
	if sig_at_range and attack_cd > 0.30:
		attack_cd = minf(attack_cd, 0.30)
	# Losing-badly retreat: extend slam cooldown (no more risky commits)
	# and dial up flame pressure from a safer distance.
	if sig_losing_badly:
		slam_cd = maxf(slam_cd, 1.4)

	_player_prev_pos = p.global_position

func _player_on_floor() -> bool:
	if player is CharacterBody2D:
		return (player as CharacterBody2D).is_on_floor()
	return true

func _begin_attack() -> void:
	# Attack selection is signal-driven. Default rhythm is the old single-vs-
	# burst coin flip; signals bias it toward what the player is failing to
	# answer for.
	var want_burst: bool = false
	var want_slam: bool = false

	if sig_at_range:
		# Player is hanging back — wall them with a fat volley.
		want_burst = true
	if sig_aggressive and _slam_makes_sense() and slam_cd <= 0.4:
		# Player is pressing in — punish with a slam instead of a flame.
		want_slam = true
	if sig_repeating and _last_attack_kind != "":
		# Player has settled into one pattern AND we just used the same
		# attack last time — swap the kind to break the rhythm.
		if _last_attack_kind == "burst":
			want_burst = false
		elif _last_attack_kind == "slam":
			want_slam = false
		elif _last_attack_kind == "flame" and volley_size_max >= 2:
			want_burst = true
	if sig_losing_badly:
		# Cagey: no slams while bleeding out, prefer ranged pressure.
		want_slam = false
		want_burst = true

	if want_slam:
		_last_attack_kind = "slam"
		_begin_slam()
		return

	if want_burst and volley_size_max >= 2:
		# Losing-badly bumps burst size by one for desperation pressure.
		var hi: int = volley_size_max + (1 if sig_losing_badly else 0)
		volley_remaining = rng.randi_range(2, hi)
		_last_attack_kind = "burst"
	elif rng.randf() < 0.55 and volley_size_max >= 2:
		volley_remaining = rng.randi_range(2, volley_size_max)
		_last_attack_kind = "burst"
	else:
		volley_remaining = 1
		_last_attack_kind = "flame"
	# Cooldown is set when the attack resolves, not here — keeps the
	# next attack from chain-firing immediately after a long burst.
	_enter_state(State.ROAR)

func _begin_leap() -> void:
	# Aim the leap horizontally toward a fresh pace target so it actually
	# repositions the boss instead of jumping in place.
	_pick_pace_target()
	var leap_dir: float = signf(pace_target_x - global_position.x)
	if leap_dir == 0.0:
		leap_dir = float(direction)
	direction = -1 if leap_dir < 0.0 else 1
	velocity = Vector2(leap_dir * leap_vx, leap_vy)
	leap_cd = rng.randf_range(2.4, 4.2)
	_enter_state(State.LEAP)

func _slam_makes_sense() -> bool:
	# Only slam when the player is roughly in the boss's plane (so the lunge
	# could actually connect) and at a useful distance — close enough to be
	# threatening, far enough that the windup reads as a telegraph.
	if not (player is Node2D):
		return false
	var p := player as Node2D
	if absf(p.global_position.y - global_position.y) > 80.0:
		return false
	var dx: float = absf(p.global_position.x - global_position.x)
	return dx >= 80.0 and dx <= 520.0

func _begin_slam() -> void:
	# Face the player and commit. slam_dir is captured here so the windup
	# locks direction visually; SLAM_WINDUP may re-aim once before the lunge.
	if player is Node2D:
		var dx: float = (player as Node2D).global_position.x - global_position.x
		slam_dir = -1 if dx < 0.0 else 1
	else:
		slam_dir = direction
	direction = slam_dir
	_enter_state(State.SLAM_WINDUP)

func _end_slam() -> void:
	# Reset slam cooldown (longer than attack_cd — slams are committed reads,
	# not constant pressure) and recover through a short stagger so the
	# player gets a punish window on a well-dodged slam.
	slam_cd = rng.randf_range(2.6, 4.5)
	if is_enraged:
		slam_cd *= 0.55
	_enter_state(State.STAGGER)

func _on_slam_body_entered(body: Node) -> void:
	if _slam_hit_this_charge:
		return
	if state != State.SLAM_CHARGE:
		return
	if not (body.has_method("take_damage") or body.has_method("request_damage")):
		return
	_slam_hit_this_charge = true
	if body.has_method("request_damage") and multiplayer.has_multiplayer_peer():
		body.request_damage.rpc_id(body.get_multiplayer_authority(), slam_damage, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(slam_damage, global_position)

func _post_attack() -> void:
	# Reset attack cooldown based on aggressiveness — more aggressive bosses
	# come back online faster.
	var base: float = lerpf(1.1, 0.45, clampf(aggressiveness, 0.0, 1.0))
	attack_cd = base + rng.randf_range(-0.12, 0.18)
	_enter_state(State.PACE)

func _pick_pace_target() -> void:
	# Bias toward the player so the boss eventually closes distance, but with
	# enough noise that it sometimes overshoots or retreats. The combat_min
	# clamp keeps the boss out of the entrance corridor regardless of where
	# the player stands — so camping the doorway is impossible.
	var bias: float = 0.0
	if player is Node2D:
		bias = (player as Node2D).global_position.x - global_position.x
		bias = clampf(bias, -pace_dist, pace_dist)
	# Brain-driven bias tweaks: losing → flip bias to retreat AWAY from the
	# player and kite with flames; range-camping → double-down on closing
	# distance so the player can't sit at long range unanswered.
	if sig_losing_badly:
		bias = -bias * 0.8
	elif sig_at_range:
		bias *= 1.6
	var jitter: float = rng.randf_range(-pace_dist * 0.6, pace_dist * 0.6)
	var combat_min: float = _combat_min_x()
	pace_target_x = clampf(global_position.x + bias * 0.6 + jitter,
		combat_min + 24.0, arena_right - 60.0)
	# If the player is in the doorway zone, actively retreat to deep arena
	# instead of pacing toward them — the boss should give space, not crowd.
	if player is Node2D and (player as Node2D).global_position.x < combat_min:
		pace_target_x = maxf(pace_target_x,
			lerpf(combat_min, arena_right, 0.5))

func _combat_min_x() -> float:
	return arena_left + maxf(entrance_buffer, 36.0)

func _face_player() -> void:
	if player is Node2D:
		var dx: float = (player as Node2D).global_position.x - global_position.x
		if absf(dx) > 4.0:
			direction = -1 if dx < 0.0 else 1

# -----------------------------------------------------------------------------
# Combat
# -----------------------------------------------------------------------------
func _spawn_flame(height_offset: float) -> void:
	var flame := Area2D.new()
	flame.set_script(FLAME_SCRIPT)
	# Horizontal spawn: a bit forward of the boss's body in its facing
	# direction, clearing the chest plates.
	var fwd_x: float = float(direction) * 56.0 * size_mult
	# Vertical spawn: at standing-player chest height (floor - 28), so a
	# stationary player is hit and a normal jump clears it. height_offset
	# jitter can push it lower (forcing a higher jump) or higher (duck/skip).
	# Clamp so flames always sit in the "jumpable but threatening" band —
	# never sunk into the floor, never sailing harmlessly overhead.
	var fy: float = clampf(arena_floor - 28.0 + height_offset, arena_floor - 56.0, arena_floor - 18.0)
	var spawn := Vector2(global_position.x + fwd_x, fy)
	get_parent().add_child(flame)
	flame.global_position = spawn
	# Slow horizontal velocity in the boss's facing direction.
	var speed: float = rng.randf_range(85.0, 115.0)
	flame.setup(Vector2(float(direction) * speed, 0.0), arena_left, arena_right)
	# Mouth flash on every spawn — short visual "spit".
	if _mouth_glow:
		_mouth_glow.modulate.a = 1.0
		get_tree().create_timer(0.10).timeout.connect(func() -> void:
			if is_instance_valid(_mouth_glow):
				_mouth_glow.modulate.a = 0.0
		)

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_dead:
		return
	current_health -= amount
	_hurt_flash = 0.12
	# Feed the brain: each hit is direct evidence of aggression. Scaled by
	# damage so a single big hit registers more than ambient chip damage.
	_aggro_score += 0.5 + float(amount) * 0.15
	# Small knockback against the hit direction — doesn't break arena lock.
	var kb: float = signf(global_position.x - source_pos.x) * 30.0
	velocity.x += kb
	# Slam and leap are full-commit windows: take the damage, but the boss
	# doesn't break out of them. Same for the established attack states.
	var committed: bool = state == State.ROAR or state == State.FIRE \
		or state == State.BURST or state == State.SLAM_WINDUP \
		or state == State.SLAM_CHARGE or state == State.LEAP
	if not committed:
		_enter_state(State.STAGGER)
	_refresh_hp_bar()
	_check_enrage()
	if current_health <= 0:
		_die()

func _check_enrage() -> void:
	if is_enraged or is_dead:
		return
	if float(current_health) > float(max_health) * enrage_threshold:
		return
	_trigger_enrage()

func _trigger_enrage() -> void:
	is_enraged = true
	# Compress cooldowns + speed across the board. The boss already attacks
	# while pacing, so multiplying speed + halving cooldowns ratchets the
	# pressure without changing the moveset.
	pace_speed *= 1.35
	slam_speed *= 1.20
	leap_vx    *= 1.15
	leap_vy    *= 1.10
	slam_windup_time = maxf(0.25, slam_windup_time * 0.65)
	aggressiveness = clampf(aggressiveness + 0.20, 0.0, 1.0)
	volley_size_max = mini(volley_size_max + 2, 7)
	burst_period   = maxf(0.08, burst_period * 0.70)
	idle_time_min  *= 0.50
	idle_time_max  *= 0.50
	# Cut current cooldowns so the enrage hits with an immediate pressure
	# spike instead of a quiet beat.
	attack_cd = minf(attack_cd, 0.15)
	slam_cd   = minf(slam_cd,   1.0)
	leap_cd   = minf(leap_cd,   0.8)
	# Visual telegraph: brief mouth flash and a sustained red aura. Spike +
	# eye colors also shift toward hot red so the player reads the phase.
	spike_color = spike_color.lerp(Color(1.0, 0.30, 0.10), 0.65)
	eye_color   = Color(1.0, 0.30, 0.20)
	for s in _spikes:
		s.color = spike_color
	if _mouth_glow:
		_mouth_glow.modulate.a = 1.0
	# Knockback shockwave on the player so the phase shift feels physical.
	if player and player.has_method("_apply_shake"):
		player.call("_apply_shake", 8.0)
	# Cascade of small explosions across the body for a "shedding skin"
	# enrage moment.
	for i in 3:
		var delay: float = float(i) * 0.10
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(self) or is_dead:
				return
			var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
			get_parent().add_child(fx)
			fx.global_position = global_position + Vector2(
				rng.randf_range(-40.0, 40.0) * size_mult,
				rng.randf_range(-100.0, -10.0) * size_mult)
		)

func get_damage() -> int:
	return contact_damage

func _refresh_hp_bar() -> void:
	if _hp_bar_fill == null:
		return
	var w: float = 120.0 * size_mult
	var t: float = clampf(float(current_health) / float(max_health), 0.0, 1.0)
	_hp_bar_fill.offset_left = -w * 0.5
	_hp_bar_fill.offset_right = -w * 0.5 + w * t
	_hp_bar_fill.color = Color(1.0, 0.20 + 0.40 * t, 0.20)

func _die() -> void:
	is_dead = true
	state = State.DEAD
	state_timer = 0.0
	_death_time = 0.0
	collision_layer = 0
	collision_mask = 1
	# Stop dealing damage and pin the boss in place so the death anim plays
	# on a stable pose instead of sliding.
	if _slam_hitbox_shape:
		_slam_hitbox_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	_hp_bar_bg.visible = false
	_hp_bar_fill.visible = false
	# Drop the enrage aura — it's about to be overridden by the death FX.
	if _enrage_aura:
		_enrage_aura.color.a = 0.0

	# Initial body-rupture explosion at center mass.
	_spawn_explosion(Vector2.ZERO)
	# Staggered explosion cascade across the silhouette over ~2.0 s. The
	# offsets cluster around the back/spine for a "broken spine" read,
	# matched to the wing-spread death pose.
	for i in 7:
		var delay: float = 0.25 + float(i) * 0.28
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			var off := Vector2(
				rng.randf_range(-50.0, 50.0) * size_mult,
				rng.randf_range(-120.0, -10.0) * size_mult)
			_spawn_explosion(off)
		)
	# Final detonation cluster as the body fades.
	get_tree().create_timer(2.6).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for j in 4:
			var off := Vector2(
				rng.randf_range(-60.0, 60.0) * size_mult,
				rng.randf_range(-90.0, 0.0) * size_mult)
			_spawn_explosion(off)
	)
	# Despawn after the full sequence finishes.
	get_tree().create_timer(3.4).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free()
	)

# Three-phase death animation: rear up with wings flaring → collapse forward
# as the legs buckle → fade out as the body dissolves into the final
# explosion cluster.
func _animate_death(delta: float) -> void:
	_death_time += delta
	if _visual_root == null:
		return

	# Wings are forced visible for the whole death sequence — the spread
	# silhouette is the centerpiece of the pose.
	if _wing_left:
		_wing_left.modulate.a = 1.0
	if _wing_right:
		_wing_right.modulate.a = 1.0

	var body_rot: float
	var body_y: float
	var body_scale_y: float
	var wing_angle: float
	var alpha: float = 1.0

	if _death_time < 0.40:
		# Phase 1: rear up. Head tilts back, body lifts slightly, wings snap
		# open wide as if catching one last gust.
		var t: float = _death_time / 0.40
		var e: float = _ease_out_back(t)
		body_rot = lerpf(0.0, -0.22, e)
		body_y = lerpf(0.0, -10.0, e)
		body_scale_y = lerpf(1.0, 1.06, e)
		wing_angle = lerpf(0.0, -1.10, e)   # wings raised high
	elif _death_time < 1.80:
		# Phase 2: collapse. Body pitches forward and shrinks vertically
		# as the legs give out; wings sag from full spread to a dropped pose.
		var t2: float = (_death_time - 0.40) / 1.40
		var e2: float = _ease_in_out_quad(t2)
		body_rot = lerpf(-0.22, 0.45, e2)
		body_y = lerpf(-10.0, 22.0, e2)
		body_scale_y = lerpf(1.06, 0.78, e2)
		wing_angle = lerpf(-1.10, 0.55, e2)
		# Late-phase shudder so the collapse doesn't read as a perfect arc.
		body_rot += sin(_death_time * 22.0) * 0.025 * (1.0 - e2)
	else:
		# Phase 3: held collapsed pose, fade out.
		var t3: float = clampf((_death_time - 1.80) / 1.40, 0.0, 1.0)
		body_rot = 0.45
		body_y = 22.0
		body_scale_y = 0.78
		wing_angle = lerpf(0.55, 0.10, t3)   # wings flatten as body fades
		alpha = 1.0 - t3

	_visual_root.rotation = body_rot
	_visual_root.position = Vector2(0.0, body_y)
	_visual_root.scale = Vector2(_visual_root.scale.x, body_scale_y)
	_visual_root.modulate = Color(1.0, 1.0, 1.0, alpha)

	if _wing_left:
		_wing_left.rotation = wing_angle
	if _wing_right:
		_wing_right.rotation = -wing_angle

	# Eye glow dims through phase 1+2 then snuffs out in phase 3.
	if _eye_glow:
		var eye_a: float = clampf(1.0 - _death_time * 0.55, 0.0, 1.0)
		_eye_glow.modulate = eye_color * eye_a
	# Mouth glow flickers during the cascade — last bursts of fire inside.
	if _mouth_glow:
		var flick: float = 0.5 + 0.5 * sin(_death_time * 18.0)
		_mouth_glow.modulate.a = (0.6 + 0.4 * flick) * clampf(2.2 - _death_time, 0.0, 1.0)

func _ease_out_back(t: float) -> float:
	# Standard easeOutBack — slight overshoot for the rear-up "kick".
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var x: float = t - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x

func _ease_in_out_quad(t: float) -> float:
	return 2.0 * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5

func _spawn_explosion(local_offset: Vector2) -> void:
	var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	get_parent().add_child(fx)
	fx.global_position = global_position + local_offset

# -----------------------------------------------------------------------------
# Visuals (per-frame animation)
# -----------------------------------------------------------------------------
func _update_visuals(delta: float) -> void:
	bob_phase += delta * 2.6
	tail_phase += delta * 3.2
	eye_phase += delta * 4.0
	_walk_anim += absf(velocity.x) * delta * 0.04

	# --- Death animation overrides everything else ----------------------
	if is_dead:
		_animate_death(delta)
		return

	# Whole-body facing flip — sprite is built facing LEFT by default so flip
	# the visual horizontally when direction > 0.
	_visual_root.scale.x = -1.0 if direction > 0 else 1.0

	# Idle breathing — subtle vertical bob, plus shoulder lift via arm offset.
	var breath: float = sin(bob_phase) * 2.2
	_visual_root.position.y = breath
	if _arm_back:
		_arm_back.rotation = sin(bob_phase) * 0.05
	if _arm_fore:
		_arm_fore.rotation = sin(bob_phase + PI) * 0.07

	# Tail sway — each segment lags slightly behind the previous for a
	# whip-like motion.
	for i in _tail_segments.size():
		var lag: float = float(i) * 0.35
		_tail_segments[i].rotation = sin(tail_phase - lag) * 0.10

	# --- Skeletal wings: visible during LEAP, flap like a gargoyle -------
	if state == State.LEAP:
		# Snap on instantly — wings unfurl at takeoff for drama.
		_wings_alpha = 1.0
		_wing_phase += delta * 11.0
	else:
		_wings_alpha = move_toward(_wings_alpha, 0.0, 5.0 * delta)
		# Slow the flap as we exit so the last beat reads as a glide,
		# not an abrupt freeze.
		_wing_phase += delta * lerpf(2.0, 11.0, _wings_alpha)
	if _wing_left:
		_wing_left.modulate.a = _wings_alpha
	if _wing_right:
		_wing_right.modulate.a = _wings_alpha
	# Gargoyle-style asymmetric flap: ~30% of the cycle is a snappy
	# down-stroke (powerful thrust), 70% is a slow recovery lift. The
	# asymmetry sells the "heavy creature beating air down" feel that
	# Disney's Gargoyles built its wing animation around.
	var cycle: float = fposmod(_wing_phase, TAU) / TAU
	var flap_angle: float
	if cycle < 0.30:
		flap_angle = lerpf(-0.55, 0.65, cycle / 0.30)
	else:
		flap_angle = lerpf(0.65, -0.55, (cycle - 0.30) / 0.70)
	if _wing_left:
		_wing_left.rotation = flap_angle
	if _wing_right:
		# Mirror so the two wings sweep down together in world space.
		_wing_right.rotation = -flap_angle

	# Walk cycle — alternate leg lift while pacing.
	if state == State.PACE and _left_leg and _right_leg:
		var step: float = sin(_walk_anim * 6.0) * 3.0
		_left_leg.position.y  =  step
		_right_leg.position.y = -step
	elif _left_leg and _right_leg:
		_left_leg.position.y  = move_toward(_left_leg.position.y,  0.0, 60.0 * delta)
		_right_leg.position.y = move_toward(_right_leg.position.y, 0.0, 60.0 * delta)

	# Eye pulse — brighter during roar/burst to telegraph attacks.
	var base_eye: float = 0.6 + 0.4 * sin(eye_phase)
	var alert: float = 1.0 if state in [State.ROAR, State.FIRE, State.BURST] else 0.35
	_eye_glow.modulate = eye_color.lightened(0.2) * (base_eye * 0.6 + alert)

	# Enrage aura — slow pulse at moderate alpha when enraged, off otherwise.
	if _enrage_aura:
		if is_enraged:
			var pulse: float = 0.5 + 0.5 * sin(bob_phase * 2.4)
			_enrage_aura.color.a = 0.18 + 0.22 * pulse
		else:
			_enrage_aura.color.a = 0.0

	# Hit flash overrides the base modulate; enraged base modulate is
	# slightly hot-tinted so the kaiju reads as "lit up" even between hits.
	if _hurt_flash > 0.0:
		_visual_root.modulate = Color(2.5, 2.5, 2.5)
	elif is_enraged:
		_visual_root.modulate = Color(1.18, 0.92, 0.88)
	else:
		_visual_root.modulate = Color.WHITE
