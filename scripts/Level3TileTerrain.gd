extends RefCounted
class_name Level3TileTerrain

# Procedurally-generated castle terrain TileSet for Level 3.
#
# 32x32 tiles. CORNERS-mode terrain so the TileMapLayer can auto-pick the right
# tile for edges / outer corners / inner corners / interior using
# set_cells_terrain_connect(). One terrain ("stone") with the four corner
# peering bits driving the 15 non-empty tile variants.
#
# Layout convention: corner-mode places the visible surface at the *mid-tile*
# line. So the top row of ground tiles is mask 0011 (top corners empty, bottom
# corners stone) — its stone occupies the bottom half of the cell, and the
# play surface sits at y = row*32 + 16. Position the TileMapLayer at (0, 0)
# and put the surface row so that row*32 + 16 == GROUND_TOP (400 → row 12).

const TILE_SIZE: int = 32
const ATLAS_COLS: int = 4
const ATLAS_ROWS: int = 4

# Palette matches the castle look of Level3.gd.
const COL_STONE_BASE: Color = Color(0.30, 0.30, 0.34)
const COL_STONE_DARK: Color = Color(0.18, 0.18, 0.22)
const COL_STONE_HI:   Color = Color(0.46, 0.46, 0.50)
const COL_MORTAR:     Color = Color(0.10, 0.10, 0.14)
const COL_MOSS_TOP:   Color = Color(0.40, 0.62, 0.30)
const COL_MOSS_DARK:  Color = Color(0.24, 0.42, 0.20)
const COL_SHADOW:     Color = Color(0.08, 0.08, 0.10, 0.55)

# Terrain ids — exposed so the caller can pass them to TileMapLayer.
const TERRAIN_SET: int = 0
const TERRAIN_STONE: int = 0

static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Physics layer 0 — collides on world layer (mask bit 1).
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	# Terrain set 0, terrain 0 = "stone".
	ts.add_terrain_set()
	ts.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	ts.add_terrain(TERRAIN_SET)
	ts.set_terrain_name(TERRAIN_SET, TERRAIN_STONE, "stone")
	ts.set_terrain_color(TERRAIN_SET, TERRAIN_STONE, COL_STONE_BASE)

	# Paint the atlas image (4x4 grid of 32x32 tiles → 128x128).
	var atlas_img := Image.create(
		ATLAS_COLS * TILE_SIZE,
		ATLAS_ROWS * TILE_SIZE,
		false,
		Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))

	# Pass 1: paint every tile into the atlas image.
	for mask in range(1, 16):
		var slot: int = mask - 1
		var ax: int = slot % ATLAS_COLS
		var ay: int = slot / ATLAS_COLS
		_paint_tile(
			atlas_img, ax * TILE_SIZE, ay * TILE_SIZE,
			(mask & 8) != 0, (mask & 4) != 0,
			(mask & 2) != 0, (mask & 1) != 0)

	# Build the source from the finished image. Texture and region size must
	# both be set before create_tile() — the source validates each tile coord
	# against (texture.size / texture_region_size).
	var source := TileSetAtlasSource.new()
	# Order matters: texture_region_size + padding flag must be set BEFORE
	# the texture, because assigning .texture triggers grid validation that
	# uses whatever region_size and padding are currently configured.
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	source.use_texture_padding = false
	source.texture = ImageTexture.create_from_image(atlas_img)
	# Register the source with the TileSet up front — some Godot 4 builds
	# require the source to be owned before create_tile() succeeds.
	ts.add_source(source, 0)

	# Pass 2: register tiles + terrain + collision now that the source is sized.
	for mask in range(1, 16):
		var tl: bool = (mask & 8) != 0
		var tr: bool = (mask & 4) != 0
		var bl: bool = (mask & 2) != 0
		var br: bool = (mask & 1) != 0
		var slot2: int = mask - 1
		var coords := Vector2i(slot2 % ATLAS_COLS, slot2 / ATLAS_COLS)
		source.create_tile(coords)
		var td: TileData = source.get_tile_data(coords, 0)
		td.terrain_set = TERRAIN_SET
		td.terrain = TERRAIN_STONE
		# Peering: a corner bit set to TERRAIN_STONE means that corner of the
		# tile sits inside stone. Bits left at -1 (default) mean empty corner.
		if tl: td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TERRAIN_STONE)
		if tr: td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, TERRAIN_STONE)
		if bl: td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TERRAIN_STONE)
		if br: td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, TERRAIN_STONE)
		_apply_collision(td, tl, tr, bl, br)

	return ts

