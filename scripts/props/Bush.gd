extends Node2D

# Low foliage — bushes and ferns. Variants:
#   0 = round bush (blob of foliage)
#   1 = fern (3-5 long leaves fanning up)
#   2 = clumpy undergrowth (two overlapping blobs)

@export var variant: int       = 0
@export var foliage_size: float = 22.0
@export var rand_seed: int     = 0
@export var color_base: Color  = Color(0.18, 0.45, 0.18)
@export var color_hi: Color    = Color(0.28, 0.58, 0.22)

func _ready() -> void:
	add_to_group("bush")
	_build()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rand_seed) if rand_seed != 0 else hash(int(foliage_size * 11.0))

	match variant:
		1:
			_build_fern(rng)
		2:
			_build_clump(rng)
		_:
			_build_bush(rng)

func _build_bush(rng: RandomNumberGenerator) -> void:
	_blob(Vector2(0.0, -foliage_size * 0.45), foliage_size * 0.95, foliage_size * 0.55, color_base, rng)
	_blob(Vector2(-foliage_size * 0.2, -foliage_size * 0.55), foliage_size * 0.45, foliage_size * 0.30, color_hi, rng)

func _build_clump(rng: RandomNumberGenerator) -> void:
	_blob(Vector2(-foliage_size * 0.25, -foliage_size * 0.4), foliage_size * 0.6, foliage_size * 0.40, color_base, rng)
	_blob(Vector2( foliage_size * 0.20, -foliage_size * 0.5), foliage_size * 0.7, foliage_size * 0.50, color_base, rng)
	_blob(Vector2(0.0, -foliage_size * 0.65), foliage_size * 0.35, foliage_size * 0.25, color_hi, rng)

func _build_fern(_rng: RandomNumberGenerator) -> void:
	var leaves: int = 5
	for i in leaves:
		var t: float = float(i) / float(leaves - 1)
		var ang: float = lerpf(-PI * 0.85, -PI * 0.15, t)  # fan upward
		var flen: float = foliage_size * (0.85 + 0.15 * sin(float(i) * 2.0))
		var fwid: float = 4.0
		var ex: float = cos(ang) * flen
		var ey: float = sin(ang) * flen
		var mid_x: float = cos(ang) * flen * 0.5
		var mid_y: float = sin(ang) * flen * 0.5
		var perp := Vector2(-sin(ang), cos(ang)) * fwid
		var leaf := Polygon2D.new()
		leaf.color = color_base if i % 2 == 0 else color_hi
		leaf.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(mid_x + perp.x, mid_y + perp.y),
			Vector2(ex, ey),
			Vector2(mid_x - perp.x, mid_y - perp.y),
		])
		add_child(leaf)

func _blob(center: Vector2, rx: float, ry: float, c: Color, _rng: RandomNumberGenerator) -> void:
	var blob := Polygon2D.new()
	blob.color = c
	var pts := PackedVector2Array()
	var n := 14
	for k in n:
		var a: float = float(k) * TAU / float(n)
		var j: float = 0.85 + 0.25 * sin(float(k) * 1.7 + center.x * 0.013)
		pts.append(center + Vector2(cos(a) * rx * j, sin(a) * ry * j))
	blob.polygon = pts
	add_child(blob)
