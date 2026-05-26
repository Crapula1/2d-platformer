extends Node2D

# =============================================================================
#  LEVEL 4 — METROIDVANIA FRAMEWORK + SMALL DEMO
# =============================================================================
#  Design touchstone: Castlevania: Symphony of the Night.
#
#  ROOM GRID
#  ---------
#  The world is a grid of rectangular ROOMS. Each room is 1+ "cells" wide and
#  tall (one cell = ROOM_W x ROOM_H = 1280 x 720). Rooms never overlap. The
#  camera is locked to the current room's rect; you cross a DOOR at the edge
#  to slide into the neighbor (SotN-style screen-snap).
#
#  ABILITY GATES
#  -------------
#  Four abilities unlock through RELIC pickups:
#    * double_jump  — re-enables Player's second jump
#    * dash         — re-enables Player's dash key (and lets you smash dash-walls)
#    * wall_jump    — re-enables wall slide / wall jump
#    * demolitions  — lets grenades break BOMB_WALLs
#  At spawn we DOWNGRADE the Player to a single-jump grounded baseline and
#  hand abilities back as you find them.
#
#  SAVE CRYSTALS & WARPS
#  ---------------------
#  Touching a save crystal heals you, sets the level-local respawn point,
#  and pulses a banner. Warp gates are pair-linked teleporters with a brief
#  fade; activating one warp registers it as a destination on every other.
#
#  MINI-MAP
#  --------
#  Top-right HUD: a grid of room cells. Unvisited rooms are dim; the current
#  room flashes; save/warp/relic markers persist after a room is seen.
#
#  DEMO LAYOUT (5 rooms, all 4 abilities used)
#  -------------------------------------------
#                                    (col grows east, row grows south)
#         (2,-1) R2-top  -- east --> (3,-1) R4 Sanctum
#            |                          ^ bomb wall (need DEMOLITIONS)
#            |  double-jump relic       |
#            |  in the shaft            warp pad ↔ R1
#            v                          wall-jump relic
#  R0 -- e --> R1 (save) -- e --> (2,0) R2-bot
#  (0,0)        (1,0)              vertical tower
#                 |
#                 | south
#                 v
#               (1,1) R3 Dash Hall
#                 dash relic mid; east-side bomb wall hides shortcut warp
# =============================================================================

# --- Asset bridges (reuse castle pack so the level looks at home) -----------
const COIN_SCENE           := preload("res://scenes/Coin.tscn")
const SPIKE_SCENE          := preload("res://scenes/Spike.tscn")
const POWERUP_SCENE        := preload("res://scenes/PowerUp.tscn")
const HEALTH_PICKUP_SCENE  := preload("res://scenes/HealthPickup.tscn")
const RANGE_SOLDIER_SCENE  := preload("res://scenes/RangeSoldier.tscn")
const WINGED_DEMON_SCENE   := preload("res://scenes/WingedDemon.tscn")
const EXIT_DOOR_SCENE      := preload("res://scenes/ExitDoor.tscn")

# --- Layout constants -------------------------------------------------------
const ROOM_W: float = 1280.0
const ROOM_H: float =  720.0
const WALL_THICK: float = 24.0
const DOOR_HEIGHT: float = 96.0
const DOOR_WIDTH: float  = 96.0
const TRANSITION_TIME: float = 0.40

# --- Palette (twilight castle catacombs) ------------------------------------
const COL_BG_TOP   := Color(0.05, 0.04, 0.10)
const COL_BG_BOT   := Color(0.14, 0.06, 0.18)
const COL_PARALLAX := Color(0.20, 0.10, 0.28, 0.55)
const COL_FOG      := Color(0.55, 0.30, 0.65, 0.10)

const COL_WALL_DEEP := Color(0.10, 0.09, 0.13)
const COL_WALL      := Color(0.20, 0.18, 0.25)
const COL_WALL_HI   := Color(0.36, 0.32, 0.42)
const COL_BRICK_LO  := Color(0.13, 0.11, 0.16)
const COL_FLOOR     := Color(0.16, 0.14, 0.20)
const COL_FLOOR_HI  := Color(0.28, 0.24, 0.34)
const COL_PLAT      := Color(0.34, 0.30, 0.40)
const COL_PLAT_TOP  := Color(0.48, 0.42, 0.55)

const COL_SAVE_GLOW := Color(0.40, 0.95, 1.00)
const COL_WARP_GLOW := Color(1.00, 0.55, 0.95)
const COL_RELIC_J   := Color(0.55, 0.95, 1.00)   # double jump (cyan)
const COL_RELIC_D   := Color(1.00, 0.70, 0.25)   # dash (amber)
const COL_RELIC_W   := Color(0.65, 1.00, 0.45)   # wall jump (lime)
const COL_RELIC_B   := Color(1.00, 0.40, 0.35)   # demolitions (red)
const COL_BOMBWALL  := Color(0.50, 0.30, 0.20)
const COL_BOMBWALL_CRACK := Color(0.18, 0.10, 0.06)
const COL_DASHWALL  := Color(0.32, 0.22, 0.45)

# --- Ability ids ------------------------------------------------------------
const ABILITY_DOUBLE_JUMP := "double_jump"
const ABILITY_DASH        := "dash"
const ABILITY_WALL_JUMP   := "wall_jump"
const ABILITY_DEMOLITIONS := "demolitions"

const ABILITY_DISPLAY := {
	ABILITY_DOUBLE_JUMP: "DOUBLE JUMP",
	ABILITY_DASH:        "PHANTOM DASH",
	ABILITY_WALL_JUMP:   "GRIP GAUNTLETS",
	ABILITY_DEMOLITIONS: "DEMOLITIONS",
}

# --- Room data --------------------------------------------------------------
# Each room: id, rect (px world coords), cells (Array[Vector2i]), name, theme.
# Rooms are built from ROOM_LAYOUT below — a hand-authored list keyed by id.
const ROOM_LAYOUT := [
	{ "id": 0, "cells": [Vector2i(0, 0)],                       "name": "Antechamber",  "theme": "stone"  },
	{ "id": 1, "cells": [Vector2i(1, 0)],                       "name": "Crossroads",   "theme": "stone"  },
	{ "id": 2, "cells": [Vector2i(2, 0), Vector2i(2, -1)],      "name": "Spire",        "theme": "tower"  },
	{ "id": 3, "cells": [Vector2i(1, 1)],                       "name": "Long Gallery", "theme": "hall"   },
	{ "id": 4, "cells": [Vector2i(3, -1)],                      "name": "Sanctum",      "theme": "shrine" },
]

