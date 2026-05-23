extends Node2D

# --- Level 2: hand-designed, industrial/facility theme, fully sealed ---------
# Mirrors Level.gd's contract:
#  * Same world bounds (LEVEL_LEFT..LEVEL_RIGHT, sealed floor/ceiling/walls)
#  * GROUND_TOP = 400, GROUND_BOTTOM = 720 — so all enemies, pickups and hazard
#    helpers behave identically. The level differs in palette, props, and the
#    arrangement of its 8 challenge sections.
#  * Exposes apply_player_camera(player) so Main.gd can expand camera bounds
#    after spawning the chosen character.

const MOVING_PLATFORM_SCRIPT := preload("res://scripts/MovingPlatform.gd")
const BREAK_PLATFORM_SCRIPT  := preload("res://scripts/BreakPlatform.gd")
const RANGE_SOLDIER_SCENE    := preload("res://scenes/RangeSoldier.tscn")
const JET_TROOPER_SCENE      := preload("res://scenes/JetTrooper.tscn")
const WINGED_DEMON_SCENE     := preload("res://scenes/WingedDemon.tscn")
const GREATER_DEMON_SCENE    := preload("res://scenes/GreaterDemon.tscn")
const COIN_SCENE             := preload("res://scenes/Coin.tscn")
const SPIKE_SCENE            := preload("res://scenes/Spike.tscn")
const POWERUP_SCENE          := preload("res://scenes/PowerUp.tscn")
const EXIT_DOOR_SCENE        := preload("res://scenes/ExitDoor.tscn")
const FIRE_ZONE_SCENE        := preload("res://scenes/FireZone.tscn")
const ELEC_ZONE_SCENE        := preload("res://scenes/ElectricZone.tscn")
const GRENADE_PICKUP_SCENE   := preload("res://scenes/GrenadePickup.tscn")
const LEVER_SCENE            := preload("res://scenes/Lever.tscn")
const DOOR_SCENE             := preload("res://scenes/Door.tscn")

const SKY_SCENE              := preload("res://scenes/props/Sky.tscn")
const CLOUD_SCENE            := preload("res://scenes/props/Cloud.tscn")
const ROCK_SCENE             := preload("res://scenes/props/Rock.tscn")
const CLIFF_SCENE            := preload("res://scenes/props/Cliff.tscn")

const LEVEL_LEFT:    float =    -20.0
const LEVEL_RIGHT:   float =  7520.0
const LEVEL_TOP:     float =   -60.0
const LEVEL_BOTTOM:  float =   820.0
const GROUND_TOP:    float =   400.0
const GROUND_BOTTOM: float =   720.0
const FLOOR_BOTTOM:  float =   820.0
const CEILING_BOT:   float =   -40.0

# --- Industrial palette ------------------------------------------------------
# Smoggy sky: dark navy at top, sulfur-orange near the horizon.
const COL_BG_TOP:      Color = Color(0.05, 0.06, 0.10)
const COL_BG_BOT:      Color = Color(0.45, 0.32, 0.20)
const COL_BG_HORIZON:  Color = Color(0.78, 0.42, 0.20)
# Far factory silhouettes
const COL_FAR_FACT:    Color = Color(0.14, 0.16, 0.22)
const COL_MID_FACT:    Color = Color(0.10, 0.12, 0.18)
# Walls / ceiling — riveted steel
const COL_WALL:        Color = Color(0.12, 0.13, 0.16)
const COL_WALL_HI:     Color = Color(0.22, 0.24, 0.28)
# Ground: dark concrete with a brushed steel top band
const COL_GROUND:      Color = Color(0.20, 0.22, 0.26)
const COL_GROUND_DARK: Color = Color(0.12, 0.13, 0.16)
const COL_GROUND_TOP:  Color = Color(0.55, 0.60, 0.66)
# Platforms: metal grating with a cyan-warning top stripe
const COL_PLAT:        Color = Color(0.32, 0.34, 0.38)
const COL_PLAT_TOP:    Color = Color(0.30, 0.85, 0.95)
# Moving platform — orange hydraulic piston tint
const COL_MOVE:        Color = Color(0.95, 0.58, 0.18)
# Break platform — rusted gantry
const COL_BREAK:       Color = Color(0.62, 0.32, 0.16)
# Floor and pit ambience
const COL_FLOOR:       Color = Color(0.04, 0.04, 0.06)
const COL_PIT_GLOW:    Color = Color(0.95, 0.30, 0.10, 0.20)
# Crates / props
const COL_CRATE:       Color = Color(0.50, 0.42, 0.28)
const COL_CRATE_EDGE:  Color = Color(0.28, 0.22, 0.14)
# Pipes & cables
const COL_PIPE:        Color = Color(0.45, 0.48, 0.52)
const COL_PIPE_HI:     Color = Color(0.65, 0.68, 0.72)
const COL_CABLE:       Color = Color(0.08, 0.08, 0.10)
# Signs
const COL_SIGN_BG:     Color = Color(0.90, 0.74, 0.16)
const COL_SIGN_FG:     Color = Color(0.10, 0.08, 0.04)
const COL_EXIT_HALO:   Color = Color(0.20, 0.90, 1.0, 0.18)

# Hazard / accent
const COL_NEON_CYAN:   Color = Color(0.20, 0.95, 1.00)
const COL_NEON_ORANGE: Color = Color(1.00, 0.55, 0.18)
const COL_RUST:        Color = Color(0.45, 0.22, 0.10)

# Z-index plan matches Level 1 so HUD / projectiles render the same:
#  -10..-8 parallax bg, -3 mid-bg, -1 near-bg, 0 world, 1 fg accents.

var _world: StaticBody2D

func _ready() -> void:
	_build_parallax_background()
	_build_world_container()
	_build_seal()
	_build_section_a_intake()
	_build_section_b_acid_pit()
	_build_section_c_gantry_climb()
	_build_section_d_spike_grates()
	_build_section_e_reactor_climb()
	_build_section_f_machine_gauntlet()
	_build_section_g_control_room()
	_build_section_h_smokestack_run()
	_spawn_air_demons()
	_setup_player_camera()

