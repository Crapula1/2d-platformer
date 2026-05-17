extends Area2D
class_name Bullet

var vel: Vector2 = Vector2.ZERO
var damage: int = 1
var lifetime: float = 2.0

@onready var sprite: ColorRect = $Sprite

func setup(direction: Vector2, speed: float, dmg: int) -> void:
	vel = direction * speed
	damage = dmg
	rotation = direction.angle()

func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += vel * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(_body: Node) -> void:
	queue_free()

func get_damage() -> int:
	return damage