# --- Demo door / feature placements (authored to demonstrate every system) ---
# DOOR: { room_a, room_b, side, cell, opt_y_offset }
#   side ∈ "east"/"west"/"north"/"south", cell = which cell of room_a the door
#   sits on (matters for multi-cell rooms like R2).
const DOORS := [
	{ "a": 0, "b": 1, "side": "east", "cell": Vector2i(0, 0) },
	{ "a": 1, "b": 2, "side": "east", "cell": Vector2i(1, 0) },
	{ "a": 1, "b": 3, "side": "south","cell": Vector2i(1, 0) },
	{ "a": 2, "b": 4, "side": "east", "cell": Vector2i(2, -1) },
]

# --- Working state ----------------------------------------------------------
var _rooms: Dictionary = {}            # id → { id, rect, cells, name, theme }
var _doors: Array = []                 # built Door records
var _cell_to_room: Dictionary = {}     # Vector2i → room_id
var _world: StaticBody2D               # collects all wall colliders

var _current_room: int = -1
var _visited: Dictionary = {}          # room_id → true
var _abilities: Dictionary = {
	ABILITY_DOUBLE_JUMP: false,
	ABILITY_DASH: false,
	ABILITY_WALL_JUMP: false,
	ABILITY_DEMOLITIONS: false,
}
var _respawn: Vector2 = Vector2(80, 380)
var _transitioning: bool = false

# Per-room marker metadata for the mini-map:
#   room_id → { save: bool, warp: bool, relic: String, exit: bool }
var _room_markers: Dictionary = {}

# Active warp pairs — every activated warp links to every other activated warp.
var _warp_nodes: Array = []
var _player_ref: Player = null
var _hud_layer: CanvasLayer = null
var _minimap: Control = null
var _banner: Label = null
var _banner_tween: Tween = null

# Cached Player baseline so we can restore on respawn / level end.
var _baseline_max_jumps: int = 2
var _baseline_dash_cd: float = 0.7
var _baseline_wj_x: float = 220.0
var _baseline_wj_y: float = -350.0
var _baseline_ws_grav: float = 0.08

# =============================================================================
#  PUBLIC API (called by Main.gd)
# =============================================================================
func apply_player_camera(player_node: Node2D) -> void:
	_player_ref = player_node as Player
	if _player_ref == null:
		return
	_cache_player_baseline()
	_apply_ability_locks()
	# Snap camera to the room containing the spawn position.
	var rid: int = _room_at_world(_player_ref.global_position)
	if rid >= 0:
		_enter_room(rid, true)

func is_transitioning() -> bool:
	return _transitioning

# Multiplayer parity with the other levels — Main.gd calls this for each
# late-joining peer. Single-player handling is identical for now.
func apply_camera_limits_for_room(player_node: Node2D, _room_idx: int) -> void:
	apply_player_camera(player_node)

# Linear-style API parity with ProceduralLevel — accepts a target room id and
# a spawn position; teleports the player and re-locks the camera.
func do_room_transition(player: Player, target_pos: Vector2, target_room: int) -> void:
	if _transitioning:
		return
	_transitioning = true
	var fade := _new_fade()
	var tw := create_tween()
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), TRANSITION_TIME * 0.5)
	tw.tween_callback(func() -> void:
		player.global_position = target_pos
		if target_room >= 0:
			_enter_room(target_room, true)
	)
	tw.tween_property(fade, "color", Color(0, 0, 0, 0), TRANSITION_TIME * 0.5)
	tw.tween_callback(func() -> void:
		fade.queue_free()
		_transitioning = false
	)

func _new_fade() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	# Free the CanvasLayer when the ColorRect is freed.
	rect.tree_exited.connect(func():
		if is_instance_valid(layer):
			layer.queue_free())
	return rect

# =============================================================================
#  BUILD
# =============================================================================
func _ready() -> void:
	# Run our ability-lock _physics_process AFTER the Player's, so resets to
	# is_wall_sliding / _dash_cd land on the same frame Player wrote them.
	process_physics_priority = 100
	_build_rooms()
	_build_background()
	_world = StaticBody2D.new()
	_world.collision_layer = 1
	_world.collision_mask = 0
	add_child(_world)
	for room in _rooms.values():
		_build_room_walls(room)
		_build_room_floor(room)
		_decorate_room(room)
	_build_doors()
	_build_features()
	_build_hud()
	# PlayerSpawn marker — Main.gd reads this to position the player.
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = _room_spawn_pos(0)
	add_child(spawn)
	_respawn = spawn.position

func _build_rooms() -> void:
	for entry in ROOM_LAYOUT:
		var cells: Array = entry["cells"]
		var min_c: Vector2i = cells[0]
		var max_c: Vector2i = cells[0]
		for c in cells:
			min_c.x = mini(min_c.x, c.x)
			min_c.y = mini(min_c.y, c.y)
			max_c.x = maxi(max_c.x, c.x)
			max_c.y = maxi(max_c.y, c.y)
		var rect := Rect2(
			Vector2(min_c.x * ROOM_W, min_c.y * ROOM_H),
			Vector2((max_c.x - min_c.x + 1) * ROOM_W, (max_c.y - min_c.y + 1) * ROOM_H)
		)
		var room := {
			"id":    int(entry["id"]),
			"cells": cells.duplicate(),
			"rect":  rect,
			"name":  String(entry["name"]),
			"theme": String(entry["theme"]),
		}
		_rooms[room["id"]] = room
		for c in cells:
			_cell_to_room[c] = room["id"]
		_room_markers[room["id"]] = { "save": false, "warp": false, "relic": "", "exit": false }

# Sealed perimeter walls per room, with door openings carved out by DOORS list.
func _build_room_walls(room: Dictionary) -> void:
	var rect: Rect2 = room["rect"]
	var openings: Array = _wall_openings_for(int(room["id"]))
	# Top, bottom, left, right walls — each broken into segments around openings.
	_add_wall_segments(Vector2(rect.position.x, rect.position.y - WALL_THICK),
		Vector2(rect.size.x, WALL_THICK), "h", openings.filter(func(o): return o.side == "north"), rect)
	_add_wall_segments(Vector2(rect.position.x, rect.position.y + rect.size.y),
		Vector2(rect.size.x, WALL_THICK), "h", openings.filter(func(o): return o.side == "south"), rect)
	_add_wall_segments(Vector2(rect.position.x - WALL_THICK, rect.position.y),
		Vector2(WALL_THICK, rect.size.y), "v", openings.filter(func(o): return o.side == "west"), rect)
	_add_wall_segments(Vector2(rect.position.x + rect.size.x, rect.position.y),
		Vector2(WALL_THICK, rect.size.y), "v", openings.filter(func(o): return o.side == "east"), rect)

