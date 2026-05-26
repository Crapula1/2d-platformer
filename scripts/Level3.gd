extends Node2D

# --- Level 3: castle keep at dusk, fully sealed --------------------------------
# Terrain is rendered with a Godot TileMapLayer driven by terrain-rule autotiles
# (Level3TileTerrain). Per-column surface elevation is sampled from SURFACE_PLAN
# and the engine picks edge / inner-corner / outer-corner tiles automatically so
# stone pieces snap together cleanly across hills, valleys, and pit edges.
#
# Same world contract as Level / Level2:
#   * LEVEL_LEFT..LEVEL_RIGHT bounds, sealed floor / ceiling / walls
#   * GROUND_TOP = 400, GROUND_BOTTOM = 720
#   * Exposes apply_player_camera(player) for Main.gd

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
const CLIFF_SCENE            := preload("res://scenes/props/Cliff.tscn")

const TerrainBuilder         := preload("res://scripts/Level3TileTerrain.gd")

# --- Castle pack textures ----------------------------------------------------
const TEX_CASTLE_BG : Texture2D = preload("res://assets/sprites/castle_pack/sprite_001_625x389.png")
const TEX_TOWER_ROOF: Texture2D = preload("res://assets/sprites/castle_pack/sprite_002_112x128.png")
const TEX_WALL_HEDGE: Texture2D = preload("res://assets/sprites/castle_pack/sprite_036_133x34.png")
const TEX_ARCH_BIG  : Texture2D = preload("res://assets/sprites/castle_pack/sprite_054_78x84.png")
const TEX_ARCH_SM   : Texture2D = preload("res://assets/sprites/castle_pack/sprite_086_63x81.png")
const TEX_BANNER    : Texture2D = preload("res://assets/sprites/castle_pack/sprite_044_66x84.png")
const TEX_SHIELD    : Texture2D = preload("res://assets/sprites/castle_pack/sprite_078_59x67.png")
const TEX_WINDOW    : Texture2D = preload("res://assets/sprites/castle_pack/sprite_073_41x68.png")
const TEX_WALL_SEC  : Texture2D = preload("res://assets/sprites/castle_pack/sprite_096_219x142.png")
const TEX_WALL_SEC2 : Texture2D = preload("res://assets/sprites/castle_pack/sprite_135_122x75.png")
const TEX_BANNER_BAR: Texture2D = preload("res://assets/sprites/castle_pack/sprite_111_142x43.png")
const TEX_TREE_OAK  : Texture2D = preload("res://assets/sprites/castle_pack/sprite_159_75x99.png")
const TEX_TREE_PINE : Texture2D = preload("res://assets/sprites/castle_pack/sprite_168_70x125.png")
const TEX_FLOWERS   : Texture2D = preload("res://assets/sprites/castle_pack/sprite_177_129x54.png")
const TEX_HEDGE_LONG: Texture2D = preload("res://assets/sprites/castle_pack/sprite_187_134x58.png")

# --- World bounds ------------------------------------------------------------
const LEVEL_LEFT:    float =    -20.0
const LEVEL_RIGHT:   float =  7520.0
const LEVEL_TOP:     float =   -60.0
const LEVEL_BOTTOM:  float =   820.0
const GROUND_TOP:    float =   400.0
const GROUND_BOTTOM: float =   720.0
const FLOOR_BOTTOM:  float =   820.0
const CEILING_BOT:   float =   -40.0

# --- Tile grid ---------------------------------------------------------------
# 32-px tiles, corner-mode autotiles. Surface lives at row*32 + 16 (mid-tile)
# because corner-mode tiles render their edges on the half-cell boundary.
# Surface row 12 → world_y 12*32 + 16 = 400 = GROUND_TOP. ✓
const TILE_PX:         int = 32
const SURFACE_ROW_DEF: int =  12
const FLOOR_ROW:       int =  21   # deepest stone row (bottom at y = 704)
const COL_COUNT:       int = 236   # spans 0 .. LEVEL_RIGHT
const PIT:             int =  -1

# --- Castle palette ----------------------------------------------------------
const COL_BG_TOP:      Color = Color(0.06, 0.08, 0.16)
const COL_BG_BOT:      Color = Color(0.32, 0.20, 0.30)
const COL_BG_HORIZON:  Color = Color(0.92, 0.55, 0.30)
const COL_FAR_HILL:    Color = Color(0.16, 0.18, 0.26)
const COL_MID_HILL:    Color = Color(0.12, 0.14, 0.22)
const COL_WALL:        Color = Color(0.22, 0.22, 0.26)
const COL_WALL_HI:     Color = Color(0.40, 0.40, 0.46)
const COL_GROUND:      Color = Color(0.30, 0.30, 0.34)
const COL_GROUND_DARK: Color = Color(0.18, 0.18, 0.22)
const COL_GROUND_TOP:  Color = Color(0.35, 0.55, 0.28)
const COL_PLAT:        Color = Color(0.46, 0.46, 0.50)
const COL_PLAT_TOP:    Color = Color(0.40, 0.62, 0.30)
const COL_MOVE:        Color = Color(0.62, 0.40, 0.20)
const COL_BREAK:       Color = Color(0.50, 0.34, 0.22)
const COL_FLOOR:       Color = Color(0.05, 0.06, 0.10)
const COL_PIT_GLOW:    Color = Color(0.20, 0.55, 0.95, 0.22)
const COL_CRATE:       Color = Color(0.56, 0.38, 0.22)
const COL_CRATE_EDGE:  Color = Color(0.30, 0.18, 0.10)
const COL_BRAZIER:     Color = Color(0.30, 0.22, 0.16)
const COL_FLAME:       Color = Color(1.00, 0.62, 0.20)
const COL_SIGN_BG:     Color = Color(0.88, 0.78, 0.40)
const COL_SIGN_FG:     Color = Color(0.10, 0.08, 0.04)
const COL_EXIT_HALO:   Color = Color(1.00, 0.85, 0.40, 0.22)
const COL_GOLD:        Color = Color(0.95, 0.82, 0.30)
const COL_BLOOD:       Color = Color(0.70, 0.10, 0.14)

