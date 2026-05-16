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

const LEVEL_LEFT:    float =    -20.0
const LEVEL_RIGHT:   float =  6020.0
const LEVEL_TOP:     float =   -60.0
const LEVEL_BOTTOM:  float =   820.0
const GROUND_TOP:    float =   400.0
const GROUND_BOTTOM: float =   720.0  # top of the sealed lower floor
const FLOOR_BOTTOM:  float =   820.0
const CEILING_BOT:   float =   -40.0

const COL_BG:        Color = Color(0.08, 0.10, 0.15)
const COL_BG_STRIPE: Color = Color(0.11, 0.13, 0.20, 0.45)
const COL_WALL:      Color = Color(0.18, 0.20, 0.25)
const COL_GROUND:    Color = Color(0.20, 0.23, 0.28)
const COL_GRASS:     Color = Color(0.28, 0.31, 0.36)
const COL_PLAT:      Color = Color(0.28, 0.32, 0.38)
const COL_PLAT_TOP:  Color = Color(0.36, 0.40, 0.46)
const COL_FLOOR:     Color = Color(0.14, 0.16, 0.20)
const COL_MOVE:      Color = Color(0.22, 0.45, 0.65)
const COL_BREAK:     Color = Color(0.50, 0.32, 0.20)

var _world: StaticBody2D

func _ready() -> void:
	_build_background()
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
# Construction helpers
# -----------------------------------------------------------------------------
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.z_index = -10
	bg.offset_left = LEVEL_LEFT - 100.0
	bg.offset_top = LEVEL_TOP - 200.0
	bg.offset_right = LEVEL_RIGHT + 100.0
	bg.offset_bottom = LEVEL_BOTTOM + 200.0
	bg.color = COL_BG
	add_child(bg)

	for i in range(3):
		var stripe := ColorRect.new()
		stripe.z_index = -9
		stripe.offset_left = LEVEL_LEFT - 100.0
		stripe.offset_top = 60.0 + float(i) * 125.0
		stripe.offset_right = LEVEL_RIGHT + 100.0
		stripe.offset_bottom = 86.0 + float(i) * 125.0
		stripe.color = COL_BG_STRIPE
		add_child(stripe)

	var pillar_x: float = 200.0
	while pillar_x < LEVEL_RIGHT - 100.0:
		var p := ColorRect.new()
		p.z_index = -9
		p.offset_left = pillar_x
		p.offset_top = LEVEL_TOP - 50.0
		p.offset_right = pillar_x + 8.0
		p.offset_bottom = GROUND_BOTTOM
		p.color = Color(0.10, 0.12, 0.17)
		add_child(p)
		pillar_x += 400.0

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

func _add_spike(x: float, y: float = GROUND_TOP - 8.0) -> void:
	var spike := SPIKE_SCENE.instantiate() as StaticBody2D
	spike.position = Vector2(x, y)
	add_child(spike)

func _add_spike_row(x_start: float, x_end: float, y: float) -> void:
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

func _add_soldier(x: float, y: float, patrol: float = 80.0) -> void:
	var s := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
	s.position = Vector2(x, y)
	s.patrol_distance = patrol
	$Enemies.add_child(s)

func _add_coin(x: float, y: float) -> void:
	var c := COIN_SCENE.instantiate()
	c.position = Vector2(x, y)
	$Coins.add_child(c)

func _add_coin_row(x_start: float, y: float, count: int, step: float = 24.0) -> void:
	for i in range(count):
		_add_coin(x_start + float(i) * step, y)

func _add_powerup(x: float, y: float) -> void:
	var pu := POWERUP_SCENE.instantiate() as PowerUp
	pu.position = Vector2(x, y)
	add_child(pu)

func _add_exit(x: float, y: float) -> void:
	var ed := EXIT_DOOR_SCENE.instantiate()
	ed.position = Vector2(x, y)
	add_child(ed)

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
# Section builders
# -----------------------------------------------------------------------------
# A — Start area: tutorial, easy hops, one enemy.
func _build_section_a_start() -> void:
	_add_ground(0.0, 700.0)
	_add_platform(150.0, 320.0, 96.0)
	_add_platform(330.0, 240.0, 96.0)
	_add_platform(530.0, 320.0, 96.0)
	_add_coin(198.0, 290.0)
	_add_coin(378.0, 210.0)
	_add_coin(578.0, 290.0)
	_add_coin(120.0, 374.0)
	_add_coin(620.0, 374.0)
	_add_soldier(450.0, 375.0)

# B — First pit guarded by two moving platforms over spike floor.
func _build_section_b_first_pit() -> void:
	# pit: 700..1400 (no ground top)
	_add_spike_row(720.0, 1380.0, GROUND_BOTTOM - 8.0)
	_add_moving_platform(780.0, 380.0, 120.0)
	_add_platform(1000.0, 320.0, 96.0)
	_add_coin(1048.0, 290.0)
	_add_moving_platform(1180.0, 380.0, 120.0)
	_add_coin(840.0, 350.0)
	_add_coin(1240.0, 350.0)

