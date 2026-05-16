extends AnimatableBody2D
class_name Door

@export var open_distance: float = 64.0
@export var open_time: float = 0.35
@export var open_color: Color = Color(0.18, 0.55, 0.28)
@export var closed_color: Color = Color(0.30, 0.32, 0.38)

var is_open: bool = false
var closed_position: Vector2
var _tween: Tween = null

@onready var sprite: ColorRect = $Sprite

func _ready() -> void:
	closed_position = position
	sprite.color = closed_color

func open() -> void:
	if is_open:
		return
	is_open = true
	_run_tween(closed_position + Vector2.UP * open_distance, open_color)

func close() -> void:
	if not is_open:
		return
	is_open = false
	_run_tween(closed_position, closed_color)

func _run_tween(target_pos: Vector2, target_color: Color) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", target_pos, open_time)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(sprite, "color", target_color, open_time * 0.6)
