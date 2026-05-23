extends Area2D
class_name Bullet

var vel: Vector2 = Vector2.ZERO
var damage: int = 1
var max_range: float = 480.0
var lifetime: float = 3.0           # absolute safety net only
var _start_pos: Vector2 = Vector2.ZERO

@onready var sprite: ColorRect = $Sprite

func setup(direction: Vector2, speed: float, dmg: int) -> void:
	vel = direction * speed
	damage = dmg
	rotation = direction.angle()

func net_setup(data: Dictionary) -> void:
	vel = Vector2(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)))
	damage = int(data.get("damage", 1))
	rotation = vel.angle()

func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)
	_start_pos = global_position

func _physics_process(delta: float) -> void:
	if not Net.is_solo() and not is_multiplayer_authority():
		return
	position += vel * delta
	lifetime -= delta
	if lifetime <= 0 or global_position.distance_to(_start_pos) >= max_range:
		queue_free()

func _on_body_entered(_body: Node) -> void:
	if not Net.is_solo() and not is_multiplayer_authority():
		return
	queue_free()

func get_damage() -> int:
	return damage
