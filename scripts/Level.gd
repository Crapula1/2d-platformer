extends Node2D

# --- Level 1: hand-designed, long & complex, fully sealed ---------------------
# Layout uses x = 0..6000 horizontally.
# Ground top is y = 400.
# A sealed floor runs the entire width below the play area (y = 720..820) so
# the player can never fall out of bounds — pits drop onto spike rows that sit
# on top of that floor.
# A sealed ceiling at y = -60..-40 and left/right walls close the volume.

const MOVING_PLATFORM_SCRIPT := preload("res://scripts/MovingPlatform.gd")
const BREAK_PLATFORM_SCRIPT  := preload("res://scripts/BreakPlatform.gd")
const RANGE_SOLDIER_SCENE    := preload("res://scenes/RangeSoldier.tscn")
const COIN_SCENE             := preload("res://scenes/Coin.tscn")
const SPIKE_SCENE            := preload("res://scenes/Spike.tscn")
const POWERUP_SCENE          := preload("res://scenes/PowerUp.tscn")
const EXIT_DOOR_SCENE        := preload("res://scenes/ExitDoor.tscn")
const FIRE_ZONE_SCENE        := preload("res://scenes/FireZone.tscn")
const ELEC_ZONE_SCENE        := preload("res://scenes/ElectricZone.tscn")
const GRENADE_PICKUP_SCENE   := preload("res://scenes/GrenadePickup.tscn")
const LEVER_SCENE            := preload("res://scenes/Lever.tscn")
const DOOR_SCENE             := preload("res://scenes/Door.tscn")

# Jungle prop scenes (visual decoration)
const SKY_SCENE              := preload("res://scenes/props/Sky.tscn")
const CLOUD_SCENE            := preload("res://scenes/props/Cloud.tscn")
const GRASS_TUFT_SCENE       := preload("res://scenes/props/GrassTuft.tscn")
const ROCK_SCENE             := preload("res://scenes/props/Rock.tscn")
const CLIFF_SCENE            := preload("res://scenes/props/Cliff.tscn")
const BUSH_SCENE             := preload("res://scenes/props/Bush.tscn")
const PALM_TREE_SCENE        := preload("res://scenes/props/PalmTree.tscn")

const LEVEL_LEFT:    float =    -20.0
const LEVEL_RIGHT:   float =  6020.0
const LEVEL_TOP:     float =   -60.0
const LEVEL_BOTTOM:  float =   820.0
const GROUND_TOP:    float =   400.0
const GROUND_BOTTOM: float =   720.0  # top of the sealed lower floor
const FLOOR_BOTTOM:  float =   820.0
const CEILING_BOT:   float =   -40.0

# Jungle palette (Contra Stage 1 inspired)
# Sky: deep teal at top fading to a warm cyan-beige horizon
const COL_BG_TOP:      Color = Color(0.04, 0.10, 0.18)
const COL_BG_BOT:      Color = Color(0.30, 0.50, 0.46)
# Far misty mountain ridges
const COL_FAR_HILL:    Color = Color(0.20, 0.30, 0.36)
# Mid-ground jungle canopy
const COL_MID_CANOPY:  Color = Color(0.08, 0.22, 0.14)
const COL_MID_TRUNK:   Color = Color(0.18, 0.12, 0.07)
# Foreground palm trees
const COL_TRUNK:       Color = Color(0.22, 0.14, 0.08)
const COL_TRUNK_HI:    Color = Color(0.34, 0.22, 0.12)
const COL_FROND:       Color = Color(0.16, 0.42, 0.18)
const COL_FROND_HI:    Color = Color(0.26, 0.56, 0.22)
# Walls / sealed bounds — dark earth
const COL_WALL:        Color = Color(0.13, 0.10, 0.07)
# Ground: dirt body with bright jungle grass top
const COL_GROUND:      Color = Color(0.32, 0.22, 0.13)
const COL_GROUND_DARK: Color = Color(0.22, 0.15, 0.08)
const COL_GRASS:       Color = Color(0.24, 0.66, 0.22)
# Platforms: mossy stone
const COL_PLAT:        Color = Color(0.36, 0.34, 0.28)
const COL_PLAT_TOP:    Color = Color(0.28, 0.60, 0.22)
const COL_FLOOR:       Color = Color(0.06, 0.04, 0.02)
const COL_PIT_GLOW:    Color = Color(0.60, 0.22, 0.10, 0.18)
# Moving platform: wooden raft with a teal tint so it still reads as "moving"
const COL_MOVE:        Color = Color(0.22, 0.55, 0.62)
# Break platform: rotten plank
const COL_BREAK:       Color = Color(0.55, 0.32, 0.16)
# Rocky outcrops
const COL_ROCK:        Color = Color(0.44, 0.42, 0.38)
const COL_ROCK_EDGE:   Color = Color(0.24, 0.22, 0.18)
const COL_ROCK_TOP:    Color = Color(0.26, 0.58, 0.22)  # mossy cap
# Vines & branches
const COL_VINE:        Color = Color(0.18, 0.40, 0.16)
const COL_VINE_HI:     Color = Color(0.28, 0.56, 0.22)
const COL_CABLE:       Color = Color(0.14, 0.32, 0.10)  # hanging vine ropes
# Wooden signs
const COL_SIGN_BG:     Color = Color(0.65, 0.48, 0.25)
const COL_SIGN_FG:     Color = Color(0.20, 0.12, 0.06)
const COL_EXIT_HALO:   Color = Color(0.30, 0.85, 0.45, 0.16)