# C — Stair climb of break platforms over solid ground.
func _build_section_c_break_climb() -> void:
	_add_ground(1400.0, 2100.0)
	_add_break_platform(1430.0, 320.0, 80.0)
	_add_break_platform(1570.0, 240.0, 80.0)
	_add_break_platform(1710.0, 160.0, 80.0)
	_add_platform(1850.0, 100.0, 160.0)
	_add_coin(1900.0, 70.0)
	_add_coin(1930.0, 70.0)
	_add_coin(1960.0, 70.0)
	_add_coin(1470.0, 290.0)
	_add_coin(1610.0, 210.0)
	_add_coin(1750.0, 130.0)
	_add_soldier(1500.0, 375.0)
	_add_soldier(1900.0, 375.0, 60.0)
	# step-down on the right side back to ground level
	_add_platform(2010.0, 220.0, 96.0)

# D — Spike corridor: islands of ground separated by spike pits.
func _build_section_d_spike_corridor() -> void:
	_add_ground(2100.0, 2220.0)
	_add_spike_row(2220.0, 2370.0, GROUND_BOTTOM - 8.0)
	_add_ground(2370.0, 2510.0)
	_add_spike_row(2510.0, 2660.0, GROUND_BOTTOM - 8.0)
	_add_ground(2660.0, 2900.0)
	# Helper static platforms over the pits — challenging hop, doable without
	# moving platforms but a moving platform makes one easier.
	_add_platform(2260.0, 340.0, 80.0)
	_add_moving_platform(2545.0, 340.0, 100.0)
	_add_coin(2295.0, 310.0)
	_add_coin(2575.0, 310.0)
	_add_coin(2435.0, 374.0)
	_add_soldier(2450.0, 375.0, 60.0)
	_add_soldier(2780.0, 375.0)

# E — Vertical break-platform climb to a power-up perch.
func _build_section_e_vertical_climb() -> void:
	_add_ground(2900.0, 3500.0)
	_add_break_platform(2970.0, 320.0, 80.0)
	_add_break_platform(3120.0, 240.0, 80.0)
	_add_break_platform(3270.0, 160.0, 80.0)
	_add_platform(3380.0, 80.0, 140.0)
	_add_powerup(3450.0, 50.0)
	_add_coin(3010.0, 290.0)
	_add_coin(3160.0, 210.0)
	_add_coin(3310.0, 130.0)
	_add_coin(3430.0, 50.0)
	# stair back down on the right
	_add_platform(3520.0, 200.0, 96.0)
	_add_soldier(3050.0, 375.0)
	_add_soldier(3350.0, 375.0, 60.0)

# F — Long horizontal pit with moving-platform gauntlet & rest islands.
func _build_section_f_big_pit_gauntlet() -> void:
	# big pit: 3500..4500
	_add_spike_row(3520.0, 4480.0, GROUND_BOTTOM - 8.0)
	_add_moving_platform(3560.0, 370.0, 120.0)
	_add_platform(3760.0, 300.0, 96.0)
	_add_coin(3790.0, 270.0)
	_add_moving_platform(3900.0, 320.0, 120.0)
	_add_platform(4080.0, 380.0, 96.0)
	_add_coin(4110.0, 350.0)
	_add_moving_platform(4220.0, 320.0, 120.0)
	_add_platform(4380.0, 380.0, 96.0)
	_add_coin(4410.0, 350.0)

# G — Mixed challenge: solid ground, break + static + moving + enemies.
func _build_section_g_mixed_challenge() -> void:
	_add_ground(4500.0, 5200.0)
	_add_platform(4540.0, 320.0, 96.0)
	_add_break_platform(4700.0, 280.0, 80.0)
	_add_platform(4860.0, 220.0, 120.0)
	_add_break_platform(5020.0, 280.0, 80.0)
	_add_moving_platform(4720.0, 160.0, 100.0)
	# a couple of floor spikes between safer spots
	_add_spike(4640.0, GROUND_TOP - 8.0)
	_add_spike(4670.0, GROUND_TOP - 8.0)
	_add_spike(5130.0, GROUND_TOP - 8.0)
	_add_coin(4580.0, 290.0)
	_add_coin(4740.0, 250.0)
	_add_coin(4900.0, 190.0)
	_add_coin(5060.0, 250.0)
	_add_soldier(4560.0, 375.0)
	_add_soldier(4880.0, 375.0, 60.0)
	_add_soldier(5160.0, 375.0)

# H — Final stretch: clear path, reward power-up, exit door.
func _build_section_h_final_stretch() -> void:
	_add_ground(5200.0, 6000.0)
	_add_platform(5260.0, 320.0, 120.0)
	_add_platform(5440.0, 260.0, 120.0)
	_add_platform(5620.0, 320.0, 120.0)
	_add_powerup(5500.0, 230.0)
	_add_coin(5310.0, 290.0)
	_add_coin(5490.0, 230.0)
	_add_coin(5670.0, 290.0)
	_add_coin(5780.0, 374.0)
	_add_coin(5820.0, 374.0)
	_add_coin(5860.0, 374.0)
	_add_soldier(5320.0, 375.0)
	_add_soldier(5700.0, 375.0, 60.0)
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
