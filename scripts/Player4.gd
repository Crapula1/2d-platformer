extends Player
class_name Squirrel

# Squirrel avatar controller. Inherits the full Player moveset.
#
# The visual rig is a single AnimatedSprite2D fed by `squirrel_frames.tres`,
# generated one time from the bundled scripts in scripts/squirrel/:
#   1. Run scripts/squirrel/squirrel_spritesheet.gd  -> writes squirrel_sheet.png
#   2. Reimport that PNG with Filter = Off
#   3. Run scripts/squirrel/build_squirrel_frames.gd -> writes squirrel_frames.tres
#
# Player.gd auto-detects an AnimatedSprite2D as $Sprite and drives
# `idle` / `walk` from it. This subclass also picks the richer squirrel
# animations (run / crouch / slide / slash / stab) when those player
# states are active.

func get_character_id() -> String:
	return "squirrel"

func _update_sprite(delta: float) -> void:
	super._update_sprite(delta)
	# Layered on top of the base sprite logic: pick a squirrel-specific
	# animation when a richer state is available. Falls back silently if
	# the SpriteFrames resource doesn't carry that animation yet.
	if _anim_sprite == null:
		return
	var desired: StringName = _pick_animation()
	if desired != &"" and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(desired) \
			and _anim_sprite.animation != desired:
		_anim_sprite.play(desired)

func _pick_animation() -> StringName:
	if is_attacking:
		# Stage 3 (Stab) → squirrel "stab"; everything else → "slash".
		return &"stab" if attack_stage == 3 else &"slash"
	if is_sliding:
		return &"slide"
	if is_crouching:
		return &"crouch"
	if is_on_floor() and absf(velocity.x) > 140.0:
		return &"run"
	return &""  # let the base "idle"/"walk" logic stand
