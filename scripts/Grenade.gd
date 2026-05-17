extends RigidBody2D
class_name Grenade

enum Type { EXPLOSIVE, INCENDIARY, ELECTRIC }

const COLORS := {
	Type.EXPLOSIVE: {
		"body": Color(0.30, 0.30, 0.30),
		"band": Color(0.42, 0.40, 0.05),
		"indicator": Color(1.0, 0.85, 0.2),
		"top": Color(0.22, 0.22, 0.22),
	},
	Type.INCENDIARY: {
		"body": Color(0.62, 0.20, 0.04),
		"band": Color(0.45, 0.08, 0.0),
		"indicator": Color(1.0, 0.42, 0.05),
		"top": Color(0.45, 0.14, 0.03),
	},
	Type.ELECTRIC: {
		"body": Color(0.10, 0.25, 0.52),
		"band": Color(0.08, 0.18, 0.40),
		"indicator": Color(0.35, 0.88, 1.0),
		"top": Color(0.08, 0.18, 0.40),
	},
}

const EXPLOSION_SCENE  = preload("res://scenes/ExplosiveEffect.tscn")
const FIRE_ZONE_SCENE  = preload("res://scenes/FireZone.tscn")
const ELECTRIC_SCENE   = preload("res://scenes/ElectricZone.tscn")

var grenade_type: Type = Type.EXPLOSIVE
var fuse_time: float = 1.1
var _fuse: float = 0.0
var _detonated: bool = false

@onready var body_rect: ColorRect = $Sprite/Body
@onready var top_rect:  ColorRect = $Sprite/Top
@onready var band_rect: ColorRect = $Sprite/Band
@onready var indicator: ColorRect = $Sprite/Indicator

func setup(type: Type, throw_vel: Vector2) -> void:
	grenade_type = type
	linear_velocity = throw_vel

func _ready() -> void:
	_fuse = fuse_time
	_apply_colors()

func _physics_process(delta: float) -> void:
	_fuse -= delta
	# Spin as it flies
	angular_velocity = clampf(linear_velocity.x * 0.08, -12.0, 12.0)
	if _fuse <= 0.0:
		_detonate()

func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	set_physics_process(false)

	var effect_scene: PackedScene = EXPLOSION_SCENE
	match grenade_type:
		Type.INCENDIARY: effect_scene = FIRE_ZONE_SCENE
		Type.ELECTRIC:   effect_scene = ELECTRIC_SCENE

	var effect: Node2D = effect_scene.instantiate() as Node2D
	get_parent().add_child(effect)
	effect.global_position = global_position
	queue_free()

func _apply_colors() -> void:
	var c: Dictionary = COLORS[grenade_type]
	body_rect.color = c["body"]
	top_rect.color  = c["top"]
	band_rect.color = c["band"]
	indicator.color = c["indicator"]