# -----------------------------------------------------------------------------
# Air patrol mini-bosses (winged + greater demon variants, industrial palette)
# -----------------------------------------------------------------------------
func _spawn_air_demons() -> void:
	# Steel — over Section A, weak intro variant
	_add_winged_demon(
		440.0, 200.0,
		Color(0.55, 0.60, 0.70),   # body  — gunmetal
		Color(0.30, 0.34, 0.42),   # wings — slate
		Color(0.10, 0.10, 0.12),   # horns — pitch
		Color(1.0, 0.65, 0.20),    # eye   — sodium lamp
		Color(0.90, 0.92, 0.98),   # sword — polished steel
		10, 280.0, 90.0)

	# Copper — patrols section C catwalk airspace
	_add_winged_demon(
		1880.0, 120.0,
		Color(0.85, 0.50, 0.22),   # body  — copper
		Color(0.55, 0.28, 0.12),   # wings — burnt rust
		Color(0.12, 0.08, 0.04),
		Color(1.00, 0.90, 0.40),
		Color(0.95, 0.82, 0.55),
		12, 360.0, 110.0)

	# Toxic — patrols above section E reactor climb
	_add_winged_demon(
		3300.0, 100.0,
		Color(0.55, 0.85, 0.30),   # body  — toxic green
		Color(0.30, 0.55, 0.18),
		Color(0.06, 0.10, 0.04),
		Color(0.95, 1.00, 0.55),
		Color(0.85, 1.00, 0.75),
		13, 360.0, 130.0)

	# Plasma — heaviest, guards section G's control airspace
	_add_winged_demon(
		4880.0, 140.0,
		Color(0.20, 0.45, 0.85),   # body  — plasma blue
		Color(0.10, 0.22, 0.55),
		Color(0.04, 0.06, 0.12),
		Color(0.55, 0.95, 1.00),
		Color(0.75, 0.92, 1.00),
		16, 420.0, 130.0)

	# --- Greater demons (heavier tier) --------------------------------------
	# Furnace — section D/E transition
	_add_greater_demon(2900.0, 130.0, Color(1.10, 0.85, 0.70), 24, 460.0, 130.0)
	# Voltaic — final guard at the end of section H, just before the exit
	_add_greater_demon(5780.0, 150.0, Color(0.75, 0.95, 1.10), 32, 360.0, 120.0)

# -----------------------------------------------------------------------------
# Parallax background — smoggy industrial sky with distant factories.
# -----------------------------------------------------------------------------
func _build_parallax_background() -> void:
	var pbg := ParallaxBackground.new()
	add_child(pbg)

	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2.ZERO
	pbg.add_child(sky_layer)
	_paint_sky_gradient(sky_layer)

	# Drifting smoke clouds — low, slow
	var smoke_layer := ParallaxLayer.new()
	smoke_layer.motion_scale = Vector2(0.10, 0.0)
	smoke_layer.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(smoke_layer)
	_paint_smoke_clouds(smoke_layer)

	# Far factory skyline — distant stacks and silos
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.22, 0.0)
	far.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(far)
	_paint_far_factories(far)

	# Mid-ground factories — taller stacks with red blinking lights
	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.45, 0.05)
	mid.motion_mirroring = Vector2(960.0, 0.0)
	pbg.add_child(mid)
	_paint_mid_factories(mid)

	# Foreground pipes and antennas (world-space, behind ground)
	_paint_near_pipes()

func _paint_sky_gradient(parent: Node) -> void:
	var sky := SKY_SCENE.instantiate()
	sky.top_color = COL_BG_TOP
	sky.mid_color = COL_BG_BOT
	sky.horizon_color = COL_BG_HORIZON
	sky.rect_size = Vector2(2560.0, 1040.0)
	sky.origin = Vector2(-640.0, -200.0)
	sky.bands = 14
	sky.show_sun = true
	sky.sun_position = Vector2(880.0, 220.0)
	sky.sun_radius = 22.0
	(sky as CanvasItem).z_index = -10
	parent.add_child(sky)

func _paint_smoke_clouds(parent: Node) -> void:
	var data: Array = [
		{"pos": Vector2(140.0, 200.0), "w": 130.0, "seed": 7},
		{"pos": Vector2(460.0, 110.0), "w":  92.0, "seed": 13},
		{"pos": Vector2(760.0, 220.0), "w": 160.0, "seed": 23},
		{"pos": Vector2(1060.0, 150.0),"w": 108.0, "seed": 31},
	]
	for d in data:
		var c := CLOUD_SCENE.instantiate()
		c.cloud_width  = float(d["w"])
		c.cloud_height = float(d["w"]) * 0.34
		c.drift_speed  = 5.0
		c.wrap_width   = 1280.0
		c.rand_seed    = int(d["seed"])
		(c as CanvasItem).z_index = -9
		(c as Node2D).position = d["pos"] as Vector2
		# Tint the prop scene's modulate so reused cloud art reads as smoke
		(c as CanvasItem).modulate = Color(0.55, 0.50, 0.45, 0.85)
		parent.add_child(c)

func _paint_far_factories(parent: Node) -> void:
	# Sawtooth silhouette of distant factory roofs + stacks.
	var x: float = -40.0
	var i: int = 0
	while x < 1320.0:
		var w: float = 140.0 + float(i % 4) * 30.0
		var h: float = 120.0 + float(i % 3) * 40.0
		var poly := Polygon2D.new()
		poly.z_index = -9
		poly.color = COL_FAR_FACT
		var base_y: float = 640.0
		poly.polygon = PackedVector2Array([
			Vector2(x,            base_y),
			Vector2(x,            base_y - h),
			Vector2(x + w * 0.35, base_y - h),
			Vector2(x + w * 0.50, base_y - h * 0.7),
			Vector2(x + w * 0.65, base_y - h),
			Vector2(x + w,        base_y - h),
			Vector2(x + w,        base_y),
		])
		parent.add_child(poly)

		# A stack rising from the roof
		if i % 2 == 0:
			var stack := ColorRect.new()
			stack.z_index = -9
			stack.color = COL_FAR_FACT.lightened(0.05)
			stack.offset_left  = x + w * 0.18
			stack.offset_right = x + w * 0.28
			stack.offset_top   = base_y - h - 50.0
			stack.offset_bottom = base_y - h
			parent.add_child(stack)

		x += w * 0.82
		i += 1