# Returns [{ side, center_world }] — door centers used to cut the wall.
func _wall_openings_for(room_id: int) -> Array:
	var out: Array = []
	for d in DOORS:
		var room_side := ""
		var other := -1
		if int(d["a"]) == room_id:
			room_side = String(d["side"])
			other = int(d["b"])
		elif int(d["b"]) == room_id:
			room_side = _opposite(String(d["side"]))
			other = int(d["a"])
		else:
			continue
		var center: Vector2 = _door_center_world(room_id, other, room_side, d["cell"] as Vector2i)
		out.append({ "side": room_side, "center": center })
	return out

func _opposite(side: String) -> String:
	match side:
		"east":  return "west"
		"west":  return "east"
		"north": return "south"
		"south": return "north"
	return side

# Place the door on the shared edge between two rooms. For the room we are
# building, the cell hint is which of its own cells the door belongs to;
# the other room's matching cell is inferred from the opposite direction.
func _door_center_world(room_a: int, room_b: int, side_in_a: String, cell_a: Vector2i) -> Vector2:
	# Verify both rooms actually share a cell on this edge — fall back to
	# midpoint of room A's edge if the authored cell is inconsistent.
	var neighbor_cell: Vector2i = cell_a
	match side_in_a:
		"east":  neighbor_cell.x += 1
		"west":  neighbor_cell.x -= 1
		"north": neighbor_cell.y -= 1
		"south": neighbor_cell.y += 1
	if _cell_to_room.get(neighbor_cell, -1) != room_b:
		# Authored door cell didn't actually neighbor room_b. Use any shared
		# edge between the rooms as a best-effort fallback.
		var fb: Variant = _any_shared_edge(room_a, room_b, side_in_a)
		if fb != null:
			cell_a = fb["cell_a"]
	var cell_origin := Vector2(cell_a.x * ROOM_W, cell_a.y * ROOM_H)
	# Horizontal doors sit on the cell's floor — bottom of the opening lines
	# up with the floor top so the player can walk straight through.
	var floor_band: float = 40.0
	var door_y_local: float = ROOM_H - floor_band - DOOR_HEIGHT * 0.5
	match side_in_a:
		"east":  return cell_origin + Vector2(ROOM_W, door_y_local)
		"west":  return cell_origin + Vector2(0.0,    door_y_local)
		"north": return cell_origin + Vector2(ROOM_W * 0.5, 0.0)
		"south": return cell_origin + Vector2(ROOM_W * 0.5, ROOM_H)
	return cell_origin

func _any_shared_edge(room_a: int, room_b: int, side: String) -> Variant:
	var cells_a: Array = _rooms[room_a]["cells"]
	for c in cells_a:
		var n: Vector2i = c
		match side:
			"east":  n.x += 1
			"west":  n.x -= 1
			"north": n.y -= 1
			"south": n.y += 1
		if _cell_to_room.get(n, -1) == room_b:
			return { "cell_a": c }
	return null

# Splits a wall span around door openings and adds solid segments + visuals.
func _add_wall_segments(origin: Vector2, size: Vector2, axis: String, openings: Array, _room_rect: Rect2) -> void:
	# 'h' wall: openings cut along X. 'v' wall: openings cut along Y.
	var cuts: Array = []
	for o in openings:
		var c: Vector2 = o["center"]
		if axis == "h":
			cuts.append({ "lo": c.x - DOOR_WIDTH * 0.5, "hi": c.x + DOOR_WIDTH * 0.5 })
		else:
			cuts.append({ "lo": c.y - DOOR_HEIGHT * 0.5, "hi": c.y + DOOR_HEIGHT * 0.5 })
	cuts.sort_custom(func(a, b): return a["lo"] < b["lo"])

	var span_lo: float = origin.x if axis == "h" else origin.y
	var span_hi: float = (origin.x + size.x) if axis == "h" else (origin.y + size.y)
	var cursor: float = span_lo
	for cut in cuts:
		if cut["lo"] > cursor:
			_emit_wall_segment(origin, size, axis, cursor, cut["lo"])
		cursor = maxf(cursor, cut["hi"])
	if cursor < span_hi:
		_emit_wall_segment(origin, size, axis, cursor, span_hi)

func _emit_wall_segment(origin: Vector2, size: Vector2, axis: String, lo: float, hi: float) -> void:
	if hi - lo < 1.0:
		return
	var pos := origin
	var ext := size
	if axis == "h":
		pos.x = lo
		ext.x = hi - lo
	else:
		pos.y = lo
		ext.y = hi - lo
	_add_solid(pos.x, pos.y, ext.x, ext.y, COL_WALL_DEEP, COL_WALL_HI)

# Floor: a solid strip across the room bottom (inside the perimeter walls).
# Gets carved at south-door positions so the player can drop through.
func _build_room_floor(room: Dictionary) -> void:
	var rect: Rect2 = room["rect"]
	var bottom_y: float = rect.position.y + rect.size.y - 40.0
	# Collect south-door openings on this room as [lo_x, hi_x] cuts.
	var cuts: Array = []
	for o in _wall_openings_for(int(room["id"])):
		if String(o["side"]) != "south":
			continue
		var c: Vector2 = o["center"]
		cuts.append({ "lo": c.x - DOOR_WIDTH * 0.5, "hi": c.x + DOOR_WIDTH * 0.5 })
	cuts.sort_custom(func(a, b): return a["lo"] < b["lo"])
	var span_lo: float = rect.position.x
	var span_hi: float = rect.position.x + rect.size.x
	var cursor: float = span_lo
	for cut in cuts:
		if cut["lo"] > cursor:
			_add_solid(cursor, bottom_y, cut["lo"] - cursor, 40.0, COL_FLOOR, COL_FLOOR_HI)
		cursor = maxf(cursor, cut["hi"])
	if cursor < span_hi:
		_add_solid(cursor, bottom_y, span_hi - cursor, 40.0, COL_FLOOR, COL_FLOOR_HI)

	# Theme-specific platforming layouts inside the room.
	match String(room["theme"]):
		"tower": _layout_tower(room)
		"hall":  _layout_hall(room)
		"shrine":_layout_shrine(room)
		_:       _layout_stone(room)

