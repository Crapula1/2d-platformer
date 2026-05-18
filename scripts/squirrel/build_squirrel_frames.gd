@tool
extends EditorScript
# ============================================================================
#  BuildSquirrelFrames.gd  -  Godot 4.x
# ----------------------------------------------------------------------------
#  ONE-SHOT BUILDER: slices squirrel_sheet.png into a SpriteFrames resource
#  with every animation pre-configured (fps, loop, frame range).
#
#  USAGE
#  -----
#  1. Make sure "res://squirrel_sheet.png" exists (run squirrel_spritesheet.gd
#     first if you haven't).
#  2. In its Import dock, set Filter = OFF (preserves crisp pixels), reimport.
#  3. Open this script in the Script editor -> File -> Run (Ctrl+Shift+X).
#  4. It writes "res://squirrel_frames.tres". Drag that onto any
#     AnimatedSprite2D's `Sprite Frames` property and you're done.
# ============================================================================

const SHEET_PATH  : String = "res://squirrel_sheet.png"
const OUT_PATH    : String = "res://squirrel_frames.tres"
const FRAME_SIZE  : int = 96
const COLS        : int = 6

# Animation table: name -> {row, frame_count, fps, loop}
const ANIMS := {
	"idle":     {"row": 0, "count": 4, "fps":  6.0, "loop": true},
	"walk":     {"row": 1, "count": 6, "fps": 10.0, "loop": true},
	"run":      {"row": 2, "count": 6, "fps": 14.0, "loop": true},
	"crouch":   {"row": 3, "count": 3, "fps": 12.0, "loop": false},  # holds last frame
	"slide":    {"row": 4, "count": 4, "fps": 12.0, "loop": false},
	"slash":    {"row": 5, "count": 5, "fps": 16.0, "loop": false},
	"stab":     {"row": 6, "count": 5, "fps": 16.0, "loop": false},
}

func _run() -> void:
	var sheet : Texture2D = load(SHEET_PATH)
	if sheet == null:
		push_error("Could not load %s. Run squirrel_spritesheet.gd first." % SHEET_PATH)
		return

	var frames := SpriteFrames.new()
	# SpriteFrames is created with a default "default" animation; drop it.
	frames.remove_animation("default")

	for name in ANIMS.keys():
		var def : Dictionary = ANIMS[name]
		frames.add_animation(name)
		frames.set_animation_speed(name, float(def.fps))
		frames.set_animation_loop(name, bool(def.loop))

		for i in int(def.count):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(
				i * FRAME_SIZE,
				int(def.row) * FRAME_SIZE,
				FRAME_SIZE, FRAME_SIZE
			)
			frames.add_frame(name, atlas)

	var err := ResourceSaver.save(frames, OUT_PATH)
	if err == OK:
		print("Saved SpriteFrames -> ", OUT_PATH)
		print("Animations: ", ANIMS.keys())
	else:
		push_error("Failed to save SpriteFrames, error %d" % err)
