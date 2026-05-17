extends Node2D

# A small to mid-sized rock / boulder. Variants:
#   0 = wide humped boulder
#   1 = pointy crag
#   2 = squat round
# Position the node so y=0 sits on the surface the rock should rest on.

@export var rock_size: float    = 24.0
@export var rock_height: float  = 12.0
@export var variant: int        = 0
@export var mossy: bool         = true
@export var rand_seed: int      = 0
@export var color_body: Color   = Color(0.44, 0.42, 0.38)
@export var color_edge: Color   = Color(0.24, 0.22, 0.18)
@export var color_moss: Color   = Color(0.26, 0.58, 0.22)

func _ready() -> void:
	_build()

func _build() -> void:
	var w: float = rock_size
	var h: float = rock_height
	var body := Polygon2D.new()
	body.color = color_body

	match variant:
		1:
			# Pointy crag — taller, narrower
			body.polygon = PackedVector2Array([
				Vector2(-w * 0.45, 0.0),
				Vector2(-w * 0.35, -h * 0.55),
				Vector2(-w * 0.05, -h * 1.05),
				Vector2( w * 0.10, -h * 0.9),
				Vector2( w * 0.35, -h * 0.35),
				Vector2( w * 0.40, 0.0),
			])
		2:
			# Squat round
			body.polygon = PackedVector2Array([
				Vector2(-w * 0.5,  0.0),
				Vector2(-w * 0.45, -h * 0.7),
				Vector2(-w * 0.15, -h * 0.95),
				Vector2( w * 0.20, -h * 0.95),
				Vector2( w * 0.45, -h * 0.65),
				Vector2( w * 0.5,  0.0),
			])
		_:
			# Wide humped
			body.polygon = PackedVector2Array([
				Vector2(-w * 0.5,  0.0),
				Vector2(-w * 0.4,  -h * 0.85),
				Vector2(-w * 0.1,  -h),
				Vector2( w * 0.25, -h * 0.95),
				Vector2( w * 0.5,  -h * 0.5),
				Vector2( w * 0.45, 0.0),
			])
	add_child(body)

	if mossy:
		var cap := Polygon2D.new()
		cap.color = color_moss
		match variant:
			1:
				cap.polygon = PackedVector2Array([
					Vector2(-w * 0.25, -h * 0.75),
					Vector2(-w * 0.05, -h * 1.05),
					Vector2( w * 0.10, -h * 0.9),
					Vector2( w * 0.15, -h * 0.55),
				])
			2:
				cap.polygon = PackedVector2Array([
					Vector2(-w * 0.35, -h * 0.6),
					Vector2(-w * 0.15, -h * 0.95),
					Vector2( w * 0.20, -h * 0.95),
					Vector2( w * 0.35, -h * 0.55),
				])
			_:
				cap.polygon = PackedVector2Array([
					Vector2(-w * 0.35, -h * 0.75),
					Vector2(-w * 0.1,  -h),
					Vector2( w * 0.25, -h * 0.95),
					Vector2( w * 0.35, -h * 0.7),
				])
		add_child(cap)

	# Shadow seam where the rock meets the ground
	var seam := ColorRect.new()
	seam.offset_left = -w * 0.5
	seam.offset_right = w * 0.5
	seam.offset_top = -1.0
	seam.offset_bottom = 1.5
	seam.color = color_edge
	add_child(seam)
