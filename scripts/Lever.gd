extends Node2D
class_name Lever

signal toggled(is_on: bool)

@export var is_on: bool = false
@export var connected_doors: Array[NodePath] = []

var player_nearby: bool = false

@onready var handle: ColorRect = $Handle
@onready var light: ColorRect = $Light
@onready var prompt: Node2D = $Prompt

const HANDLE_OFF_Y: float = 4.0
const HANDLE_ON_Y: float = -4.0

func _ready() -> void:
	$InteractZone.body_entered.connect(_on_body_entered)
	$InteractZone.body_exited.connect(_on_body_exited)
	_apply_state(false)

func _process(_delta: float) -> void:
	if player_nearby and Input.is_action_just_pressed("interact"):
		_toggle()

func _toggle() -> void:
	is_on = !is_on
	_apply_state(true)
	toggled.emit(is_on)
	for path in connected_doors:
		var door = get_node_or_null(path)
		if door == null:
			continue
		if is_on and door.has_method("open"):
			door.open()
		elif not is_on and door.has_method("close"):
			door.close()

func _apply_state(animate: bool) -> void:
	var target_y := HANDLE_ON_Y if is_on else HANDLE_OFF_Y
	light.color = Color(0.2, 0.9, 0.3) if is_on else Color(0.9, 0.15, 0.1)

	if animate:
		var tween := create_tween()
		tween.tween_property(handle, "position:y", target_y, 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		handle.position.y = target_y

func _on_body_entered(body: Node) -> void:
	if body is Player:
		player_nearby = true
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		player_nearby = false
		prompt.visible = false
