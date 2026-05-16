extends Node2D

const GROUND_Y: int = 400
const PLAT_H: int = 14

const RANGE_SOLDIER_SCENE := preload("res://scenes/RangeSoldier.tscn")
const COIN_SCENE         := preload("res://scenes/Coin.tscn")
const POWERUP_SCENE      := preload("res://scenes/PowerUp.tscn")
const EXIT_DOOR_SCENE    := preload("res://scenes/ExitDoor.tscn")
const PLAYER_SCENE       := preload("res://scenes/Player.tscn")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/MovingPlatform.gd")
const BREAK_PLATFORM_SCRIPT  := preload("res://scripts/BreakPlatform.gd")

var level_width: int = 0
var _platforms: Array = []

func _ready() -> void:
	var depth: int = RunState.depth
	level_width = 1200 + depth * 150
	var pal := _depth_palette(depth)
	_spawn_background(pal)
	_spawn_ground_and_walls(pal)
	_platforms = _spawn_platforms(depth, pal)
	_spawn_enemies(_platforms)
	_spawn_collectibles(_platforms)
	_spawn_exit(_platforms)
	_spawn_player()

# ---------------------------------------------------------------------------
# Depth-based colour palette
# ---------------------------------------------------------------------------
func _depth_palette(depth: int) -> Dictionary:
	if depth < 3:
		return {
			"bg":      Color(0.08, 0.10, 0.15),
			"strip":   Color(0.11, 0.13, 0.19, 0.45),
			"pillar":  Color(0.10, 0.12, 0.17),
			"ground":  Color(0.20, 0.23, 0.28),
			"wall":    Color(0.18, 0.20, 0.25),
			"plat":    Color(0.28, 0.32, 0.38),
			"move":    Color(0.24, 0.42, 0.34),
			"brk":     Color(0.46, 0.30, 0.22),
			"support": Color(0.22, 0.25, 0.31),
			"corridor":Color(0.24, 0.27, 0.33),
		}
	elif depth < 6:
		return {
			"bg":      Color(0.12, 0.08, 0.07),
			"strip":   Color(0.17, 0.10, 0.09, 0.45),
			"pillar":  Color(0.14, 0.09, 0.08),
			"ground":  Color(0.26, 0.18, 0.16),
			"wall":    Color(0.22, 0.15, 0.13),
			"plat":    Color(0.36, 0.26, 0.22),
			"move":    Color(0.42, 0.30, 0.18),
			"brk":     Color(0.52, 0.28, 0.18),
			"support": Color(0.28, 0.20, 0.18),
			"corridor":Color(0.30, 0.22, 0.19),
		}
	else:
		return {
			"bg":      Color(0.07, 0.06, 0.12),
			"strip":   Color(0.10, 0.08, 0.16, 0.45),
			"pillar":  Color(0.09, 0.07, 0.14),
			"ground":  Color(0.18, 0.14, 0.28),
			"wall":    Color(0.15, 0.12, 0.24),
			"plat":    Color(0.24, 0.18, 0.36),
			"move":    Color(0.20, 0.24, 0.44),
			"brk":     Color(0.40, 0.18, 0.34),
			"support": Color(0.18, 0.14, 0.28),
			"corridor":Color(0.20, 0.16, 0.30),
		}

# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------
func _spawn_background(pal: Dictionary) -> void:
	var bg_root := Node2D.new()
	bg_root.z_index = -10
	add_child(bg_root)

	var bg := ColorRect.new()
	bg.offset_left = -200.0
	bg.offset_top = -400.0
	bg.offset_right = float(level_width + 200)
	bg.offset_bottom = float(GROUND_Y + 400)
	bg.color = pal["bg"]
	bg_root.add_child(bg)

	for _i in range(randi_range(4, 7)):
		var strip := ColorRect.new()
		var sy := float(randi_range(-300, GROUND_Y - 50))
		strip.offset_left = -200.0
		strip.offset_top = sy
		strip.offset_right = float(level_width + 200)
		strip.offset_bottom = sy + float(randi_range(16, 42))
		strip.color = pal["strip"]
		bg_root.add_child(strip)

	var px: int = 0
	while px < level_width:
		var p := ColorRect.new()
		p.offset_left = float(px)
		p.offset_top = -400.0
		p.offset_right = float(px + 8)
		p.offset_bottom = float(GROUND_Y + 400)
		p.color = pal["pillar"]
		bg_root.add_child(p)
		px += 200

