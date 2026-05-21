extends Player
class_name Demon

# Demon avatar controller. Owns the demon's identity; visuals are baked
# into PlayerDemon.tscn (polygon body / horns / wings). No weapon rig is
# built — the demon is a melee-only brawler, attacks resolve through the
# inherited attack_area hitbox without a visible axe.

func get_character_id() -> String:
	return "demon"