func _paint_mid_factories(parent: Node) -> void:
	# Taller factory blocks with chimney lights — closer to play area.
	var x: float = 0.0
	var i: int = 0
	while x < 1280.0:
		var w: float = 120.0 + float(i % 3) * 24.0
		var h: float = 180.0 + float(i % 4) * 30.0
		var base_y: float = 600.0

		var body := ColorRect.new()
		body.z_index = -8
		body.offset_left = x
		body.offset_right = x + w
		body.offset_top   = base_y - h
		body.offset_bottom = base_y
		body.color = COL_MID_FACT
		parent.add_child(body)

		# Stack on top
		var stack := ColorRect.new()
		stack.z_index = -8
		stack.offset_left  = x + w * 0.62
		stack.offset_right = x + w * 0.78
		stack.offset_top   = base_y - h - 70.0
		stack.offset_bottom = base_y - h
		stack.color = COL_MID_FACT
		parent.add_child(stack)

		# Red blinker
		var light := ColorRect.new()
		light.z_index = -8
		light.offset_left  = x + w * 0.66
		light.offset_right = x + w * 0.74
		light.offset_top   = base_y - h - 76.0
		light.offset_bottom = base_y - h - 70.0
		light.color = Color(0.95, 0.20, 0.18)
		parent.add_child(light)

		# Lit windows — tiny warm rectangles dotted across the body
		for wy in range(3):
			for wx in range(4):
				if ((wx + wy + i) % 5) == 0:
					continue
				var win := ColorRect.new()
				win.z_index = -8
				win.color = Color(0.95, 0.78, 0.32, 0.95)
				var cx: float = x + 10.0 + float(wx) * (w - 20.0) / 4.0
				var cy: float = base_y - h + 24.0 + float(wy) * 40.0
				win.offset_left = cx
				win.offset_right = cx + 5.0
				win.offset_top = cy
				win.offset_bottom = cy + 7.0
				parent.add_child(win)

		x += w * 1.05
		i += 1

# Decorative near-bg pipes drawn at world coords; skipped over pits.
func _paint_near_pipes() -> void:
	var pipe_ys: Array = [80.0, 140.0]
	for py in pipe_ys:
		var x: float = 0.0
		while x < LEVEL_RIGHT:
			# Long horizontal pipe segment
			var seg_w: float = randf_range(180.0, 320.0)
			if _is_on_ground((x + seg_w * 0.5)):
				_add_bg_pipe_h(x, py, seg_w)
				if int(x) % 360 < 60:
					_add_bg_antenna(x + seg_w * 0.5, py)
			x += seg_w + randf_range(20.0, 80.0)

func _add_bg_pipe_h(x: float, y: float, w: float) -> void:
	var pipe := ColorRect.new()
	pipe.z_index = -1
	pipe.offset_left = x
	pipe.offset_right = x + w
	pipe.offset_top = y
	pipe.offset_bottom = y + 12.0
	pipe.color = COL_PIPE
	add_child(pipe)
	var hi := ColorRect.new()
	hi.z_index = -1
	hi.offset_left = x
	hi.offset_right = x + w
	hi.offset_top = y
	hi.offset_bottom = y + 3.0
	hi.color = COL_PIPE_HI
	add_child(hi)
	# Flanges every 60 px
	var fx: float = x + 30.0
	while fx < x + w - 8.0:
		var f := ColorRect.new()
		f.z_index = -1
		f.offset_left = fx - 2.0
		f.offset_right = fx + 2.0
		f.offset_top = y - 2.0
		f.offset_bottom = y + 14.0
		f.color = COL_PIPE_HI.darkened(0.25)
		add_child(f)
		fx += 60.0

func _add_bg_pipe_v(x: float, y_top: float, y_bot: float) -> void:
	var pipe := ColorRect.new()
	pipe.z_index = -1
	pipe.offset_left = x
	pipe.offset_right = x + 10.0
	pipe.offset_top = y_top
	pipe.offset_bottom = y_bot
	pipe.color = COL_PIPE
	add_child(pipe)
	var hi := ColorRect.new()
	hi.z_index = -1
	hi.offset_left = x
	hi.offset_right = x + 3.0
	hi.offset_top = y_top
	hi.offset_bottom = y_bot
	hi.color = COL_PIPE_HI
	add_child(hi)

func _add_bg_antenna(x: float, y: float) -> void:
	var a := ColorRect.new()
	a.z_index = -1
	a.offset_left = x - 1.0
	a.offset_right = x + 1.0
	a.offset_top = y - 40.0
	a.offset_bottom = y
	a.color = COL_PIPE_HI.darkened(0.20)
	add_child(a)
	var blink := ColorRect.new()
	blink.z_index = -1
	blink.offset_left = x - 3.0
	blink.offset_right = x + 3.0
	blink.offset_top = y - 46.0
	blink.offset_bottom = y - 40.0
	blink.color = Color(1.0, 0.30, 0.20)
	add_child(blink)

# Ground continuity — used by background painters to skip over pits.
const GROUND_SPANS := [
	Vector2(0.0, 700.0),
	Vector2(1400.0, 2100.0),
	Vector2(2100.0, 2220.0),
	Vector2(2380.0, 2520.0),
	Vector2(2680.0, 3500.0),
	Vector2(4500.0, 6000.0),
	Vector2(7000.0, 7500.0),
]

func _is_on_ground(x: float, margin: float = 24.0) -> bool:
	for s in GROUND_SPANS:
		if x >= s.x + margin and x <= s.y - margin:
			return true
	return false

# -----------------------------------------------------------------------------
# World container + primitive helpers
# -----------------------------------------------------------------------------
func _build_world_container() -> void:
	_world = StaticBody2D.new()
	_world.collision_layer = 1
	_world.collision_mask = 0
	add_child(_world)

func _add_solid(x: float, y: float, w: float, h: float, body: Color, top_band: float = 0.0, top_color: Color = COL_GROUND_TOP) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(x + w * 0.5, y + h * 0.5)
	_world.add_child(shape)

	var fill := ColorRect.new()
	fill.offset_left = x
	fill.offset_top = y
	fill.offset_right = x + w
	fill.offset_bottom = y + h
	fill.color = body
	_world.add_child(fill)

	if top_band > 0.0:
		var top := ColorRect.new()
		top.offset_left = x
		top.offset_top = y
		top.offset_right = x + w
		top.offset_bottom = y + top_band
		top.color = top_color
		_world.add_child(top)

