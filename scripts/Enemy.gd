extends CharacterBody2D
class_name Enemy

@export var speed: float = 60.0
@export var max_health: int = 2
@export var damage: int = 1
@export var patrol_distance: float = 100.0
@export_range(0.0, 1.0) var health_drop_chance: float = 0.2

const HEALTH_PICKUP_SCENE := preload("res://scenes/HealthPickup.tscn")

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var current_health: int
var direction: int = 1
var start_position: Vector2
var is_dead: bool = false
var stunned_timer: float = 0.0
var _base_color: Color

@onready var sprite: ColorRect = $Sprite
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck

func _ready() -> void:
	current_health = max_health
	start_position = global_position
	_base_color = sprite.color
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	if stunned_timer > 0:
		stunned_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
	else:
		# Patrol logic
		velocity.x = direction * speed

		# Turn around at wall or edge
		wall_check.target_position = Vector2(20 * direction, 0)
		floor_check.position.x = 18 * direction

		# Check if we need to turn around
		var distance_from_start: float = absf(global_position.x - start_position.x)
		if distance_from_start > patrol_distance:
			direction *= -1
		elif wall_check.is_colliding():
			direction *= -1
		elif is_on_floor() and not floor_check.is_colliding():
			direction *= -1

		# Update sprite facing
		sprite.position.x = -2 * direction

	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()

func get_damage() -> int:
	return damage

func take_damage(amount: int, source_pos: Vector2) -> void:
	if is_dead:
		return
	current_health -= amount
	stunned_timer = 0.3

	# Knockback
	var knockback_dir: float = sign(global_position.x - source_pos.x)
	velocity.x = knockback_dir * 200
	velocity.y = -150

	net_flash.rpc()

	if current_health <= 0:
		_net_kill.rpc()

@rpc("any_peer", "call_local", "reliable")
func request_damage(amount: int, source_pos: Vector2) -> void:
	if is_multiplayer_authority():
		take_damage(amount, source_pos)

@rpc("authority", "call_local", "reliable")
func _net_kill() -> void:
	if not is_dead:
		_die()

@rpc("authority", "call_local", "reliable")
func net_flash() -> void:
	sprite.color = Color.WHITE
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			sprite.color = _base_color
	)

func _die() -> void:
	is_dead = true
	sprite.color = Color(0.3, 0.3, 0.3)
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox/CollisionShape2D.set_deferred("disabled", true)
	# Fall off screen
	collision_layer = 0
	collision_mask = 1
	_maybe_drop_health()
	EnemyFx.free_after(self, 1.5)

func _maybe_drop_health() -> void:
	# Host is the only one allowed to spawn loot in MP so we don't get
	# duplicates. Solo (no peer) always passes the check.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if randf() >= health_drop_chance:
		return
	var pickup := HEALTH_PICKUP_SCENE.instantiate() as Node2D
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(pickup)
	pickup.global_position = global_position
