extends Node2D

# A vertical jagged cliff face — purely decorative (background). Origin (0,0)
# is the top-left of the cliff's bounding box; it extends right and down.

@export var cliff_width: float  = 140.0
@export var cliff_height: float = 220.0
@export var jagged_count: int   = 6      # bumps along the visible (right) edge
@export var face_color: Color   = Color(0.30, 0.26, 0.22)
@export var shade_color: Color  = Color(0.18, 0.15, 0.12)
@export var mossy: bool         = true
@export var moss_color: Color   = Color(0.26, 0.58, 0.22)

func _ready() -> void:
	_build()

func _build() -> void:
	# Main face — irregular polygon with the right edge having `jagged_count`
	# bumps.
	var face := Polygon2D.new()
	face.color = face_color
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, 0.0))
	pts.append(Vector2(cliff_width, 0.0))
	var n: int = maxi(jagged_count, 2)
	for i in range(1, n + 1):
		var t: float = float(i) / float(n + 1)
		var y: float = t * cliff_height
		var bump: float = sin(t * PI * 3.0 + float(jagged_count) * 0.7) * cliff_width * 0.10
		pts.append(Vector2(cliff_width + bump, y))
	pts.append(Vector2(cliff_width * 0.55, cliff_height))
	pts.append(Vector2(0.0, cliff_height))
	face.polygon = pts
	add_child(face)

	# Inner shading band on the left side for depth
	var shade := Polygon2D.new()
	shade.color = shade_color
	shade.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(cliff_width * 0.22, 0.0),
		Vector2(cliff_width * 0.32, cliff_height * 0.5),
		Vector2(cliff_width * 0.22, cliff_height),
		Vector2(0.0, cliff_height),
	])
	add_child(shade)

	# Mossy cap along the top edge
	if mossy:
		var cap := Polygon2D.new()
		cap.color = moss_color
		var cap_pts := PackedVector2Array()
		cap_pts.append(Vector2(0.0, 0.0))
		var caps := 5
		for i in range(1, caps + 1):
			var t: float = float(i) / float(caps + 1)
			var x: float = t * cliff_width
			var jut: float = -3.0 + sin(t * PI * 2.0) * 4.0
			cap_pts.append(Vector2(x, jut))
		cap_pts.append(Vector2(cliff_width, 0.0))
		cap_pts.append(Vector2(cliff_width, 6.0))
		cap_pts.append(Vector2(0.0, 6.0))
		cap.polygon = cap_pts
		add_child(cap)

		# Trailing moss bits dripping down the face
		for i in 3:
			var dx: float = cliff_width * (0.25 + 0.25 * float(i))
			var drip := Polygon2D.new()
			drip.color = moss_color
			drip.polygon = PackedVector2Array([
				Vector2(dx - 2.0,  4.0),
				Vector2(dx + 2.0,  4.0),
				Vector2(dx + 1.0,  18.0 + float(i) * 4.0),
				Vector2(dx - 1.0,  18.0 + float(i) * 4.0),
			])
			add_child(drip)
