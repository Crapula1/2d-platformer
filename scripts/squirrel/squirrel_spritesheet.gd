@tool
extends EditorScript
# ============================================================================
#  SquirrelSpriteSheet.gd  -  Godot 4.x
# ----------------------------------------------------------------------------
#  Procedurally draws a 96x96 humanoid-squirrel sprite sheet covering:
#     idle (4f)  walking (6f)  running (6f)  crouching (3f)
#     slide-dash (4f)  slashing (5f)  stabbing (5f)
#
#  HOW TO USE
#  ----------
#  1. Save this file in your Godot 4 project (any path).
#  2. Open Script editor  ->  File  ->  Run  (Ctrl+Shift+X).
#     It writes "res://squirrel_sheet.png" (7 rows x 6 cols, 576 x 672 px).
#  3. Import it as a Texture2D, slice it 96x96 in an AnimatedSprite2D /
#     SpriteFrames, and use the rows below for each animation.
#
#  Row layout (top -> bottom), columns left -> right:
#      Row 0: idle      (frames 0..3)   -- cols 4 & 5 blank
#      Row 1: walking   (frames 0..5)
#      Row 2: running   (frames 0..5)
#      Row 3: crouching (frames 0..2)   -- cols 3..5 blank
#      Row 4: slide     (frames 0..3)   -- cols 4 & 5 blank
#      Row 5: slash     (frames 0..4)   -- col  5    blank
#      Row 6: stab      (frames 0..4)   -- col  5    blank
# ============================================================================

const FRAME : int = 96
const COLS  : int = 6
const ROWS  : int = 7
const OUT_PATH : String = "res://squirrel_sheet.png"

# ---------- palette --------------------------------------------------------
const FUR_LIGHT   := Color8(199, 138,  85)
const FUR_MID     := Color8(160, 102,  58)
const FUR_DARK    := Color8(110,  66,  36)
const BELLY       := Color8(240, 215, 170)
const EAR_INNER   := Color8(200, 150, 110)
const EYE_WHITE   := Color8(245, 245, 245)
const EYE_BLACK   := Color8( 20,  20,  25)
const NOSE        := Color8( 50,  30,  35)
const TOOTH       := Color8(250, 245, 220)
const CLOTH       := Color8( 60,  80, 110)   # blue tunic
const CLOTH_DARK  := Color8( 38,  52,  78)
const BELT        := Color8( 70,  45,  25)
const BUCKLE      := Color8(210, 175,  80)
const PANTS       := Color8( 70,  55,  40)
const PANTS_DARK  := Color8( 45,  35,  25)
const BOOT        := Color8( 55,  35,  20)
const BOOT_DARK   := Color8( 35,  22,  12)
const BLADE       := Color8(220, 225, 235)
const BLADE_EDGE  := Color8(255, 255, 255)
const BLADE_DARK  := Color8(140, 145, 155)
const HILT        := Color8( 95,  60,  30)
const GUARD       := Color8(180, 145,  70)
const OUTLINE     := Color8( 20,  14,  10)
const CLEAR       := Color8(0, 0, 0, 0)

# Working image + draw cursor (top-left of current frame)
var img : Image
var ox  : int = 0
var oy  : int = 0


