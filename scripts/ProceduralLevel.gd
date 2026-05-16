extends Node2D

const ROOM_W: int  = 800
const ROOM_H: int  = 700
const ROOM_GAP: int = 300
const WALL_W: int  = 24
const FLOOR_H: int = 40
const CEIL_H: int  = 20
const DOOR_H: int  = 90
const PLAT_H: int  = 14

const RANGE_SOLDIER_SCENE    := preload("res://scenes/RangeSoldier.tscn")
const COIN_SCENE             := preload("res://scenes/Coin.tscn")
const POWERUP_SCENE          := preload("res://scenes/PowerUp.tscn")
const EXIT_DOOR_SCENE        := preload("res://scenes/ExitDoor.tscn")
const PLAYER_SCENE           := preload("res://scenes/Player.tscn")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/MovingPlatform.gd")
const BREAK_PLATFORM_SCRIPT  := preload("res://scripts/BreakPlatform.gd")
const ROOM_PORTAL_SCRIPT     := preload("res://scripts/RoomPortal.gd")

var _rooms: Array = []
var _player: Player = null
var _cam: Camera2D = null
var _is_transitioning: bool = false

func _ready() -> void:
	var depth: int = RunState.depth
	var num_rooms: int = clampi(3 + depth, 3, 8)
	var pal := _depth_palette(depth)
	_generate_world(num_rooms, depth, pal)
	_spawn_player_in_room(0)

# ---------------------------------------------------------------------------
# Public API used by RoomPortal
# ---------------------------------------------------------------------------
func is_transitioning() -> bool:
	return _is_transitioning

func do_room_transition(player: Player, target_pos: Vector2, target_room: int) -> void:
	_is_transitioning = true
	player.set_physics_process(false)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 15
	add_child(fade_layer)
	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_layer.add_child(black)

	var tw := create_tween()
	tw.tween_property(black, "color", Color(0, 0, 0, 1), 0.22)
	tw.tween_callback(func() -> void:
		player.global_position = target_pos
		player.velocity = Vector2.ZERO
		if _cam != null and target_room >= 0 and target_room < _rooms.size():
			_set_camera_limits(_rooms[target_room]["offset"])
		player.set_physics_process(true)
		var tw2 := create_tween()
		tw2.tween_property(black, "color", Color(0, 0, 0, 0), 0.22)
		tw2.tween_callback(func() -> void:
			fade_layer.queue_free()
			_is_transitioning = false
		)
	)

# ---------------------------------------------------------------------------
# World generation
# ---------------------------------------------------------------------------
func _generate_world(num_rooms: int, depth: int, pal: Dictionary) -> void:
	var stride: int = ROOM_W + ROOM_GAP
	var floor_rel: float = float(ROOM_H - FLOOR_H)  # Y of floor surface within a room

	for i in range(num_rooms):
		var offset := Vector2(float(i * stride), 0.0)
		var is_last: bool = (i == num_rooms - 1)

		var door_left_y: float = -1.0
		var door_right_y: float = -1.0

		if i > 0:
			door_left_y = _rooms[i - 1]["door_right_y"]

		if not is_last:
			if i == 0:
				# First door: floor-level so the run starts easy
				door_right_y = floor_rel - float(DOOR_H) * 0.5
			else:
				# Progressively raise doors toward the ceiling as rooms advance
				var t: float = float(i) / float(num_rooms - 1)
				var raise: float = clampf(float(depth) * 0.18, 0.0, 0.72)
				door_right_y = lerpf(floor_rel - float(DOOR_H) * 0.5, 160.0, t * raise)

		var room := _build_room(i, offset, door_left_y, door_right_y, is_last, depth, pal)
		room["door_right_y"] = door_right_y
		_rooms.append(room)

	# Link portal pairs between adjacent rooms
	for i in range(num_rooms - 1):
		var pr: RoomPortal = _rooms[i]["portal_right"]
		var pl: RoomPortal = _rooms[i + 1]["portal_left"]
		if pr != null and pl != null:
			pr.partner = pl
			pl.partner = pr

