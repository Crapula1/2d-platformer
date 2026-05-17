extends Area2D
class_name Goal

signal reached()

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if triggered:
		return
	if body is Player:
		triggered = true
		reached.emit()
