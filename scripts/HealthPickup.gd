extends Area2D
class_name HealthPickup

# Heart-style health drop. Bobs in place, picked up on touch, heals the
# player. Spawned by Enemy._die() with a small random chance.

@export var heal_amount: int = 3

var _time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Player layer
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visual()
	_base_y = position.y

func _build_visual() -> void:
	# Soft red glow halo
	var glow := ColorRect.new()
	glow.color = Color(1.0, 0.25, 0.30, 0.25)
	glow.offset_left = -10
	glow.offset_top = -10
	glow.offset_right = 10
	glow.offset_bottom = 10
	add_child(glow)

	# Stylised pixel heart out of three rects + a triangle bottom.
	# Top-left lobe
	var lobe_l := ColorRect.new()
	lobe_l.color = Color(0.92, 0.18, 0.22)
	lobe_l.offset_left = -7
	lobe_l.offset_top = -6
	lobe_l.offset_right = -1
	lobe_l.offset_bottom = 0
	add_child(lobe_l)

	# Top-right lobe
	var lobe_r := ColorRect.new()
	lobe_r.color = Color(0.92, 0.18, 0.22)
	lobe_r.offset_left = 1
	lobe_r.offset_top = -6
	lobe_r.offset_right = 7
	lobe_r.offset_bottom = 0
	add_child(lobe_r)

	# Middle body bridge between lobes
	var body := ColorRect.new()
	body.color = Color(0.92, 0.18, 0.22)
	body.offset_left = -7
	body.offset_top = -2
	body.offset_right = 7
	body.offset_bottom = 3
	add_child(body)

	# Lower triangle point
	var tip := Polygon2D.new()
	tip.color = Color(0.92, 0.18, 0.22)
	tip.polygon = PackedVector2Array([
		Vector2(-7.0, 3.0),
		Vector2( 7.0, 3.0),
		Vector2( 0.0, 9.0),
	])
	add_child(tip)

	# Highlight blob
	var hi := ColorRect.new()
	hi.color = Color(1.0, 0.65, 0.65, 0.85)
	hi.offset_left = -5
	hi.offset_top = -4
	hi.offset_right = -2
	hi.offset_bottom = -1
	add_child(hi)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.5) * 3.0
	modulate.a = 0.85 + sin(_time * 5.0) * 0.15

func _on_body_entered(body: Node) -> void:
	if body is Player:
		var p := body as Player
		# Skip if already at full health — feels bad to waste a drop.
		if p.current_health >= p.max_health:
			return
		p.heal(heal_amount)
		queue_free()