func _build_room(idx: int, offset: Vector2, door_left_y: float, door_right_y: float,
		is_last: bool, depth: int, pal: Dictionary) -> Dictionary:
	var room: Dictionary = {
		"offset": offset,
		"portal_left": null,
		"portal_right": null,
		"door_right_y": door_right_y,
	}
	_build_room_bg(offset, pal)
	_build_room_geometry(idx, offset, door_left_y, door_right_y, pal, room)
	var plats := _build_room_platforms(idx, offset, depth, pal)
	room["platforms"] = plats
	_build_wall_columns(offset, pal)
	_spawn_room_enemies(plats, depth, idx == 0)
	_spawn_room_collectibles(plats)
	if is_last:
		_spawn_exit_in_room(plats)
	return room

# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------
func _build_room_bg(offset: Vector2, pal: Dictionary) -> void:
	var bg_root := Node2D.new()
	bg_root.z_index = -10
	add_child(bg_root)

	var bg := ColorRect.new()
	bg.offset_left   = offset.x
	bg.offset_top    = offset.y
	bg.offset_right  = offset.x + float(ROOM_W)
	bg.offset_bottom = offset.y + float(ROOM_H)
	bg.color = pal["bg"] as Color
	bg_root.add_child(bg)

	for _i in range(randi_range(3, 5)):
		var sy := offset.y + float(randi_range(0, ROOM_H))
		var strip := ColorRect.new()
		strip.offset_left   = offset.x
		strip.offset_top    = sy
		strip.offset_right  = offset.x + float(ROOM_W)
		strip.offset_bottom = sy + float(randi_range(8, 24))
		strip.color = pal["strip"] as Color
		bg_root.add_child(strip)

	var px: float = offset.x
	while px < offset.x + float(ROOM_W):
		var col := ColorRect.new()
		col.offset_left   = px
		col.offset_top    = offset.y
		col.offset_right  = px + 8.0
		col.offset_bottom = offset.y + float(ROOM_H)
		col.color = pal["pillar"] as Color
		bg_root.add_child(col)
		px += 160.0

# ---------------------------------------------------------------------------
# Walls, floor, ceiling — with door gaps where connected
# ---------------------------------------------------------------------------
func _build_room_geometry(idx: int, offset: Vector2, door_left_y: float, door_right_y: float,
		pal: Dictionary, room: Dictionary) -> void:
	var wc: Color = pal["wall"]
	var gc: Color = pal["ground"]

	# Ceiling
	_make_solid_rect(offset + Vector2(float(WALL_W), 0.0),
			float(ROOM_W - WALL_W * 2), float(CEIL_H), wc)

	# Floor
	_make_solid_rect(offset + Vector2(float(WALL_W), float(ROOM_H - FLOOR_H)),
			float(ROOM_W - WALL_W * 2), float(FLOOR_H), gc)
	var fhl := ColorRect.new()
	fhl.offset_left   = offset.x + float(WALL_W)
	fhl.offset_top    = offset.y + float(ROOM_H - FLOOR_H)
	fhl.offset_right  = offset.x + float(ROOM_W - WALL_W)
	fhl.offset_bottom = offset.y + float(ROOM_H - FLOOR_H) + 3.0
	fhl.color = Color(gc.r + 0.07, gc.g + 0.07, gc.b + 0.07)
	fhl.z_index = 1
	add_child(fhl)

	# Left wall
	if door_left_y > 0.0:
		_build_wall_with_door(idx, offset, true, door_left_y, wc, room)
	else:
		_make_solid_rect(Vector2(offset.x, offset.y), float(WALL_W), float(ROOM_H), wc)

	# Right wall
	if door_right_y > 0.0:
		_build_wall_with_door(idx, offset, false, door_right_y, wc, room)
	else:
		_make_solid_rect(Vector2(offset.x + float(ROOM_W - WALL_W), offset.y),
				float(WALL_W), float(ROOM_H), wc)