# Z-index plan:
#  -10 .. -8 : parallax background layers (sky, hills, towers)
#  -3        : mid-background props (deep pipes, far scaffolding)
#  -1        : near-background props (pillars, vines, signs)
#   0        : world terrain, hazards, enemies, player (default)
#   1        : foreground accents (dust, light wash)

var _world: StaticBody2D

func _ready() -> void:
	_build_parallax_background()
	_build_world_container()
	_build_seal()
	_build_section_a_start()
	_build_section_b_first_pit()
	_build_section_c_break_climb()
	_build_section_d_spike_corridor()
	_build_section_e_vertical_climb()
	_build_section_f_big_pit_gauntlet()
	_build_section_g_mixed_challenge()
	_build_section_h_final_stretch()
	_setup_player_camera()

# -----------------------------------------------------------------------------
# Background (parallax) + sky gradient
# -----------------------------------------------------------------------------
func _build_parallax_background() -> void:
	var pbg := ParallaxBackground.new()
	add_child(pbg)

	# Sky gradient (no scroll) — instance of the Sky prop scene
	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2.ZERO
	pbg.add_child(sky_layer)
	_paint_sky_gradient(sky_layer)

	# Drifting clouds — very slow scroll
	var cloud_layer := ParallaxLayer.new()
	cloud_layer.motion_scale = Vector2(0.08, 0.0)
	cloud_layer.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(cloud_layer)
	_paint_clouds(cloud_layer)

	# Far misty mountain ridges — slow scroll
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.18, 0.0)
	far.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(far)
	_paint_far_hills(far)

	# Mid-ground jungle canopy — medium scroll
	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.42, 0.05)
	mid.motion_mirroring = Vector2(960.0, 0.0)
	pbg.add_child(mid)
	_paint_mid_canopy(mid)

	# Foreground palm trees + hanging vines — attached to world coords
	_paint_near_trees()

func _paint_sky_gradient(parent: Node) -> void:
	var sky := SKY_SCENE.instantiate()
	sky.top_color = COL_BG_TOP
	sky.mid_color = COL_BG_BOT
	sky.horizon_color = Color(0.48, 0.42, 0.34)
	sky.rect_size = Vector2(2560.0, 1040.0)
	sky.origin = Vector2(-640.0, -200.0)
	sky.bands = 12
	sky.show_sun = true
	sky.sun_position = Vector2(980.0, 240.0)
	sky.sun_radius = 26.0
	(sky as CanvasItem).z_index = -10
	parent.add_child(sky)

func _paint_clouds(parent: Node) -> void:
	var data: Array = [
		{"pos": Vector2(120.0, 180.0),  "w": 110.0, "seed": 3},
		{"pos": Vector2(420.0, 100.0),  "w":  84.0, "seed": 11},
		{"pos": Vector2(720.0, 200.0),  "w": 140.0, "seed": 19},
		{"pos": Vector2(1020.0, 140.0), "w":  96.0, "seed": 27},
	]
	for d in data:
		var c := CLOUD_SCENE.instantiate()
		c.cloud_width  = float(d["w"])
		c.cloud_height = float(d["w"]) * 0.32
		c.drift_speed  = 4.0
		c.wrap_width   = 1280.0
		c.rand_seed    = int(d["seed"])
		(c as CanvasItem).z_index = -9
		(c as Node2D).position = d["pos"] as Vector2
		parent.add_child(c)

func _paint_far_hills(parent: Node) -> void:
	# Two ridges of rolling mountains, layered for depth
	var bases: Array = [
		{"y": 600.0, "col": COL_FAR_HILL.darkened(0.15), "h": 90.0, "step": 220.0},
		{"y": 620.0, "col": COL_FAR_HILL,                "h": 140.0, "step": 260.0},
	]
	for layer in bases:
		var x: float = -40.0
		while x < 1320.0:
			var hill := Polygon2D.new()
			hill.z_index = -9
			hill.color = layer["col"]
			var h: float = float(layer["h"]) + sin(x * 0.012) * 35.0
			var w: float = float(layer["step"])
			var base_y: float = float(layer["y"])
			hill.polygon = PackedVector2Array([
				Vector2(x,              base_y),
				Vector2(x + w * 0.25,   base_y - h * 0.55),
				Vector2(x + w * 0.5,    base_y - h),
				Vector2(x + w * 0.75,   base_y - h * 0.50),
				Vector2(x + w,          base_y),
			])
			parent.add_child(hill)
			x += w * 0.78