func _layout_stone(room: Dictionary) -> void:
	# Small jumping platforms — easy traversal.
	var rect: Rect2 = room["rect"]
	var base_y: float = rect.position.y + rect.size.y - 40.0
	_add_platform(rect.position.x + 220.0, base_y - 130.0, 180.0, 22.0)
	_add_platform(rect.position.x + 540.0, base_y - 230.0, 180.0, 22.0)
	_add_platform(rect.position.x + 880.0, base_y - 150.0, 180.0, 22.0)

func _layout_tower(room: Dictionary) -> void:
	# Two-cell-tall vertical shaft. The lower half climbs with single jumps;
	# the gap above platform P3 needs DOUBLE JUMP. The relic sits on P3 so it
	# is reachable WITHOUT the ability you're going there to find.
	#
	# The top exit door (east of cell (2,-1)) lands at world y ≈ -40 (room
	# bottom y minus the floor-band + door-half-height), so the topmost ledge
	# is positioned so its top edge meets the door opening floor.
	var rect: Rect2 = room["rect"]
	var x_left: float = rect.position.x
	var x_mid:  float = rect.position.x + rect.size.x * 0.5
	var x_right:float = rect.position.x + rect.size.x - 220.0
	var floor_y: float = rect.position.y + rect.size.y - 40.0
	# Lower ascent — single-jump friendly (≤110 px rise per hop)
	_add_platform(x_left + 80.0,  floor_y - 110.0, 200.0, 22.0)
	_add_platform(x_mid - 100.0,  floor_y - 220.0, 200.0, 22.0)
	_add_platform(x_right - 40.0, floor_y - 330.0, 220.0, 22.0)  # double-jump relic
	# Double-jump gap (~190 px rises)
	_add_platform(x_mid - 110.0,  floor_y - 520.0, 220.0, 22.0)
	_add_platform(x_left + 100.0, floor_y - 660.0, 220.0, 22.0)
	# Final ledge — its top aligns with the east door of the upper cell so the
	# player walks straight through after the double-jump climb.
	_add_platform(x_right - 60.0, floor_y - 720.0, 280.0, 22.0)

func _layout_hall(room: Dictionary) -> void:
	# Long horizontal corridor with two pillars; mid pillar holds the dash relic
	# and the east-most pillar guards a dash-wall.
	var rect: Rect2 = room["rect"]
	var base_y: float = rect.position.y + rect.size.y - 40.0
	# Decorative pillars
	_add_solid(rect.position.x + 380.0, base_y - 280.0, 60.0, 280.0, COL_FLOOR, COL_FLOOR_HI)
	_add_solid(rect.position.x + 720.0, base_y - 280.0, 60.0, 280.0, COL_FLOOR, COL_FLOOR_HI)
	# Mid alcove platform — dash relic pedestal
	_add_platform(rect.position.x + 540.0, base_y - 160.0, 180.0, 22.0)
	# Higher ledges to set up the dash trajectory
	_add_platform(rect.position.x + 220.0, base_y - 260.0, 160.0, 22.0)
	_add_platform(rect.position.x + 900.0, base_y - 260.0, 160.0, 22.0)

func _layout_shrine(room: Dictionary) -> void:
	# Save + warp + bomb-wall room (north-side: bomb-relic alcove).
	var rect: Rect2 = room["rect"]
	var base_y: float = rect.position.y + rect.size.y - 40.0
	# Central altar platform
	_add_platform(rect.position.x + 540.0, base_y - 80.0, 200.0, 24.0)
	# Side ledges for wall-jump relic perch
	_add_platform(rect.position.x + 140.0, base_y - 220.0, 160.0, 22.0)
	_add_platform(rect.position.x + 980.0, base_y - 220.0, 160.0, 22.0)
	_add_platform(rect.position.x + 540.0, base_y - 360.0, 200.0, 22.0)

# Wraps a sized rect into a StaticBody2D collider + decorative ColorRect.
func _add_solid(x: float, y: float, w: float, h: float, fill: Color, edge: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	shape.position = Vector2(w * 0.5, h * 0.5)
	body.position = Vector2(x, y)
	body.add_child(shape)
	# Visual
	var fill_rect := ColorRect.new()
	fill_rect.color = fill
	fill_rect.size = Vector2(w, h)
	fill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(fill_rect)
	var edge_top := ColorRect.new()
	edge_top.color = edge
	edge_top.size = Vector2(w, 3.0)
	body.add_child(edge_top)
	add_child(body)
	return body

func _add_platform(x: float, y: float, w: float, h: float) -> StaticBody2D:
	return _add_solid(x, y, w, h, COL_PLAT, COL_PLAT_TOP)

# =============================================================================
#  BACKGROUND
# =============================================================================
func _build_background() -> void:
	# Compute total world bounds from rooms.
	var bounds := Rect2()
	var first := true
	for room in _rooms.values():
		var r: Rect2 = room["rect"]
		if first:
			bounds = r
			first = false
		else:
			bounds = bounds.merge(r)
	bounds = bounds.grow(400.0)

	var bg := ColorRect.new()
	bg.color = COL_BG_BOT
	bg.position = bounds.position
	bg.size = bounds.size
	bg.z_index = -50
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# A simple vertical gradient via a second tinted rect at top half.
	var top := ColorRect.new()
	top.color = COL_BG_TOP
	top.position = bounds.position
	top.size = Vector2(bounds.size.x, bounds.size.y * 0.55)
	top.z_index = -49
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	# Parallax stripes (cheap silhouette layers)
	for i in 6:
		var stripe := ColorRect.new()
		stripe.color = COL_PARALLAX * (0.65 + 0.05 * i)
		stripe.size = Vector2(bounds.size.x, 80.0 + i * 20.0)
		stripe.position = Vector2(bounds.position.x, bounds.position.y + bounds.size.y - (140.0 + i * 90.0))
		stripe.z_index = -40 + i
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(stripe)

	# A subtle violet fog hanging over the world
	var fog := ColorRect.new()
	fog.color = COL_FOG
	fog.position = bounds.position
	fog.size = bounds.size
	fog.z_index = -10
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)

func _decorate_room(room: Dictionary) -> void:
	# Brick wash on the back of each room for visual interest.
	var rect: Rect2 = room["rect"]
	var brick := ColorRect.new()
	brick.color = COL_BRICK_LO
	brick.position = rect.position
	brick.size = rect.size
	brick.z_index = -20
	brick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brick)
	# Room title placard near the top — fades as you cross in
	var label := Label.new()
	label.text = String(room["name"]).to_upper()
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0, 0.55))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = rect.position + Vector2(24.0, 12.0)
	label.z_index = -5
	add_child(label)

