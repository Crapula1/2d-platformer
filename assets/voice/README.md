# Voice Lines

Loaded by `Player.play_voice(event)` in `scripts/Player.gd`. Path scheme:

    res://assets/voice/<character_id>/<event>.ogg

`character_id` matches the keys in `RunState.CHARACTER_STATS`:
`marine`, `demon`, `greater_demon`, `squirrel`.

## Events currently triggered

| Event   | Fires when                          |
|---------|-------------------------------------|
| `jump`  | First jump and any mid-air jump     |
| `hurt`  | Player takes damage                 |
| `die`   | Player runs out of HP               |

## Adding a new event

1. Drop the `.ogg` at the path above.
2. Add a `play_voice(&"event_name")` call in `Player.gd` where you want it.

Missing files are cached as null on first lookup, so absent voice lines
cost a single `ResourceLoader.exists` check per character/event and then
go silent — no per-frame overhead.
