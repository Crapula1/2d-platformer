extends Area2D

const ENEMY_DAMAGE  := 3
const PLAYER_DAMAGE := 1
const PUSH_FORCE    := 420.0

func _ready() -> void:
	collision_mask = 14  # player(2) + enemy layers(4+8)
	monitoring = true
	_spawn_visuals()
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		_hit(body)
	_fade_out()

func _hit(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	var dmg: int = PLAYER_DAMAGE if body is Player else ENEMY_DAMAGE
	body.take_damage(dmg, global_position)
	if body is CharacterBody2D:
		var cb: CharacterBody2D = body as CharacterBody2D
		var offset: Vector2 = cb.global_position - global_position
		var dir: Vector2 = offset.normalized()
		cb.velocity += dir * PUSH_FORCE

func _spawn_visuals() -> void:
	# White core flash
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.98, 0.88)
	flash.offset_left  = -52; flash.offset_top    = -52
	flash.offset_right =  52; flash.offset_bottom =  52
	add_child(flash)

	# Orange mid ring
	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.52, 0.05)
	ring.offset_left  = -38; ring.offset_top    = -38
	ring.offset_right =  38; ring.offset_bottom =  38
	add_child(ring)

	# Dark smoke outer
	var smoke := ColorRect.new()
	smoke.color = Color(0.18, 0.15, 0.12, 0.7)
	smoke.offset_left  = -24; smoke.offset_top    = -24
	smoke.offset_right =  24; smoke.offset_bottom =  24
	add_child(smoke)

func _fade_out() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.4, 2.4), 0.3)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.32)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