# =============================================================================
#  DOORS — Area2D trigger that snaps to neighbor room
# =============================================================================
func _build_doors() -> void:
	for d in DOORS:
		_make_door(int(d["a"]), int(d["b"]), String(d["side"]), d["cell"] as Vector2i)

func _make_door(room_a: int, room_b: int, side_in_a: String, cell_a: Vector2i) -> void:
	# Two trigger plates, one on each side of the wall opening.
	var center_a: Vector2 = _door_center_world(room_a, room_b, side_in_a, cell_a)
	# Re-derive plate sizes / spawn positions.
	var plate_a := Area2D.new()
	plate_a.collision_layer = 0
	plate_a.collision_mask = 2  # Player layer
	var shape_a := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	# Door plate dimensions oriented to the wall axis.
	var horizontal := (side_in_a == "north" or side_in_a == "south")
	if horizontal:
		rect_shape.size = Vector2(DOOR_WIDTH, 32.0)
	else:
		rect_shape.size = Vector2(32.0, DOOR_HEIGHT)
	shape_a.shape = rect_shape
	plate_a.add_child(shape_a)
	# Plate A position: just inside room A by 8 px
	plate_a.global_position = _shift_inward(center_a, side_in_a, 12.0, true)
	add_child(plate_a)

	var plate_b := Area2D.new()
	plate_b.collision_layer = 0
	plate_b.collision_mask = 2
	var sb := CollisionShape2D.new()
	var rb := RectangleShape2D.new()
	rb.size = rect_shape.size
	sb.shape = rb
	plate_b.add_child(sb)
	plate_b.global_position = _shift_inward(center_a, side_in_a, 12.0, false)
	add_child(plate_b)

	var record := {
		"a": room_a, "b": room_b, "side": side_in_a,
		"center": center_a, "plate_a": plate_a, "plate_b": plate_b,
	}
	_doors.append(record)
	plate_a.body_entered.connect(func(body): _on_door_touch(body, record, room_b))
	plate_b.body_entered.connect(func(body): _on_door_touch(body, record, room_a))

	# Visual door frame (a faint rectangle in the opening)
	var frame := ColorRect.new()
	frame.color = Color(0.65, 0.50, 0.80, 0.18)
	if horizontal:
		frame.size = Vector2(DOOR_WIDTH, 12.0)
		frame.position = center_a - Vector2(DOOR_WIDTH * 0.5, 6.0)
	else:
		frame.size = Vector2(12.0, DOOR_HEIGHT)
		frame.position = center_a - Vector2(6.0, DOOR_HEIGHT * 0.5)
	frame.z_index = -2
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

func _shift_inward(center: Vector2, side_in_a: String, dist: float, side_a: bool) -> Vector2:
	# side_in_a points OUT of A toward B. Plate A sits just inside A
	# (opposite to the side direction); plate B sits just inside B.
	var n: Vector2 = _side_normal(side_in_a)
	return center + (n * dist * (1.0 if not side_a else -1.0))

func _side_normal(side: String) -> Vector2:
	match side:
		"east":  return Vector2(1, 0)
		"west":  return Vector2(-1, 0)
		"north": return Vector2(0, -1)
		"south": return Vector2(0, 1)
	return Vector2.ZERO

func _on_door_touch(body: Node, record: Dictionary, target_room: int) -> void:
	if _transitioning:
		return
	if not body.is_in_group("player"):
		return
	if _current_room == target_room:
		return
	# Step the player a small distance into the new room so they don't bounce
	# off the door plate.
	var side_in_a: String = String(record["side"])
	var n: Vector2 = _side_normal(side_in_a)
	var direction := n if target_room == record["b"] else -n
	var step: Vector2 = direction * (DOOR_WIDTH * 0.55 + 12.0)
	var landing: Vector2 = (body as Node2D).global_position + step
	# Ensure landing is well above the new room's floor.
	landing.y = _clamp_to_room_safe(landing, target_room)
	do_room_transition(body as Player, landing, target_room)

func _clamp_to_room_safe(p: Vector2, room_id: int) -> float:
	var r: Rect2 = _rooms[room_id]["rect"]
	# Floor band is 40 px at room bottom; keep player at least 100 px above.
	var floor_top: float = r.position.y + r.size.y - 40.0
	return clamp(p.y, r.position.y + 80.0, floor_top - 24.0)

# =============================================================================
#  ROOM ENTER + CAMERA LOCK
# =============================================================================
func _room_at_world(pos: Vector2) -> int:
	for room in _rooms.values():
		var r: Rect2 = room["rect"]
		if r.has_point(pos):
			return int(room["id"])
	return -1

func _enter_room(room_id: int, instant: bool) -> void:
	_current_room = room_id
	_visited[room_id] = true
	_apply_camera_to_room(room_id, instant)
	_refresh_minimap()

func _apply_camera_to_room(room_id: int, instant: bool) -> void:
	if _player_ref == null:
		return
	var cam := _player_ref.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var r: Rect2 = _rooms[room_id]["rect"]
	cam.limit_left   = int(r.position.x)
	cam.limit_top    = int(r.position.y)
	cam.limit_right  = int(r.position.x + r.size.x)
	cam.limit_bottom = int(r.position.y + r.size.y)
	cam.position_smoothing_enabled = not instant
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(1.7, 1.7)

# A safe spawn point inside a given room.
func _room_spawn_pos(room_id: int) -> Vector2:
	var r: Rect2 = _rooms[room_id]["rect"]
	return r.position + Vector2(120.0, r.size.y - 120.0)