func _add_platform(x: float, y: float, w: float) -> void:
	# Static catwalk — 14 tall with a cyan warning stripe on top.
	_add_solid(x, y, w, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	# Underside bolts
	var b: int = 0
	while float(b) * 32.0 < w - 12.0:
		var bolt := ColorRect.new()
		bolt.z_index = 0
		bolt.color = COL_WALL_HI
		var bx: float = x + 8.0 + float(b) * 32.0
		bolt.offset_left = bx
		bolt.offset_right = bx + 3.0
		bolt.offset_top = y + 14.0
		bolt.offset_bottom = y + 17.0
		_world.add_child(bolt)
		b += 1

func _add_ground(x_start: float, x_end: float) -> void:
	_add_solid(x_start, GROUND_TOP, x_end - x_start, GROUND_BOTTOM - GROUND_TOP, COL_GROUND, 3.0, COL_GROUND_TOP)
	# Dark soil/concrete band under the top stripe
	_paint_dark_band(x_start, x_end, GROUND_TOP + 8.0, GROUND_TOP + 22.0)
	# Hatch lines for industrial floor pattern
	_paint_floor_hatches(x_start, x_end)
	# Scatter crates and conduit boxes
	var rx: float = x_start + randf_range(60.0, 140.0)
	while rx < x_end - 80.0:
		_add_floor_conduit(rx)
		rx += randf_range(180.0, 320.0)

func _paint_dark_band(x_start: float, x_end: float, y_top: float, y_bot: float) -> void:
	var band := ColorRect.new()
	band.z_index = 0
	band.offset_left = x_start
	band.offset_right = x_end
	band.offset_top = y_top
	band.offset_bottom = y_bot
	band.color = COL_GROUND_DARK
	add_child(band)

func _paint_floor_hatches(x_start: float, x_end: float) -> void:
	# Thin vertical lines every 64px on the ground top — reads as floor plating.
	var x: float = x_start + 32.0
	while x < x_end - 8.0:
		var ln := ColorRect.new()
		ln.z_index = 0
		ln.offset_left = x
		ln.offset_right = x + 1.0
		ln.offset_top = GROUND_TOP + 4.0
		ln.offset_bottom = GROUND_TOP + 18.0
		ln.color = COL_GROUND.darkened(0.30)
		add_child(ln)
		x += 64.0

func _add_floor_conduit(x: float) -> void:
	# A short knee-high conduit box (decorative, no collision) on the floor.
	var box := ColorRect.new()
	box.z_index = -1
	box.offset_left = x - 12.0
	box.offset_right = x + 12.0
	box.offset_top = GROUND_TOP - 14.0
	box.offset_bottom = GROUND_TOP
	box.color = COL_WALL_HI
	add_child(box)
	var trim := ColorRect.new()
	trim.z_index = -1
	trim.offset_left = x - 12.0
	trim.offset_right = x + 12.0
	trim.offset_top = GROUND_TOP - 14.0
	trim.offset_bottom = GROUND_TOP - 11.0
	trim.color = COL_NEON_CYAN
	add_child(trim)

func _add_crate(x: float, y: float, size: float = 22.0) -> void:
	# Solid crate (collidable). Identical mechanics to Level 1's _add_rock so
	# enemies and players can still stand on it.
	_add_solid(x, y, size, size, COL_CRATE, 2.0, COL_CRATE_EDGE)
	var hi := ColorRect.new()
	hi.offset_left = x + size - 4.0
	hi.offset_top = y + 2.0
	hi.offset_right = x + size - 2.0
	hi.offset_bottom = y + size - 2.0
	hi.color = COL_CRATE_EDGE
	_world.add_child(hi)

func _add_spike(x: float, y: float = GROUND_TOP - 8.0) -> void:
	var spike := SPIKE_SCENE.instantiate() as StaticBody2D
	spike.position = Vector2(x, y)
	add_child(spike)

func _add_spike_row(x_start: float, x_end: float, y: float) -> void:
	var glow := ColorRect.new()
	glow.z_index = -1
	glow.offset_left = x_start
	glow.offset_top = y - 32.0
	glow.offset_right = x_end
	glow.offset_bottom = y + 4.0
	glow.color = COL_PIT_GLOW
	add_child(glow)

	var x: float = x_start + 16.0
	while x + 16.0 <= x_end:
		_add_spike(x, y)
		x += 32.0

func _add_moving_platform(x: float, y: float, w: float) -> void:
	var mp := AnimatableBody2D.new()
	mp.set_script(MOVING_PLATFORM_SCRIPT)
	mp.setup(x, y, w, COL_MOVE)
	add_child(mp)

func _add_break_platform(x: float, y: float, w: float) -> void:
	var bp := StaticBody2D.new()
	bp.set_script(BREAK_PLATFORM_SCRIPT)
	bp.setup(x, y, w, COL_BREAK)
	add_child(bp)

func _add_soldier(x: float, y: float, patrol: float = 320.0, speed: float = -1.0) -> void:
	var s := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
	s.position = Vector2(x, y)
	s.patrol_distance = patrol
	if speed >= 0.0:
		s.patrol_speed = speed
	$Enemies.add_child(s)

func _add_turret(x: float, y: float) -> void:
	_add_soldier(x, y, 1.0, 0.0)

func _add_jet_trooper(x: float, y: float, hp: int = 9, patrol_w: float = 280.0, patrol_h: float = 60.0) -> void:
	var jt := JET_TROOPER_SCENE.instantiate() as JetTrooper
	jt.position = Vector2(x, y)
	jt.max_health = hp
	jt.patrol_width = patrol_w
	jt.patrol_height = patrol_h
	$Enemies.add_child(jt)

func _add_greater_demon(x: float, y: float, tint: Color = Color.WHITE, hp: int = 24, patrol_w: float = 380.0, patrol_h: float = 100.0) -> void:
	var d := GREATER_DEMON_SCENE.instantiate() as GreaterDemon
	d.position = Vector2(x, y)
	d.sprite_tint = tint
	d.max_health = hp
	d.patrol_width = patrol_w
	d.patrol_height = patrol_h
	$Enemies.add_child(d)

func _add_winged_demon(x: float, y: float, body: Color, wing: Color, horn: Color, eye: Color, sword: Color, hp: int = 12, patrol_w: float = 320.0, patrol_h: float = 80.0) -> void:
	var d := WINGED_DEMON_SCENE.instantiate() as WingedDemon
	d.position = Vector2(x, y)
	d.tint = body
	d.wing_color = wing
	d.wing_edge_color = wing.darkened(0.35)
	d.horn_color = horn
	d.eye_color = eye
	d.sword_color = sword
	d.max_health = hp
	d.patrol_width = patrol_w
	d.patrol_height = patrol_h
	$Enemies.add_child(d)

func _add_coin(x: float, y: float) -> void:
	var c := COIN_SCENE.instantiate()
	c.position = Vector2(x, y)
	$Coins.add_child(c)

func _add_coin_row(x_start: float, y: float, count: int, step: float = 24.0) -> void:
	for i in range(count):
		_add_coin(x_start + float(i) * step, y)

func _add_coin_arc(x_center: float, y_apex: float, count: int, span: float = 120.0) -> void:
	var half := span * 0.5
	for i in range(count):
		var t: float = -1.0 + 2.0 * float(i) / float(maxi(count - 1, 1))
		var cx: float = x_center + t * half
		var cy: float = y_apex + (t * t) * 28.0
		_add_coin(cx, cy)

func _add_powerup(x: float, y: float) -> void:
	var pu := POWERUP_SCENE.instantiate() as PowerUp
	pu.position = Vector2(x, y)
	add_child(pu)

func _add_exit(x: float, y: float) -> void:
	var ed := EXIT_DOOR_SCENE.instantiate()
	ed.position = Vector2(x, y)
	add_child(ed)
	var halo := ColorRect.new()
	halo.z_index = -1
	halo.offset_left = x - 48.0
	halo.offset_top = y - 80.0
	halo.offset_right = x + 48.0
	halo.offset_bottom = y + 12.0
	halo.color = COL_EXIT_HALO
	add_child(halo)

func _add_grenade_pickup(x: float, y: float, type: int = 0) -> void:
	var gp := GRENADE_PICKUP_SCENE.instantiate()
	(gp as Node2D).position = Vector2(x, y)
	gp.setup(type)
	add_child(gp)

# Pulsing fire vent — same mechanics as Level 1, with a redrawn "vent" prop
# tinted to fit the industrial palette.
func _add_fire_pulse(x: float, y: float, period: float = 6.0, phase: float = 0.0) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	add_child(node)

	var warn := ColorRect.new()
	warn.z_index = -1
	warn.color = Color(0.95, 0.40, 0.10, 0.22)
	warn.offset_left = -32.0
	warn.offset_top = -10.0
	warn.offset_right = 32.0
	warn.offset_bottom = 8.0
	node.add_child(warn)

	var vent := ColorRect.new()
	vent.offset_left = -14.0
	vent.offset_top = 4.0
	vent.offset_right = 14.0
	vent.offset_bottom = 10.0
	vent.color = COL_WALL
	node.add_child(vent)
	var rim := ColorRect.new()
	rim.offset_left = -14.0
	rim.offset_top = 4.0
	rim.offset_right = 14.0
	rim.offset_bottom = 6.0
	rim.color = COL_NEON_ORANGE
	node.add_child(rim)

	var timer := Timer.new()
	timer.wait_time = period
	timer.one_shot = false
	timer.autostart = false
	node.add_child(timer)

	var fire_at := func() -> void:
		if not is_instance_valid(node):
			return
		var fz := FIRE_ZONE_SCENE.instantiate()
		add_child(fz)
		(fz as Node2D).global_position = node.global_position

	timer.timeout.connect(fire_at)

	var delay := maxf(phase, 0.05)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(timer):
			fire_at.call()
			timer.start()
	)

