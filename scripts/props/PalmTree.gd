extends Node2D

# A foreground palm tree. Origin (0,0) sits where the trunk meets the ground.
# Variants:
#   0 = standard medium palm
#   1 = tall slender palm
#   2 = short bushy palm with extra fronds

@export var tree_height: float = 130.0
@export var variant: int       = 0
@export var rand_seed: int     = 0
@export var color_trunk: Color  = Color(0.22, 0.14, 0.08)
@export var color_trunk_hi: Color = Color(0.34, 0.22, 0.12)
@export var color_frond: Color  = Color(0.16, 0.42, 0.18)
@export var color_frond_hi: Color = Color(0.26, 0.56, 0.22)

func _ready() -> void:
	_build()

func _build() -> void:
	var h: float = tree_height
	if variant == 1: h *= 1.30
	if variant == 2: h *= 0.78
	var lean: float = sin(float(rand_seed) * 1.3) * 6.0
	if variant == 1: lean *= 1.4
	var base_y: float = 0.0
	var top_y: float = base_y - h

	# Trunk
	var trunk := Polygon2D.new()
	trunk.color = color_trunk
	trunk.polygon = PackedVector2Array([
		Vector2(-6.0, base_y),
		Vector2( 6.0, base_y),
		Vector2( 4.0 + lean * 0.3, base_y - h * 0.55),
		Vector2( 3.0 + lean, top_y),
		Vector2(-3.0 + lean, top_y),
		Vector2(-4.0 + lean * 0.3, base_y - h * 0.55),
	])
	add_child(trunk)

	# Bark ring highlights
	for k in 3:
		var ry: float = base_y - h * (0.25 + 0.22 * float(k))
		var ring := ColorRect.new()
		var ring_lean: float = lean * (ry - base_y) / -h * 0.6
		ring.offset_left = -5.0 + ring_lean
		ring.offset_right = 5.0 + ring_lean
		ring.offset_top = ry
		ring.offset_bottom = ry + 2.0
		ring.color = color_trunk_hi
		add_child(ring)

	# Fronds
	var frond_count: int = 7
	if variant == 1: frond_count = 5
	if variant == 2: frond_count = 9
	for k in frond_count:
		var t: float = float(k) / float(frond_count - 1)
		var ang: float = lerpf(PI * 1.15, TAU - PI * 0.15, t)
		var flen: float = 58.0 + sin(float(k + rand_seed) * 1.7) * 8.0
		if variant == 2: flen *= 0.85
		if variant == 1: flen *= 1.05
		var fwid: float = 8.0
		var ex: float = lean + cos(ang) * flen
		var ey: float = top_y + sin(ang) * flen * 0.55
		var mid_x: float = lean + cos(ang) * flen * 0.5
		var mid_y: float = top_y + sin(ang) * flen * 0.27
		var perp := Vector2(-sin(ang), cos(ang)) * fwid
		var frond := Polygon2D.new()
		frond.color = color_frond if (k + rand_seed) % 2 == 0 else color_frond_hi
		frond.polygon = PackedVector2Array([
			Vector2(lean, top_y),
			Vector2(mid_x + perp.x, mid_y + perp.y),
			Vector2(ex, ey),
			Vector2(mid_x - perp.x, mid_y - perp.y),
		])
		add_child(frond)

	# Coconut cluster (skip on tall slender variant for cleaner silhouette)
	if variant != 1:
		for k in 3:
			var co := ColorRect.new()
			co.offset_left = lean - 6.0 + float(k) * 5.0
			co.offset_right = lean - 2.0 + float(k) * 5.0
			co.offset_top = top_y + 2.0
			co.offset_bottom = top_y + 6.0
			co.color = color_trunk
			add_child(co)
