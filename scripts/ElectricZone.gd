extends Area2D

const ENEMY_DAMAGE  := 2
const PLAYER_DAMAGE := 1
const STUN_DURATION := 1.8

func _ready() -> void:
	collision_mask = 14
	monitoring = true
	_build_visuals()
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		_hit(body)
	_fade_out()

func _hit(body: Node) -> void:
	var dmg: int = PLAYER_DAMAGE if body is Player else ENEMY_DAMAGE
	if body.has_method("request_damage"):
		body.request_damage.rpc_id(body.get_multiplayer_authority(), dmg, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(dmg, global_position)
	else:
		return
	if not (body is Player) and body.has_method("stun"):
		body.stun(STUN_DURATION)

func _build_visuals() -> void:
	# Core white-blue flash
	var core := ColorRect.new()
	core.color = Color(0.7, 0.92, 1.0, 0.9)
	core.offset_left  = -44; core.offset_top    = -44
	core.offset_right =  44; core.offset_bottom =  44
	add_child(core)

	# Lightning bolts radiating outward
	var bolt_angles := [0.0, 0.52, 1.05, 1.57, 2.09, 2.62, 3.14, 3.67, 4.19, 4.71, 5.24, 5.76]
	for angle in bolt_angles:
		var bolt := ColorRect.new()
		var length := randf_range(28.0, 46.0)
		bolt.color = Color(0.55, 0.95, 1.0)
		bolt.offset_left  = -1.5
		bolt.offset_top   = -length
		bolt.offset_right =  1.5
		bolt.offset_bottom = 0.0
		bolt.pivot_offset = Vector2(1.5, length)
		bolt.rotation = angle + randf_range(-0.15, 0.15)
		add_child(bolt)

func _fade_out() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.25)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