# -----------------------------------------------------------------------------
# Surface plan — per-column terrain-surface row. -1 = pit (no ground tiles).
# Edges between segments are linearly interpolated, which is what gives the
# level natural hill / valley silhouettes instead of flat slabs.
# Format: { "from": col, "to": col, "row_from": int, "row_to": int }
# -----------------------------------------------------------------------------
const SURFACE_PLAN: Array = [
	# A — Courtyard intake: gentle hill rising left to right
	{ "from":   0, "to":   8, "row_from": 12, "row_to": 12 },
	{ "from":   8, "to":  14, "row_from": 12, "row_to": 10 },
	{ "from":  14, "to":  21, "row_from": 10, "row_to": 12 },
	# B — Moat (full pit)
	{ "from":  22, "to":  43, "row_from": PIT, "row_to": PIT },
	# C — Tower climb: terrain steps up to the keep wall
	{ "from":  44, "to":  50, "row_from": 12, "row_to": 12 },
	{ "from":  50, "to":  58, "row_from": 12, "row_to":  9 },
	{ "from":  58, "to":  65, "row_from":  9, "row_to":  9 },
	# D — Drawbridge gaps: two pit slits split by stone islands
	{ "from":  66, "to":  71, "row_from":  9, "row_to": 11 },
	{ "from":  72, "to":  75, "row_from": PIT, "row_to": PIT },
	{ "from":  76, "to":  80, "row_from": 11, "row_to": 11 },
	{ "from":  81, "to":  84, "row_from": PIT, "row_to": PIT },
	{ "from":  85, "to":  90, "row_from": 11, "row_to": 12 },
	# E — Battlement climb: long rise into the upper bailey
	{ "from":  91, "to":  96, "row_from": 12, "row_to": 12 },
	{ "from":  96, "to": 109, "row_from": 12, "row_to":  8 },
	# F — Great hall gauntlet (full pit)
	{ "from": 110, "to": 140, "row_from": PIT, "row_to": PIT },
	# G — Throne room: dais in the middle
	{ "from": 141, "to": 146, "row_from": 12, "row_to": 12 },
	{ "from": 146, "to": 152, "row_from": 12, "row_to":  9 },
	{ "from": 152, "to": 156, "row_from":  9, "row_to":  9 },
	{ "from": 156, "to": 162, "row_from":  9, "row_to": 12 },
	# H — Keep run: rolling hills, then ravine, then exit terrace
	{ "from": 163, "to": 173, "row_from": 12, "row_to": 12 },
	{ "from": 173, "to": 180, "row_from": 12, "row_to": 10 },
	{ "from": 180, "to": 188, "row_from": 10, "row_to": 13 },
	{ "from": 188, "to": 195, "row_from": 13, "row_to": 12 },
	{ "from": 196, "to": 218, "row_from": PIT, "row_to": PIT },
	{ "from": 219, "to": 224, "row_from": 12, "row_to": 11 },
	{ "from": 224, "to": 234, "row_from": 11, "row_to": 11 },
]

var _world: StaticBody2D
var _tiles: TileMapLayer
var _surface_rows: PackedInt32Array

func _ready() -> void:
	_compute_surface_rows()
	_build_parallax_background()
	_build_world_container()
	_build_terrain_tiles()
	_build_seal_walls_and_ceiling()
	_paint_pit_atmospherics()
	_build_section_a_courtyard()
	_build_section_b_moat()
	_build_section_c_tower_climb()
	_build_section_d_drawbridge_gaps()
	_build_section_e_battlement_climb()
	_build_section_f_great_hall()
	_build_section_g_throne_room()
	_build_section_h_keep_run()
	_build_upper_route()
	_build_gated_exit()
	_build_hidden_vault()
	_spawn_air_demons()
	_setup_player_camera()

# -----------------------------------------------------------------------------
# Surface plan resolution + tile build
# -----------------------------------------------------------------------------
func _compute_surface_rows() -> void:
	_surface_rows = PackedInt32Array()
	_surface_rows.resize(COL_COUNT)
	for c in COL_COUNT:
		_surface_rows[c] = SURFACE_ROW_DEF
	for seg in SURFACE_PLAN:
		var c0: int = int(seg["from"])
		var c1: int = int(seg["to"])
		var r0: int = int(seg["row_from"])
		var r1: int = int(seg["row_to"])
		var span: int = max(1, c1 - c0)
		for c in range(c0, min(c1 + 1, COL_COUNT)):
			if r0 == PIT or r1 == PIT:
				_surface_rows[c] = PIT
			else:
				var t: float = float(c - c0) / float(span)
				_surface_rows[c] = int(round(lerp(float(r0), float(r1), t)))

func _build_terrain_tiles() -> void:
	_tiles = TileMapLayer.new()
	_tiles.name = "Terrain"
	_tiles.tile_set = TerrainBuilder.build()
	_tiles.z_index = -1
	add_child(_tiles)

	var stone_cells: Array[Vector2i] = []
	for c in COL_COUNT:
		var surf: int = _surface_rows[c]
		if surf == PIT:
			continue
		# Fill from surface down to floor row inclusive.
		for r in range(surf, FLOOR_ROW + 1):
			stone_cells.append(Vector2i(c, r))

	_tiles.set_cells_terrain_connect(
		stone_cells,
		TerrainBuilder.TERRAIN_SET,
		TerrainBuilder.TERRAIN_STONE,
		false)

