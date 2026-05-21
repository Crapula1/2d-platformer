extends Player
class_name GreaterDemon

# Greater Demon avatar controller. Heavy melee — cape + twin horns + claws
# are part of PlayerGreaterDemon.tscn. Reduced max_jumps and slower
# jump_mult come from the CHARACTER_STATS dict applied by the base
# Player._apply_character_stats; no extra rig is built here.

func get_character_id() -> String:
	return "greater_demon"
