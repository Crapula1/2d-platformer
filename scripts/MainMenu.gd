extends Control

const LOBBY_SCENE: String = "res://scenes/Lobby.tscn"

var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var status_label: Label

func _ready() -> void:
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected.connect(_on_disconnected)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.13)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.custom_minimum_size = Vector2(360, 0)
	vb.position = Vector2(-180, -180)
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	var title := Label.new()
	title.text = "2D PLATFORMER"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb.add_child(title)

	vb.add_child(_labeled("Name"))
	name_edit = LineEdit.new()
	name_edit.text = "Player"
	name_edit.max_length = 16
	vb.add_child(name_edit)

	vb.add_child(_labeled("Host IP (Join only)"))
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	vb.add_child(ip_edit)

	vb.add_child(_labeled("Port"))
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	vb.add_child(port_edit)

	var host_btn := Button.new()
	host_btn.text = "Host"
	host_btn.custom_minimum_size = Vector2(0, 38)
	host_btn.pressed.connect(_on_host_pressed)
	vb.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.custom_minimum_size = Vector2(0, 38)
	join_btn.pressed.connect(_on_join_pressed)
	vb.add_child(join_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit_btn)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	vb.add_child(status_label)

func _labeled(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	return l

func _player_name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Player"

func _port_value() -> int:
	var p := int(port_edit.text)
	return p if p > 0 else Net.DEFAULT_PORT

func _on_host_pressed() -> void:
	if Net.host(_port_value(), _player_name()):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		status_label.text = "Failed to host on port %d" % _port_value()

func _on_join_pressed() -> void:
	status_label.text = "Connecting..."
	if Net.join(ip_edit.text.strip_edges(), _port_value(), _player_name()):
		get_tree().change_scene_to_file(LOBBY_SCENE)
	else:
		status_label.text = "Failed to start client"

func _on_connection_failed() -> void:
	status_label.text = "Connection failed"
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_disconnected() -> void:
	status_label.text = "Disconnected from host"
