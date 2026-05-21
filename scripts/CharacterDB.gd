extends Node

# Central roster. Index in CHARACTERS is the canonical character id used over
# the wire and in RunState. Keep additions append-only so saved ids stay stable.
#
# All characters currently share the marine sprite — stat modifiers and locks
# are the only thing differentiating them until per-character art lands.

const MARINE_SPRITE := preload("res://assets/sprites/space_marine.png")

const CHARACTERS := [
	{
		"id": "marine",
		"name": "Marine",
		"blurb": "Balanced trooper. The baseline.",
		"sprite": MARINE_SPRITE,
		"tint": Color(1.0, 1.0, 1.0),
		"locked": false,
		"unlock_hint": "",
		"speed_mult": 1.0,
		"hp_bonus": 0,
		"attack_bonus": 0,
	},
	{
		"id": "scout",
		"name": "Scout",
		"blurb": "Lightly armored, very fast.",
		"sprite": MARINE_SPRITE,
		"tint": Color(0.55, 0.85, 1.0),
		"locked": false,
		"unlock_hint": "",
		"speed_mult": 1.25,
		"hp_bonus": -2,
		"attack_bonus": 0,
	},
	{
		"id": "heavy",
		"name": "Heavy",
		"blurb": "Slow tank, soaks damage.",
		"sprite": MARINE_SPRITE,
		"tint": Color(1.0, 0.65, 0.45),
		"locked": false,
		"unlock_hint": "",
		"speed_mult": 0.8,
		"hp_bonus": 4,
		"attack_bonus": 1,
	},
	{
		"id": "demolitionist",
		"name": "Demolitionist",
		"blurb": "Heavy hitter, slower legs.",
		"sprite": MARINE_SPRITE,
		"tint": Color(1.0, 0.45, 0.35),
		"locked": true,
		"unlock_hint": "Reach depth 5 in any run",
		"speed_mult": 0.9,
		"hp_bonus": 1,
		"attack_bonus": 3,
	},
	{
		"id": "ghost",
		"name": "Ghost",
		"blurb": "Glass-cannon recon. High risk.",
		"sprite": MARINE_SPRITE,
		"tint": Color(0.7, 0.7, 0.85),
		"locked": true,
		"unlock_hint": "Clear a level without taking damage",
		"speed_mult": 1.4,
		"hp_bonus": -3,
		"attack_bonus": 2,
	},
	{
		"id": "warden",
		"name": "Warden",
		"blurb": "Disciplined veteran. Locked.",
		"sprite": MARINE_SPRITE,
		"tint": Color(0.85, 0.95, 0.65),
		"locked": true,
		"unlock_hint": "Score 200 coins in a single run",
		"speed_mult": 1.05,
		"hp_bonus": 2,
		"attack_bonus": 1,
	},
]

func count() -> int:
	return CHARACTERS.size()

func get_character(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return CHARACTERS[0]

func index_of(id: String) -> int:
	for i in CHARACTERS.size():
		if CHARACTERS[i]["id"] == id:
			return i
	return 0

func is_unlocked(id: String) -> bool:
	return not get_character(id).get("locked", false)

func unlocked_ids() -> Array:
	var out: Array = []
	for c in CHARACTERS:
		if not c["locked"]:
			out.append(c["id"])
	return out

func random_unlocked_id() -> String:
	var ids := unlocked_ids()
	return ids[randi() % ids.size()]