func _add_elec_pulse(x: float, y: float, period: float = 1.9, phase: float = 0.0) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	add_child(node)

	# Warning marker — small cyan cross
	var marker_v := ColorRect.new()
	marker_v.color = Color(0.55, 0.85, 1.0, 0.55)
	marker_v.offset_left = -1.5
	marker_v.offset_top = -8.0
	marker_v.offset_right = 1.5
	marker_v.offset_bottom = 8.0
	node.add_child(marker_v)
	var marker_h := ColorRect.new()
	marker_h.color = Color(0.55, 0.85, 1.0, 0.55)
	marker_h.offset_left = -8.0
	marker_h.offset_top = -1.5
	marker_h.offset_right = 8.0
	marker_h.offset_bottom = 1.5
	node.add_child(marker_h)

	# Ceiling-mounted arc emitter prop
	var emitter := ColorRect.new()
	emitter.offset_left = -8.0
	emitter.offset_top = -36.0
	emitter.offset_right = 8.0
	emitter.offset_bottom = -28.0
	emitter.color = COL_WALL_HI
	node.add_child(emitter)
	var lens := ColorRect.new()
	lens.offset_left = -5.0
	lens.offset_top = -30.0
	lens.offset_right = 5.0
	lens.offset_bottom = -28.0
	lens.color = COL_NEON_CYAN
	node.add_child(lens)

	var timer := Timer.new()
	timer.wait_time = period
	timer.one_shot = false
	timer.autostart = false
	node.add_child(timer)

	var fire_at := func() -> void:
		if not is_instance_valid(node):
			return
		var ez := ELEC_ZONE_SCENE.instantiate()
		add_child(ez)
		(ez as Node2D).global_position = node.global_position

	timer.timeout.connect(fire_at)

	var delay := maxf(phase, 0.05)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(timer):
			timer.start()
	)

# -----------------------------------------------------------------------------
# Decorative prop helpers
# -----------------------------------------------------------------------------
func _add_sign(x: float, y: float, glyph_color: Color = COL_SIGN_FG) -> void:
	var post := ColorRect.new()
	post.z_index = -1
	post.offset_left = x - 1.0
	post.offset_top = y
	post.offset_right = x + 1.0
	post.offset_bottom = y + 24.0
	post.color = Color(0.18, 0.16, 0.12)
	add_child(post)

	var face := ColorRect.new()
	face.z_index = -1
	face.offset_left = x - 10.0
	face.offset_top = y - 12.0
	face.offset_right = x + 10.0
	face.offset_bottom = y + 4.0
	face.color = COL_SIGN_BG
	add_child(face)

	var stem := ColorRect.new()
	stem.z_index = -1
	stem.offset_left = x - 1.0
	stem.offset_top = y - 9.0
	stem.offset_right = x + 1.0
	stem.offset_bottom = y - 2.0
	stem.color = glyph_color
	add_child(stem)
	var dot := ColorRect.new()
	dot.z_index = -1
	dot.offset_left = x - 1.0
	dot.offset_top = y
	dot.offset_right = x + 1.0
	dot.offset_bottom = y + 2.0
	dot.color = glyph_color
	add_child(dot)

