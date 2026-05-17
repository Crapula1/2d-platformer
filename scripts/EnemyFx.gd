class_name EnemyFx

# Shared visual helpers so enemies don't each reimplement the
# flash-then-restore + delayed-free dance.

static func flash(target: CanvasItem, duration: float, flash_color: Color, restore: Color = Color.WHITE) -> void:
	if not is_instance_valid(target):
		return
	target.modulate = flash_color
	var tree := target.get_tree()
	if tree == null:
		return
	tree.create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(target):
			target.modulate = restore
	)

static func free_after(node: Node, delay: float) -> void:
	if not is_instance_valid(node):
		return
	var tree := node.get_tree()
	if tree == null:
		return
	tree.create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)