# ---------------------------------------------------------------------------
# Ground and perimeter walls
# ---------------------------------------------------------------------------
func _spawn_ground_and_walls(pal: Dictionary) -> void:
	var gc := pal["ground"]
	var wc := pal["wall"]

	var gsb := StaticBody2D.new()
	gsb.collision_layer = 1
	gsb.collision_mask = 0
	add_child(gsb)
	var gcr := ColorRect.new()
	gcr.offset_left = 0.0
	gcr.offset_top = float(GROUND_Y)
	gcr.offset_right = float(level_width)
	gcr.offset_bottom = float(GROUND_Y + 200)
	gcr.color = gc
	gsb.add_child(gcr)
	var gt := ColorRect.new()
	gt.offset_left = 0.0
	gt.offset_top = float(GROUND_Y)
	gt.offset_right = float(level_width)
	gt.offset_bottom = float(GROUND_Y) + 3.0
	gt.color = Color(gc.r + 0.06, gc.g + 0.06, gc.b + 0.06)
	gsb.add_child(gt)
	var gs := CollisionShape2D.new()
	var gr := RectangleShape2D.new()
	gr.size = Vector2(float(level_width), 200.0)
	gs.shape = gr
	gs.position = Vector2(float(level_width) * 0.5, float(GROUND_Y) + 100.0)
	gsb.add_child(gs)

	var lsb := StaticBody2D.new()
	lsb.collision_layer = 1
	lsb.collision_mask = 0
	add_child(lsb)
	var lcr := ColorRect.new()
	lcr.offset_left = -24.0
	lcr.offset_top = -400.0
	lcr.offset_right = 0.0
	lcr.offset_bottom = float(GROUND_Y + 200)
	lcr.color = wc
	lsb.add_child(lcr)
	var ls := CollisionShape2D.new()
	var lr := RectangleShape2D.new()
	lr.size = Vector2(24.0, float(GROUND_Y + 600))
	ls.shape = lr
	ls.position = Vector2(-12.0, float(GROUND_Y) * 0.5)
	lsb.add_child(ls)

	var rsb: StaticBody2D = StaticBody2D.new()
	rsb.collision_layer = 1
	rsb.collision_mask = 0
	add_child(rsb)
	var rcr := ColorRect.new()
	rcr.offset_left = float(level_width)
	rcr.offset_top = -400.0
	rcr.offset_right = float(level_width + 24)
	rcr.offset_bottom = float(GROUND_Y + 200)
	rcr.color = wc
	rsb.add_child(rcr)
	var rs := CollisionShape2D.new()
	var rr := RectangleShape2D.new()
	rr.size = Vector2(24.0, float(GROUND_Y + 600))
	rs.shape = rr
	rs.position = Vector2(float(level_width + 12), float(GROUND_Y) * 0.5)
	rsb.add_child(rs)

# ---------------------------------------------------------------------------
# Platform helpers
# ---------------------------------------------------------------------------
func _make_platform(x: float, y: float, w: float, color: Color) -> StaticBody2D:
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	add_child(sb)

	var cr := ColorRect.new()
	cr.offset_left = x
	cr.offset_top = y
	cr.offset_right = x + w
	cr.offset_bottom = y + float(PLAT_H)
	cr.color = color
	sb.add_child(cr)

	var hl := ColorRect.new()
	hl.offset_left = x
	hl.offset_top = y
	hl.offset_right = x + w
	hl.offset_bottom = y + 3.0
	hl.color = Color(color.r + 0.08, color.g + 0.08, color.b + 0.08)
	sb.add_child(hl)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, float(PLAT_H))
	shape.shape = rect
	shape.position = Vector2(x + w * 0.5, y + float(PLAT_H) * 0.5)
	sb.add_child(shape)
	return sb

func _make_moving_platform(x: float, y: float, w: float, color: Color) -> void:
	var mp := AnimatableBody2D.new()
	mp.set_script(MOVING_PLATFORM_SCRIPT)
	mp.setup(x, y, w, color)
	add_child(mp)

func _make_break_platform(x: float, y: float, w: float, color: Color) -> void:
	var bp := StaticBody2D.new()
	bp.set_script(BREAK_PLATFORM_SCRIPT)
	bp.setup(x, y, w, color)
	add_child(bp)

func _add_wall_pillar(x: float, y: float, w: float, h: float, color: Color) -> void:
	if h < 30.0:
		return
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	add_child(sb)
	var cr := ColorRect.new()
	cr.offset_left = x
	cr.offset_top = y
	cr.offset_right = x + w
	cr.offset_bottom = y + h
	cr.color = color
	sb.add_child(cr)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(x + w * 0.5, y + h * 0.5)
	sb.add_child(shape)

func _maybe_add_pillar(plat: Dictionary, color: Color) -> void:
	if randf() >= 0.40:
		return
	var pw := 16.0
	var px := plat["x"] + plat["w"] * 0.5 - pw * 0.5
	var pt := plat["y"] + float(PLAT_H)
	_add_wall_pillar(px, pt, pw, float(GROUND_Y) - pt, color)

