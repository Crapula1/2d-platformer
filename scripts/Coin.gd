extends Area2D
class_name Coin

@export var value: int = 1

var time: float = 0.0
var start_y: float = 0.0
var collected: bool = false

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	add_to_group("collectible")
	start_y = position.y

func _process(delta: float) -> void:
	if collected:
		return
	time += delta
	# Bobbing animation
	position.y = start_y + sin(time * 3.0) * 3.0
	# Rotation effect via scale
	sprite.scale.x = abs(sin(time * 4.0)) * 0.8 + 0.2

func collect() -> int:
	if collected:
		return 0
	collected = true
	# Pickup animation
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2, 2), 0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "position:y", position.y - 20, 0.2)
	tween.chain().tween_callback(queue_free)
	return value
