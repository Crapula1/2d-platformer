extends Node2D
# ============================================================================
#  SquirrelDemo.gd  -  Quick playground to verify all animations work.
#
#  Attach to a Node2D scene root. Adds a floor + spawns the squirrel.
#  Press the input actions to cycle through states; on-screen labels show
#  the current state and currently playing animation.
# ============================================================================

const SQUIRREL_SCENE := "res://Squirrel.tscn"   # change if you saved elsewhere

@onready var squirrel : SquirrelCharacter
@onready var label : Label

func _ready() -> void:
	# floor (StaticBody2D with a wide rectangle collider)
	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(2000, 40)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	floor_body.position = Vector2(0, 300)
	add_child(floor_body)

	# visual for the floor so you can see it
	var line := Line2D.new()
	line.add_point(Vector2(-1000, 280))
	line.add_point(Vector2( 1000, 280))
	line.width = 2
	line.default_color = Color(0.4, 0.3, 0.2)
	add_child(line)

	# spawn squirrel
	var scene : PackedScene = load(SQUIRREL_SCENE)
	if scene:
		squirrel = scene.instantiate()
		squirrel.position = Vector2(0, 200)
		add_child(squirrel)
		squirrel.state_changed.connect(_on_state_changed)

	# HUD label
	label = Label.new()
	label.position = Vector2(-380, -200)
	label.add_theme_color_override("font_color", Color(1,1,1))
	label.text = "State: IDLE"
	add_child(label)

func _on_state_changed(new_state: int) -> void:
	if label == null: return
	var names := ["IDLE","WALK","RUN","CROUCH","SLIDE","SLASH","STAB"]
	label.text = "State: %s" % names[new_state]