# ============================================================================
#                                ENTRY POINT
# ============================================================================
func _run() -> void:
	img = Image.create(FRAME * COLS, FRAME * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(CLEAR)

	# ---- Row 0: idle ------------------------------------------------------
	for f in 4:
		_set_cell(f, 0)
		_draw_idle(f)

	# ---- Row 1: walking ---------------------------------------------------
	for f in 6:
		_set_cell(f, 1)
		_draw_walk(f)

	# ---- Row 2: running ---------------------------------------------------
	for f in 6:
		_set_cell(f, 2)
		_draw_run(f)

	# ---- Row 3: crouching -------------------------------------------------
	for f in 3:
		_set_cell(f, 3)
		_draw_crouch(f)

	# ---- Row 4: slide dash ------------------------------------------------
	for f in 4:
		_set_cell(f, 4)
		_draw_slide(f)

	# ---- Row 5: slashing --------------------------------------------------
	for f in 5:
		_set_cell(f, 5)
		_draw_slash(f)

	# ---- Row 6: stabbing --------------------------------------------------
	for f in 5:
		_set_cell(f, 6)
		_draw_stab(f)

	var err := img.save_png(OUT_PATH)
	if err == OK:
		print("Saved sprite sheet -> ", OUT_PATH)
	else:
		push_error("Failed to save sheet, error %d" % err)


# ============================================================================
#                            FRAME / DRAW HELPERS
# ============================================================================
func _set_cell(col: int, row: int) -> void:
	ox = col * FRAME
	oy = row * FRAME

func _px(x: int, y: int, c: Color) -> void:
	# put a single pixel inside the current frame, clipped
	if x < 0 or y < 0 or x >= FRAME or y >= FRAME:
		return
	img.set_pixel(ox + x, oy + y, c)

func _rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for j in h:
		for i in w:
			_px(x + i, y + j, c)

func _disc(cx: int, cy: int, r: int, c: Color) -> void:
	var r2 := r * r
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			if i * i + j * j <= r2:
				_px(cx + i, cy + j, c)

func _ellipse(cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for j in range(-ry, ry + 1):
		for i in range(-rx, rx + 1):
			var fx := float(i) / float(rx)
			var fy := float(j) / float(ry)
			if fx * fx + fy * fy <= 1.0:
				_px(cx + i, cy + j, c)

func _line(x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var x := x0
	var y := y0
	while true:
		if thick <= 1:
			_px(x, y, c)
		else:
			_disc(x, y, thick / 2, c)
		if x == x1 and y == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy

# Outline an opaque shape by adding a 1-px dark border around any colored pixel
# that touches transparency. Called once per frame at the end.
func _outline_frame() -> void:
	var snapshot : PackedColorArray = PackedColorArray()
	snapshot.resize(FRAME * FRAME)
	for j in FRAME:
		for i in FRAME:
			snapshot[j * FRAME + i] = img.get_pixel(ox + i, oy + j)

	for j in FRAME:
		for i in FRAME:
			var c : Color = snapshot[j * FRAME + i]
			if c.a > 0.0:
				continue
			# transparent pixel -> if any 4-neighbor is opaque, paint outline
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var ni : int = i + d.x
				var nj : int = j + d.y
				if ni < 0 or nj < 0 or ni >= FRAME or nj >= FRAME:
					continue
				var n : Color = snapshot[nj * FRAME + ni]
				if n.a > 0.0:
					_px(i, j, OUTLINE)
					break


# ============================================================================
#                              BODY BUILDER
# ----------------------------------------------------------------------------
#  A reusable rig. Parameters control posture so every animation can be
#  expressed by tweaking offsets/angles.
# ============================================================================
#
# Pose dictionary keys (all optional, defaults given inside _draw_squirrel):
#   pos        : Vector2i   torso center offset from default
#   crouch     : float      0..1 lowering amount
#   lean       : float      degrees forward lean
#   tail_phase : float      -1..1 tail sway amount (positive -> back curl)
#   l_arm      : Vector2    (shoulder->hand offset from rest)
#   r_arm      : Vector2
#   l_leg      : Vector2    foot offset from default stance
#   r_leg      : Vector2
#   weapon     : String     "" | "slash" | "stab" | "carry"
#   weapon_ang : float      degrees, 0 = pointing right
#   weapon_off : Vector2    extra offset
#   blink      : bool
#   mouth      : String     "n" normal, "o" open
#   facing     : int        1 right, -1 left  (default 1)
# ============================================================================
func _draw_squirrel(pose: Dictionary) -> void:
	var facing : int = pose.get("facing", 1)
	var crouch : float = pose.get("crouch", 0.0)
	var lean   : float = pose.get("lean", 0.0)
	var pos    : Vector2 = pose.get("pos", Vector2.ZERO)

	# Default torso center near middle of frame, feet around y=88
	var cx : float = 48.0 + pos.x
	var cy : float = 50.0 + pos.y + crouch * 8.0      # torso sinks when crouching

	# --- tail (drawn FIRST so body sits in front) -------------------------
	var tail_phase : float = pose.get("tail_phase", 0.0)
	_draw_tail(cx, cy, facing, tail_phase, crouch)

	# --- legs -------------------------------------------------------------
	var hip_y : float = cy + 16.0 - crouch * 4.0
	var l_leg : Vector2 = pose.get("l_leg", Vector2.ZERO)
	var r_leg : Vector2 = pose.get("r_leg", Vector2.ZERO)
	_draw_leg(cx - 6 * facing, hip_y, l_leg, crouch, facing, false)
	_draw_leg(cx + 6 * facing, hip_y, r_leg, crouch, facing, true)

	# --- torso ------------------------------------------------------------
	var torso_top : float = cy - 14.0
	var lean_off  : float = lean * 0.4
	_draw_torso(cx + lean_off, cy, facing, crouch)

	# --- head -------------------------------------------------------------
	var head_cx : float = cx + lean_off * 1.6 + facing * 1.0
	var head_cy : float = torso_top - 10.0
	_draw_head(head_cx, head_cy, facing, pose.get("blink", false), pose.get("mouth", "n"))

	# --- arms -------------------------------------------------------------
	var sh_y : float = torso_top + 2.0
	var l_arm : Vector2 = pose.get("l_arm", Vector2.ZERO)
	var r_arm : Vector2 = pose.get("r_arm", Vector2.ZERO)
	_draw_arm(cx - 9 * facing + lean_off, sh_y, l_arm, facing, false)
	# right arm may hold weapon
	var weapon : String = pose.get("weapon", "")
	var hand_pos : Vector2 = _draw_arm(cx + 9 * facing + lean_off, sh_y, r_arm, facing, true)

	if weapon != "":
		var ang : float = deg_to_rad(pose.get("weapon_ang", 0.0))
		var woff : Vector2 = pose.get("weapon_off", Vector2.ZERO)
		_draw_weapon(hand_pos + woff, ang, facing, weapon)

	_outline_frame()


# ---------- TAIL -----------------------------------------------------------
func _draw_tail(cx: float, cy: float, facing: int, phase: float, crouch: float) -> void:
	# Big bushy curl that sweeps from lower-back up and over.
	# We build it from a chain of overlapping discs.
	var base_x : float = cx - 10.0 * facing
	var base_y : float = cy + 12.0 - crouch * 3.0
	var seg : int = 8
	for i in seg:
		var t : float = float(i) / float(seg - 1)
		# curl path: starts behind hip, arcs up and back forward
		var ang : float = lerp(160.0, 60.0 + phase * 25.0, t)   # degrees
		var dist : float = 14.0 * (0.6 + t * 0.9)
		var r : float = lerp(9.0, 4.0, t)
		var ax : float = deg_to_rad(ang)
		var x : float = base_x - cos(ax) * dist * facing
		var y : float = base_y - sin(ax) * dist
		_disc(int(round(x)), int(round(y)), int(r), FUR_MID)
	# inner highlight
	for i in seg:
		var t2 : float = float(i) / float(seg - 1)
		var ang2 : float = lerp(160.0, 60.0 + phase * 25.0, t2)
		var dist2 : float = 14.0 * (0.6 + t2 * 0.9)
		var r2 : float = lerp(6.0, 2.0, t2)
		var ax2 : float = deg_to_rad(ang2)
		var x2 : float = base_x - cos(ax2) * dist2 * facing - 1.0 * facing
		var y2 : float = base_y - sin(ax2) * dist2 - 1.0
		_disc(int(round(x2)), int(round(y2)), int(r2), FUR_LIGHT)


# ---------- HEAD -----------------------------------------------------------
func _draw_head(cx: float, cy: float, facing: int, blink: bool, mouth: String) -> void:
	var icx := int(round(cx))
	var icy := int(round(cy))

	# ears
	_disc(icx - 7, icy - 9, 5, FUR_MID)
	_disc(icx + 7, icy - 9, 5, FUR_MID)
	_disc(icx - 7, icy - 9, 3, EAR_INNER)
	_disc(icx + 7, icy - 9, 3, EAR_INNER)

	# main head
	_ellipse(icx, icy, 10, 9, FUR_MID)
	# muzzle
	_ellipse(icx + 5 * facing, icy + 3, 6, 4, FUR_LIGHT)
	# cheek tuft
	_disc(icx - 7 * facing, icy + 2, 3, FUR_LIGHT)

	# eyes
	var ex : int = icx + 2 * facing
	var ey : int = icy - 2
	if blink:
		_rect(ex - 1, ey, 3, 1, EYE_BLACK)
	else:
		_disc(ex, ey, 2, EYE_WHITE)
		_px(ex + facing, ey, EYE_BLACK)
		_px(ex, ey, EYE_BLACK)
	# brow
	_px(ex - 1, ey - 3, FUR_DARK)
	_px(ex,     ey - 3, FUR_DARK)
	_px(ex + 1, ey - 3, FUR_DARK)

	# nose
	_disc(icx + 9 * facing, icy + 2, 1, NOSE)

	# mouth
	if mouth == "o":
		_rect(icx + 6 * facing, icy + 5, 3, 2, EYE_BLACK)
		_px(icx + 6 * facing, icy + 5, TOOTH)
		_px(icx + 7 * facing, icy + 5, TOOTH)
	else:
		_px(icx + 6 * facing, icy + 5, EYE_BLACK)
		_px(icx + 7 * facing, icy + 5, EYE_BLACK)


# ---------- TORSO ----------------------------------------------------------
func _draw_torso(cx: float, cy: float, facing: int, crouch: float) -> void:
	var icx := int(round(cx))
	var icy := int(round(cy))
	# tunic main shape
	_ellipse(icx, icy, 10, 13 - int(crouch * 3.0), CLOTH)
	# shadow side
	for j in range(-12, 12):
		for i in range(-10, 0):
			var fx := float(i) / 10.0
			var fy := float(j) / 13.0
			if fx * fx + fy * fy <= 1.0:
				_px(icx + i * facing, icy + j, CLOTH_DARK)
	# belly fur peeking
	_ellipse(icx, icy + 2, 4, 6, BELLY)
	# belt
	_rect(icx - 9, icy + 9, 18, 3, BELT)
	_rect(icx - 1, icy + 9, 3, 3, BUCKLE)


# ---------- ARM ------------------------------------------------------------
# Returns the hand center (frame coords) so weapon can attach.
func _draw_arm(sx: float, sy: float, offset: Vector2, facing: int, is_right: bool) -> Vector2:
	# shoulder
	var isx := int(round(sx))
	var isy := int(round(sy))
	_disc(isx, isy, 4, CLOTH)

	# elbow midway between shoulder and hand
	var hand_x : float = sx + offset.x * facing
	var hand_y : float = sy + offset.y + 14.0
	var elbow_x : float = (sx + hand_x) * 0.5 + (1.5 * facing if is_right else -1.5 * facing)
	var elbow_y : float = (sy + hand_y) * 0.5 - 1.0

	# upper arm (sleeve)
	_line(isx, isy, int(round(elbow_x)), int(round(elbow_y)), CLOTH, 5)
	# forearm (fur)
	_line(int(round(elbow_x)), int(round(elbow_y)),
		  int(round(hand_x)),  int(round(hand_y)),  FUR_MID, 4)
	# hand
	_disc(int(round(hand_x)), int(round(hand_y)), 3, FUR_LIGHT)

	return Vector2(hand_x, hand_y)


# ---------- LEG ------------------------------------------------------------
func _draw_leg(hx: float, hy: float, offset: Vector2, crouch: float, facing: int, is_right: bool) -> void:
	var foot_x : float = hx + offset.x
	var foot_y : float = hy + offset.y + 22.0 - crouch * 6.0
	var knee_x : float = (hx + foot_x) * 0.5 + (2.0 if is_right else -2.0) * facing
	var knee_y : float = (hy + foot_y) * 0.5 + crouch * 4.0

	# thigh (pants)
	_line(int(round(hx)), int(round(hy)),
		  int(round(knee_x)), int(round(knee_y)), PANTS, 6)
	# shin (pants darker)
	_line(int(round(knee_x)), int(round(knee_y)),
		  int(round(foot_x)), int(round(foot_y)), PANTS_DARK, 5)
	# boot
	_ellipse(int(round(foot_x)) + facing, int(round(foot_y)) + 1, 5, 3, BOOT)
	_rect(int(round(foot_x)) - 3, int(round(foot_y)) + 2, 8, 2, BOOT_DARK)


# ---------- WEAPON --------------------------------------------------------
# kind: "carry" | "slash" | "stab"
func _draw_weapon(hand: Vector2, ang: float, facing: int, kind: String) -> void:
	# A short sword: hilt 6px, guard 2px, blade 18px.
	var length : int = 22 if kind != "stab" else 24
	var dir := Vector2(cos(ang) * facing, sin(ang))

	# hilt sits in hand, blade extends outward
	var hilt_start : Vector2 = hand - dir * 4.0
	var hilt_end   : Vector2 = hand + dir * 2.0
	var guard_end  : Vector2 = hand + dir * 3.0
	var blade_end  : Vector2 = hand + dir * length

	# hilt
	_line(int(round(hilt_start.x)), int(round(hilt_start.y)),
		  int(round(hilt_end.x)),   int(round(hilt_end.y)),   HILT, 3)
	# guard (perpendicular)
	var perp := Vector2(-dir.y, dir.x)
	var g1 : Vector2 = guard_end + perp * 4.0
	var g2 : Vector2 = guard_end - perp * 4.0
	_line(int(round(g1.x)), int(round(g1.y)),
		  int(round(g2.x)), int(round(g2.y)), GUARD, 2)
	# blade
	_line(int(round(guard_end.x)), int(round(guard_end.y)),
		  int(round(blade_end.x)), int(round(blade_end.y)), BLADE, 3)
	# blade highlight
	var hl1 : Vector2 = guard_end + perp * 0.5
	var hl2 : Vector2 = blade_end + perp * 0.5
	_line(int(round(hl1.x)), int(round(hl1.y)),
		  int(round(hl2.x)), int(round(hl2.y)), BLADE_EDGE, 1)
	# blade shadow
	var sh1 : Vector2 = guard_end - perp * 1.0
	var sh2 : Vector2 = blade_end - perp * 1.0
	_line(int(round(sh1.x)), int(round(sh1.y)),
		  int(round(sh2.x)), int(round(sh2.y)), BLADE_DARK, 1)


# ============================================================================
#                              ANIMATIONS
# ============================================================================

func _draw_idle(f: int) -> void:
	# 4 frames, gentle breathing + tail sway
	var bob : float = sin(f * PI * 0.5) * 1.0
	var tail : float = sin(f * PI * 0.5) * 0.4
	_draw_squirrel({
		"pos":   Vector2(0, bob),
		"tail_phase": tail,
		"l_arm": Vector2(-1, 1 + bob * 0.3),
		"r_arm": Vector2( 1, 1 + bob * 0.3),
		"weapon": "carry",
		"weapon_ang": -90.0 + 6.0 * sin(f * PI * 0.5),
		"weapon_off": Vector2(0, -2),
		"blink": f == 3,
	})

func _draw_walk(f: int) -> void:
	# 6 frames classic walk cycle
	var phase : float = f / 6.0 * TAU
	var leg_swing : float = sin(phase) * 5.0
	var arm_swing : float = sin(phase) * 4.0
	var bob : float = abs(sin(phase * 2.0)) * -1.5
	_draw_squirrel({
		"pos":   Vector2(0, bob),
		"tail_phase": sin(phase) * 0.5,
		"l_leg": Vector2( leg_swing,  abs(sin(phase)) * -3.0),
		"r_leg": Vector2(-leg_swing,  abs(cos(phase)) * -3.0),
		"l_arm": Vector2(-arm_swing,  0),
		"r_arm": Vector2( arm_swing,  0),
		"weapon": "carry",
		"weapon_ang": -90.0 + arm_swing * 2.0,
		"weapon_off": Vector2(0, -1),
	})

func _draw_run(f: int) -> void:
	var phase : float = f / 6.0 * TAU
	var leg_swing : float = sin(phase) * 9.0
	var arm_swing : float = sin(phase) * 8.0
	var bob : float = abs(sin(phase * 2.0)) * -3.0
	_draw_squirrel({
		"pos":   Vector2(0, bob),
		"lean":  12.0,
		"tail_phase": 0.7 + sin(phase) * 0.3,
		"l_leg": Vector2( leg_swing,  -abs(sin(phase)) * 6.0),
		"r_leg": Vector2(-leg_swing,  -abs(cos(phase)) * 6.0),
		"l_arm": Vector2(-arm_swing - 2,  -2),
		"r_arm": Vector2( arm_swing + 2,  -2),
		"weapon": "carry",
		"weapon_ang": -70.0 + arm_swing * 3.0,
		"weapon_off": Vector2(0, -1),
		"mouth": "o",
	})

func _draw_crouch(f: int) -> void:
	# 3 frames: stand -> mid -> low
	var t : float = float(f) / 2.0
	_draw_squirrel({
		"pos":   Vector2(0, 0),
		"crouch": t,
		"tail_phase": -0.2 - t * 0.4,
		"l_arm": Vector2(-2, 4 * t),
		"r_arm": Vector2( 2, 4 * t),
		"weapon": "carry",
		"weapon_ang": -90.0 + 30.0 * t,
		"weapon_off": Vector2(0, -1 + 2 * t),
	})

func _draw_slide(f: int) -> void:
	# 4 frames: low slide pose, dust streaks behind
	var t : float = float(f) / 3.0
	_draw_squirrel({
		"pos":   Vector2(4, 14),         # pushed down + forward
		"crouch": 1.0,
		"lean":  35.0,
		"tail_phase": -0.8,
		"l_leg": Vector2( 14, 4),        # leg extended forward
		"r_leg": Vector2( -2, 4),
		"l_arm": Vector2(-6,  6),
		"r_arm": Vector2( 8,  4),
		"weapon": "carry",
		"weapon_ang": -30.0,
		"weapon_off": Vector2(2, 0),
		"mouth": "o",
	})
	# dust puffs behind the squirrel (right side of frame because facing=1)
	for i in 3:
		var dx : int = 8 + i * 10
		var dy : int = 80 + (i % 2) * 2 - int(t * 2.0)
		_disc(dx, dy, 3 + i, Color(0.85, 0.78, 0.65, 0.55))
		_disc(dx - 2, dy + 2, 2, Color(0.95, 0.9, 0.78, 0.4))

func _draw_slash(f: int) -> void:
	# 5 frames: wind-up -> swing -> follow-through
	# Sword angle sweeps from up-back to down-forward.
	var angles := [-160.0, -110.0, -40.0, 30.0, 60.0]
	var arm_x  := [-4.0,    0.0,   8.0, 10.0,  6.0]
	var arm_y  := [-6.0,   -8.0,  -4.0,  2.0,  4.0]
	var lean   := [-8.0,   -4.0,   6.0, 12.0,  8.0]
	_draw_squirrel({
		"pos":   Vector2(0, 0),
		"lean":  lean[f],
		"tail_phase": 0.3 + f * 0.1,
		"l_arm": Vector2(-2, 2),
		"r_arm": Vector2(arm_x[f], arm_y[f]),
		"l_leg": Vector2(-2, 0),
		"r_leg": Vector2( 3, 0),
		"weapon": "slash",
		"weapon_ang": angles[f],
		"weapon_off": Vector2.ZERO,
		"mouth": "o" if f == 2 else "n",
	})
	# motion arc on the swing frame
	if f == 2 or f == 3:
		_draw_slash_arc(f)

func _draw_slash_arc(f: int) -> void:
	# A faint white arc to show the slash trail.
	var cx : int = 60
	var cy : int = 50
	var r  : int = 26 if f == 2 else 28
	for a_deg in range(-70, 30, 4):
		var a : float = deg_to_rad(a_deg)
		var x : int = cx + int(round(cos(a) * r))
		var y : int = cy + int(round(sin(a) * r))
		_px(x, y, Color(1, 1, 1, 0.7))
		_px(x, y + 1, Color(1, 1, 1, 0.4))

func _draw_stab(f: int) -> void:
	# 5 frames: cock back -> thrust forward -> hold -> recover -> rest
	var arm_x := [-6.0, -2.0, 16.0, 14.0,  6.0]
	var arm_y := [ 0.0,  0.0,  0.0,  0.0,  1.0]
	var ang   := [-10.0,  0.0,  0.0,  0.0, -8.0]
	var lean  := [-6.0, -2.0,  8.0,  4.0,  0.0]
	_draw_squirrel({
		"pos":   Vector2(0, 0),
		"lean":  lean[f],
		"tail_phase": 0.2 + (0.5 if f == 2 else 0.0),
		"l_arm": Vector2(-3, 2),
		"r_arm": Vector2(arm_x[f], arm_y[f]),
		"l_leg": Vector2(-3, 0),
		"r_leg": Vector2( 4, 0),
		"weapon": "stab",
		"weapon_ang": ang[f],
		"weapon_off": Vector2.ZERO,
		"mouth": "o" if f == 2 else "n",
	})
	# thrust impact lines on peak frame
	if f == 2:
		for i in 4:
			_px(86 + i, 48, Color(1, 1, 1, 0.8))
			_px(86 + i, 50, Color(1, 1, 1, 0.5))
			_px(86 + i, 52, Color(1, 1, 1, 0.8))
