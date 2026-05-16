extends Area2D
class_name GrenadePickup

const GRENADE_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2),
	Color(1.0, 0.42, 0.08),
	Color(0.35, 0.88, 1.0),
]

var grenade_type: int = 0
var _time: float = 0.0
var _base_y: float = 0.0

func setup(type: int) -> void:
	grenade_type = clamp(type, 0, 2)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visual()
	_base_y = position.y

func _build_visual() -> void:
	var c := GRENADE_COLORS[grenade_type]

	var glow := ColorRect.new()
	glow.color = Color(c.r, c.g, c.b, 0.25)
	glow.offset_left = -10; glow.offset_top = -12
	glow.offset_right = 10; glow.offset_bottom = 10
	add_child(glow)

	var body := ColorRect.new()
	body.color = c
	body.offset_left = -6; body.offset_top = -8
	body.offset_right = 6; body.offset_bottom = 7
	add_child(body)

	var band := ColorRect.new()
	band.color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55)
	band.offset_left = -6; band.offset_top = -1
	band.offset_right = 6; band.offset_bottom = 2
	add_child(band)

	var pin := ColorRect.new()
	pin.color = Color(0.75, 0.75, 0.75)
	pin.offset_left = -2; pin.offset_top = -12
	pin.offset_right = 2; pin.offset_bottom = -8
	add_child(pin)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 3.5) * 4.0
	modulate.a = 0.8 + sin(_time * 5.0) * 0.2

func _on_body_entered(body: Node) -> void:
	if body is Player:
		if body.add_grenade(grenade_type):
			queue_free()