# Return the world Y where the stone surface sits for a given world x.
# For columns inside a pit this returns GROUND_BOTTOM (the floor of the moat).
func _surface_y_at(world_x: float) -> float:
	var col: int = clamp(int(floor(world_x / float(TILE_PX))), 0, COL_COUNT - 1)
	var r: int = _surface_rows[col]
	if r == PIT:
		return GROUND_BOTTOM
	return float(r) * float(TILE_PX) + 16.0

func _is_on_ground(x: float, _margin: float = 24.0) -> bool:
	# Used by older decoration logic — true wherever the column has terrain.
	var c: int = clamp(int(floor(x / float(TILE_PX))), 0, COL_COUNT - 1)
	return _surface_rows[c] != PIT

# -----------------------------------------------------------------------------
# Outer seal — vertical walls, ceiling, and the pit-catch floor below tiles.
# Ground is covered by the TileMapLayer; this is only the off-screen boundary.
# -----------------------------------------------------------------------------
func _build_seal_walls_and_ceiling() -> void:
	# Left wall
	_add_solid(LEVEL_LEFT, LEVEL_TOP, -LEVEL_LEFT, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	# Right wall
	_add_solid(LEVEL_RIGHT - 20.0, LEVEL_TOP, 20.0, LEVEL_BOTTOM - LEVEL_TOP, COL_WALL)
	# Ceiling
	_add_solid(LEVEL_LEFT, LEVEL_TOP, LEVEL_RIGHT - LEVEL_LEFT, CEILING_BOT - LEVEL_TOP, COL_WALL)
	# Pit-catch floor (below ground tiles)
	_add_solid(LEVEL_LEFT, GROUND_BOTTOM, LEVEL_RIGHT - LEVEL_LEFT, FLOOR_BOTTOM - GROUND_BOTTOM, COL_FLOOR)

# Draw the dark moat / ravine atmospherics under every pit span.
func _paint_pit_atmospherics() -> void:
	var run_start: int = -1
	for c in range(COL_COUNT + 1):
		var in_pit: bool = c < COL_COUNT and _surface_rows[c] == PIT
		if in_pit and run_start < 0:
			run_start = c
		elif not in_pit and run_start >= 0:
			var x0: float = float(run_start) * float(TILE_PX)
			var x1: float = float(c) * float(TILE_PX)
			_add_pit_depth(x0, x1)
			run_start = -1

# -----------------------------------------------------------------------------
# Parallax background — dusk sky, distant hills, far castle, near banners.
# -----------------------------------------------------------------------------
func _build_parallax_background() -> void:
	var pbg := ParallaxBackground.new()
	add_child(pbg)

	var sky_layer := ParallaxLayer.new()
	sky_layer.motion_scale = Vector2.ZERO
	pbg.add_child(sky_layer)
	_paint_sky_gradient(sky_layer)

	var cloud_layer := ParallaxLayer.new()
	cloud_layer.motion_scale = Vector2(0.10, 0.0)
	cloud_layer.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(cloud_layer)
	_paint_dusk_clouds(cloud_layer)

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.22, 0.0)
	far.motion_mirroring = Vector2(1280.0, 0.0)
	pbg.add_child(far)
	_paint_far_castle(far)

	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.45, 0.05)
	mid.motion_mirroring = Vector2(960.0, 0.0)
	pbg.add_child(mid)
	_paint_mid_hills(mid)

func _paint_sky_gradient(parent: Node) -> void:
	var sky := SKY_SCENE.instantiate()
	sky.top_color = COL_BG_TOP
	sky.mid_color = COL_BG_BOT
	sky.horizon_color = COL_BG_HORIZON
	sky.rect_size = Vector2(2560.0, 1040.0)
	sky.origin = Vector2(-640.0, -200.0)
	sky.bands = 14
	sky.show_sun = true
	sky.sun_position = Vector2(960.0, 260.0)
	sky.sun_radius = 26.0
	(sky as CanvasItem).z_index = -10
	parent.add_child(sky)

func _paint_dusk_clouds(parent: Node) -> void:
	var data: Array = [
		{"pos": Vector2(120.0, 180.0), "w": 130.0, "seed": 7},
		{"pos": Vector2(440.0,  90.0), "w":  92.0, "seed": 13},
		{"pos": Vector2(760.0, 200.0), "w": 160.0, "seed": 23},
		{"pos": Vector2(1060.0,140.0), "w": 108.0, "seed": 31},
	]
	for d in data:
		var c := CLOUD_SCENE.instantiate()
		c.cloud_width  = float(d["w"])
		c.cloud_height = float(d["w"]) * 0.34
		c.drift_speed  = 6.0
		c.wrap_width   = 1280.0
		c.rand_seed    = int(d["seed"])
		(c as CanvasItem).z_index = -9
		(c as Node2D).position = d["pos"] as Vector2
		(c as CanvasItem).modulate = Color(0.85, 0.65, 0.55, 0.85)
		parent.add_child(c)

func _paint_far_castle(parent: Node) -> void:
	var xs := [-40.0, 540.0, 1080.0]
	for x in xs:
		var s := Sprite2D.new()
		s.z_index = -9
		s.texture = TEX_CASTLE_BG
		s.centered = false
		s.position = Vector2(x, 240.0)
		s.scale = Vector2(0.7, 0.7)
		s.modulate = Color(0.35, 0.32, 0.40, 0.95)
		parent.add_child(s)

