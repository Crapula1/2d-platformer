extends Area2D
class_name HomingMissile

# A slow-turning rocket. Always points at its target but its turn rate is
# capped, so the player can dodge by changing direction sharply (Metroid /
# Contra style — readable, fair, deadly if ignored).

@export var max_speed: float = 230.0
@export var acceleration: float = 280.0
@export var turn_rate: float = 2.4   # rad/s — lower = easier to dodge
@export var lifetime: float = 4.0
@export var damage: int = 1
@export var arm_time: float = 0.18   # don't track for the first frames

const EXPLOSIVE_EFFECT_SCENE = preload("res://scenes/ExplosiveEffect.tscn")

var velocity: Vector2 = Vector2.ZERO
var target: Node2D = null
var _age: float = 0.0

@onready var flame: Polygon2D = $Flame

func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)

func setup(launch_velocity: Vector2, tgt: Node2D, dmg: int = 1) -> void:
	velocity = launch_velocity
	target = tgt
	damage = dmg
	rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	_age += delta
	lifetime -= delta
	if lifetime <= 0.0:
		_explode()
		return

	if _age > arm_time and target != null and is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length_squared() > 1.0:
			var desired_angle: float = to_target.angle()
			var current_angle: float = velocity.angle() if velocity.length_squared() > 1.0 else rotation
			var diff: float = wrapf(desired_angle - current_angle, -PI, PI)
			var max_change: float = turn_rate * delta
			var new_angle: float = current_angle + clampf(diff, -max_change, max_change)
			var speed: float = minf(velocity.length() + acceleration * delta, max_speed)
			velocity = Vector2(cos(new_angle), sin(new_angle)) * speed

	rotation = velocity.angle()
	position += velocity * delta

	# Thrust flame flicker
	if flame:
		flame.scale = Vector2(0.85 + 0.35 * sin(Time.get_ticks_msec() * 0.05), 1.0)

func _on_body_entered(_b: Node) -> void:
	_explode()

func _explode() -> void:
	var fx := EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	get_parent().add_child(fx)
	fx.global_position = global_position
	queue_free()

func get_damage() -> int:
	return damage