func _paint_mid_canopy(parent: Node) -> void:
	# Row of overlapping blob-shaped tree silhouettes with thin trunks below.
	var x: float = 0.0
	var i: int = 0
	while x < 1280.0:
		var cy: float = 470.0 + sin(float(i) * 0.9) * 35.0
		var rx: float = 70.0 + float(i % 3) * 12.0
		var ry: float = 80.0 + float(i % 2) * 14.0
		_blob_polygon(parent, x + rx, cy, rx, ry, COL_MID_CANOPY, -8)
		# Highlight on the sunward side
		_blob_polygon(parent, x + rx - 8.0, cy - 8.0, rx * 0.55, ry * 0.55,
			COL_MID_CANOPY.lightened(0.10), -8)
		# Trunk
		var trunk := ColorRect.new()
		trunk.z_index = -8
		trunk.offset_left  = x + rx - 5.0
		trunk.offset_right = x + rx + 5.0
		trunk.offset_top   = cy + ry * 0.35
		trunk.offset_bottom = 640.0
		trunk.color = COL_MID_TRUNK
		parent.add_child(trunk)
		x += rx * 1.55
		i += 1

func _blob_polygon(parent: Node, cx: float, cy: float, rx: float, ry: float, c: Color, z: int) -> void:
	var n := 14
	var pts := PackedVector2Array()
	for k in n:
		var a: float = float(k) * TAU / float(n)
		var jitter: float = 0.85 + 0.25 * sin(float(k) * 1.7 + cx * 0.013)
		pts.append(Vector2(cx + cos(a) * rx * jitter, cy + sin(a) * ry * jitter))
	var poly := Polygon2D.new()
	poly.z_index = z
	poly.color = c
	poly.polygon = pts
	parent.add_child(poly)

const GROUND_SPANS := [
	Vector2(0.0, 700.0),
	Vector2(1400.0, 2220.0),
	Vector2(2370.0, 2510.0),
	Vector2(2660.0, 3500.0),
	Vector2(4500.0, 6000.0),
]

func _is_on_ground(x: float, margin: float = 24.0) -> bool:
	for s in GROUND_SPANS:
		if x >= s.x + margin and x <= s.y - margin:
			return true
	return false

func _paint_near_trees() -> void:
	# Foreground palm trees (instances of the PalmTree prop scene) plus the
	# occasional hanging liana from the ceiling. Both are skipped above pits so
	# trees don't float and lianas don't dangle over spike rows.
	var x: float = 200.0
	var i: int = 0
	while x < LEVEL_RIGHT - 80.0:
		if _is_on_ground(x):
			var palm := PALM_TREE_SCENE.instantiate()
			palm.tree_height = 130.0 + float(i % 3) * 18.0
			palm.variant     = i % 3
			palm.rand_seed   = i + 7
			(palm as Node2D).position = Vector2(x, GROUND_TOP - 2.0)
			(palm as CanvasItem).z_index = -1
			add_child(palm)
			if i % 2 == 0 and _is_on_ground(x + 160.0):
				_draw_liana(x + 160.0)
		x += 380.0
		i += 1

func _draw_liana(x: float) -> void:
	var length: float = randf_range(60.0, 140.0)
	var vine := ColorRect.new()
	vine.z_index = -1
	vine.offset_left  = x
	vine.offset_right = x + 3.0
	vine.offset_top   = CEILING_BOT
	vine.offset_bottom = CEILING_BOT + length
	vine.color = COL_CABLE
	add_child(vine)
	# A small leaf cluster at the tip
	var leaf := Polygon2D.new()
	leaf.z_index = -1
	leaf.color = COL_FROND
	var ty: float = CEILING_BOT + length
	leaf.polygon = PackedVector2Array([
		Vector2(x + 1.5,  ty),
		Vector2(x + 10.0, ty + 4.0),
		Vector2(x + 6.0,  ty + 14.0),
		Vector2(x - 6.0,  ty + 12.0),
		Vector2(x - 10.0, ty + 3.0),
	])
	add_child(leaf)

# -----------------------------------------------------------------------------
# World container + primitive add helpers
# -----------------------------------------------------------------------------
func _build_world_container() -> void:
	_world = StaticBody2D.new()
	_world.collision_layer = 1
	_world.collision_mask = 0
	add_child(_world)

# rect at world space (x, y, w, h). Adds collision + visible fill on _world.
func _add_solid(x: float, y: float, w: float, h: float, body: Color, top_band: float = 0.0, top_color: Color = COL_GRASS) -> void:
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
	# Static platform: 14 tall, top edge at y.
	_add_solid(x, y, w, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)

