extends Area2D
class_name RoomPortal

var partner: RoomPortal = null
var player_spawn: Vector2 = Vector2.ZERO
var room_idx: int = 0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or partner == null:
		return
	var level: Node = get_parent()
	while level != null and not level.has_method("do_room_transition"):
		level = level.get_parent()
	if level != null and not level.is_transitioning():
		level.do_room_transition(body as Player, partner.player_spawn, partner.room_idx)
