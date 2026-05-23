extends Node
# Autoloaded menu background — a CanvasLayer beneath the menu UI that cycles
# the title-screen GIF frames. Survives `change_scene_to_file` because it
# lives on the root, so the same animation persists from MainMenu → Character
# Select → Lobby etc. Each menu scene calls `show()` in _ready; Main calls
# `hide()` when the game proper starts.

const FRAME_COUNT := 48
const FRAME_TIME := 0.05   # 20 fps, matches the source GIF's 5cs frame delay
const DIM_ALPHA := 0.45

var _frames: Array[Texture2D] = []
var _index: int = 0
var _accum: float = 0.0
var _layer: CanvasLayer
var _texture_rect: TextureRect
var _dim: ColorRect

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

	for i in FRAME_COUNT:
		var tex := load("res://assets/menu_bg/frame_%02d.png" % i) as Texture2D
		if tex != null:
			_frames.append(tex)
	if not _frames.is_empty():
		_texture_rect.texture = _frames[0]

func show() -> void:
	_layer.visible = true

func hide() -> void:
	_layer.visible = false

func _process(delta: float) -> void:
	if not _layer.visible or _frames.is_empty():
		return
	_accum += delta
	if _accum < FRAME_TIME:
		return
	_accum -= FRAME_TIME
	_index = (_index + 1) % _frames.size()
	_texture_rect.texture = _frames[_index]