func _add_ground(x_start: float, x_end: float) -> void:
	_add_solid(x_start, GROUND_TOP, x_end - x_start, GROUND_BOTTOM - GROUND_TOP, COL_GROUND, 3.0, COL_GRASS)
	# Darker dirt band below the grass for soil layering
	_paint_dirt_band(x_start, x_end, GROUND_TOP + 8.0, GROUND_TOP + 22.0)
	# Sprinkle grass tufts on top
	var gx: float = x_start + 24.0
	while gx < x_end - 24.0:
		_add_grass_tuft(gx)
		gx += randf_range(48.0, 110.0)
	# Scatter mossy rocky outcrops
	var rx: float = x_start + randf_range(60.0, 140.0)
	while rx < x_end - 80.0:
		_add_ground_rock(rx)
		rx += randf_range(180.0, 320.0)
	# Scatter low foliage (bushes / ferns / undergrowth) — sparse, organic
	var bx: float = x_start + randf_range(40.0, 120.0)
	while bx < x_end - 40.0:
		_add_bush(bx)
		bx += randf_range(140.0, 260.0)

func _paint_dirt_band(x_start: float, x_end: float, y_top: float, y_bot: float) -> void:
	var band := ColorRect.new()
	band.z_index = 0
	band.offset_left = x_start
	band.offset_right = x_end
	band.offset_top = y_top
	band.offset_bottom = y_bot
	band.color = COL_GROUND_DARK
	add_child(band)

func _add_ground_rock(x: float) -> void:
	var r := ROCK_SCENE.instantiate()
	r.rock_size   = randf_range(18.0, 34.0)
	r.rock_height = randf_range(10.0, 18.0)
	r.variant     = randi() % 3
	r.mossy       = true
	r.rand_seed   = int(x)
	(r as Node2D).position = Vector2(x, GROUND_TOP)
	add_child(r)

func _add_grass_tuft(x: float) -> void:
	var g := GRASS_TUFT_SCENE.instantiate()
	g.variant     = randi() % 2
	g.tuft_width  = randf_range(6.0, 11.0)
	g.tuft_height = randf_range(6.0, 11.0)
	g.blade_count = 3 + (randi() % 3)
	(g as Node2D).position = Vector2(x, GROUND_TOP)
	add_child(g)

func _add_bush(x: float) -> void:
	var b := BUSH_SCENE.instantiate()
	b.variant       = randi() % 3
	b.foliage_size  = randf_range(16.0, 26.0)
	b.rand_seed     = int(x) + 13
	(b as Node2D).position = Vector2(x, GROUND_TOP)
	(b as CanvasItem).z_index = -1 if (randi() % 2 == 0) else 1
	add_child(b)

func _add_cliff(x: float, y: float, w: float, h: float) -> void:
	var c := CLIFF_SCENE.instantiate()
	c.cliff_width  = w
	c.cliff_height = h
	c.mossy        = true
	(c as Node2D).position = Vector2(x, y)
	(c as CanvasItem).z_index = -2
	add_child(c)

func _add_spike(x: float, y: float = GROUND_TOP - 8.0) -> void:
	var spike := SPIKE_SCENE.instantiate() as StaticBody2D
	spike.position = Vector2(x, y)
	add_child(spike)

func _add_spike_row(x_start: float, x_end: float, y: float) -> void:
	# Wash a dim red glow above the spike pit
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

func _add_soldier(x: float, y: float, patrol: float = 80.0, speed: float = -1.0) -> void:
	var s := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
	s.position = Vector2(x, y)
	s.patrol_distance = patrol
	if speed >= 0.0:
		s.patrol_speed = speed
	$Enemies.add_child(s)

func _add_turret(x: float, y: float) -> void:
	# A range soldier rooted in place — sees and shoots, doesn't wander.
	_add_soldier(x, y, 1.0, 0.0)

func _add_coin(x: float, y: float) -> void:
	var c := COIN_SCENE.instantiate()
	c.position = Vector2(x, y)
	$Coins.add_child(c)

func _add_coin_row(x_start: float, y: float, count: int, step: float = 24.0) -> void:
	for i in range(count):
		_add_coin(x_start + float(i) * step, y)

func _add_coin_arc(x_center: float, y_apex: float, count: int, span: float = 120.0) -> void:
	# Coin arc — peaks at y_apex over a horizontal span. Encourages jump arcs.
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

	# Halo glow behind the exit door
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

# -----------------------------------------------------------------------------
# Pulsing fire vent — re-spawns a FireZone every `period` seconds.
# Telegraph: a dim warning glow at the vent position so the player can see it
# coming. `phase` delays the first activation to stagger multiple vents.
# -----------------------------------------------------------------------------
func _add_fire_pulse(x: float, y: float, period: float = 6.0, phase: float = 0.0) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	add_child(node)

	var warn := ColorRect.new()
	warn.z_index = -1
	warn.color = Color(0.9, 0.40, 0.10, 0.22)
	warn.offset_left = -32.0
	warn.offset_top = -10.0
	warn.offset_right = 32.0
	warn.offset_bottom = 8.0
	node.add_child(warn)

	# A small "vent" prop at the base
	var vent := ColorRect.new()
	vent.offset_left = -14.0
	vent.offset_top = 4.0
	vent.offset_right = 14.0
	vent.offset_bottom = 10.0
	vent.color = COL_ROCK_EDGE
	node.add_child(vent)
	var rim := ColorRect.new()
	rim.offset_left = -14.0
	rim.offset_top = 4.0
	rim.offset_right = 14.0
	rim.offset_bottom = 6.0
	rim.color = COL_ROCK
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

	# Stagger first activation, then loop.
	var delay := maxf(phase, 0.05)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(timer):
			fire_at.call()
			timer.start()
	)