# Look up the atlas coords for a corner-mask. Mirrors the layout used in build().
static func atlas_coords_for_mask(mask: int) -> Vector2i:
	if mask <= 0 or mask > 15:
		return Vector2i(-1, -1)
	var slot: int = mask - 1
	return Vector2i(slot % ATLAS_COLS, slot / ATLAS_COLS)

# -----------------------------------------------------------------------------
# Pixel painter
# -----------------------------------------------------------------------------
static func _paint_tile(img: Image, ox: int, oy: int, tl: bool, tr: bool, bl: bool, br: bool) -> void:
	# Each 16x16 quadrant is drawn if its outer corner bit is set.
	# Quadrant rects (tile-local px): TL (0..16,0..16), TR (16..32,0..16),
	# BL (0..16,16..32), BR (16..32,16..32).
	if tl: _paint_quadrant(img, ox + 0,  oy + 0,  tl, tr, bl, br, 0)
	if tr: _paint_quadrant(img, ox + 16, oy + 0,  tl, tr, bl, br, 1)
	if bl: _paint_quadrant(img, ox + 0,  oy + 16, tl, tr, bl, br, 2)
	if br: _paint_quadrant(img, ox + 16, oy + 16, tl, tr, bl, br, 3)

# quad_id: 0=TL, 1=TR, 2=BL, 3=BR. We need the masks to know if the *adjacent*
# quadrants are filled, which decides where moss / shadows go inside this tile.
static func _paint_quadrant(img: Image, qx: int, qy: int, tl: bool, tr: bool, bl: bool, br: bool, quad_id: int) -> void:
	# Determine which of this quadrant's INTERNAL neighbors (above, below,
	# left, right) is empty. Moss appears where stone is exposed upward.
	var neighbor_up_empty: bool
	var neighbor_dn_empty: bool
	var neighbor_lf_empty: bool
	var neighbor_rt_empty: bool
	match quad_id:
		0: # TL
			neighbor_up_empty = true   # tile-top boundary; conservative
			neighbor_dn_empty = not bl
			neighbor_lf_empty = true
			neighbor_rt_empty = not tr
		1: # TR
			neighbor_up_empty = true
			neighbor_dn_empty = not br
			neighbor_lf_empty = not tl
			neighbor_rt_empty = true
		2: # BL
			neighbor_up_empty = not tl
			neighbor_dn_empty = true
			neighbor_lf_empty = true
			neighbor_rt_empty = not br
		3: # BR
			neighbor_up_empty = not tr
			neighbor_dn_empty = true
			neighbor_lf_empty = not bl
			neighbor_rt_empty = true

	# Fill base stone with mortar grid.
	for ly in range(16):
		for lx in range(16):
			var px: int = qx + lx
			var py: int = qy + ly
			var c: Color = COL_STONE_BASE
			# Subtle mortar grid every 8 px in the tile's local frame.
			var tx: int = px % 8
			var ty: int = py % 8
			if tx == 0 or ty == 0:
				c = COL_MORTAR.lerp(COL_STONE_DARK, 0.35)
			elif tx == 7 or ty == 7:
				c = COL_STONE_DARK
			else:
				# Per-block highlight: top-left of each 8x8 block is brighter
				if tx <= 2 and ty <= 2:
					c = COL_STONE_HI
				elif (lx + ly) % 5 == 0:
					c = COL_STONE_BASE.lerp(COL_STONE_HI, 0.25)
			img.set_pixel(px, py, c)

	# Moss stripe along the exposed upward edge of this quadrant.
	if neighbor_up_empty:
		for lx in range(16):
			var px2: int = qx + lx
			# 2-px moss band, with a slightly darker pixel-line beneath.
			img.set_pixel(px2, qy + 0, COL_MOSS_TOP)
			img.set_pixel(px2, qy + 1, COL_MOSS_TOP)
			img.set_pixel(px2, qy + 2, COL_MOSS_DARK)
			# Hanging vine flecks every few pixels for texture.
			if lx % 5 == 2:
				img.set_pixel(px2, qy + 3, COL_MOSS_DARK)

	# Soft inner shadow on the side opposite of an exposed face — gives volume.
	if neighbor_lf_empty:
		for ly2 in range(16):
			var py3: int = qy + ly2
			var base := img.get_pixel(qx + 1, py3)
			img.set_pixel(qx + 1, py3, base.lerp(Color(0, 0, 0), 0.18))
	if neighbor_rt_empty:
		for ly3 in range(16):
			var py4: int = qy + ly3
			var base2 := img.get_pixel(qx + 14, py4)
			img.set_pixel(qx + 14, py4, base2.lerp(Color(0, 0, 0), 0.18))

	# Dark underside if downward neighbor is empty.
	if neighbor_dn_empty:
		for lx2 in range(16):
			var px3: int = qx + lx2
			var base3 := img.get_pixel(px3, qy + 15)
			img.set_pixel(px3, qy + 15, base3.lerp(Color(0, 0, 0), 0.40))