func _build_wall_with_door(room_idx: int, offset: Vector2, is_left: bool,
		door_center_y: float, wc: Color, room: Dictionary) -> void:
	var wx: float = offset.x if is_left else offset.x + float(ROOM_W - WALL_W)
	var door_top: float = offset.y + door_center_y - float(DOOR_H) * 0.5
	var door_bot: float = door_top + float(DOOR_H)

	# Upper wall segment
	var ceil_bot: float = offset.y + float(CEIL_H)
	if door_top > ceil_bot:
		_make_solid_rect(Vector2(wx, ceil_bot), float(WALL_W), door_top - ceil_bot, wc)

	# Lower wall segment
	var floor_top: float = offset.y + float(ROOM_H - FLOOR_H)
	if door_bot < floor_top:
		_make_solid_rect(Vector2(wx, door_bot), float(WALL_W), floor_top - door_bot, wc)

	# Portal frame (teal glow border)
	var portal_color := Color(0.18, 0.78, 0.88)
	var frame := ColorRect.new()
	frame.offset_left   = wx - 2.0
	frame.offset_top    = door_top - 2.0
	frame.offset_right  = wx + float(WALL_W) + 2.0
	frame.offset_bottom = door_bot + 2.0
	frame.color = portal_color
	frame.z_index = 2
	add_child(frame)

	# Portal interior fill
	var fill := ColorRect.new()
	fill.offset_left   = wx
	fill.offset_top    = door_top
	fill.offset_right  = wx + float(WALL_W)
	fill.offset_bottom = door_bot
	fill.color = Color(0.04, 0.22, 0.32, 0.85)
	fill.z_index = 3
	add_child(fill)

	# Spawn point inside the room, near the door
	var spawn_x: float
	if is_left:
		spawn_x = offset.x + float(WALL_W) + 38.0
	else:
		spawn_x = offset.x + float(ROOM_W - WALL_W) - 38.0
	var spawn_y: float = door_bot - 22.0

	# Portal Area2D trigger
	var portal := Area2D.new()
	portal.set_script(ROOM_PORTAL_SCRIPT)
	portal.room_idx = room_idx
	portal.player_spawn = Vector2(spawn_x, spawn_y)
	portal.position = Vector2(wx + float(WALL_W) * 0.5, (door_top + door_bot) * 0.5)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(WALL_W) + 10.0, float(DOOR_H) - 6.0)
	shape.shape = rect
	portal.add_child(shape)
	add_child(portal)

	if is_left:
		room["portal_left"] = portal
	else:
		room["portal_right"] = portal

# ---------------------------------------------------------------------------
# Solid rect — StaticBody2D + ColorRect + CollisionShape2D
# ---------------------------------------------------------------------------
func _make_solid_rect(pos: Vector2, w: float, h: float, color: Color) -> void:
	if w <= 0.0 or h <= 0.0:
		return
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	add_child(sb)

	var cr := ColorRect.new()
	cr.offset_left   = pos.x
	cr.offset_top    = pos.y
	cr.offset_right  = pos.x + w
	cr.offset_bottom = pos.y + h
	cr.color = color
	sb.add_child(cr)

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	cs.shape = rs
	cs.position = pos + Vector2(w * 0.5, h * 0.5)
	sb.add_child(cs)

# ---------------------------------------------------------------------------
# Three-tier platform layout per room
# ---------------------------------------------------------------------------
func _build_room_platforms(room_idx: int, offset: Vector2, depth: int, pal: Dictionary) -> Array:
	var plats: Array = []
	var bc: Color = pal["plat"]
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)

	# Heights above the floor for each tier
	var tier_lifts: Array[float] = [90.0, 240.0, 400.0]

	for tier in range(tier_lifts.size()):
		var base_y: float = floor_y - tier_lifts[tier]
		var n: int = randi_range(3, 4)
		var cur_x: float = offset.x + float(WALL_W) + randf_range(30.0, 70.0)

		for _p in range(n):
			var y: float = base_y + randf_range(-15.0, 15.0)
			var w: float = randf_range(80.0, 140.0)
			if cur_x + w > offset.x + float(ROOM_W - WALL_W) - 20.0:
				break

			var roll := randf() if room_idx > 0 else 1.0
			if roll < 0.14 and tier > 0:
				_make_moving_platform(cur_x, y, w, pal["move"] as Color)
			elif roll < 0.27 and tier > 0:
				_make_break_platform(cur_x, y, w, pal["brk"] as Color)
			else:
				var shade := randf_range(0.0, 0.06)
				_make_platform(cur_x, y, w, Color(bc.r + shade, bc.g + shade, bc.b + shade))

			var pd := {"x": cur_x, "y": y, "w": w}
			plats.append(pd)
			_maybe_add_pillar(pd, pal["support"] as Color, floor_y)

			cur_x += w + randf_range(55.0, 115.0)

	return plats