func _add_arrow_sign(x: float, y: float) -> void:
	var face := ColorRect.new()
	face.z_index = -1
	face.offset_left = x - 14.0
	face.offset_top = y - 6.0
	face.offset_right = x + 14.0
	face.offset_bottom = y + 6.0
	face.color = COL_SIGN_BG
	add_child(face)
	for i in range(3):
		var chev := ColorRect.new()
		chev.z_index = -1
		chev.offset_left = x - 8.0 + float(i) * 6.0
		chev.offset_top = y - 3.0
		chev.offset_right = x - 5.0 + float(i) * 6.0
		chev.offset_bottom = y + 3.0
		chev.color = COL_SIGN_FG
		add_child(chev)

func _add_pit_depth(x_start: float, x_end: float) -> void:
	var top: float = GROUND_TOP + 12.0
	var bot: float = GROUND_BOTTOM
	var steps := 4
	for i in steps:
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var band := ColorRect.new()
		band.z_index = -2
		band.offset_left = x_start
		band.offset_top = top + (bot - top) * t0
		band.offset_right = x_end
		band.offset_bottom = top + (bot - top) * t1
		var c := Color(0.02, 0.03, 0.05)
		c.a = 0.20 + float(i) * 0.14
		band.color = c
		add_child(band)

	# Hot orange under-glow at the bottom of the pit — molten/acid feel
	var glow := ColorRect.new()
	glow.z_index = -2
	glow.offset_left = x_start
	glow.offset_top = GROUND_BOTTOM - 18.0
	glow.offset_right = x_end
	glow.offset_bottom = GROUND_BOTTOM - 8.0
	glow.color = Color(0.95, 0.32, 0.10, 0.40)
	add_child(glow)

func _add_lever_door(lever_pos: Vector2, door_pos: Vector2) -> void:
	var uid := "%d_%d" % [int(door_pos.x), int(door_pos.y)]

	var door := DOOR_SCENE.instantiate() as Door
	door.name = "Door_" + uid
	door.position = door_pos
	add_child(door)

	var lever := LEVER_SCENE.instantiate() as Lever
	lever.position = lever_pos
	lever.connected_doors = [NodePath("../Door_" + uid)]
	add_child(lever)

