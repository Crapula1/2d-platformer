extends Player
class_name GreaterDemon

# Greater Demon avatar controller. Heavy melee — the visual rig is a single
# AnimatedSprite2D in PlayerGreaterDemon.tscn carrying the full greater_demon
# frameset (idle / walk / run / stab / lunge_impact / slash / hurt / die).
#
# The base Player only drives idle/walk/run/slide/crouch/slash/stab. This
# subclass layers on the greater-demon-specific clips: a brief `hurt` flash
# on damage, a `lunge_impact` tail at the end of a Stab, and a `die`
# animation on death (instead of freezing the current frame).

const HURT_FLASH_TIME: float = 0.30
const LUNGE_IMPACT_TAIL: float = 0.07

func get_character_id() -> String:
	return "greater_demon"

func _die() -> void:
	# Base class stops the AnimatedSprite on death, which freezes whatever
	# frame happened to be showing. Play the death clip instead so the
	# greater demon visibly collapses.
	is_dead = true
	if _anim_sprite != null and _anim_sprite.sprite_frames != null \
			and _anim_sprite.sprite_frames.has_animation(&"die"):
		_anim_sprite.play(&"die")
	elif _anim_sprite != null:
		_anim_sprite.stop()
	sprite.modulate = Color(0.5, 0.5, 0.5)
	_apply_shake(12.0)
	play_voice(&"die")
	died.emit()

func _update_sprite(delta: float) -> void:
	super._update_sprite(delta)
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	var frames := _anim_sprite.sprite_frames
	var desired := _pick_greater_demon_anim(frames)
	if desired != &"" and _anim_sprite.animation != desired:
		_anim_sprite.play(desired)

func _pick_greater_demon_anim(frames: SpriteFrames) -> StringName:
	# Dying state takes priority — also covers non-local peers that learn
	# about the death through replicated `is_dead` rather than _die().
	if is_dead:
		if frames.has_animation(&"die"):
			return &"die"
		return &""
	# Tail end of a Stab swing: switch to the impact pose for the last
	# sliver so the lunge reads as connecting rather than just retracting.
	if is_attacking and attack_stage == 3 and attack_timer <= LUNGE_IMPACT_TAIL \
			and frames.has_animation(&"lunge_impact"):
		return &"lunge_impact"
	# Recently hit: invincibility_timer is reset to invincibility_time on
	# every damage event, so the first slice of the i-frame window is the
	# "just got hit" window for the flinch animation.
	if not is_attacking and is_invincible \
			and invincibility_timer > invincibility_time - HURT_FLASH_TIME \
			and frames.has_animation(&"hurt"):
		return &"hurt"
	return &""
