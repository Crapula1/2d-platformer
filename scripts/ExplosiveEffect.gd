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
	var dmg: int = PLAYER_DAMAGE if body is Player else ENEMY_DAMAGE
	if body.has_method("request_damage"):
		body.request_damage.rpc_id(body.get_multiplayer_authority(), dmg, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(dmg, global_position)
	else:
		return
	if body is CharacterBody2D:
		var cb: CharacterBody2D = body as CharacterBody2D
		var offset: Vector2 = cb.global_position - global_position
		var dir: Vector2 = offset.normalized()
		cb.velocity += dir * PUSH_FORCE

func _spawn_visuals() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.98, 0.88)
	flash.offset_left  = -40; flash.offset_top    = -40
	flash.offset_right =  40; flash.offset_bottom =  40
	add_child(flash)

	var ring := ColorRect.new()
	ring.color = Color(1.0, 0.52, 0.05)
	ring.offset_left  = -28; ring.offset_top    = -28
	ring.offset_right =  28; ring.offset_bottom =  28
	add_child(ring)

	var smoke := ColorRect.new()
	smoke.color = Color(0.18, 0.15, 0.12, 0.7)
	smoke.offset_left  = -17; smoke.offset_top    = -17
	smoke.offset_right =  17; smoke.offset_bottom =  17
	add_child(smoke)

func _fade_out() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
