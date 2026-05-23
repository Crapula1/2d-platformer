extends RefCounted
class_name MobileUI

# Static helpers for mobile-only UI tweaks. Menus call
# `MobileUI.scale_menu(self)` from _ready; on desktop it's a no-op.

const DEFAULT_MULT: float = 1.6
const MIN_TOUCH_HEIGHT: float = 56.0

static func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available() \
		or OS.has_feature("mobile") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")

# Walks a Control subtree and grows interactive widgets so they're
# thumb-friendly. Buttons/labels get a font-size bump; clickable widgets
# also get a minimum height. Safe to call from any menu's _ready.
static func scale_menu(root: Node, mult: float = DEFAULT_MULT) -> void:
	if not is_touch():
		return
	_walk(root, mult)

static func _walk(node: Node, mult: float) -> void:
	if node is Control:
		var c := node as Control
		var is_interactive := c is Button or c is OptionButton or c is CheckButton \
			or c is HSlider or c is LineEdit
		if is_interactive:
			var h: float = maxf(c.custom_minimum_size.y * mult, MIN_TOUCH_HEIGHT)
			c.custom_minimum_size.y = h
			if c.custom_minimum_size.x > 0.0:
				c.custom_minimum_size.x = ceilf(c.custom_minimum_size.x * mult)
		if is_interactive or c is Label:
			var fs := c.get_theme_font_size("font_size")
			if fs > 0:
				c.add_theme_font_size_override("font_size", int(ceil(fs * mult)))
	for child in node.get_children():
		_walk(child, mult)