# -----------------------------------------------------------------------------
# Collision — one rect per stone region, merged where adjacent quadrants are
# both filled to keep the body count down.
# -----------------------------------------------------------------------------
static func _apply_collision(td: TileData, tl: bool, tr: bool, bl: bool, br: bool) -> void:
	# Coords are tile-local CENTERED (Godot 4 convention): (-16,-16) top-left.
	var rects: Array = []
	if tl and tr and bl and br:
		rects.append([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)])
	elif tl and tr:
		# Top half
		rects.append([Vector2(-16, -16), Vector2(16, -16), Vector2(16, 0), Vector2(-16, 0)])
		if bl:
			rects.append([Vector2(-16, 0), Vector2(0, 0), Vector2(0, 16), Vector2(-16, 16)])
		if br:
			rects.append([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	elif bl and br:
		# Bottom half
		rects.append([Vector2(-16, 0), Vector2(16, 0), Vector2(16, 16), Vector2(-16, 16)])
		if tl:
			rects.append([Vector2(-16, -16), Vector2(0, -16), Vector2(0, 0), Vector2(-16, 0)])
		if tr:
			rects.append([Vector2(0, -16), Vector2(16, -16), Vector2(16, 0), Vector2(0, 0)])
	elif tl and bl:
		# Left half
		rects.append([Vector2(-16, -16), Vector2(0, -16), Vector2(0, 16), Vector2(-16, 16)])
		if tr:
			rects.append([Vector2(0, -16), Vector2(16, -16), Vector2(16, 0), Vector2(0, 0)])
		if br:
			rects.append([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])
	elif tr and br:
		# Right half
		rects.append([Vector2(0, -16), Vector2(16, -16), Vector2(16, 16), Vector2(0, 16)])
		if tl:
			rects.append([Vector2(-16, -16), Vector2(0, -16), Vector2(0, 0), Vector2(-16, 0)])
		if bl:
			rects.append([Vector2(-16, 0), Vector2(0, 0), Vector2(0, 16), Vector2(-16, 16)])
	else:
		# Single quadrant (or two diagonal) — emit per stone quadrant.
		if tl: rects.append([Vector2(-16, -16), Vector2(0, -16), Vector2(0, 0), Vector2(-16, 0)])
		if tr: rects.append([Vector2(0, -16), Vector2(16, -16), Vector2(16, 0), Vector2(0, 0)])
		if bl: rects.append([Vector2(-16, 0), Vector2(0, 0), Vector2(0, 16), Vector2(-16, 16)])
		if br: rects.append([Vector2(0, 0), Vector2(16, 0), Vector2(16, 16), Vector2(0, 16)])

	for i in range(rects.size()):
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, i, PackedVector2Array(rects[i]))
