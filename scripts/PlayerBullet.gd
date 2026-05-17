extends Area2D
class_name PlayerBullet

var vel: Vector2 = Vector2.ZERO
var damage: int = 1
var lifetime: float = 1.4

func setup(direction: Vector2, speed: float, dmg: int) -> void:
	vel = direction * speed
	damage = dmg
	rotation = direction.angle()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 5  # layer 1 (World) + layer 3 (Enemy)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += vel * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