# ---------------------------------------------------------------------------
# Interior wall columns — the surfaces players wall-jump off
# ---------------------------------------------------------------------------
func _build_wall_columns(offset: Vector2, pal: Dictionary) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	var inner_left: float = offset.x + float(WALL_W) + 60.0
	var inner_right: float = offset.x + float(ROOM_W - WALL_W) - 60.0
	var n: int = randi_range(2, 4)
	var used_xs: Array[float] = []

	for _i in range(n):
		var cx: float = randf_range(inner_left, inner_right)
		var too_close := false
		for ux: float in used_xs:
			if absf(cx - ux) < 65.0:
				too_close = true
				break
		if too_close:
			continue
		used_xs.append(cx)

		var col_h: float = randf_range(220.0, 500.0)
		_add_wall_pillar(cx, floor_y - col_h, 20.0, col_h, pal["support"] as Color)

# ---------------------------------------------------------------------------
# Enemies, collectibles, exit
# ---------------------------------------------------------------------------
func _spawn_room_enemies(plats: Array, depth: int, is_first_room: bool) -> void:
	for i in range(plats.size()):
		if is_first_room and i == 0:
			continue
		var plat: Dictionary = plats[i] as Dictionary
		if randf() < 0.55:
			var e := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
			e.max_health = 3 + int(depth / 2.0)
			e.fire_rate = 1.0 + depth * 0.12
			e.position = Vector2(plat["x"] + plat["w"] * 0.5, plat["y"] - 1.0)
			add_child(e)
		if depth > 2 and randf() < 0.25:
			var e2 := RANGE_SOLDIER_SCENE.instantiate() as RangeSoldier
			e2.max_health = 3 + int(depth / 2.0)
			e2.fire_rate = 1.0 + depth * 0.12
			e2.position = Vector2(plat["x"] + plat["w"] * 0.75, plat["y"] - 1.0)
			add_child(e2)

func _spawn_room_collectibles(plats: Array) -> void:
	for plat: Dictionary in plats:
		var cn: int = randi_range(1, 3)
		for c in range(cn):
			var coin := COIN_SCENE.instantiate()
			coin.position = Vector2(plat["x"] + (plat["w"] / float(cn + 1)) * float(c + 1), plat["y"] - 16.0)
			add_child(coin)
		if randf() < 0.30:
			var pu := POWERUP_SCENE.instantiate() as PowerUp
			pu.type = PowerUp.Type.values()[randi() % 4]
			pu.position = Vector2(plat["x"] + plat["w"] * 0.5, plat["y"] - 24.0)
			add_child(pu)

func _spawn_exit_in_room(plats: Array) -> void:
	var pos: Vector2
	if plats.is_empty():
		pos = Vector2(float(ROOM_W) * 0.5, float(ROOM_H - FLOOR_H) - 40.0)
	else:
		var highest: Dictionary = plats[0]
		for p: Dictionary in plats:
			if p["y"] < highest["y"]:
				highest = p
		pos = Vector2(highest["x"] + highest["w"] * 0.5, highest["y"] - 36.0)
	var door := EXIT_DOOR_SCENE.instantiate()
	door.position = pos
	add_child(door)

# ---------------------------------------------------------------------------
# Player spawn and camera
# ---------------------------------------------------------------------------
func _spawn_player_in_room(room_idx: int) -> void:
	var offset: Vector2 = _rooms[room_idx]["offset"]
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = offset + Vector2(float(WALL_W) + 60.0, float(ROOM_H - FLOOR_H) - 20.0)
	add_child(player)
	_player = player

	_cam = player.get_node_or_null("Camera2D") as Camera2D
	if _cam != null:
		_set_camera_limits(offset)

func _set_camera_limits(offset: Vector2) -> void:
	if _cam == null:
		return
	_cam.limit_left   = int(offset.x) - 50
	_cam.limit_right  = int(offset.x) + ROOM_W + 50
	_cam.limit_top    = int(offset.y) - 50
	_cam.limit_bottom = int(offset.y) + ROOM_H + 50

# ---------------------------------------------------------------------------
# Depth-based colour palette (unchanged)
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
		}

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

func _maybe_add_pillar(plat: Dictionary, color: Color, floor_y: float) -> void:
	if randf() >= 0.35:
		return
	var pw := 16.0
	var px: float = plat["x"] + plat["w"] * 0.5 - pw * 0.5
	var pt: float = plat["y"] + float(PLAT_H)
	_add_wall_pillar(px, pt, pw, floor_y - pt, color)
