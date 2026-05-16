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
const GRENADE_PICKUP_SCENE   := preload("res://scenes/GrenadePickup.tscn")
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
	var theme := _pick_theme(depth)
	_generate_world(num_rooms, depth, theme)
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
func _generate_world(num_rooms: int, depth: int, theme: Dictionary) -> void:
	var stride: int = ROOM_W + ROOM_GAP
	var floor_rel: float = float(ROOM_H - FLOOR_H)

	for i in range(num_rooms):
		var offset := Vector2(float(i * stride), 0.0)
		var is_last: bool = (i == num_rooms - 1)

		var door_left_y: float = -1.0
		var door_right_y: float = -1.0

		if i > 0:
			door_left_y = _rooms[i - 1]["door_right_y"]

		if not is_last:
			if i == 0:
				door_right_y = floor_rel - float(DOOR_H) * 0.5
			else:
				var t: float = float(i) / float(num_rooms - 1)
				var raise: float = clampf(float(depth) * 0.18, 0.0, 0.72)
				door_right_y = lerpf(floor_rel - float(DOOR_H) * 0.5, 160.0, t * raise)

		var room := _build_room(i, offset, door_left_y, door_right_y, is_last, depth, theme)
		room["door_right_y"] = door_right_y
		_rooms.append(room)

	for i in range(num_rooms - 1):
		var pr: RoomPortal = _rooms[i]["portal_right"]
		var pl: RoomPortal = _rooms[i + 1]["portal_left"]
		if pr != null and pl != null:
			pr.partner = pl
			pl.partner = pr

func _build_room(idx: int, offset: Vector2, door_left_y: float, door_right_y: float,
		is_last: bool, depth: int, theme: Dictionary) -> Dictionary:
	var room: Dictionary = {
		"offset": offset,
		"portal_left": null,
		"portal_right": null,
		"door_right_y": door_right_y,
	}
	_build_room_bg(offset, theme)
	_build_room_geometry(idx, offset, door_left_y, door_right_y, theme, room)
	var plats := _build_room_platforms(idx, offset, depth, theme)
	room["platforms"] = plats
	_build_wall_columns(offset, theme)
	_add_env_deco(offset, theme)
	_spawn_room_enemies(plats, depth, idx == 0)
	_spawn_room_collectibles(plats)
	if is_last:
		_spawn_exit_in_room(plats)
	return room

# ---------------------------------------------------------------------------
# Background
# ---------------------------------------------------------------------------
func _build_room_bg(offset: Vector2, theme: Dictionary) -> void:
	var bg_root := Node2D.new()
	bg_root.z_index = -10
	add_child(bg_root)

	var bg := ColorRect.new()
	bg.offset_left   = offset.x
	bg.offset_top    = offset.y
	bg.offset_right  = offset.x + float(ROOM_W)
	bg.offset_bottom = offset.y + float(ROOM_H)
	bg.color = theme["bg"] as Color
	bg_root.add_child(bg)

	for _i in range(randi_range(3, 5)):
		var sy := offset.y + float(randi_range(0, ROOM_H))
		var strip := ColorRect.new()
		strip.offset_left   = offset.x
		strip.offset_top    = sy
		strip.offset_right  = offset.x + float(ROOM_W)
		strip.offset_bottom = sy + float(randi_range(8, 24))
		strip.color = theme["strip"] as Color
		bg_root.add_child(strip)

	var px: float = offset.x
	while px < offset.x + float(ROOM_W):
		var col := ColorRect.new()
		col.offset_left   = px
		col.offset_top    = offset.y
		col.offset_right  = px + 8.0
		col.offset_bottom = offset.y + float(ROOM_H)
		col.color = theme["pillar"] as Color
		bg_root.add_child(col)
		px += 160.0

