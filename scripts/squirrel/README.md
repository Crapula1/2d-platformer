# Squirrel Sprite Pipeline (Godot 4)

Four scripts, run in order, give you a fully playable humanoid squirrel
with idle / walk / run / crouch / slide / slash / stab.

```
squirrel_spritesheet.gd  -> generates  squirrel_sheet.png    (one-shot)
build_squirrel_frames.gd -> generates  squirrel_frames.tres  (one-shot)
squirrel.gd              -> attached to a CharacterBody2D scene
squirrel_demo.gd         -> optional test playground
```

## 1. Generate the sheet
- Drop `squirrel_spritesheet.gd` anywhere in your project.
- Open it in the Script editor → **File → Run** (Ctrl+Shift+X).
- It writes `res://squirrel_sheet.png`.

## 2. Import the sheet crisp
- Click `squirrel_sheet.png` in the FileSystem dock → **Import tab**.
- Set **Filter = Off** (so pixels stay sharp).
- Click **Reimport**.

## 3. Build the SpriteFrames resource
- Drop `build_squirrel_frames.gd` in your project.
- Open and **Run** it (Ctrl+Shift+X).
- It writes `res://squirrel_frames.tres` with all 7 animations sliced and
  named (`idle`, `walk`, `run`, `crouch`, `slide`, `slash`, `stab`) with
  sensible fps and loop flags already set.

## 4. Build the character scene
Create a new scene with this node tree, save as `Squirrel.tscn`:

```
Squirrel (CharacterBody2D)        [attach squirrel.gd]
├── AnimatedSprite2D              [Sprite Frames = squirrel_frames.tres]
├── CollisionShape2D              [CapsuleShape2D, ~24 wide x 80 tall]
└── HitboxPivot (Node2D)
    └── AttackHitbox (Area2D)
        └── CollisionShape2D      [RectangleShape2D ~40x32, offset to the right]
```

Position the AttackHitbox's CollisionShape so it sits in front of the
squirrel (positive X). `squirrel.gd` flips `HitboxPivot.scale.x` to mirror
it when facing changes.

## 5. Input Map
In Project Settings → Input Map, add:

| Action | Suggested keys |
|---|---|
| `move_left`  | A, Left Arrow |
| `move_right` | D, Right Arrow |
| `jump`       | Space |
| `crouch`     | Ctrl or S (hold) |
| `slide`      | Shift (tap while running) |
| `slash`      | Left Mouse, J |
| `stab`       | Right Mouse, K |

## 6. Test it
- Make a new scene with a Node2D root, attach `squirrel_demo.gd`.
- Run that scene. You should see a floor and the squirrel; controls work
  immediately and the on-screen label shows the current state.

## State machine quick reference

```
IDLE ↔ WALK ↔ RUN
  ↓     ↓     ↓
CROUCH  (hold crouch key from any ground state)
RUN → SLIDE (tap slide while running)
any ground → SLASH / STAB (tap attack key)

SLIDE → IDLE/CROUCH when anim finishes
SLASH/STAB → IDLE when anim finishes
CROUCH → IDLE when crouch released
```

## Tuning

All gameplay numbers are `@export` properties on `squirrel.gd`, editable
from the Inspector without touching code:

- `walk_speed`, `run_speed`, `run_threshold`
- `slide_speed`, `slide_decel`
- `crouch_speed`
- `gravity`, `jump_velocity`
- `attack_lock` (whether attacks freeze movement input)

## Hitbox timing

The attack hitbox automatically enables only on the "active" frames:
- **Slash**: frames 2 and 3 (the swing + follow-through)
- **Stab**: frame 2 (peak thrust)

If you tweak the animations to be longer/shorter, edit the frame numbers
inside `_on_attack_frame()` in `squirrel.gd`.

## Damage hook

When the hitbox touches a body, `squirrel.gd` calls `body.take_damage(dmg,
source_position)` if the method exists. Slash deals 2, stab deals 3.
Implement `take_damage(amount: int, from: Vector2)` on your enemies.