# =============================================================================
#  FEATURES (save crystals, warp gates, relics, bomb-walls, dash-walls)
# =============================================================================
func _build_features() -> void:
	# R1 has a save crystal + cracked north wall (no actual neighbor here in the
	# demo — bomb-walls in this demo are placed inside the dash hall instead).
	var r1: Rect2 = _rooms[1]["rect"]
	_spawn_save_crystal(1, r1.position + Vector2(280.0, r1.size.y - 96.0))

	# R2 — double jump relic on the topmost single-jump-reachable platform
	# (matches P3 in _layout_tower so it's grabbable BEFORE you have the relic).
	var r2: Rect2 = _rooms[2]["rect"]
	var r2_floor_y: float = r2.position.y + r2.size.y - 40.0
	_spawn_relic(2,
		Vector2(r2.position.x + r2.size.x - 110.0, r2_floor_y - 360.0),
		ABILITY_DOUBLE_JUMP)

	# R3 — dash relic on mid alcove platform, dash-wall blocks east exit
	var r3: Rect2 = _rooms[3]["rect"]
	var r3_floor_y: float = r3.position.y + r3.size.y - 40.0
	_spawn_relic(3, Vector2(r3.position.x + 630.0, r3_floor_y - 192.0), ABILITY_DASH)
	# Dash wall blocks the east-side wall just above the floor (decorative —
	# wall is breakable by entering it while dashing).
	_spawn_dash_wall(3, Vector2(r3.position.x + r3.size.x - 80.0, r3_floor_y - 130.0))
	# Bomb-wall at west side of R3 hides a coin reward niche.
	_spawn_bomb_wall(3, Vector2(r3.position.x + 60.0, r3_floor_y - 140.0))

	# R4 — wall jump + demolitions relics + warp + save
	var r4: Rect2 = _rooms[4]["rect"]
	var r4_floor_y: float = r4.position.y + r4.size.y - 40.0
	_spawn_relic(4, Vector2(r4.position.x + 200.0, r4_floor_y - 252.0), ABILITY_WALL_JUMP)
	_spawn_relic(4, Vector2(r4.position.x + r4.size.x - 200.0, r4_floor_y - 252.0), ABILITY_DEMOLITIONS)
	_spawn_save_crystal(4, Vector2(r4.position.x + r4.size.x * 0.5, r4_floor_y - 110.0))
	_spawn_warp(4, Vector2(r4.position.x + r4.size.x * 0.5, r4_floor_y - 360.0))
	# Mirror warp pad in R1 so you have somewhere to warp to from R4.
	_spawn_warp(1, Vector2(r1.position.x + r1.size.x - 200.0, r1.position.y + r1.size.y - 96.0))

	# Exit door — placed in R4 to mark the level's end.
	var exit_door := EXIT_DOOR_SCENE.instantiate() as Node2D
	exit_door.position = Vector2(r4.position.x + r4.size.x - 80.0, r4_floor_y - 60.0)
	add_child(exit_door)
	_room_markers[4]["exit"] = true

	# South-door return chute: R1 floor sits ~680 px above R3 floor. Drop in
	# zig-zag stepping platforms inside the door column so the player can
	# bounce back up. Steps stay strictly inside the 96-px chute width.
	var chute_left: float = 1872.0   # matches R1↔R3 south-door cut span
	var step_w: float = 56.0
	for i in 5:
		var step_y: float = 1240.0 - float(i) * 130.0
		var on_left: bool = (i % 2 == 0)
		var step_x: float = chute_left + (4.0 if on_left else (96.0 - step_w - 4.0))
		_add_platform(step_x, step_y, step_w, 20.0)

	# Scatter a handful of coins per room as visual reward signposting.
	for room_id in _rooms.keys():
		_scatter_coins(int(room_id), 6)

func _scatter_coins(room_id: int, count: int) -> void:
	var r: Rect2 = _rooms[room_id]["rect"]
	for i in count:
		var coin := COIN_SCENE.instantiate() as Node2D
		coin.position = Vector2(
			r.position.x + 180.0 + randf() * (r.size.x - 360.0),
			r.position.y + r.size.y - 80.0 - randf() * 240.0
		)
		add_child(coin)

# --- Save crystal -----------------------------------------------------------
func _spawn_save_crystal(room_id: int, pos: Vector2) -> void:
	var node := Area2D.new()
	node.name = "SaveCrystal_R%d" % room_id
	node.collision_layer = 0
	node.collision_mask = 2
	node.position = pos
	var shape := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 28.0
	shape.shape = cs
	node.add_child(shape)
	# Visual: pulsing diamond
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0, -34), Vector2(24, 0), Vector2(0, 34), Vector2(-24, 0)
	])
	diamond.color = COL_SAVE_GLOW
	node.add_child(diamond)
	# Glow
	var glow := Polygon2D.new()
	glow.polygon = PackedVector2Array([
		Vector2(0, -52), Vector2(40, 0), Vector2(0, 52), Vector2(-40, 0)
	])
	glow.color = Color(COL_SAVE_GLOW.r, COL_SAVE_GLOW.g, COL_SAVE_GLOW.b, 0.25)
	node.add_child(glow)
	add_child(node)

	# Pulse tween
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "scale", Vector2(1.15, 1.15), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow, "scale", Vector2(0.9, 0.9), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	node.body_entered.connect(func(body):
		if not body.is_in_group("player"):
			return
		_on_save_touched(body as Player, room_id, pos))
	_room_markers[room_id]["save"] = true

func _on_save_touched(p: Player, room_id: int, pos: Vector2) -> void:
	_respawn = pos + Vector2(0, -12)
	if p.has_method("heal_to_full"):
		p.call("heal_to_full")
	else:
		p.current_health = p.max_health
		if p.has_signal("health_changed"):
			p.emit_signal("health_changed", p.current_health, p.max_health)
	_show_banner("✦ SAVED — %s ✦" % String(_rooms[room_id]["name"]).to_upper(), COL_SAVE_GLOW)

# --- Warp gate --------------------------------------------------------------
func _spawn_warp(room_id: int, pos: Vector2) -> void:
	var node := Area2D.new()
	node.name = "Warp_R%d" % room_id
	node.collision_layer = 0
	node.collision_mask = 2
	node.position = pos
	var shape := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(72.0, 110.0)
	shape.shape = cs
	node.add_child(shape)
	# Visual: glowing pylon
	var pillar := ColorRect.new()
	pillar.color = Color(COL_WARP_GLOW.r, COL_WARP_GLOW.g, COL_WARP_GLOW.b, 0.45)
	pillar.size = Vector2(72.0, 110.0)
	pillar.position = Vector2(-36.0, -55.0)
	node.add_child(pillar)
	var halo := ColorRect.new()
	halo.color = Color(COL_WARP_GLOW.r, COL_WARP_GLOW.g, COL_WARP_GLOW.b, 0.20)
	halo.size = Vector2(110.0, 150.0)
	halo.position = Vector2(-55.0, -75.0)
	node.add_child(halo)
	add_child(node)
	node.set_meta("room_id", room_id)
	node.set_meta("activated", false)
	_warp_nodes.append(node)

	node.body_entered.connect(func(body):
		if not body.is_in_group("player"):
			return
		_on_warp_touched(body as Player, node))
	_room_markers[room_id]["warp"] = true

