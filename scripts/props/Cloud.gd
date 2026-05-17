extends Node2D

# A drifting cloud made from overlapping circular puffs. Place inside a
# ParallaxLayer for cheap parallax, or set drift_speed > 0 for self-drift.

@export var cloud_width: float  = 90.0
@export var cloud_height: float = 26.0
@export var drift_speed: float  = 0.0   # px/sec, 0 = static
@export var wrap_width: float   = 0.0   # if > 0, wraps horizontally after this distance
@export var rand_seed: int      = 0
@export var color: Color        = Color(0.95, 0.97, 1.00, 0.88)
@export var shadow_color: Color = Color(0.55, 0.62, 0.72, 0.45)

var _start_x: float = 0.0

func _ready() -> void:
	_start_x = position.x
	_build()

func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(rand_seed) if rand_seed != 0 else hash(int(cloud_width * 7.0))
	var puffs: int = 3 + (abs(rand_seed) % 3)
	var step: float = cloud_width / float(puffs)

	# Underside shadow band
	var shadow := Polygon2D.new()
	shadow.color = shadow_color
	var spts := PackedVector2Array()
	for k in 14:
		var a: float = float(k) * TAU / 14.0
		spts.append(Vector2(cos(a) * cloud_width * 0.5, abs(sin(a)) * cloud_height * 0.55 + 1.0))
	shadow.polygon = spts
	add_child(shadow)

	# Stacked puffs
	for i in puffs:
		var cx: float = -cloud_width * 0.5 + step * (0.5 + float(i))
		var cy: float = rng.randf_range(-3.0, 3.0)
		var rx: float = step * rng.randf_range(0.55, 0.95)
		var ry: float = cloud_height * rng.randf_range(0.65, 0.95)
		var puff := Polygon2D.new()
		puff.color = color
		var pts := PackedVector2Array()
		var n := 14
		for k in n:
			var a: float = float(k) * TAU / float(n)
			var j: float = 0.88 + 0.18 * sin(float(k) * 1.7 + float(i))
			pts.append(Vector2(cx + cos(a) * rx * j, cy + sin(a) * ry * j))
		puff.polygon = pts
		add_child(puff)

func _process(delta: float) -> void:
	if drift_speed == 0.0:
		return
	position.x += drift_speed * delta
	if wrap_width > 0.0 and position.x > _start_x + wrap_width:
		position.x -= wrap_width