func _maybe_add_corridor(gap_start: float, gap_end: float, plat_y: float, color: Color) -> void:
	var gw := gap_end - gap_start
	if gw < 110.0 or randf() >= 0.28:
		return
	var cx := gap_start + gw * 0.5
	var pw := 14.0
	var ph := float(GROUND_Y) - plat_y
	_add_wall_pillar(cx - 48.0 - pw, plat_y, pw, ph, color)
	_add_wall_pillar(cx + 48.0,       plat_y, pw, ph, color)

# ---------------------------------------------------------------------------
# Platform spawning with section-based layout and platform variety
# ---------------------------------------------------------------------------
func _spawn_platforms(depth: int, pal: Dictionary) -> Array:
	var plats: Array = []
	var num: int = 5 + depth
	var cur_x: float = 180.0
	var cur_y: float = float(GROUND_Y) - 110.0
	var trend: int = 0     # -1 = climb, 0 = flat, 1 = descend
	var trend_left: int = 0

	for i in range(num):
		# Pick a new directional section every 2-4 platforms
		if trend_left <= 0:
			trend_left = randi_range(2, 4)
			trend = randi_range(-1, 1)
		trend_left -= 1

		var dy: float
		match trend:
			-1: dy = randf_range(-38.0, -5.0)   # climb (lower Y = higher on screen)
			1:  dy = randf_range(5.0, 38.0)      # descend
			_:  dy = randf_range(-18.0, 18.0)    # flat
		cur_y = clampf(cur_y + dy, float(GROUND_Y) - 140.0, float(GROUND_Y) - 55.0)

		var w: float = randf_range(90.0, 170.0)
		var gap: float = randf_range(75.0, 130.0)

		# Platform type — first platform always solid so the run starts safely
		var roll := randf() if i > 0 else 1.0
		if roll < 0.18:
			_make_moving_platform(cur_x, cur_y, w, pal["move"])
		elif roll < 0.33:
			_make_break_platform(cur_x, cur_y, w, pal["brk"])
		else:
			var shade := randf_range(0.0, 0.07)
			var bc := pal["plat"]
			_make_platform(cur_x, cur_y, w, Color(bc.r + shade, bc.g + shade, bc.b + shade))

		var pd := {"x": cur_x, "y": cur_y, "w": w}
		plats.append(pd)
		_maybe_add_pillar(pd, pal["support"])
		_maybe_add_corridor(cur_x + w, cur_x + w + gap, cur_y, pal["corridor"])

		cur_x += w + gap
		if cur_x > float(level_width) - 200.0:
			break

	return plats

# ---------------------------------------------------------------------------
# Enemies, collectibles, exit, player — unchanged
# ---------------------------------------------------------------------------
func _spawn_enemies(platforms: Array) -> void:
	var depth: int = RunState.depth
	var count: int = platforms.size()
	for i in range(count):
		if i == 0 or i == count - 1:
			continue
		var plat: Dictionary = platforms[i]
		if randf() < 0.60:
			var enemy := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
			enemy.max_health = 3 + int(depth / 2.0)
			enemy.fire_rate = 1.0 + depth * 0.12
			enemy.position = Vector2(plat["x"] + plat["w"] * 0.5, plat["y"] - 1.0)
			add_child(enemy)
		if depth > 2 and randf() < 0.30:
			var enemy2 := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
			enemy2.max_health = 3 + int(depth / 2.0)
			enemy2.fire_rate = 1.0 + depth * 0.12
			enemy2.position = Vector2(plat["x"] + plat["w"] * 0.75, plat["y"] - 1.0)
			add_child(enemy2)

func _spawn_collectibles(platforms: Array) -> void:
	for plat in platforms:
		var coin_count: int = randi_range(2, 3)
		for c in range(coin_count):
			var coin := COIN_SCENE.instantiate()
			var cx: float = plat["x"] + (plat["w"] / float(coin_count + 1)) * float(c + 1)
			coin.position = Vector2(cx, plat["y"] - 16.0)
			add_child(coin)
		if randf() < 0.35:
			var pu := POWERUP_SCENE.instantiate() as PowerUp
			pu.type = PowerUp.Type.values()[randi() % 4]
			pu.position = Vector2(plat["x"] + plat["w"] * 0.5, plat["y"] - 24.0)
			add_child(pu)

func _spawn_exit(platforms: Array) -> void:
	if platforms.is_empty():
		return
	var last: Dictionary = platforms[platforms.size() - 1]
	var door := EXIT_DOOR_SCENE.instantiate()
	door.position = Vector2(last["x"] + last["w"] * 0.5, last["y"] - 36.0)
	add_child(door)

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(80.0, float(GROUND_Y) - 20.0)
	add_child(player)

	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_right = level_width + 80
		cam.limit_bottom = GROUND_Y + 200
		cam.limit_top = -400
		cam.limit_left = -50
