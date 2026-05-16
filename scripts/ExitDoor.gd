extends Area2D

signal exited()

var _player_nearby: bool = false
var _time: float = 0.0
var _prompt: Label = null

@onready var inner_glow: ColorRect = $InnerGlow

func _ready() -> void:
	add_to_group("exit")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.text = "[ E ]  NEXT FLOOR"
	_prompt.add_theme_font_size_override("font_size", 11)
	_prompt.add_theme_color_override("font_color", Color(0.65, 1.0, 0.72))
	_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(90.0, 20.0)
	_prompt.position = Vector2(-45.0, -62.0)
	_prompt.visible = false
	add_child(_prompt)

func _process(delta: float) -> void:
	_time += delta
	inner_glow.modulate.a = 0.35 + sin(_time * 3.0) * 0.22

	if _prompt != null:
		_prompt.position.y = -62.0 + sin(_time * 4.5) * 3.0
		_prompt.modulate.a = 0.7 + sin(_time * 6.0) * 0.3

	if _player_nearby and Input.is_action_just_pressed("interact"):
		emit_signal("exited")

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_nearby = true
		if _prompt != null:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_nearby = false
		if _prompt != null:
			_prompt.visible = false
