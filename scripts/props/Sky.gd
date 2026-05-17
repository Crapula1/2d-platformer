extends Node2D

# A reusable jungle sky backdrop: vertical gradient (top -> bottom -> horizon)
# with an optional sun disc. All sizes are in local coordinates; place this
# inside a ParallaxLayer with motion_scale = Vector2.ZERO for a non-scrolling
# sky, or with a small motion_scale.x for slow drift.

@export var top_color: Color    = Color(0.04, 0.10, 0.18)
@export var mid_color: Color    = Color(0.30, 0.50, 0.46)
@export var horizon_color: Color = Color(0.48, 0.42, 0.34)
@export var rect_size: Vector2  = Vector2(2560.0, 1040.0)
@export var origin: Vector2     = Vector2(-640.0, -200.0)
@export var bands: int          = 10
@export var horizon_split: float = 0.65  # 0..1; fraction where mid -> horizon starts
@export var show_sun: bool      = true
@export var sun_position: Vector2 = Vector2(950.0, 240.0)
@export var sun_radius: float   = 24.0
@export var sun_color: Color    = Color(1.00, 0.95, 0.82, 0.92)
@export var sun_glow_color: Color = Color(1.00, 0.88, 0.55, 0.20)

func _ready() -> void:
	_build_gradient()
	if show_sun:
		_build_sun()

func _build_gradient() -> void:
	var n: int = maxi(bands, 2)
	for i in n:
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var col: Color
		if t0 < horizon_split:
			col = top_color.lerp(mid_color, t0 / horizon_split)
		else:
			col = mid_color.lerp(horizon_color, (t0 - horizon_split) / (1.0 - horizon_split))
		var band := ColorRect.new()
		band.offset_left = origin.x
		band.offset_right = origin.x + rect_size.x
		band.offset_top = origin.y + t0 * rect_size.y
		band.offset_bottom = origin.y + t1 * rect_size.y + 1.0
		band.color = col
		add_child(band)

func _build_sun() -> void:
	_add_disc(sun_position, sun_radius * 2.4, sun_glow_color)
	_add_disc(sun_position, sun_radius * 1.5, Color(sun_glow_color.r, sun_glow_color.g, sun_glow_color.b, sun_glow_color.a * 1.6))
	_add_disc(sun_position, sun_radius, sun_color)

func _add_disc(center: Vector2, radius: float, c: Color) -> void:
	var p := Polygon2D.new()
	p.color = c
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a: float = float(i) * TAU / float(n)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	p.polygon = pts
	add_child(p)
