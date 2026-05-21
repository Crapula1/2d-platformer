# Character Portraits

Loaded by `Main._build_character_card` in `scripts/Main.gd` for the
top-left HUD chip. Path scheme:

    res://assets/portraits/<character_id>.png

Expected files (replace the auto-generated placeholders any time):

- `marine.png`
- `demon.png`
- `greater_demon.png`
- `squirrel.png`

Recommended size: 36x36 (the `TextureRect` is sized that way) or any
square at 2x/3x for sharper rendering — Godot scales to fit.

Missing files are tolerated: the chip simply hides the portrait slot
and shows only the tint stripe + name label.
