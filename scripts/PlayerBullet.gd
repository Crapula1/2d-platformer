extends Area2D
class_name PlayerBullet

var vel: Vector2 = Vector2.ZERO
var damage: int = 1
var max_range: float = 640.0
var lifetime: float = 2.5           # absolute safety net only
var _start_pos: Vector2 = Vector2.ZERO
var _start_captured: bool = false

func setup(direction: Vector2, speed: float, dmg: int) -> void:
	vel = direction * speed
	damage = dmg
	rotation = direction.angle()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 5  # layer 1 (World) + layer 3 (Enemy)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not _start_captured:
		_start_pos = global_position
		_start_captured = true
	position += vel * delta
	lifetime -= delta
	if lifetime <= 0 or global_position.distance_to(_start_pos) >= max_range:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("request_damage") and multiplayer.has_multiplayer_peer():
		body.request_damage.rpc_id(body.get_multiplayer_authority(), damage, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	queue_free()