func _on_warp_touched(p: Player, node: Area2D) -> void:
	if not node.get_meta("activated"):
		node.set_meta("activated", true)
		_show_banner("⟿ WARP ANCHOR SET", COL_WARP_GLOW)
		return
	# Touch an already-activated warp: pick another activated warp and travel.
	for other in _warp_nodes:
		if other == node:
			continue
		if not other.get_meta("activated"):
			continue
		var target_room: int = int(other.get_meta("room_id"))
		var dest: Vector2 = (other as Node2D).global_position + Vector2(0, -24)
		do_room_transition(p, dest, target_room)
		return
	_show_banner("⟿ NO OTHER WARP ACTIVE", COL_WARP_GLOW)

# --- Relics + ability gating ------------------------------------------------
func _spawn_relic(room_id: int, pos: Vector2, ability_id: String) -> void:
	var node := Area2D.new()
	node.name = "Relic_%s" % ability_id
	node.collision_layer = 0
	node.collision_mask = 2
	node.position = pos
	var shape := CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = 24.0
	shape.shape = cs
	node.add_child(shape)
	var color: Color = _relic_color(ability_id)
	# Star polygon to distinguish from coins.
	var star := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 10:
		var ang: float = float(i) * PI / 5.0
		var rdist: float = 24.0 if i % 2 == 0 else 10.0
		pts.append(Vector2(cos(ang) * rdist, sin(ang) * rdist))
	star.polygon = pts
	star.color = color
	node.add_child(star)
	add_child(node)
	# Bob animation
	var tw := create_tween().set_loops()
	tw.tween_property(star, "position", Vector2(0, -6), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(star, "position", Vector2(0,  6), 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	node.body_entered.connect(func(body):
		if not body.is_in_group("player"):
			return
		_on_relic_taken(node, ability_id, room_id))
	_room_markers[room_id]["relic"] = ability_id

func _relic_color(ability_id: String) -> Color:
	match ability_id:
		ABILITY_DOUBLE_JUMP: return COL_RELIC_J
		ABILITY_DASH:        return COL_RELIC_D
		ABILITY_WALL_JUMP:   return COL_RELIC_W
		ABILITY_DEMOLITIONS: return COL_RELIC_B
	return Color.WHITE

func _on_relic_taken(node: Area2D, ability_id: String, _room_id: int) -> void:
	if _abilities[ability_id]:
		return
	_abilities[ability_id] = true
	_apply_ability_locks()
	_show_banner("✦ %s ACQUIRED ✦" % String(ABILITY_DISPLAY[ability_id]), _relic_color(ability_id))
	node.queue_free()
	_refresh_minimap()

func _cache_player_baseline() -> void:
	if _player_ref == null:
		return
	_baseline_max_jumps = _player_ref.max_jumps
	_baseline_dash_cd   = _player_ref.dash_cooldown
	_baseline_wj_x      = _player_ref.wall_jump_vel_x
	_baseline_wj_y      = _player_ref.wall_jump_vel_y
	_baseline_ws_grav   = _player_ref.wall_slide_gravity_scale

# Force the Player's stats to match the current ability set. Each frame? No —
# only on relic pickup and on room enter / respawn. Player code never resets
# these values from a relic-set baseline, so persistent fields are enough.
func _apply_ability_locks() -> void:
	if _player_ref == null:
		return
	# Double jump
	_player_ref.max_jumps = 2 if _abilities[ABILITY_DOUBLE_JUMP] else 1
	_player_ref.jumps_remaining = clamp(_player_ref.jumps_remaining, 0, _player_ref.max_jumps)
	# Dash — push cooldown to infinity to disable, restore baseline to enable.
	# Player checks `_dash_cd <= 0` to allow a dash, and resets _dash_cd to
	# dash_cooldown after one fires. We poke BOTH so a dash already cooling
	# down can't slip through, and a freshly-spawned player can't dash once.
	if _abilities[ABILITY_DASH]:
		_player_ref.dash_cooldown = _baseline_dash_cd
		_player_ref._dash_cd = minf(_player_ref._dash_cd, 0.0)
	else:
		_player_ref.dash_cooldown = 9999.0
		_player_ref._dash_cd = 9999.0
	# Wall jump — zero the impulse and slide friction
	if _abilities[ABILITY_WALL_JUMP]:
		_player_ref.wall_jump_vel_x = _baseline_wj_x
		_player_ref.wall_jump_vel_y = _baseline_wj_y
		_player_ref.wall_slide_gravity_scale = _baseline_ws_grav
	else:
		_player_ref.wall_jump_vel_x = 0.0
		_player_ref.wall_jump_vel_y = 0.0
		_player_ref.wall_slide_gravity_scale = 1.0   # no slide assist

# --- Bomb walls -------------------------------------------------------------
func _spawn_bomb_wall(_room_id: int, pos: Vector2) -> void:
	var w: float = 60.0
	var h: float = 110.0
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	shape.shape = rs
	shape.position = Vector2(w * 0.5, h * 0.5)
	body.add_child(shape)
	var fill := ColorRect.new()
	fill.color = COL_BOMBWALL
	fill.size = Vector2(w, h)
	body.add_child(fill)
	# Crack overlay
	var cracks := Line2D.new()
	cracks.default_color = COL_BOMBWALL_CRACK
	cracks.width = 2.0
	cracks.points = PackedVector2Array([
		Vector2(8, 10), Vector2(28, 40), Vector2(18, 70),
		Vector2(46, 90), Vector2(30, 102)
	])
	body.add_child(cracks)
	body.add_to_group("level4_bomb_wall")
	add_child(body)
	# Hide a coin reward behind the wall
	var coin := COIN_SCENE.instantiate() as Node2D
	coin.position = pos + Vector2(-30.0, 40.0)
	add_child(coin)

# --- Dash walls -------------------------------------------------------------
func _spawn_dash_wall(_room_id: int, pos: Vector2) -> void:
	var w: float = 36.0
	var h: float = 130.0
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(w, h)
	shape.shape = rs
	shape.position = Vector2(w * 0.5, h * 0.5)
	body.add_child(shape)
	var fill := ColorRect.new()
	fill.color = COL_DASHWALL
	fill.size = Vector2(w, h)
	body.add_child(fill)
	body.add_to_group("level4_dash_wall")
	# A trigger Area in front of the wall that listens for the player passing
	# through it while dashing.
	var sensor := Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var sshape := CollisionShape2D.new()
	var srs := RectangleShape2D.new()
	srs.size = Vector2(w + 40.0, h + 20.0)
	sshape.shape = srs
	sshape.position = Vector2(w * 0.5, h * 0.5)
	sensor.add_child(sshape)
	sensor.position = pos
	add_child(sensor)
	add_child(body)
	sensor.body_entered.connect(func(b):
		if not b.is_in_group("player"):
			return
		if not _abilities[ABILITY_DASH]:
			return
		if (b as Player).is_dashing:
			body.queue_free()
			sensor.queue_free())

# =============================================================================
#  BOMB-WALL DETONATION HOOK
# =============================================================================
# Grenades fire net_spawn_explosion via Main; we tap that pattern by polling
# ExplosiveEffect nodes each physics frame and shattering bomb walls inside
# the blast radius, but only when the player has DEMOLITIONS.
func _physics_process(_delta: float) -> void:
	# Keep ability locks fresh — Player's internal state can drift back into
	# enabled values otherwise (dash cooldown decays, wall-slide flips true
	# any frame the player pushes into a wall).
	if _player_ref != null:
		if not _abilities[ABILITY_DASH]:
			_player_ref._dash_cd = 9999.0
		if not _abilities[ABILITY_WALL_JUMP]:
			# Force the flag off so the jump handler can't read it as true
			# and apply a (0, 0) wall-jump velocity that freezes the player.
			_player_ref.is_wall_sliding = false
	if not _abilities[ABILITY_DEMOLITIONS]:
		return
	var walls := get_tree().get_nodes_in_group("level4_bomb_wall")
	if walls.is_empty():
		return
	for fx in get_tree().get_nodes_in_group("explosive_effect"):
		var fxp: Vector2 = (fx as Node2D).global_position
		for w in walls:
			var wn := w as Node2D
			if wn == null:
				continue
			var center: Vector2 = wn.global_position + Vector2(30.0, 55.0)
			if center.distance_to(fxp) < 120.0:
				wn.queue_free()

# =============================================================================
#  HUD — banner + mini-map
# =============================================================================
func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 6
	add_child(_hud_layer)

	# Mini-map container — top-right
	_minimap = _build_minimap_root()
	_hud_layer.add_child(_minimap)

	# Banner label, centered top
	_banner = Label.new()
	_banner.text = ""
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 110.0
	_banner.offset_bottom = 160.0
	_banner.modulate = Color(1, 1, 1, 0)
	_hud_layer.add_child(_banner)

func _show_banner(text: String, color: Color) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate = Color(1, 1, 1, 0)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate", Color(1, 1, 1, 1), 0.25)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(_banner, "modulate", Color(1, 1, 1, 0), 0.4)

# --- Mini-map ---------------------------------------------------------------
const MINIMAP_CELL: float = 22.0
const MINIMAP_PAD:  float = 4.0
const MINIMAP_BG_COLOR := Color(0.05, 0.05, 0.10, 0.78)
const MINIMAP_FRAME_COLOR := Color(0.55, 0.50, 0.75)

var _minimap_cells: Dictionary = {}   # Vector2i → ColorRect
var _minimap_room_panels: Dictionary = {} # room_id → Panel

func _build_minimap_root() -> Control:
	# Bounds of all cells
	var min_c := Vector2i(99999, 99999)
	var max_c := Vector2i(-99999, -99999)
	for room in _rooms.values():
		for c in room["cells"]:
			min_c.x = mini(min_c.x, c.x)
			min_c.y = mini(min_c.y, c.y)
			max_c.x = maxi(max_c.x, c.x)
			max_c.y = maxi(max_c.y, c.y)
	var cols: int = max_c.x - min_c.x + 1
	var rows: int = max_c.y - min_c.y + 1
	var size := Vector2(cols * MINIMAP_CELL + MINIMAP_PAD * 2.0, rows * MINIMAP_CELL + MINIMAP_PAD * 2.0)

	var root := PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	root.offset_left = -size.x - 16.0
	root.offset_right = -16.0
	root.offset_top = 16.0
	root.offset_bottom = 16.0 + size.y
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = MINIMAP_BG_COLOR
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = MINIMAP_FRAME_COLOR
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = MINIMAP_PAD
	sb.content_margin_right = MINIMAP_PAD
	sb.content_margin_top = MINIMAP_PAD
	sb.content_margin_bottom = MINIMAP_PAD
	root.add_theme_stylebox_override("panel", sb)

	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(cols * MINIMAP_CELL, rows * MINIMAP_CELL)
	root.add_child(canvas)

	for room in _rooms.values():
		var panels_for_room: Array = []
		for c in room["cells"]:
			var local := Vector2((c.x - min_c.x) * MINIMAP_CELL, (c.y - min_c.y) * MINIMAP_CELL)
			var cell := ColorRect.new()
			cell.color = Color(0.10, 0.09, 0.16, 0.85)
			cell.size = Vector2(MINIMAP_CELL - 2.0, MINIMAP_CELL - 2.0)
			cell.position = local + Vector2(1.0, 1.0)
			canvas.add_child(cell)
			_minimap_cells[c] = cell
			panels_for_room.append(cell)
		_minimap_room_panels[int(room["id"])] = panels_for_room
	return root

func _refresh_minimap() -> void:
	if _minimap == null:
		return
	for room in _rooms.values():
		var room_id: int = int(room["id"])
		var visited: bool = _visited.has(room_id)
		var is_current: bool = (room_id == _current_room)
		var markers: Dictionary = _room_markers[room_id]
		var color: Color = Color(0.10, 0.09, 0.16, 0.85)
		if visited:
			color = Color(0.32, 0.28, 0.45, 0.95)
		if markers.get("save", false) and visited:
			color = COL_SAVE_GLOW.lerp(Color.WHITE, 0.05)
			color.a = 0.95
		if markers.get("warp", false) and visited:
			color = COL_WARP_GLOW.lerp(Color.WHITE, 0.05)
			color.a = 0.95
		var relic_id: String = String(markers.get("relic", ""))
		if relic_id != "" and visited:
			color = _relic_color(relic_id)
			color.a = 0.85
		if markers.get("exit", false) and visited:
			color = Color(0.95, 0.85, 0.35, 0.95)
		if is_current:
			color = color.lerp(Color.WHITE, 0.45)
		for cell in _minimap_room_panels.get(room_id, []):
			(cell as ColorRect).color = color
