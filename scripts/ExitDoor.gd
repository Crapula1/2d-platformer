extends Area2D

signal exited()

var _time: float = 0.0

@onready var inner_glow: ColorRect = $InnerGlow

func _ready() -> void:
	add_to_group("exit")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	var alpha := 0.35 + sin(_time * 3.0) * 0.2
	inner_glow.modulate.a = alpha

func _on_body_entered(body: Node) -> void:
	if body is Player:
		emit_signal("exited")