# ---------------------------------------------------------------------------
# Walls, floor, ceiling
# ---------------------------------------------------------------------------
func _build_room_geometry(idx: int, offset: Vector2, door_left_y: float, door_right_y: float,
		theme: Dictionary, room: Dictionary) -> void:
	var wc: Color = theme["wall"]
	var gc: Color = theme["ground"]

	_make_solid_rect(offset + Vector2(float(WALL_W), 0.0),
			float(ROOM_W - WALL_W * 2), float(CEIL_H), wc)

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

	if door_left_y > 0.0:
		_build_wall_with_door(idx, offset, true, door_left_y, wc, room)
	else:
		_make_solid_rect(Vector2(offset.x, offset.y), float(WALL_W), float(ROOM_H), wc)

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

	var ceil_bot: float = offset.y + float(CEIL_H)
	if door_top > ceil_bot:
		_make_solid_rect(Vector2(wx, ceil_bot), float(WALL_W), door_top - ceil_bot, wc)

	var floor_top: float = offset.y + float(ROOM_H - FLOOR_H)
	if door_bot < floor_top:
		_make_solid_rect(Vector2(wx, door_bot), float(WALL_W), floor_top - door_bot, wc)

	var portal_color := Color(0.18, 0.78, 0.88)
	var frame := ColorRect.new()
	frame.offset_left   = wx - 2.0
	frame.offset_top    = door_top - 2.0
	frame.offset_right  = wx + float(WALL_W) + 2.0
	frame.offset_bottom = door_bot + 2.0
	frame.color = portal_color
	frame.z_index = 2
	add_child(frame)

	var fill := ColorRect.new()
	fill.offset_left   = wx
	fill.offset_top    = door_top
	fill.offset_right  = wx + float(WALL_W)
	fill.offset_bottom = door_bot
	fill.color = Color(0.04, 0.22, 0.32, 0.85)
	fill.z_index = 3
	add_child(fill)

	var spawn_x: float
	if is_left:
		spawn_x = offset.x + float(WALL_W) + 38.0
	else:
		spawn_x = offset.x + float(ROOM_W - WALL_W) - 38.0

	var portal := Area2D.new()
	portal.set_script(ROOM_PORTAL_SCRIPT)
	portal.room_idx = room_idx
	portal.player_spawn = Vector2(spawn_x, door_bot - 22.0)
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
# Solid rect helper
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
# Three-tier platform layout
# ---------------------------------------------------------------------------
func _build_room_platforms(room_idx: int, offset: Vector2, depth: int, theme: Dictionary) -> Array:
	var plats: Array = []
	var bc: Color = theme["plat"]
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
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
				_make_moving_platform(cur_x, y, w, theme["move"] as Color)
			elif roll < 0.27 and tier > 0:
				_make_break_platform(cur_x, y, w, theme["brk"] as Color)
			else:
				var shade := randf_range(0.0, 0.06)
				_make_platform(cur_x, y, w, Color(bc.r + shade, bc.g + shade, bc.b + shade))

			var pd := {"x": cur_x, "y": y, "w": w}
			plats.append(pd)
			_maybe_add_pillar(pd, theme["support"] as Color, floor_y)
			_add_plat_deco(cur_x, y, w, theme)

			cur_x += w + randf_range(55.0, 115.0)

	return plats

# ---------------------------------------------------------------------------
# Interior wall columns
# ---------------------------------------------------------------------------
func _build_wall_columns(offset: Vector2, theme: Dictionary) -> void:
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
		_add_wall_pillar(cx, floor_y - col_h, 20.0, col_h, theme["support"] as Color)

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
	var grenade_spawned := false
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
		if not grenade_spawned and randf() < 0.40:
			var gp := GRENADE_PICKUP_SCENE.instantiate() as GrenadePickup
			gp.setup(randi() % 3)
			gp.position = Vector2(plat["x"] + plat["w"] * 0.75, plat["y"] - 20.0)
			add_child(gp)
			grenade_spawned = true

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
# Platform helpers
# ---------------------------------------------------------------------------
func _make_platform(x: float, y: float, w: float, color: Color) -> StaticBody2D:
	var sb := StaticBody2D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	add_child(sb)
	var cr := ColorRect.new()
	cr.offset_left = x; cr.offset_top = y
	cr.offset_right = x + w; cr.offset_bottom = y + float(PLAT_H)
	cr.color = color
	sb.add_child(cr)
	var hl := ColorRect.new()
	hl.offset_left = x; hl.offset_top = y
	hl.offset_right = x + w; hl.offset_bottom = y + 3.0
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
	cr.offset_left = x; cr.offset_top = y
	cr.offset_right = x + w; cr.offset_bottom = y + h
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