# -----------------------------------------------------------------------------
# Pulsing electric strike — fires ElectricZone every `period` seconds.
# -----------------------------------------------------------------------------
func _add_elec_pulse(x: float, y: float, period: float = 1.9, phase: float = 0.0) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	add_child(node)

	# Persistent warning marker — small blue cross
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

	# A small ceiling-mounted "emitter" prop above
	var emitter := ColorRect.new()
	emitter.offset_left = -8.0
	emitter.offset_top = -36.0
	emitter.offset_right = 8.0
	emitter.offset_bottom = -28.0
	emitter.color = COL_TRUNK
	node.add_child(emitter)

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
# Decorative prop helpers (visual only, no collision)
# -----------------------------------------------------------------------------
func _add_rock(x: float, y: float, size: float = 22.0) -> void:
	# Solid crate the player can stand on — adds traversal options + visual juice.
	_add_solid(x, y, size, size, COL_ROCK, 2.0, COL_ROCK_EDGE)
	# corner highlight
	var hi := ColorRect.new()
	hi.offset_left = x + size - 4.0
	hi.offset_top = y + 2.0
	hi.offset_right = x + size - 2.0
	hi.offset_bottom = y + size - 2.0
	hi.color = COL_ROCK_EDGE
	_world.add_child(hi)

func _add_branch_h(x: float, y: float, w: float) -> void:
	# Horizontal background pipe (no collision)
	var pipe := ColorRect.new()
	pipe.z_index = -1
	pipe.offset_left = x
	pipe.offset_top = y
	pipe.offset_right = x + w
	pipe.offset_bottom = y + 8.0
	pipe.color = COL_VINE
	add_child(pipe)
	var hi := ColorRect.new()
	hi.z_index = -1
	hi.offset_left = x
	hi.offset_top = y
	hi.offset_right = x + w
	hi.offset_bottom = y + 2.0
	hi.color = COL_VINE_HI
	add_child(hi)

func _add_branch_v(x: float, y_top: float, y_bot: float) -> void:
	var pipe := ColorRect.new()
	pipe.z_index = -1
	pipe.offset_left = x
	pipe.offset_top = y_top
	pipe.offset_right = x + 8.0
	pipe.offset_bottom = y_bot
	pipe.color = COL_VINE
	add_child(pipe)
	var hi := ColorRect.new()
	hi.z_index = -1
	hi.offset_left = x
	hi.offset_top = y_top
	hi.offset_right = x + 2.0
	hi.offset_bottom = y_bot
	hi.color = COL_VINE_HI
	add_child(hi)

func _add_sign(x: float, y: float, glyph_color: Color = COL_SIGN_FG) -> void:
	# Yellow sign with a small "!" — purely decorative
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

	# Stem of "!"
	var stem := ColorRect.new()
	stem.z_index = -1
	stem.offset_left = x - 1.0
	stem.offset_top = y - 9.0
	stem.offset_right = x + 1.0
	stem.offset_bottom = y - 2.0
	stem.color = glyph_color
	add_child(stem)
	# Dot
	var dot := ColorRect.new()
	dot.z_index = -1
	dot.offset_left = x - 1.0
	dot.offset_top = y
	dot.offset_right = x + 1.0
	dot.offset_bottom = y + 2.0
	dot.color = glyph_color
	add_child(dot)

func _add_arrow_sign(x: float, y: float) -> void:
	# Right-pointing arrow sign — guides players toward the exit
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
	# Darker gradient stripes inside a pit to give it depth.
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
		var c := Color(0.05, 0.06, 0.09)
		c.a = 0.18 + float(i) * 0.12
		band.color = c
		add_child(band)