# -----------------------------------------------------------------------------
# Sealing: outer walls, ceiling, full-width bottom floor
# -----------------------------------------------------------------------------
func _build_seal() -> void:
	_add_solid(LEVEL_LEFT, LEVEL_TOP, -LEVEL_LEFT, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	_add_solid(LEVEL_RIGHT - 20.0, LEVEL_TOP, 20.0, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	_add_solid(LEVEL_LEFT, LEVEL_TOP, LEVEL_RIGHT - LEVEL_LEFT, CEILING_BOT - LEVEL_TOP, COL_WALL)
	_add_solid(LEVEL_LEFT, GROUND_BOTTOM, LEVEL_RIGHT - LEVEL_LEFT, FLOOR_BOTTOM - GROUND_BOTTOM, COL_FLOOR)

# -----------------------------------------------------------------------------
# Section A — Intake (0..700)
# Tutorial-ish entry hall: catwalks, intro coin trail, one patrol, grenade pickup.
# -----------------------------------------------------------------------------
func _build_section_a_intake() -> void:
	_add_ground(0.0, 700.0)

	_add_bg_pipe_v(40.0, 120.0, 396.0)
	_add_bg_pipe_h(60.0, 60.0, 240.0)
	_add_sign(80.0, 380.0)

	# Coin breadcrumb to the right
	_add_coin(130.0, 374.0)
	_add_coin(170.0, 364.0)
	_add_coin(210.0, 354.0)

	# Stepping catwalks
	_add_platform(160.0, 320.0, 96.0)
	_add_platform(340.0, 240.0, 96.0)
	_add_platform(540.0, 320.0, 96.0)

	_add_coin(208.0, 290.0)
	_add_coin(388.0, 210.0)
	_add_coin(588.0, 290.0)

	# Reward arc above the middle catwalk
	_add_coin_arc(388.0, 170.0, 5, 100.0)

	_add_grenade_pickup(388.0, 218.0, 0)

	# Crate stack
	_add_crate(620.0, 378.0)
	_add_crate(620.0, 356.0)
	_add_crate(642.0, 378.0)
	_add_coin(631.0, 332.0)

	_add_soldier(450.0, 375.0)

# -----------------------------------------------------------------------------
# Section B — Acid pit (700..1400)
# Spike floor with hot under-glow, two moving conveyor platforms, fire vent.
# -----------------------------------------------------------------------------
func _build_section_b_acid_pit() -> void:
	_add_spike_row(720.0, 1380.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(720.0, 1380.0)

	_add_bg_pipe_h(700.0, 100.0, 700.0)

	# Two moving "conveyor" platforms with a static rest island between them
	_add_moving_platform(780.0, 380.0, 120.0)
	_add_platform(1000.0, 320.0, 96.0)
	_add_moving_platform(1180.0, 380.0, 120.0)

	# Pulsing fire vent rising from the floor between platforms
	_add_fire_pulse(1100.0, GROUND_BOTTOM - 14.0, 6.0, 1.0)

	_add_coin(840.0, 350.0)
	_add_coin(1048.0, 290.0)
	_add_coin(1240.0, 350.0)
	_add_coin_arc(1048.0, 200.0, 5, 140.0)

	_add_sign(1100.0, 100.0)

	_add_grenade_pickup(900.0, 348.0, 1)

# -----------------------------------------------------------------------------
# Section C — Gantry climb (1400..2100)
# Vertical break-platform stack with a lever puzzle that opens a side cargo
# door at ground level revealing a powerup alcove.
# -----------------------------------------------------------------------------
func _build_section_c_gantry_climb() -> void:
	_add_ground(1400.0, 2100.0)

	_add_bg_pipe_v(1418.0, 80.0, 400.0)
	_add_bg_pipe_h(1418.0, 80.0, 660.0)

	# Break-platform stair
	_add_break_platform(1430.0, 320.0, 80.0)
	_add_break_platform(1570.0, 240.0, 80.0)
	_add_break_platform(1710.0, 160.0, 80.0)

	# Top landing
	_add_platform(1850.0, 100.0, 160.0)
	_add_coin_row(1900.0, 70.0, 4, 24.0)

	_add_coin(1470.0, 290.0)
	_add_coin(1610.0, 210.0)
	_add_coin(1750.0, 130.0)

	# Lever opens cargo door at x=2010 (right of the section, behind which sits
	# a powerup + grenade alcove).
	_add_lever_door(Vector2(1950.0, 92.0), Vector2(2010.0, 368.0))

	# Alcove (decorative ceiling beam + contents)
	_add_solid(2020.0, 350.0, 80.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_powerup(2060.0, 374.0)
	_add_coin_row(2040.0, 380.0, 3, 18.0)
	_add_grenade_pickup(2090.0, 372.0, 2)

	# Drop-down catwalk on the right (skip-the-lever path)
	_add_platform(2010.0, 220.0, 96.0)

	_add_soldier(1500.0, 375.0)
	_add_soldier(1900.0, 375.0, 180.0)

# -----------------------------------------------------------------------------
# Section D — Spike grates (2100..2900)
# Two grate-gap pits with electrified arc above the first.
# -----------------------------------------------------------------------------
func _build_section_d_spike_grates() -> void:
	_add_ground(2100.0, 2220.0)
	_add_spike_row(2220.0, 2380.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(2220.0, 2380.0)
	_add_ground(2380.0, 2520.0)
	_add_spike_row(2520.0, 2680.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(2520.0, 2680.0)
	_add_ground(2680.0, 2900.0)

	# Mid-pit help
	_add_platform(2270.0, 340.0, 80.0)
	_add_moving_platform(2555.0, 340.0, 100.0)

	_add_elec_pulse(2310.0, 300.0, 1.9, 0.4)

	_add_coin(2305.0, 310.0)
	_add_coin(2585.0, 310.0)
	_add_coin(2445.0, 374.0)
	_add_coin_arc(2445.0, 290.0, 5, 90.0)

	_add_grenade_pickup(2450.0, 372.0, 0)

	_add_crate(2820.0, 378.0)
	_add_crate(2820.0, 356.0)

	_add_bg_pipe_h(2120.0, 80.0, 760.0)

	_add_soldier(2460.0, 375.0, 140.0)
	_add_soldier(2790.0, 375.0, 200.0)

# -----------------------------------------------------------------------------
# Section E — Reactor climb (2900..3500)
# Vertical break-platform climb up to a powerup, with a turret defending and
# a fire vent mid-climb.
# -----------------------------------------------------------------------------
func _build_section_e_reactor_climb() -> void:
	_add_ground(2900.0, 3500.0)

	# Reactor cooling tower silhouettes (reuse Cliff prop with neutral colors)
	var c1 := CLIFF_SCENE.instantiate()
	c1.cliff_width  = 120.0
	c1.cliff_height = 340.0
	c1.mossy        = false
	(c1 as Node2D).position = Vector2(2880.0, 60.0)
	(c1 as CanvasItem).z_index = -2
	(c1 as CanvasItem).modulate = Color(0.45, 0.48, 0.55)
	add_child(c1)

	var c2 := CLIFF_SCENE.instantiate()
	c2.cliff_width  = 140.0
	c2.cliff_height = 300.0
	c2.mossy        = false
	(c2 as Node2D).position = Vector2(3340.0, 100.0)
	(c2 as CanvasItem).z_index = -2
	(c2 as CanvasItem).modulate = Color(0.50, 0.52, 0.58)
	add_child(c2)

	_add_bg_pipe_v(2950.0, 60.0, 400.0)
	_add_bg_pipe_v(3300.0, 60.0, 400.0)
	_add_bg_pipe_h(2950.0, 60.0, 358.0)

	_add_break_platform(2970.0, 320.0, 80.0)
	_add_break_platform(3120.0, 240.0, 80.0)
	_add_break_platform(3270.0, 160.0, 80.0)

	_add_platform(3380.0, 80.0, 140.0)
	_add_powerup(3450.0, 50.0)

	_add_coin(3010.0, 290.0)
	_add_coin(3160.0, 210.0)
	_add_coin(3310.0, 130.0)
	_add_coin(3430.0, 50.0)

	# Side cubby
	_add_solid(2910.0, 200.0, 56.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_coin_row(2920.0, 174.0, 3, 16.0)

	_add_fire_pulse(3070.0, 314.0, 5.5, 1.6)

	# Turret defending the powerup perch
	_add_turret(3410.0, 60.0)

	_add_platform(3520.0, 200.0, 96.0)
	_add_coin(3568.0, 174.0)

	_add_soldier(3050.0, 375.0, 260.0)
	_add_soldier(3350.0, 375.0, 220.0)

# -----------------------------------------------------------------------------
# Section F — Machine gauntlet (3500..4500)
# Long spike pit traversed via mixed moving + static platforms with two fire
# vents and a jet-trooper mini-boss patrolling the airspace.
# -----------------------------------------------------------------------------
func _build_section_f_machine_gauntlet() -> void:
	_add_spike_row(3520.0, 4480.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(3520.0, 4480.0)

	var darken := ColorRect.new()
	darken.z_index = -2
	darken.offset_left = 3520.0
	darken.offset_top = 360.0
	darken.offset_right = 4480.0
	darken.offset_bottom = GROUND_BOTTOM
	darken.color = Color(0.02, 0.03, 0.05, 0.40)
	add_child(darken)

	_add_moving_platform(3560.0, 370.0, 120.0)
	_add_platform(3760.0, 300.0, 96.0)
	_add_moving_platform(3900.0, 320.0, 120.0)
	_add_platform(4080.0, 380.0, 96.0)
	_add_moving_platform(4220.0, 320.0, 120.0)
	_add_platform(4380.0, 380.0, 96.0)

	_add_fire_pulse(3830.0, GROUND_BOTTOM - 14.0, 6.0, 0.6)
	_add_fire_pulse(4150.0, GROUND_BOTTOM - 14.0, 6.0, 3.4)

	_add_grenade_pickup(3790.0, 268.0, 1)
	_add_grenade_pickup(4110.0, 348.0, 2)

	_add_coin(3608.0, 340.0)
	_add_coin(3808.0, 270.0)
	_add_coin(3960.0, 290.0)
	_add_coin(4128.0, 350.0)
	_add_coin(4280.0, 290.0)
	_add_coin(4408.0, 350.0)
	_add_coin_arc(3960.0, 220.0, 5, 100.0)

	_add_bg_pipe_h(3520.0, 60.0, 960.0)

	# Mini-boss patrolling the full pit airspace
	_add_jet_trooper(4000.0, 180.0, 10, 820.0, 110.0)

# -----------------------------------------------------------------------------
# Section G — Control room (4500..5200)
# Lever + door gate at section's end, electrified arc between two break-platforms.
# -----------------------------------------------------------------------------
func _build_section_g_control_room() -> void:
	_add_ground(4500.0, 5200.0)

	# Tall reactor-style backdrop on the right
	var c := CLIFF_SCENE.instantiate()
	c.cliff_width  = 110.0
	c.cliff_height = 320.0
	c.mossy        = false
	(c as Node2D).position = Vector2(5120.0, 80.0)
	(c as CanvasItem).z_index = -2
	(c as CanvasItem).modulate = Color(0.42, 0.45, 0.50)
	add_child(c)

	_add_platform(4540.0, 320.0, 96.0)
	_add_break_platform(4700.0, 280.0, 80.0)
	_add_platform(4860.0, 220.0, 120.0)
	_add_break_platform(5020.0, 280.0, 80.0)
	_add_moving_platform(4720.0, 160.0, 100.0)

	_add_elec_pulse(4860.0, 180.0, 1.8, 0.9)

	# Door blocks ground-level passage at section's end until lever flipped
	_add_lever_door(Vector2(4920.0, 212.0), Vector2(5160.0, 368.0))

	# Hazard spikes scattered on ground
	_add_spike(4640.0, GROUND_TOP - 8.0)
	_add_spike(4670.0, GROUND_TOP - 8.0)
	_add_spike(5130.0, GROUND_TOP - 8.0)

	_add_coin(4580.0, 290.0)
	_add_coin(4740.0, 250.0)
	_add_coin(4900.0, 190.0)
	_add_coin(5060.0, 250.0)
	_add_coin_arc(4860.0, 130.0, 5, 110.0)

	_add_grenade_pickup(4770.0, 148.0, 1)

	_add_bg_pipe_h(4500.0, 80.0, 700.0)
	_add_bg_pipe_v(4860.0, 80.0, 200.0)

	# Cover crates near the door
	_add_crate(5095.0, 378.0)
	_add_crate(5095.0, 356.0)

	_add_soldier(4560.0, 375.0, 240.0)
	_add_soldier(4880.0, 375.0, 200.0)
	_add_soldier(5170.0, 375.0, 200.0)

# -----------------------------------------------------------------------------
# Section H — Smokestack run (5200..7500)
# Arched reward catwalks (5200..6000), big ravine with jet-trooper (6000..7000),
# and the final exit ground (7000..7500).
# -----------------------------------------------------------------------------
func _build_section_h_smokestack_run() -> void:
	_add_ground(5200.0, 6000.0)

	_add_platform(5260.0, 320.0, 120.0)
	_add_platform(5440.0, 260.0, 120.0)
	_add_platform(5620.0, 320.0, 120.0)

	_add_powerup(5500.0, 230.0)

	_add_coin(5310.0, 290.0)
	_add_coin(5490.0, 230.0)
	_add_coin(5670.0, 290.0)
	_add_coin_arc(5500.0, 200.0, 5, 130.0)
	_add_coin(5780.0, 374.0)
	_add_coin(5820.0, 374.0)
	_add_coin(5860.0, 374.0)

	_add_bg_pipe_h(5200.0, 80.0, 800.0)

	_add_arrow_sign(5320.0, 378.0)
	_add_arrow_sign(5700.0, 378.0)

	_add_soldier(5320.0, 375.0, 220.0)
	_add_soldier(5700.0, 375.0, 220.0)
	_add_soldier(5840.0, 375.0, 140.0)

	_add_grenade_pickup(5780.0, 366.0, 0)

	# --- Ravine (6000..7000) ----------------------------------------------
	_add_spike_row(6020.0, 6980.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(6020.0, 6980.0)

	var darken := ColorRect.new()
	darken.z_index = -2
	darken.offset_left = 6020.0
	darken.offset_top = 360.0
	darken.offset_right = 6980.0
	darken.offset_bottom = GROUND_BOTTOM
	darken.color = Color(0.02, 0.03, 0.05, 0.45)
	add_child(darken)

	_add_moving_platform(6060.0, 370.0, 120.0)
	_add_platform(6260.0, 300.0, 96.0)
	_add_moving_platform(6420.0, 330.0, 120.0)
	_add_platform(6600.0, 380.0, 96.0)
	_add_moving_platform(6760.0, 320.0, 120.0)
	_add_platform(6900.0, 380.0, 80.0)

	_add_fire_pulse(6340.0, GROUND_BOTTOM - 14.0, 6.0, 0.8)
	_add_fire_pulse(6680.0, GROUND_BOTTOM - 14.0, 6.0, 3.4)

	_add_coin(6108.0, 340.0)
	_add_coin(6308.0, 270.0)
	_add_coin(6480.0, 300.0)
	_add_coin(6648.0, 350.0)
	_add_coin(6820.0, 290.0)
	_add_coin(6940.0, 350.0)
	_add_coin_arc(6480.0, 220.0, 5, 110.0)

	_add_bg_pipe_h(6020.0, 60.0, 960.0)

	# Heavier ravine boss (depth 2 should be tougher than depth 1's mid-boss)
	_add_jet_trooper(6500.0, 180.0, 16, 880.0, 120.0)

	# --- Final exit ground (7000..7500) ------------------------------------
	_add_ground(7000.0, 7500.0)

	_add_bg_pipe_v(7400.0, 80.0, 400.0)

	_add_arrow_sign(7140.0, 378.0)
	_add_coin(7220.0, 374.0)
	_add_coin(7260.0, 374.0)
	_add_coin(7300.0, 374.0)

	_add_exit(7400.0, 370.0)

# -----------------------------------------------------------------------------
# Camera limits — match the sealed world bounds so the camera can pan the
# whole level. Called by Main.gd after spawning the chosen character.
# -----------------------------------------------------------------------------
func apply_player_camera(player_node: Node2D) -> void:
	if player_node == null:
		return
	var cam := player_node.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left   = int(LEVEL_LEFT)
	cam.limit_top    = int(LEVEL_TOP - 100.0)
	cam.limit_right  = int(LEVEL_RIGHT)
	cam.limit_bottom = int(FLOOR_BOTTOM)
	cam.position_smoothing_enabled = false
	cam.drag_horizontal_enabled = false
	cam.drag_vertical_enabled = false
	cam.zoom = Vector2(2.25, 2.25)

func _setup_player_camera() -> void:
	apply_player_camera(get_node_or_null("Player") as Node2D)
