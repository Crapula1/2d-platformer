extends Node2D

# A single tuft of grass blades. Variants:
#   0 = small upright blades (default)
#   1 = tall windswept blades
#   2 = low clump (rounded blob)

@export var variant: int       = 0
@export var tuft_width: float  = 8.0
@export var tuft_height: float = 8.0
@export var blade_count: int   = 4
@export var color_a: Color     = Color(0.24, 0.66, 0.22)
@export var color_b: Color     = Color(0.16, 0.48, 0.16)

func _ready() -> void:
	_build()

func _build() -> void:
	if variant == 2:
		var clump := Polygon2D.new()
		clump.color = color_a
		var pts := PackedVector2Array()
		for k in 12:
			var a: float = float(k) * TAU / 12.0
			var j: float = 0.85 + 0.2 * sin(float(k) * 1.7)
			pts.append(Vector2(cos(a) * tuft_width * j, min(sin(a) * tuft_height * 0.6 * j, 0.0)))
		clump.polygon = pts
		add_child(clump)
		return

	var n: int = maxi(blade_count, 2)
	for i in n:
		var t: float = float(i) / float(n - 1) - 0.5  # -0.5 .. +0.5
		var x: float = t * tuft_width
		var lean: float = (t * 4.0) if variant == 1 else (t * 1.5)
		var h: float = tuft_height * (0.6 + 0.6 * (1.0 - abs(t) * 2.0)) if variant == 1 else tuft_height
		var blade := Polygon2D.new()
		blade.color = color_a if i % 2 == 0 else color_b
		blade.polygon = PackedVector2Array([
			Vector2(x - 1.2, 0.0),
			Vector2(x + 1.2, 0.0),
			Vector2(x + lean, -h),
		])
		add_child(blade)