# -----------------------------------------------------------------------------
# Lever + Door pairing. The lever, when toggled on, raises the door.
# Both nodes are siblings under Level, so the lever references the door via
# a sibling NodePath.
# -----------------------------------------------------------------------------
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
	# Left wall
	_add_solid(LEVEL_LEFT, LEVEL_TOP, -LEVEL_LEFT, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	# Right wall
	_add_solid(LEVEL_RIGHT - 20.0, LEVEL_TOP, 20.0, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	# Ceiling
	_add_solid(LEVEL_LEFT, LEVEL_TOP, LEVEL_RIGHT - LEVEL_LEFT, CEILING_BOT - LEVEL_TOP, COL_WALL)
	# Sealed bottom floor (under all pits) — top at y = GROUND_BOTTOM
	_add_solid(LEVEL_LEFT, GROUND_BOTTOM, LEVEL_RIGHT - LEVEL_LEFT, FLOOR_BOTTOM - GROUND_BOTTOM, COL_FLOOR)

# -----------------------------------------------------------------------------
# Section A — Start (0..700): tutorial hops, intro to coins, grenades, enemies.
# -----------------------------------------------------------------------------
func _build_section_a_start() -> void:
	_add_ground(0.0, 700.0)

	# Background props that introduce the industrial feel
	_add_branch_h(40.0, 120.0, 220.0)
	_add_branch_v(254.0, 120.0, 396.0)
	_add_sign(60.0, 380.0)

	# Tutorial coin trail leading the eye to the right
	_add_coin(120.0, 374.0)
	_add_coin(160.0, 364.0)
	_add_coin(200.0, 354.0)

	# Easy stepping platforms
	_add_platform(150.0, 320.0, 96.0)
	_add_platform(330.0, 240.0, 96.0)
	_add_platform(530.0, 320.0, 96.0)

	_add_coin(198.0, 290.0)
	_add_coin(378.0, 210.0)
	_add_coin(578.0, 290.0)

	# Reward arc above middle platform
	_add_coin_arc(378.0, 170.0, 5, 100.0)

	# A grenade pickup tucked onto the top platform (introduce grenades)
	_add_grenade_pickup(378.0, 218.0, 0)

	# Small crate stack on the right to teach "things can be platforms"
	_add_rock(620.0, 378.0)
	_add_rock(620.0, 356.0)
	_add_rock(642.0, 378.0)
	_add_coin(631.0, 332.0)

	# One patrol enemy
	_add_soldier(450.0, 375.0)

# -----------------------------------------------------------------------------
# Section B — First pit (700..1400): moving platforms over spike floor,
# pulsing fire vent mid-pit, and a hidden coin arc up high.
# -----------------------------------------------------------------------------
func _build_section_b_first_pit() -> void:
	_add_spike_row(720.0, 1380.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(720.0, 1380.0)

	# Background pipes spanning the gap (visual continuity)
	_add_branch_h(700.0, 100.0, 700.0)

	# Two moving platforms over the pit
	_add_moving_platform(780.0, 380.0, 120.0)
	_add_platform(1000.0, 320.0, 96.0)
	_add_moving_platform(1180.0, 380.0, 120.0)

	# Pulsing fire vent rising from the spike floor between the platforms
	_add_fire_pulse(1100.0, GROUND_BOTTOM - 14.0, 6.0, 1.0)

	# Standard coins on the path
	_add_coin(840.0, 350.0)
	_add_coin(1048.0, 290.0)
	_add_coin(1240.0, 350.0)

	# Hidden up-high coin arc — visible from the static platform, reachable
	# with a double-jump from it.
	_add_coin_arc(1048.0, 200.0, 5, 140.0)

	# Hanging "danger" sign over the fire pulse
	_add_sign(1100.0, 100.0)

	# Grenade pickup on the first moving platform's arc apex (risk/reward)
	_add_grenade_pickup(900.0, 348.0, 1)

# -----------------------------------------------------------------------------
# Section C — Break climb (1400..2100): vertical break-stair, with a
# Lever + Door puzzle gating an alcove that rewards a powerup + coin cache.
# -----------------------------------------------------------------------------
func _build_section_c_break_climb() -> void:
	_add_ground(1400.0, 2100.0)

	# Background scaffolding
	_add_branch_v(1418.0, 80.0, 400.0)
	_add_branch_h(1418.0, 80.0, 660.0)

	# Break-platform staircase up
	_add_break_platform(1430.0, 320.0, 80.0)
	_add_break_platform(1570.0, 240.0, 80.0)
	_add_break_platform(1710.0, 160.0, 80.0)

	# Top landing with a powerup-adjacent perch
	_add_platform(1850.0, 100.0, 160.0)
	_add_coin_row(1900.0, 70.0, 4, 24.0)

	# Path coins along the climb
	_add_coin(1470.0, 290.0)
	_add_coin(1610.0, 210.0)
	_add_coin(1750.0, 130.0)

	# A lever sits on the top landing — flipping it raises the door below.
	# The door blocks an alcove on the right side at ground level which
	# contains a powerup + coin row.
	_add_lever_door(Vector2(1950.0, 92.0), Vector2(2010.0, 368.0))

	# Build the alcove (right side, behind the door): wall above forms ceiling,
	# floor extends, opens to the section boundary on the right.
	_add_solid(2020.0, 350.0, 80.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)  # alcove ceiling
	_add_powerup(2060.0, 374.0)
	_add_coin_row(2040.0, 380.0, 3, 18.0)
	_add_grenade_pickup(2090.0, 372.0, 2)

	# Step-down platform on the right (for descending without the lever path)
	_add_platform(2010.0, 220.0, 96.0)

	_add_soldier(1500.0, 375.0)
	_add_soldier(1900.0, 375.0, 60.0)

# -----------------------------------------------------------------------------
# Section D — Spike corridor (2100..2900): islands of ground separated by
# spike pits, pulsing electric trap above one pit.
# -----------------------------------------------------------------------------
func _build_section_d_spike_corridor() -> void:
	_add_ground(2100.0, 2220.0)
	_add_spike_row(2220.0, 2370.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(2220.0, 2370.0)
	_add_ground(2370.0, 2510.0)
	_add_spike_row(2510.0, 2660.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(2510.0, 2660.0)
	_add_ground(2660.0, 2900.0)

	# Mid-pit helper platforms
	_add_platform(2260.0, 340.0, 80.0)
	_add_moving_platform(2545.0, 340.0, 100.0)

	# Pulsing electric trap hangs above the first pit's apex platform —
	# you must time the dash across.
	_add_elec_pulse(2300.0, 300.0, 1.9, 0.4)

	# Coins reward the timed jumps
	_add_coin(2295.0, 310.0)
	_add_coin(2575.0, 310.0)
	_add_coin(2435.0, 374.0)
	_add_coin_arc(2435.0, 290.0, 5, 90.0)

	# Grenade pickup on the precarious middle island
	_add_grenade_pickup(2440.0, 372.0, 0)

	# Crate stack at the end of the corridor
	_add_rock(2820.0, 378.0)
	_add_rock(2820.0, 356.0)

	# Overhead pipes for visual cohesion
	_add_branch_h(2120.0, 80.0, 760.0)

	_add_soldier(2450.0, 375.0, 60.0)
	_add_soldier(2780.0, 375.0)

# -----------------------------------------------------------------------------
# Section E — Vertical climb (2900..3500): break-platforms up to a powerup
# perch, with a turret on top and a fire pulse mid-climb.
# -----------------------------------------------------------------------------
func _build_section_e_vertical_climb() -> void:
	_add_ground(2900.0, 3500.0)

	# Towering cliff backdrop frames the vertical climb section
	_add_cliff(2880.0, 60.0, 120.0, 340.0)
	_add_cliff(3340.0, 100.0, 140.0, 300.0)

	# Background scaffolding columns to sell the verticality
	_add_branch_v(2950.0, 60.0, 400.0)
	_add_branch_v(3300.0, 60.0, 400.0)
	_add_branch_h(2950.0, 60.0, 358.0)

	# Climb itself
	_add_break_platform(2970.0, 320.0, 80.0)
	_add_break_platform(3120.0, 240.0, 80.0)
	_add_break_platform(3270.0, 160.0, 80.0)

	# Top landing with powerup
	_add_platform(3380.0, 80.0, 140.0)
	_add_powerup(3450.0, 50.0)

	# Coins up the climb
	_add_coin(3010.0, 290.0)
	_add_coin(3160.0, 210.0)
	_add_coin(3310.0, 130.0)
	_add_coin(3430.0, 50.0)

	# Side cubby on the left — a tiny optional reward for exploring
	_add_solid(2910.0, 200.0, 56.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_coin_row(2920.0, 174.0, 3, 16.0)

	# Pulsing fire vent at the side, in the gap between break platforms
	_add_fire_pulse(3070.0, 314.0, 5.5, 1.6)

	# Stationary turret on the top landing — must engage or skirt
	_add_turret(3410.0, 60.0)

	# Step-down platform on the right
	_add_platform(3520.0, 200.0, 96.0)
	_add_coin(3568.0, 174.0)

	_add_soldier(3050.0, 375.0)
	_add_soldier(3350.0, 375.0, 60.0)

# -----------------------------------------------------------------------------
# Section F — Big pit gauntlet (3500..4500): a long spike pit traversed via
# moving + static platforms, dotted with fire pulses and grenade pickups.
# -----------------------------------------------------------------------------
func _build_section_f_big_pit_gauntlet() -> void:
	_add_spike_row(3520.0, 4480.0, GROUND_BOTTOM - 8.0)
	_add_pit_depth(3520.0, 4480.0)

	# Deeper darkness for the long pit
	var darken := ColorRect.new()
	darken.z_index = -2
	darken.offset_left = 3520.0
	darken.offset_top = 360.0
	darken.offset_right = 4480.0
	darken.offset_bottom = GROUND_BOTTOM
	darken.color = Color(0.02, 0.03, 0.05, 0.35)
	add_child(darken)

	_add_moving_platform(3560.0, 370.0, 120.0)
	_add_platform(3760.0, 300.0, 96.0)
	_add_moving_platform(3900.0, 320.0, 120.0)
	_add_platform(4080.0, 380.0, 96.0)
	_add_moving_platform(4220.0, 320.0, 120.0)
	_add_platform(4380.0, 380.0, 96.0)

	# Two fire vents from the spike floor
	_add_fire_pulse(3830.0, GROUND_BOTTOM - 14.0, 6.0, 0.6)
	_add_fire_pulse(4150.0, GROUND_BOTTOM - 14.0, 6.0, 3.4)

	# Two grenade pickups on rest islands (incentivize taking them)
	_add_grenade_pickup(3790.0, 268.0, 1)
	_add_grenade_pickup(4110.0, 348.0, 2)

	# Coin trail across the gauntlet
	_add_coin(3608.0, 340.0)
	_add_coin(3808.0, 270.0)
	_add_coin(3960.0, 290.0)
	_add_coin(4128.0, 350.0)
	_add_coin(4280.0, 290.0)
	_add_coin(4408.0, 350.0)

	# Reward arc above the second moving platform
	_add_coin_arc(3960.0, 220.0, 5, 100.0)

	# Hanging cable + pipe over the pit
	_add_branch_h(3520.0, 60.0, 960.0)

# -----------------------------------------------------------------------------
# Section G — Mixed challenge (4500..5200): mixed platforms, enemies,
# Lever + Door gating the end, pulsing electric between high platforms.
# -----------------------------------------------------------------------------
func _build_section_g_mixed_challenge() -> void:
	_add_ground(4500.0, 5200.0)

	# Cliff backdrop on the right side as you approach the final gate
	_add_cliff(5120.0, 80.0, 110.0, 320.0)

	_add_platform(4540.0, 320.0, 96.0)
	_add_break_platform(4700.0, 280.0, 80.0)
	_add_platform(4860.0, 220.0, 120.0)
	_add_break_platform(5020.0, 280.0, 80.0)
	_add_moving_platform(4720.0, 160.0, 100.0)

	# Pulsing electric trap between the two break platforms (must time)
	_add_elec_pulse(4860.0, 180.0, 1.8, 0.9)

	# Lever on the high static platform; door blocks ground-level path at x=5160
	_add_lever_door(Vector2(4920.0, 212.0), Vector2(5160.0, 368.0))

	# Floor spikes between safer spots
	_add_spike(4640.0, GROUND_TOP - 8.0)
	_add_spike(4670.0, GROUND_TOP - 8.0)
	_add_spike(5130.0, GROUND_TOP - 8.0)

	# Coins
	_add_coin(4580.0, 290.0)
	_add_coin(4740.0, 250.0)
	_add_coin(4900.0, 190.0)
	_add_coin(5060.0, 250.0)
	_add_coin_arc(4860.0, 130.0, 5, 110.0)

	# A grenade pickup on the moving high platform
	_add_grenade_pickup(4770.0, 148.0, 1)

	# Background props
	_add_branch_h(4500.0, 80.0, 700.0)
	_add_branch_v(4860.0, 80.0, 200.0)

	# Stacked crates as cover near the door
	_add_rock(5095.0, 378.0)
	_add_rock(5095.0, 356.0)

	_add_soldier(4560.0, 375.0)
	_add_soldier(4880.0, 375.0, 60.0)
	_add_soldier(5170.0, 375.0)

# -----------------------------------------------------------------------------
# Section H — Final stretch (5200..6000): clear path, ceremonial visuals,
# a powerup, an enemy cluster guarding the exit, and the exit door.
# -----------------------------------------------------------------------------
func _build_section_h_final_stretch() -> void:
	_add_ground(5200.0, 6000.0)

	# Arching reward platforms
	_add_platform(5260.0, 320.0, 120.0)
	_add_platform(5440.0, 260.0, 120.0)
	_add_platform(5620.0, 320.0, 120.0)

	# Powerup midway
	_add_powerup(5500.0, 230.0)

	# Coins
	_add_coin(5310.0, 290.0)
	_add_coin(5490.0, 230.0)
	_add_coin(5670.0, 290.0)
	_add_coin_arc(5500.0, 200.0, 5, 130.0)
	_add_coin(5780.0, 374.0)
	_add_coin(5820.0, 374.0)
	_add_coin(5860.0, 374.0)

	# Background pipes lit toward exit
	_add_branch_h(5200.0, 80.0, 800.0)
	_add_branch_v(5800.0, 80.0, 400.0)

	# Arrow signs pointing toward the exit
	_add_arrow_sign(5320.0, 378.0)
	_add_arrow_sign(5700.0, 378.0)

	# Guard cluster at the exit — three soldiers, tighter patrols
	_add_soldier(5320.0, 375.0, 50.0)
	_add_soldier(5700.0, 375.0, 50.0)
	_add_soldier(5840.0, 375.0, 30.0)

	# Final grenade resupply right before the exit
	_add_grenade_pickup(5780.0, 366.0, 0)

	# Exit door
	_add_exit(5900.0, 370.0)

# -----------------------------------------------------------------------------
# Camera limits — Player.tscn ships with limit_right = 2400, which is too tight
# for this level. Expand bounds to match the sealed world.
# -----------------------------------------------------------------------------
func _setup_player_camera() -> void:
	var player_node := get_node_or_null("Player") as Node2D
	if player_node == null:
		return
	var cam := player_node.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left   = int(LEVEL_LEFT)
	cam.limit_top    = int(LEVEL_TOP - 100.0)
	cam.limit_right  = int(LEVEL_RIGHT)
	cam.limit_bottom = int(FLOOR_BOTTOM)
	# Metroid / Hollow Knight feel: room for the camera to lead in the direction
	# of motion, with a small vertical drag for jumps.
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.drag_horizontal_enabled = true
	cam.drag_left_margin = 0.20
	cam.drag_right_margin = 0.20
	cam.drag_vertical_enabled = true
	cam.drag_top_margin = 0.18
	cam.drag_bottom_margin = 0.30
