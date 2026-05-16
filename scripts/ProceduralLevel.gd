extends Node2D

const GROUND_Y: int = 400
const PLAT_H: int = 14

const RANGE_SOLDIER_SCENE := preload("res://scenes/RangeSoldier.tscn")
const COIN_SCENE := preload("res://scenes/Coin.tscn")
const POWERUP_SCENE := preload("res://scenes/PowerUp.tscn")
const EXIT_DOOR_SCENE := preload("res://scenes/ExitDoor.tscn")
const PLAYER_SCENE := preload("res://scenes/Player.tscn")

var level_width: int = 0
var _platforms: Array = []

func _ready() -> void:
	var depth: int = RunState.depth
	level_width = 1200 + depth * 150
	_spawn_background()
	_spawn_ground_and_walls()
	_platforms = _spawn_platforms()
	_spawn_enemies(_platforms)
	_spawn_collectibles(_platforms)
	_spawn_exit(_platforms)
	_spawn_player()

func _spawn_background() -> void:
	var bg_root := Node2D.new()
	bg_root.z_index = -10
	add_child(bg_root)

	var bg := ColorRect.new()
	bg.offset_left = -200.0
	bg.offset_top = -400.0
	bg.offset_right = float(level_width + 200)
	bg.offset_bottom = float(GROUND_Y + 400)
	bg.color = Color(0.08, 0.10, 0.15)
	bg_root.add_child(bg)

	# Horizontal depth strips
	for i in range(randi_range(4, 6)):
		var strip := ColorRect.new()
		var strip_y := float(randi_range(-300, GROUND_Y - 50))
		strip.offset_left = -200.0
		strip.offset_top = strip_y
		strip.offset_right = float(level_width + 200)
		strip.offset_bottom = strip_y + float(randi_range(18, 40))
		strip.color = Color(0.11, 0.13, 0.19, 0.45)
		bg_root.add_child(strip)

	# Vertical pillars every 200px
	var px: int = 0
	while px < level_width:
		var pillar := ColorRect.new()
		pillar.offset_left = float(px)
		pillar.offset_top = -400.0
		pillar.offset_right = float(px + 8)
		pillar.offset_bottom = float(GROUND_Y + 400)
		pillar.color = Color(0.10, 0.12, 0.17)
		bg_root.add_child(pillar)
		px += 200

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

	# Lighter top highlight strip
	var highlight := ColorRect.new()
	highlight.offset_left = x
	highlight.offset_top = y
	highlight.offset_right = x + w
	highlight.offset_bottom = y + 3.0
	highlight.color = Color(color.r + 0.08, color.g + 0.08, color.b + 0.08)
	sb.add_child(highlight)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, float(PLAT_H))
	shape.shape = rect
	shape.position = Vector2(x + w * 0.5, y + float(PLAT_H) * 0.5)
	sb.add_child(shape)

	return sb

func _spawn_ground_and_walls() -> void:
	var ground_color := Color(0.20, 0.23, 0.28)

	# Ground platform spanning full width
	var ground_sb := StaticBody2D.new()
	ground_sb.collision_layer = 1
	ground_sb.collision_mask = 0
	add_child(ground_sb)

	var ground_cr := ColorRect.new()
	ground_cr.offset_left = 0.0
	ground_cr.offset_top = float(GROUND_Y)
	ground_cr.offset_right = float(level_width)
	ground_cr.offset_bottom = float(GROUND_Y + 200)
	ground_cr.color = ground_color
	ground_sb.add_child(ground_cr)

	var ground_top := ColorRect.new()
	ground_top.offset_left = 0.0
	ground_top.offset_top = float(GROUND_Y)
	ground_top.offset_right = float(level_width)
	ground_top.offset_bottom = float(GROUND_Y) + 3.0
	ground_top.color = Color(ground_color.r + 0.06, ground_color.g + 0.06, ground_color.b + 0.06)
	ground_sb.add_child(ground_top)

	var ground_shape := CollisionShape2D.new()
	var ground_rect := RectangleShape2D.new()
	ground_rect.size = Vector2(float(level_width), 200.0)
	ground_shape.shape = ground_rect
	ground_shape.position = Vector2(float(level_width) * 0.5, float(GROUND_Y) + 100.0)
	ground_sb.add_child(ground_shape)

	# Left wall
	var wall_color := Color(0.18, 0.20, 0.25)
	var lwall_sb := StaticBody2D.new()
	lwall_sb.collision_layer = 1
	lwall_sb.collision_mask = 0
	add_child(lwall_sb)
	var lwall_cr := ColorRect.new()
	lwall_cr.offset_left = -24.0
	lwall_cr.offset_top = -400.0
	lwall_cr.offset_right = 0.0
	lwall_cr.offset_bottom = float(GROUND_Y + 200)
	lwall_cr.color = wall_color
	lwall_sb.add_child(lwall_cr)
	var lwall_shape := CollisionShape2D.new()
	var lwall_rect := RectangleShape2D.new()
	lwall_rect.size = Vector2(24.0, float(GROUND_Y + 600))
	lwall_shape.shape = lwall_rect
	lwall_shape.position = Vector2(-12.0, float(GROUND_Y) * 0.5)
	lwall_sb.add_child(lwall_shape)

	# Right wall
	var rwall_sb: StaticBody2D = StaticBody2D.new()
	rwall_sb.collision_layer = 1
	rwall_sb.collision_mask = 0
	add_child(rwall_sb)
	var rwall_cr := ColorRect.new()
	rwall_cr.offset_left = float(level_width)
	rwall_cr.offset_top = -400.0
	rwall_cr.offset_right = float(level_width + 24)
	rwall_cr.offset_bottom = float(GROUND_Y + 200)
	rwall_cr.color = wall_color
	rwall_sb.add_child(rwall_cr)
	var rwall_shape := CollisionShape2D.new()
	var rwall_rect := RectangleShape2D.new()
	rwall_rect.size = Vector2(24.0, float(GROUND_Y + 600))
	rwall_shape.shape = rwall_rect
	rwall_shape.position = Vector2(float(level_width + 12), float(GROUND_Y) * 0.5)
	rwall_sb.add_child(rwall_shape)

func _spawn_platforms() -> Array:
	var depth: int = RunState.depth
	var plats: Array = []
	var num: int = 5 + depth
	var cur_x: float = 180.0
	var cur_y: float = float(GROUND_Y) - 110.0

	for _i in range(num):
		var w: float = randf_range(90.0, 170.0)
		cur_y = clampf(cur_y + randf_range(-40.0, 40.0), float(GROUND_Y) - 140.0, float(GROUND_Y) - 55.0)
		var shade: float = randf_range(0.0, 0.07)
		var base_r: float = 0.28 + shade
		var base_g: float = 0.32 + shade
		var base_b: float = 0.38 + shade
		var color := Color(base_r, base_g, base_b)
		_make_platform(cur_x, cur_y, w, color)
		plats.append({"x": cur_x, "y": cur_y, "w": w})
		cur_x += w + randf_range(75.0, 130.0)
		if cur_x > float(level_width) - 200.0:
			break

	return plats

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
			enemy2.max_health = 3 + depth / 2
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
	var last_plat: Dictionary = platforms[platforms.size() - 1]
	var door := EXIT_DOOR_SCENE.instantiate()
	door.position = Vector2(last_plat["x"] + last_plat["w"] * 0.5, last_plat["y"] - 36.0)
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
