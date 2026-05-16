extends Area2D
class_name PowerUp

enum Type { HEALTH, SPEED, DAMAGE, SHIELD }

@export var type: Type = Type.HEALTH
@export var magnitude: float = 2.0
@export var duration: float = 6.0

var time: float = 0.0
var start_y: float = 0.0
var collected: bool = false

@onready var sprite: ColorRect = $Sprite
@onready var glow: ColorRect = $Glow

const COLORS: Dictionary = {
	Type.HEALTH: Color(0.15, 0.85, 0.30),
	Type.SPEED:  Color(0.25, 0.55, 1.00),
	Type.DAMAGE: Color(1.00, 0.45, 0.10),
	Type.SHIELD: Color(0.65, 0.20, 1.00),
}
const GLOW_COLORS: Dictionary = {
	Type.HEALTH: Color(0.15, 0.85, 0.30, 0.35),
	Type.SPEED:  Color(0.25, 0.55, 1.00, 0.35),
	Type.DAMAGE: Color(1.00, 0.45, 0.10, 0.35),
	Type.SHIELD: Color(0.65, 0.20, 1.00, 0.35),
}

func _ready() -> void:
	add_to_group("collectible")
	start_y = position.y
	sprite.color = COLORS[type]
	glow.color = GLOW_COLORS[type]

func _process(delta: float) -> void:
	if collected:
		return
	time += delta
	position.y = start_y + sin(time * 3.5) * 4.0
	glow.scale = Vector2.ONE * (1.0 + sin(time * 5.0) * 0.15)

func apply_effect(player: Player) -> void:
	if collected:
		return
	collected = true
	match type:
		Type.HEALTH:
			player.heal(int(magnitude))
		Type.SPEED:
			player.apply_powerup("speed", duration, magnitude)
		Type.DAMAGE:
			player.apply_powerup("damage", duration, magnitude)
		Type.SHIELD:
			player.apply_powerup("shield", duration, magnitude)
	_play_collect_fx()

func _play_collect_fx() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.2, 2.2), 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)