# ---------------------------------------------------------------------------
# Decoration helpers — shared
# ---------------------------------------------------------------------------
func _deco_rect(root: Node2D, x: float, y: float, w: float, h: float, color: Color) -> void:
	var cr := ColorRect.new()
	cr.offset_left = x; cr.offset_top = y
	cr.offset_right = x + w; cr.offset_bottom = y + h
	cr.color = color
	root.add_child(cr)

# ---------------------------------------------------------------------------
# Platform decorations — per theme
# ---------------------------------------------------------------------------
func _add_plat_deco(x: float, y: float, w: float, theme: Dictionary) -> void:
	var root := Node2D.new()
	root.z_index = 2
	add_child(root)
	match theme["id"]:
		"forest":  _plat_forest(x, y, w, theme, root)
		"cave":    _plat_cave(x, y, w, theme, root)
		"volcano": _plat_volcano(x, y, w, theme, root)
		"crystal": _plat_crystal(x, y, w, theme, root)
		"arctic":  _plat_arctic(x, y, w, theme, root)
		"ruins":   _plat_ruins(x, y, w, theme, root)

func _plat_forest(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Bright grass strip along top
	_deco_rect(root, x, y - 3.0, w, 3.0, t["c1"])
	# Grass blades
	var blades := int(w / 10.0)
	for i in range(blades):
		if randf() < 0.45:
			continue
		var bx: float = x + float(i) * 10.0 + randf_range(1.0, 7.0)
		var bh: float = randf_range(5.0, 11.0)
		_deco_rect(root, bx, y - 3.0 - bh, randf_range(2.0, 3.0), bh,
				t["c2"] if randf() < 0.4 else t["c1"])
	# Occasional flower or mushroom
	if randf() < 0.35:
		var fx: float = x + randf_range(6.0, w - 6.0)
		_deco_rect(root, fx - 2.0, y - 11.0, 4.0, 8.0, t["c3"])

func _plat_cave(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Glowing moss strip
	if randf() < 0.5:
		_deco_rect(root, x + randf_range(0.0, w * 0.4), y - 2.0,
				randf_range(w * 0.3, w * 0.7), 2.0, t["c2"])
	# Small crystal spikes
	for _i in range(randi_range(1, 3)):
		var cx: float = x + randf_range(5.0, w - 5.0)
		var ch: float = randf_range(6.0, 13.0)
		_deco_rect(root, cx - 2.0, y - ch, 4.0, ch, t["c3"])

func _plat_volcano(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Lava crack glow along top
	_deco_rect(root, x, y - 2.0, w, 2.0, t["c1"])
	# Ember dots
	for _i in range(randi_range(2, 5)):
		var ex: float = x + randf_range(3.0, w - 3.0)
		var es: float = randf_range(2.0, 4.0)
		_deco_rect(root, ex, y - 6.0 - es, es, es,
				t["c3"] if randf() < 0.5 else t["c1"])

func _plat_crystal(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Glow rim
	_deco_rect(root, x, y - 2.0, w, 2.0, Color(t["c4"].r, t["c4"].g, t["c4"].b, 0.7))
	# Crystal spires
	var colors_c: Array[Color] = [t["c1"], t["c2"], t["c3"]]
	for _i in range(randi_range(3, 6)):
		var sx: float = x + randf_range(4.0, w - 4.0)
		var sh: float = randf_range(8.0, 20.0)
		_deco_rect(root, sx - 2.0, y - sh, 4.0, sh, colors_c[randi() % 3])

func _plat_arctic(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Snow cap
	_deco_rect(root, x, y - 5.0, w, 5.0, t["c1"])
	# Icicles hanging from bottom
	var count := int(w / 16.0)
	for i in range(count):
		if randf() < 0.45:
			continue
		var ix: float = x + float(i) * 16.0 + randf_range(2.0, 10.0)
		var ih: float = randf_range(8.0, 18.0)
		var iw: float = randf_range(3.0, 5.0)
		_deco_rect(root, ix, y + float(PLAT_H), iw, ih, t["c2"])
		_deco_rect(root, ix + iw * 0.25, y + float(PLAT_H) + ih, iw * 0.5, 4.0, t["c3"])

func _plat_ruins(x: float, y: float, w: float, t: Dictionary, root: Node2D) -> void:
	# Stone fragment rubble
	for _i in range(randi_range(2, 4)):
		var rx: float = x + randf_range(2.0, w - 8.0)
		_deco_rect(root, rx, y - randf_range(4.0, 9.0),
				randf_range(5.0, 12.0), randf_range(4.0, 8.0),
				t["c3"] if randf() < 0.5 else t["c4"])
	# Vine patch
	if randf() < 0.4:
		_deco_rect(root, x + randf_range(0.0, w - 6.0), y - 4.0,
				randf_range(6.0, 20.0), 3.0, t["c1"])

# ---------------------------------------------------------------------------
# Environment decorations — per theme (background layer)
# ---------------------------------------------------------------------------
func _add_env_deco(offset: Vector2, theme: Dictionary) -> void:
	var root := Node2D.new()
	root.z_index = -5
	add_child(root)
	match theme["id"]:
		"forest":  _env_forest(offset, theme, root)
		"cave":    _env_cave(offset, theme, root)
		"volcano": _env_volcano(offset, theme, root)
		"crystal": _env_crystal(offset, theme, root)
		"arctic":  _env_arctic(offset, theme, root)
		"ruins":   _env_ruins(offset, theme, root)

func _env_forest(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	# Trees
	for _i in range(randi_range(3, 5)):
		var tx: float = offset.x + float(WALL_W) + randf_range(30.0, float(ROOM_W - WALL_W * 2 - 30))
		var trunk_h: float = randf_range(55.0, 95.0)
		var trunk_w: float = randf_range(10.0, 14.0)
		_deco_rect(root, tx - trunk_w * 0.5, floor_y - trunk_h, trunk_w, trunk_h, t["c4"])
		# Leaf cluster (3 layers)
		var leaf_tops: Array[float] = [floor_y - trunk_h - 52.0, floor_y - trunk_h - 34.0, floor_y - trunk_h - 16.0]
		var leaf_widths_f: Array[float] = [randf_range(22.0, 30.0), randf_range(34.0, 46.0), randf_range(28.0, 38.0)]
		for li in range(3):
			var lw: float = leaf_widths_f[li]
			var leaf_c := Color(t["c5"].r + randf_range(-0.03, 0.06),
					t["c5"].g + randf_range(-0.03, 0.08), t["c5"].b)
			_deco_rect(root, tx - lw * 0.5, leaf_tops[li], lw, 20.0, leaf_c)
	# Floor flowers / mushrooms
	for _i in range(randi_range(4, 8)):
		var fx: float = offset.x + float(WALL_W) + randf_range(10.0, float(ROOM_W - WALL_W * 2 - 10))
		_deco_rect(root, fx - 2.0, floor_y - 9.0, 4.0, 9.0, t["c3"])

func _env_cave(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	# Stalactites from ceiling
	for _i in range(randi_range(5, 9)):
		var sx: float = offset.x + float(WALL_W) + randf_range(20.0, float(ROOM_W - WALL_W * 2 - 20))
		var sh: float = randf_range(25.0, 75.0)
		var sw: float = randf_range(6.0, 12.0)
		_deco_rect(root, sx - sw * 0.5, offset.y + float(CEIL_H), sw, sh * 0.65, t["c1"])
		_deco_rect(root, sx - sw * 0.25, offset.y + float(CEIL_H) + sh * 0.55, sw * 0.5, sh * 0.45, t["c1"])
	# Bioluminescent glow dots
	for _i in range(randi_range(8, 14)):
		var gx: float = offset.x + float(WALL_W) + randf_range(0.0, float(ROOM_W - WALL_W * 2))
		var gy: float = offset.y + randf_range(100.0, float(ROOM_H - FLOOR_H - 20))
		_deco_rect(root, gx - 3.0, gy - 3.0, 6.0, 6.0, t["c2"])

func _env_volcano(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	# Lava glow strip at floor
	_deco_rect(root, offset.x + float(WALL_W), floor_y - 3.0,
			float(ROOM_W - WALL_W * 2), 3.0, Color(t["c1"].r, t["c1"].g, t["c1"].b, 0.65))
	# Lava vent columns
	for _i in range(randi_range(2, 4)):
		var lx: float = offset.x + float(WALL_W) + randf_range(20.0, float(ROOM_W - WALL_W * 2 - 20))
		var lh: float = randf_range(20.0, 55.0)
		var lw: float = randf_range(8.0, 16.0)
		_deco_rect(root, lx - lw * 0.5, floor_y - lh, lw, lh, t["c2"])
	# Scattered embers
	for _i in range(randi_range(10, 18)):
		var ex: float = offset.x + randf_range(float(WALL_W), float(ROOM_W - WALL_W))
		var ey: float = offset.y + randf_range(float(ROOM_H) * 0.45, float(ROOM_H - FLOOR_H - 5))
		var es: float = randf_range(2.0, 4.0)
		_deco_rect(root, ex, ey, es, es, t["c3"] if randf() < 0.5 else t["c1"])

func _env_crystal(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	# Large crystal formations from floor
	var colors_cr: Array[Color] = [t["c1"], t["c2"], t["c3"]]
	for _i in range(randi_range(4, 7)):
		var cx: float = offset.x + float(WALL_W) + randf_range(20.0, float(ROOM_W - WALL_W * 2 - 20))
		var ch: float = randf_range(40.0, 100.0)
		var cw: float = randf_range(8.0, 18.0)
		_deco_rect(root, cx - cw * 0.5, floor_y - ch, cw, ch, colors_cr[randi() % 3])
	# Ambient glow nodes
	for _i in range(randi_range(10, 16)):
		var gx: float = offset.x + randf_range(float(WALL_W), float(ROOM_W - WALL_W))
		var gy: float = offset.y + randf_range(float(CEIL_H), float(ROOM_H - FLOOR_H))
		_deco_rect(root, gx - 3.0, gy - 3.0, 6.0, 6.0, t["c4"])

func _env_arctic(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	# Ice pillar formations
	for _i in range(randi_range(2, 4)):
		var px: float = offset.x + float(WALL_W) + randf_range(30.0, float(ROOM_W - WALL_W * 2 - 30))
		var ph: float = randf_range(30.0, 70.0)
		var pw: float = randf_range(8.0, 14.0)
		_deco_rect(root, px - pw * 0.5, floor_y - ph, pw, ph, t["c2"])
	# Snowflakes scattered
	for _i in range(randi_range(18, 28)):
		var sx: float = offset.x + randf_range(float(WALL_W), float(ROOM_W - WALL_W))
		var sy: float = offset.y + randf_range(float(CEIL_H), float(ROOM_H - FLOOR_H))
		var ss: float = randf_range(2.0, 5.0)
		_deco_rect(root, sx, sy, ss, ss, t["c1"])
	# Frost rim along ceiling
	_deco_rect(root, offset.x + float(WALL_W), offset.y + float(CEIL_H),
			float(ROOM_W - WALL_W * 2), 5.0, Color(t["c1"].r, t["c1"].g, t["c1"].b, 0.5))

func _env_ruins(offset: Vector2, t: Dictionary, root: Node2D) -> void:
	var floor_y: float = offset.y + float(ROOM_H - FLOOR_H)
	# Broken pillars
	for _i in range(randi_range(2, 4)):
		var px: float = offset.x + float(WALL_W) + randf_range(30.0, float(ROOM_W - WALL_W * 2 - 30))
		var ph: float = randf_range(60.0, 140.0)
		var pw: float = randf_range(14.0, 22.0)
		_deco_rect(root, px - pw * 0.5, floor_y - ph, pw, ph, t["c3"])
		# Broken jagged top
		_deco_rect(root, px - pw * 0.3, floor_y - ph - 10.0, pw * 0.5, 10.0, t["c4"])
	# Vines
	for _i in range(randi_range(3, 6)):
		var vx: float = offset.x + float(WALL_W) + randf_range(0.0, float(ROOM_W - WALL_W * 2))
		var vy: float = offset.y + randf_range(float(CEIL_H), float(ROOM_H) * 0.65)
		_deco_rect(root, vx, vy, randf_range(2.0, 4.0), randf_range(30.0, 80.0), t["c1"])
	# Rubble on floor
	for _i in range(randi_range(4, 8)):
		var rx: float = offset.x + float(WALL_W) + randf_range(10.0, float(ROOM_W - WALL_W * 2 - 10))
		_deco_rect(root, rx, floor_y - randf_range(4.0, 10.0),
				randf_range(6.0, 16.0), randf_range(4.0, 10.0), t["c5"])

# ---------------------------------------------------------------------------
# Theme palettes — 6 environments cycling with depth
# ---------------------------------------------------------------------------
func _pick_theme(depth: int) -> Dictionary:
	match depth % 6:
		0: return _theme_forest()
		1: return _theme_cave()
		2: return _theme_volcano()
		3: return _theme_crystal()
		4: return _theme_arctic()
		_: return _theme_ruins()

func _theme_forest() -> Dictionary:
	return {
		"id": "forest",
		"bg":      Color(0.05, 0.10, 0.04),
		"strip":   Color(0.08, 0.14, 0.06, 0.50),
		"pillar":  Color(0.06, 0.11, 0.05),
		"ground":  Color(0.16, 0.22, 0.08),
		"wall":    Color(0.26, 0.18, 0.09),
		"plat":    Color(0.30, 0.20, 0.10),
		"move":    Color(0.18, 0.50, 0.16),
		"brk":     Color(0.40, 0.26, 0.12),
		"support": Color(0.22, 0.15, 0.07),
		"c1": Color(0.22, 0.72, 0.12),  # bright grass
		"c2": Color(0.13, 0.46, 0.07),  # dark grass
		"c3": Color(0.92, 0.82, 0.16),  # flower yellow
		"c4": Color(0.28, 0.17, 0.08),  # tree trunk
		"c5": Color(0.09, 0.36, 0.05),  # tree leaves
	}

func _theme_cave() -> Dictionary:
	return {
		"id": "cave",
		"bg":      Color(0.05, 0.05, 0.06),
		"strip":   Color(0.08, 0.08, 0.10, 0.50),
		"pillar":  Color(0.06, 0.06, 0.07),
		"ground":  Color(0.18, 0.17, 0.20),
		"wall":    Color(0.22, 0.21, 0.25),
		"plat":    Color(0.28, 0.27, 0.32),
		"move":    Color(0.22, 0.30, 0.44),
		"brk":     Color(0.44, 0.28, 0.20),
		"support": Color(0.20, 0.19, 0.23),
		"c1": Color(0.26, 0.25, 0.30),  # stalactite stone
		"c2": Color(0.08, 0.55, 0.20),  # bioluminescent green
		"c3": Color(0.38, 0.68, 0.90),  # crystal blue
		"c4": Color(0.15, 0.14, 0.18),  # deep shadow
		"c5": Color(0.42, 0.40, 0.50),  # lighter stone
	}

func _theme_volcano() -> Dictionary:
	return {
		"id": "volcano",
		"bg":      Color(0.08, 0.03, 0.02),
		"strip":   Color(0.16, 0.05, 0.03, 0.50),
		"pillar":  Color(0.10, 0.04, 0.02),
		"ground":  Color(0.16, 0.08, 0.05),
		"wall":    Color(0.20, 0.10, 0.06),
		"plat":    Color(0.24, 0.14, 0.09),
		"move":    Color(0.55, 0.28, 0.08),
		"brk":     Color(0.62, 0.20, 0.07),
		"support": Color(0.18, 0.09, 0.05),
		"c1": Color(0.90, 0.45, 0.05),  # lava orange
		"c2": Color(0.78, 0.18, 0.02),  # lava red
		"c3": Color(1.00, 0.75, 0.10),  # ember yellow
		"c4": Color(0.12, 0.05, 0.03),  # ash
		"c5": Color(0.50, 0.22, 0.06),  # cooled lava
	}

func _theme_crystal() -> Dictionary:
	return {
		"id": "crystal",
		"bg":      Color(0.05, 0.04, 0.10),
		"strip":   Color(0.08, 0.06, 0.16, 0.50),
		"pillar":  Color(0.06, 0.05, 0.12),
		"ground":  Color(0.14, 0.10, 0.24),
		"wall":    Color(0.18, 0.13, 0.30),
		"plat":    Color(0.22, 0.16, 0.36),
		"move":    Color(0.18, 0.28, 0.52),
		"brk":     Color(0.42, 0.16, 0.38),
		"support": Color(0.16, 0.12, 0.26),
		"c1": Color(0.35, 0.90, 1.00),  # cyan crystal
		"c2": Color(0.65, 0.30, 0.96),  # purple crystal
		"c3": Color(0.90, 0.40, 0.80),  # pink crystal
		"c4": Color(0.20, 0.62, 0.88),  # blue glow
		"c5": Color(0.10, 0.08, 0.20),  # deep shadow
	}

func _theme_arctic() -> Dictionary:
	return {
		"id": "arctic",
		"bg":      Color(0.06, 0.08, 0.14),
		"strip":   Color(0.10, 0.12, 0.20, 0.50),
		"pillar":  Color(0.08, 0.10, 0.16),
		"ground":  Color(0.28, 0.34, 0.44),
		"wall":    Color(0.52, 0.62, 0.74),
		"plat":    Color(0.42, 0.52, 0.66),
		"move":    Color(0.30, 0.55, 0.82),
		"brk":     Color(0.56, 0.64, 0.76),
		"support": Color(0.36, 0.44, 0.56),
		"c1": Color(0.90, 0.95, 1.00),  # snow white
		"c2": Color(0.70, 0.82, 0.96),  # ice blue
		"c3": Color(0.46, 0.62, 0.82),  # mid ice
		"c4": Color(0.20, 0.30, 0.50),  # shadow ice
		"c5": Color(0.96, 0.98, 1.00),  # pure white
	}

func _theme_ruins() -> Dictionary:
	return {
		"id": "ruins",
		"bg":      Color(0.08, 0.06, 0.04),
		"strip":   Color(0.12, 0.10, 0.07, 0.50),
		"pillar":  Color(0.10, 0.08, 0.05),
		"ground":  Color(0.28, 0.24, 0.18),
		"wall":    Color(0.34, 0.29, 0.22),
		"plat":    Color(0.40, 0.34, 0.25),
		"move":    Color(0.28, 0.42, 0.22),
		"brk":     Color(0.48, 0.36, 0.22),
		"support": Color(0.26, 0.22, 0.16),
		"c1": Color(0.14, 0.40, 0.09),  # vine green
		"c2": Color(0.09, 0.28, 0.06),  # dark vine
		"c3": Color(0.46, 0.40, 0.30),  # stone tan
		"c4": Color(0.62, 0.54, 0.40),  # light stone
		"c5": Color(0.20, 0.16, 0.10),  # dark stone
	}