func _paint_mid_hills(parent: Node) -> void:
	var x: float = 0.0
	var i: int = 0
	while x < 1280.0:
		var w: float = 220.0 + float(i % 3) * 60.0
		var h: float = 80.0 + float(i % 4) * 30.0
		var base_y: float = 620.0
		var poly := Polygon2D.new()
		poly.z_index = -8
		poly.color = COL_MID_HILL
		poly.polygon = PackedVector2Array([
			Vector2(x,            base_y),
			Vector2(x + w * 0.20, base_y - h * 0.7),
			Vector2(x + w * 0.50, base_y - h),
			Vector2(x + w * 0.80, base_y - h * 0.6),
			Vector2(x + w,        base_y),
		])
		parent.add_child(poly)

		var t := Sprite2D.new()
		t.z_index = -8
		t.texture = TEX_TREE_PINE
		t.centered = false
		t.scale = Vector2(0.55, 0.55)
		t.modulate = Color(0.55, 0.55, 0.62)
		t.position = Vector2(x + w * 0.45, base_y - h - 60.0)
		parent.add_child(t)

		x += w * 0.90
		i += 1

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
	_add_solid(x, y, w, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	var b: int = 0
	while float(b) * 32.0 < w - 12.0:
		var bolt := ColorRect.new()
		bolt.z_index = 0
		bolt.color = COL_WALL.darkened(0.20)
		var bx: float = x + 8.0 + float(b) * 32.0
		bolt.offset_left = bx
		bolt.offset_right = bx + 4.0
		bolt.offset_top = y + 14.0
		bolt.offset_bottom = y + 17.0
		_world.add_child(bolt)
		b += 1

# Decorate the top of the terrain in a column range with castle props.
func _scatter_ground_decor(x_start: float, x_end: float, seed_kind: int = 0) -> void:
	var rx: float = x_start + randf_range(80.0, 160.0)
	var i: int = seed_kind
	while rx < x_end - 80.0:
		var pick := i % 5
		var surf := _surface_y_at(rx)
		match pick:
			0: _place_texture(TEX_HEDGE_LONG, rx, surf - 38.0, Vector2(0.55, 0.55), -1)
			1: _place_texture(TEX_FLOWERS,    rx, surf - 30.0, Vector2(0.50, 0.50), -1)
			2: _place_texture(TEX_TREE_OAK,   rx, surf - 86.0, Vector2(0.85, 0.85), -2)
			3: _place_texture(TEX_WALL_HEDGE, rx, surf - 22.0, Vector2(0.65, 0.65), -1)
			4: _place_texture(TEX_TREE_PINE,  rx, surf - 108.0, Vector2(0.80, 0.80), -2)
		rx += randf_range(180.0, 320.0)
		i += 1

func _place_texture(tex: Texture2D, x: float, y: float, scl: Vector2 = Vector2.ONE, z: int = -1, tint: Color = Color(1,1,1,1)) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(x, y)
	s.scale = scl
	s.z_index = z
	s.modulate = tint
	add_child(s)
	return s

func _add_crate(x: float, y: float, size: float = 22.0) -> void:
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
	_place_texture(TEX_ARCH_BIG, x - 40.0, y - 90.0, Vector2(1.0, 1.0), -1)
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

func _add_fire_pulse(x: float, y: float, period: float = 6.0, phase: float = 0.0) -> void:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	add_child(node)

	var warn := ColorRect.new()
	warn.z_index = -1
	warn.color = Color(0.95, 0.55, 0.20, 0.22)
	warn.offset_left = -32.0
	warn.offset_top = -10.0
	warn.offset_right = 32.0
	warn.offset_bottom = 8.0
	node.add_child(warn)

	var basin := ColorRect.new()
	basin.offset_left = -16.0
	basin.offset_top = 4.0
	basin.offset_right = 16.0
	basin.offset_bottom = 14.0
	basin.color = COL_BRAZIER
	node.add_child(basin)
	var rim := ColorRect.new()
	rim.offset_left = -16.0
	rim.offset_top = 4.0
	rim.offset_right = 16.0
	rim.offset_bottom = 6.0
	rim.color = COL_FLAME
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

	var sconce := ColorRect.new()
	sconce.offset_left = -10.0
	sconce.offset_top = -36.0
	sconce.offset_right = 10.0
	sconce.offset_bottom = -28.0
	sconce.color = COL_WALL_HI
	node.add_child(sconce)
	var lens := ColorRect.new()
	lens.offset_left = -5.0
	lens.offset_top = -30.0
	lens.offset_right = 5.0
	lens.offset_bottom = -28.0
	lens.color = Color(0.55, 0.85, 1.0)
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
	post.color = Color(0.18, 0.14, 0.08)
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
		var c := Color(0.04, 0.06, 0.10)
		c.a = 0.20 + float(i) * 0.14
		band.color = c
		add_child(band)

	var glow := ColorRect.new()
	glow.z_index = -2
	glow.offset_left = x_start
	glow.offset_top = GROUND_BOTTOM - 18.0
	glow.offset_right = x_end
	glow.offset_bottom = GROUND_BOTTOM - 8.0
	glow.color = Color(0.18, 0.45, 0.95, 0.40)
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

func _hang_banner(x: float, y: float, tint: Color = Color(1,1,1,1)) -> void:
	_place_texture(TEX_BANNER, x, y, Vector2(0.85, 0.85), -1, tint)

func _wall_window(x: float, y: float) -> void:
	_place_texture(TEX_WINDOW, x, y, Vector2(0.85, 0.85), -2, Color(0.85, 0.85, 0.92))

# -----------------------------------------------------------------------------
# Sections — gameplay placement. Terrain elevation comes from SURFACE_PLAN;
# these only seed entities, props, hazards, and floating platforms.
# Per-section spawns are anchored to _surface_y_at() so they sit naturally
# on the new tiled silhouette no matter how the elevation table shifts.
# -----------------------------------------------------------------------------
func _build_section_a_courtyard() -> void:
	# Spawn-side wall mural
	_place_texture(TEX_WALL_SEC, 20.0, 240.0, Vector2(0.85, 0.85), -3, Color(0.75, 0.75, 0.80))
	_hang_banner(120.0, 240.0, Color(0.95, 0.40, 0.30))
	_wall_window(380.0, 230.0)
	_add_sign(80.0, _surface_y_at(80.0) - 20.0)

	_add_coin(130.0, _surface_y_at(130.0) - 26.0)
	_add_coin(170.0, _surface_y_at(170.0) - 36.0)
	_add_coin(210.0, _surface_y_at(210.0) - 46.0)

	# Catwalk parapets stepping up to the upper route
	_add_platform(160.0, 320.0, 96.0)
	_add_platform(340.0, 240.0, 96.0)
	_add_platform(540.0, 320.0, 96.0)

	_add_coin(208.0, 290.0)
	_add_coin(388.0, 210.0)
	_add_coin(588.0, 290.0)
	_add_coin_arc(388.0, 170.0, 5, 100.0)

	_add_grenade_pickup(388.0, 218.0, 0)

	# Crate stack at the courtyard wall — sits on the hilltop
	var crate_x: float = 620.0
	var crate_base: float = _surface_y_at(crate_x) - 22.0
	_add_crate(crate_x, crate_base)
	_add_crate(crate_x, crate_base - 22.0)
	_add_crate(crate_x + 22.0, crate_base)
	_add_coin(crate_x + 11.0, crate_base - 46.0)

	_add_soldier(450.0, _surface_y_at(450.0) - 25.0)

	# Climb shaft up to the upper route over the moat
	_add_platform(620.0, 200.0, 80.0)
	_add_platform(540.0, 140.0, 80.0)
	_add_platform(640.0,  80.0, 80.0)
	_add_coin(660.0, 170.0)
	_add_coin(580.0, 110.0)
	_add_coin(680.0,  50.0)
	_add_arrow_sign(610.0, 168.0)

	_place_texture(TEX_TOWER_ROOF, 600.0, -40.0, Vector2(0.7, 0.7), -3, Color(0.85, 0.85, 0.90))

	_scatter_ground_decor(40.0, 600.0, 0)

func _build_section_b_moat() -> void:
	_add_spike_row(720.0, 1380.0, GROUND_BOTTOM - 8.0)

	# Drawbridge segments — alternating moving/static platforms across the moat
	_add_moving_platform(780.0, 380.0, 120.0)
	_add_platform(1000.0, 320.0, 96.0)
	_add_moving_platform(1180.0, 380.0, 120.0)

	_add_fire_pulse(1100.0, GROUND_BOTTOM - 14.0, 6.0, 1.0)

	_add_coin(840.0, 350.0)
	_add_coin(1048.0, 290.0)
	_add_coin(1240.0, 350.0)
	_add_coin_arc(1048.0, 200.0, 5, 140.0)

	_add_sign(1100.0, 100.0)
	_add_grenade_pickup(900.0, 348.0, 1)

	_hang_banner(820.0, 60.0, Color(0.30, 0.60, 1.0))
	_hang_banner(1200.0, 60.0, Color(1.0, 0.85, 0.30))

func _build_section_c_tower_climb() -> void:
	_place_texture(TEX_WALL_SEC, 1400.0, 80.0, Vector2(1.0, 1.0), -3, Color(0.70, 0.70, 0.75))
	_wall_window(1500.0, 200.0)
	_wall_window(1700.0, 260.0)
	_hang_banner(1850.0, 220.0, COL_BLOOD)

	# Plank-stair climb up the inside of the tower
	_add_break_platform(1430.0, 320.0, 80.0)
	_add_break_platform(1570.0, 240.0, 80.0)
	_add_break_platform(1710.0, 160.0, 80.0)

	_add_platform(1850.0, 100.0, 160.0)
	_add_coin_row(1900.0, 70.0, 4, 24.0)

	_add_coin(1470.0, 290.0)
	_add_coin(1610.0, 210.0)
	_add_coin(1750.0, 130.0)

	# Portcullis: lever up top opens the gate down on the wall
	_add_lever_door(Vector2(1950.0, 92.0), Vector2(2010.0, _surface_y_at(2010.0) - 32.0))

	# Alcove above the wall step
	var alc_y: float = _surface_y_at(2060.0) - 50.0
	_add_solid(2020.0, alc_y, 80.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_powerup(2060.0, alc_y - 24.0)
	_add_coin_row(2040.0, alc_y - 18.0, 3, 18.0)
	_add_grenade_pickup(2090.0, alc_y - 26.0)

	_add_platform(2010.0, 220.0, 96.0)

	_add_soldier(1500.0, _surface_y_at(1500.0) - 25.0)
	_add_soldier(1900.0, _surface_y_at(1900.0) - 25.0, 180.0)

	_place_texture(TEX_TOWER_ROOF, 1880.0, -40.0, Vector2(0.85, 0.85), -3, Color(0.80, 0.78, 0.82))

	_scatter_ground_decor(1420.0, 1980.0, 2)

func _build_section_d_drawbridge_gaps() -> void:
	_add_spike_row(2304.0, 2400.0, GROUND_BOTTOM - 8.0)
	_add_spike_row(2592.0, 2688.0, GROUND_BOTTOM - 8.0)

	_add_platform(2310.0, 340.0, 80.0)
	_add_moving_platform(2600.0, 340.0, 100.0)

	_add_elec_pulse(2350.0, 300.0, 1.9, 0.4)

	_add_coin(2345.0, 310.0)
	_add_coin(2640.0, 310.0)
	_add_coin(2490.0, _surface_y_at(2490.0) - 26.0)
	_add_coin_arc(2490.0, 290.0, 5, 90.0)

	_add_grenade_pickup(2490.0, _surface_y_at(2490.0) - 28.0, 0)

	var crate_x2: float = 2820.0
	var crate_y2: float = _surface_y_at(crate_x2) - 22.0
	_add_crate(crate_x2, crate_y2)
	_add_crate(crate_x2, crate_y2 - 22.0)

	_hang_banner(2450.0, 60.0, Color(0.30, 0.85, 0.45))
	_wall_window(2150.0, 220.0)
	_wall_window(2720.0, 220.0)

	_add_soldier(2460.0, _surface_y_at(2460.0) - 25.0, 140.0)
	_add_soldier(2790.0, _surface_y_at(2790.0) - 25.0, 200.0)

func _build_section_e_battlement_climb() -> void:
	var c1 := CLIFF_SCENE.instantiate()
	c1.cliff_width  = 120.0
	c1.cliff_height = 340.0
	c1.mossy        = false
	(c1 as Node2D).position = Vector2(2880.0, 60.0)
	(c1 as CanvasItem).z_index = -2
	(c1 as CanvasItem).modulate = Color(0.50, 0.50, 0.55)
	add_child(c1)

	var c2 := CLIFF_SCENE.instantiate()
	c2.cliff_width  = 140.0
	c2.cliff_height = 300.0
	c2.mossy        = false
	(c2 as Node2D).position = Vector2(3340.0, 100.0)
	(c2 as CanvasItem).z_index = -2
	(c2 as CanvasItem).modulate = Color(0.55, 0.55, 0.60)
	add_child(c2)

	_place_texture(TEX_WALL_SEC2, 2940.0, 200.0, Vector2(1.0, 1.0), -3, Color(0.70, 0.70, 0.75))
	_wall_window(3200.0, 230.0)

	_add_break_platform(2970.0, 320.0, 80.0)
	_add_break_platform(3120.0, 240.0, 80.0)
	_add_break_platform(3270.0, 160.0, 80.0)

	_add_platform(3380.0, 80.0, 140.0)
	_add_powerup(3450.0, 50.0)

	_add_coin(3010.0, 290.0)
	_add_coin(3160.0, 210.0)
	_add_coin(3310.0, 130.0)
	_add_coin(3430.0,  50.0)

	# Side cubby tucked into the lower wall
	var cubby_y: float = _surface_y_at(2940.0) - 200.0
	_add_solid(2910.0, cubby_y, 56.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_coin_row(2920.0, cubby_y - 26.0, 3, 16.0)

	_add_fire_pulse(3070.0, 314.0, 5.5, 1.6)

	_add_turret(3410.0, 60.0)

	_add_platform(3520.0, 200.0, 96.0)
	_add_coin(3568.0, 174.0)

	_add_soldier(3050.0, _surface_y_at(3050.0) - 25.0, 260.0)
	_add_soldier(3350.0, _surface_y_at(3350.0) - 25.0, 220.0)

	_place_texture(TEX_TOWER_ROOF, 3400.0, -40.0, Vector2(0.75, 0.75), -3, Color(0.80, 0.80, 0.85))

	_scatter_ground_decor(2920.0, 3490.0, 4)

func _build_section_f_great_hall() -> void:
	_add_spike_row(3520.0, 4480.0, GROUND_BOTTOM - 8.0)

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

	_hang_banner(3600.0, 40.0, Color(0.30, 0.45, 0.95))
	_hang_banner(3900.0, 40.0, Color(0.95, 0.30, 0.30))
	_hang_banner(4200.0, 40.0, COL_GOLD)
	_place_texture(TEX_SHIELD, 4040.0, 80.0, Vector2(0.85, 0.85), -1)

	_add_jet_trooper(4000.0, 180.0, 11, 820.0, 110.0)

func _build_section_g_throne_room() -> void:
	_place_texture(TEX_WALL_SEC, 4500.0, 80.0, Vector2(1.0, 1.0), -3, Color(0.75, 0.72, 0.80))
	_hang_banner(4640.0, 100.0, COL_GOLD)
	_hang_banner(4900.0, 100.0, COL_GOLD)
	_place_texture(TEX_SHIELD, 4770.0, 140.0, Vector2(1.0, 1.0), -1)
	_wall_window(5040.0, 200.0)

	var c := CLIFF_SCENE.instantiate()
	c.cliff_width  = 110.0
	c.cliff_height = 320.0
	c.mossy        = false
	(c as Node2D).position = Vector2(5120.0, 80.0)
	(c as CanvasItem).z_index = -2
	(c as CanvasItem).modulate = Color(0.50, 0.48, 0.55)
	add_child(c)

	_add_platform(4540.0, 320.0, 96.0)
	_add_break_platform(4700.0, 280.0, 80.0)
	_add_platform(4860.0, 220.0, 120.0)
	_add_break_platform(5020.0, 280.0, 80.0)
	_add_moving_platform(4720.0, 160.0, 100.0)

	_add_elec_pulse(4860.0, 180.0, 1.8, 0.9)

	_add_lever_door(Vector2(4920.0, 212.0), Vector2(5160.0, _surface_y_at(5160.0) - 32.0))

	# Dais spikes warning visitors away from the throne approach
	_add_spike(4640.0, _surface_y_at(4640.0) - 8.0)
	_add_spike(4670.0, _surface_y_at(4670.0) - 8.0)
	_add_spike(5130.0, _surface_y_at(5130.0) - 8.0)

	_add_coin(4580.0, 290.0)
	_add_coin(4740.0, 250.0)
	_add_coin(4900.0, 190.0)
	_add_coin(5060.0, 250.0)
	_add_coin_arc(4860.0, 130.0, 5, 110.0)

	_add_grenade_pickup(4770.0, 148.0, 1)

	var crate_x3: float = 5095.0
	var crate_y3: float = _surface_y_at(crate_x3) - 22.0
	_add_crate(crate_x3, crate_y3)
	_add_crate(crate_x3, crate_y3 - 22.0)

	_add_soldier(4560.0, _surface_y_at(4560.0) - 25.0, 240.0)
	_add_soldier(4880.0, _surface_y_at(4880.0) - 25.0, 200.0)
	_add_soldier(5170.0, _surface_y_at(5170.0) - 25.0, 200.0)

	_scatter_ground_decor(4520.0, 5180.0, 1)

func _build_section_h_keep_run() -> void:
	_add_platform(5260.0, 320.0, 120.0)
	_add_platform(5440.0, 260.0, 120.0)
	_add_platform(5620.0, 320.0, 120.0)

	_add_powerup(5500.0, 230.0)

	_add_coin(5310.0, 290.0)
	_add_coin(5490.0, 230.0)
	_add_coin(5670.0, 290.0)
	_add_coin_arc(5500.0, 200.0, 5, 130.0)
	_add_coin(5780.0, _surface_y_at(5780.0) - 26.0)
	_add_coin(5820.0, _surface_y_at(5820.0) - 26.0)
	_add_coin(5860.0, _surface_y_at(5860.0) - 26.0)

	_hang_banner(5400.0, 60.0, COL_GOLD)
	_hang_banner(5700.0, 60.0, COL_BLOOD)
	_place_texture(TEX_WALL_SEC2, 5200.0, 200.0, Vector2(1.0, 1.0), -3, Color(0.72, 0.70, 0.78))

	_add_arrow_sign(5320.0, _surface_y_at(5320.0) - 22.0)
	_add_arrow_sign(5700.0, _surface_y_at(5700.0) - 22.0)

	_add_soldier(5320.0, _surface_y_at(5320.0) - 25.0, 220.0)
	_add_soldier(5700.0, _surface_y_at(5700.0) - 25.0, 220.0)
	_add_soldier(5840.0, _surface_y_at(5840.0) - 25.0, 140.0)

	_add_grenade_pickup(5780.0, _surface_y_at(5780.0) - 34.0, 0)

	# Ravine (cols 196..218 = 6272..6976)
	_add_spike_row(6272.0, 6976.0, GROUND_BOTTOM - 8.0)

	var darken := ColorRect.new()
	darken.z_index = -2
	darken.offset_left = 6272.0
	darken.offset_top = 360.0
	darken.offset_right = 6976.0
	darken.offset_bottom = GROUND_BOTTOM
	darken.color = Color(0.02, 0.03, 0.05, 0.45)
	add_child(darken)

	_add_moving_platform(6320.0, 370.0, 120.0)
	_add_platform(6520.0, 300.0, 96.0)
	_add_moving_platform(6680.0, 330.0, 120.0)
	_add_platform(6860.0, 380.0, 80.0)

	_add_fire_pulse(6480.0, GROUND_BOTTOM - 14.0, 6.0, 0.8)
	_add_fire_pulse(6800.0, GROUND_BOTTOM - 14.0, 6.0, 3.4)

	_add_coin(6368.0, 340.0)
	_add_coin(6568.0, 270.0)
	_add_coin(6740.0, 300.0)
	_add_coin(6908.0, 350.0)
	_add_coin_arc(6620.0, 220.0, 5, 110.0)

	_hang_banner(6500.0, 40.0, COL_BLOOD)
	_hang_banner(6800.0, 40.0, COL_GOLD)

	_add_jet_trooper(6600.0, 180.0, 17, 800.0, 120.0)

	# Exit terrace
	_place_texture(TEX_WALL_SEC, 7100.0, 80.0, Vector2(1.0, 1.0), -3, Color(0.78, 0.74, 0.82))
	_place_texture(TEX_TOWER_ROOF, 7340.0, -40.0, Vector2(0.85, 0.85), -3, Color(0.85, 0.82, 0.88))

	_add_arrow_sign(7140.0, _surface_y_at(7140.0) - 22.0)
	_add_coin(7220.0, _surface_y_at(7220.0) - 26.0)
	_add_coin(7260.0, _surface_y_at(7260.0) - 26.0)
	_add_coin(7300.0, _surface_y_at(7300.0) - 26.0)

	_scatter_ground_decor(7060.0, 7440.0, 3)

# -----------------------------------------------------------------------------
# Air patrols
# -----------------------------------------------------------------------------
func _spawn_air_demons() -> void:
	_add_winged_demon(
		440.0, 200.0,
		Color(0.55, 0.55, 0.60),
		Color(0.32, 0.32, 0.38),
		Color(0.10, 0.10, 0.12),
		Color(1.0, 0.65, 0.20),
		Color(0.85, 0.78, 0.40),
		11, 280.0, 90.0)

	_add_winged_demon(
		1880.0, 120.0,
		Color(0.70, 0.18, 0.20),
		Color(0.45, 0.10, 0.12),
		Color(0.12, 0.04, 0.04),
		Color(1.00, 0.90, 0.40),
		Color(0.95, 0.82, 0.55),
		13, 360.0, 110.0)

	_add_winged_demon(
		3300.0, 100.0,
		Color(0.75, 0.78, 0.90),
		Color(0.40, 0.42, 0.55),
		Color(0.10, 0.10, 0.18),
		Color(0.55, 0.95, 1.00),
		Color(0.85, 0.92, 1.00),
		14, 360.0, 130.0)

	_add_winged_demon(
		4880.0, 140.0,
		Color(0.60, 0.45, 0.18),
		Color(0.40, 0.28, 0.10),
		Color(0.10, 0.08, 0.04),
		Color(1.00, 0.92, 0.40),
		Color(1.00, 0.85, 0.35),
		17, 420.0, 130.0)

	_add_greater_demon(2900.0, 130.0, Color(1.00, 0.75, 0.55), 26, 460.0, 130.0)
	_add_greater_demon(5780.0, 150.0, Color(0.95, 0.85, 0.40), 34, 360.0, 120.0)

# =============================================================================
# Metroidvania overlay
# =============================================================================
func _build_upper_route() -> void:
	var segs: Array = [
		Vector2(720.0,  88.0),
		Vector2(880.0,  72.0),
		Vector2(1040.0, 88.0),
		Vector2(1220.0, 104.0),
		Vector2(1400.0, 120.0),
		Vector2(1620.0, 120.0),
		Vector2(1840.0, 110.0),
		Vector2(2060.0, 120.0),
		Vector2(2280.0, 130.0),
		Vector2(2500.0, 120.0),
		Vector2(2720.0, 130.0),
		Vector2(2940.0, 120.0),
		Vector2(3160.0, 110.0),
		Vector2(3380.0, 100.0),
		Vector2(3600.0, 110.0),
		Vector2(3820.0, 100.0),
		Vector2(4040.0, 110.0),
		Vector2(4260.0, 100.0),
		Vector2(4480.0, 120.0),
	]
	for s in segs:
		_add_platform(s.x, s.y, 120.0)

	for s in segs:
		_add_coin(s.x + 56.0, s.y - 18.0)
	_add_coin_arc(1500.0, 80.0, 5, 140.0)
	_add_coin_arc(3270.0, 70.0, 5, 140.0)

	_add_arrow_sign(1900.0, 100.0)
	_add_arrow_sign(4140.0, 88.0)

	_add_solid(3260.0, 40.0, 96.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_powerup(3308.0, 14.0)
	_add_turret(3308.0, 28.0)
	_place_texture(TEX_ARCH_SM, 3270.0, -40.0, Vector2(1.0, 1.0), -2)

	_add_solid(4520.0, 40.0, 80.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_coin_row(4540.0, 14.0, 4, 18.0)

	_add_platform(4700.0, 130.0, 120.0)
	_add_platform(4900.0, 150.0, 120.0)
	_add_solid(5080.0, 170.0, 160.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)

	var halo := ColorRect.new()
	halo.z_index = -1
	halo.offset_left = 5080.0
	halo.offset_top = 100.0
	halo.offset_right = 5240.0
	halo.offset_bottom = 170.0
	halo.color = COL_EXIT_HALO
	add_child(halo)

	_place_texture(TEX_BANNER, 5130.0, 60.0, Vector2(1.0, 1.0), -1, COL_GOLD)

	var key_lever := LEVER_SCENE.instantiate() as Lever
	key_lever.position = Vector2(5160.0, 162.0)
	key_lever.name = "CrownKeyLever"
	key_lever.connected_doors = [NodePath("../ExitGate")]
	add_child(key_lever)

	_add_coin_row(5100.0, 140.0, 6, 18.0)
	_add_grenade_pickup(5120.0, 158.0, 2)

func _build_gated_exit() -> void:
	var exit_x: float = 7400.0
	var exit_surface: float = _surface_y_at(exit_x)
	var door := DOOR_SCENE.instantiate() as Door
	door.name = "ExitGate"
	door.position = Vector2(7340.0, exit_surface - 32.0)
	add_child(door)

	_add_exit(exit_x, exit_surface - 30.0)

	var stripe := ColorRect.new()
	stripe.z_index = -1
	stripe.offset_left = 7330.0
	stripe.offset_top = exit_surface - 80.0
	stripe.offset_right = 7350.0
	stripe.offset_bottom = exit_surface
	stripe.color = COL_GOLD
	add_child(stripe)
	_add_sign(7300.0, exit_surface - 20.0, COL_BLOOD)

func _build_hidden_vault() -> void:
	var vault_x: float = 50.0
	var vault_surface: float = _surface_y_at(vault_x)
	var door := DOOR_SCENE.instantiate() as Door
	door.name = "VaultDoor"
	door.position = Vector2(vault_x, vault_surface - 32.0)
	add_child(door)

	_add_powerup(20.0, vault_surface - 26.0)
	_add_coin_row(-10.0, vault_surface - 40.0, 3, 18.0)
	_add_grenade_pickup(40.0, vault_surface - 28.0, 1)

	var halo := ColorRect.new()
	halo.z_index = -1
	halo.offset_left = -20.0
	halo.offset_top = vault_surface - 70.0
	halo.offset_right = 50.0
	halo.offset_bottom = vault_surface
	halo.color = Color(0.95, 0.78, 0.30, 0.18)
	add_child(halo)

	_place_texture(TEX_SHIELD, 0.0, vault_surface - 80.0, Vector2(0.8, 0.8), -1)

	var vault_lever := LEVER_SCENE.instantiate() as Lever
	vault_lever.position = Vector2(7220.0, _surface_y_at(7220.0) - 78.0)
	vault_lever.name = "VaultLever"
	vault_lever.connected_doors = [NodePath("../VaultDoor")]
	add_child(vault_lever)

	# Lever perch above the exit terrace
	_add_solid(7180.0, _surface_y_at(7180.0) - 60.0, 80.0, 14.0, COL_PLAT, 3.0, COL_PLAT_TOP)
	_add_sign(7220.0, _surface_y_at(7220.0) - 68.0, COL_GOLD)

# -----------------------------------------------------------------------------
# Camera limits
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
