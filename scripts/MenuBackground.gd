extends Node
# Autoloaded menu background — a CanvasLayer beneath the menu UI that cycles
# a GIF frame set. Survives `change_scene_to_file` because it lives on the
# root, so animation + music persist from MainMenu → Character Select →
# Lobby etc. Each menu scene calls `show()` (or `show_scene(name)` for a
# specific frame set) in _ready; Main calls `hide()` when the game starts.
#
# Named scenes are lazy-loaded the first time they're shown and cached so a
# second visit doesn't pay the load cost again.

const DIM_ALPHA := 0.45
const MUSIC_PATH := "res://assets/music/menu_theme.mp3"
const MUSIC_VOLUME_DB := -8.0

# Per-scene config: where the frame PNGs live, how many to load, and how
# long each frame holds. Frame timing matches each source GIF's average
# delay so the cycle plays at its native speed.
const SCENES := {
	"default": {
		"dir":   "res://assets/menu_bg",
		"count": 48,
		"frame_time": 0.05,    # 20 fps from a 5cs/frame GIF
	},
	"character_select": {
		"dir":   "res://assets/menu_bg_charselect",
		"count": 73,
		"frame_time": 0.067,   # 15 fps from a ~6.7cs/frame GIF
	},
}

var _scene_cache: Dictionary = {}   # name -> Array[Texture2D]
var _current_scene: String = ""
var _frames: Array[Texture2D] = []
var _frame_time: float = 0.05
var _index: int = 0
var _accum: float = 0.0
var _layer: CanvasLayer
var _texture_rect: TextureRect
var _dim: ColorRect
var _music: AudioStreamPlayer

func _ready() -> void:
	_layer = CanvasLayer.new()
	# Negative layer renders behind the default-layer 0 menus.
	_layer.layer = -1
	_layer.visible = false
	add_child(_layer)

	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_texture_rect)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_dim)

	_load_scene("default")

	# Looped menu music. Force loop on the stream itself so it survives a
	# reimport that didn't toggle the loop flag in the .import file.
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	if ResourceLoader.exists(MUSIC_PATH):
		var stream: AudioStream = load(MUSIC_PATH)
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_music.stream = stream

func _load_scene(scene_name: String) -> void:
	# Switch the active frame set. Caches loaded textures by scene name so a
	# second visit is free, and resets the play cursor so the new scene
	# starts on frame 0 instead of inheriting the prior scene's index.
	if scene_name == _current_scene and not _frames.is_empty():
		return
	if not SCENES.has(scene_name):
		return
	var cfg: Dictionary = SCENES[scene_name]
	var frames: Array[Texture2D]
	if _scene_cache.has(scene_name):
		frames = _scene_cache[scene_name]
	else:
		frames = []
		var dir: String = String(cfg["dir"])
		var count: int = int(cfg["count"])
		for i in count:
			var tex := load("%s/frame_%02d.png" % [dir, i]) as Texture2D
			if tex != null:
				frames.append(tex)
		_scene_cache[scene_name] = frames
	_current_scene = scene_name
	_frames = frames
	_frame_time = float(cfg.get("frame_time", 0.05))
	_index = 0
	_accum = 0.0
	if not _frames.is_empty():
		_texture_rect.texture = _frames[0]

func show() -> void:
	show_scene("default")

func show_scene(scene_name: String) -> void:
	_load_scene(scene_name)
	_layer.visible = true
	if _music != null and _music.stream != null and not _music.playing:
		_music.play()

func hide() -> void:
	_layer.visible = false
	if _music != null and _music.playing:
		_music.stop()

func _process(delta: float) -> void:
	if not _layer.visible or _frames.is_empty():
		return
	_accum += delta
	if _accum < _frame_time:
		return
	_accum -= _frame_time
	_index = (_index + 1) % _frames.size()
	_texture_rect.texture = _frames[_index]
