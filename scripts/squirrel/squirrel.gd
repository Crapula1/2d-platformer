extends CharacterBody2D
class_name SquirrelCharacter
# ============================================================================
#  Squirrel.gd  -  Godot 4.x
# ----------------------------------------------------------------------------
#  Playable humanoid squirrel with state machine driving the 7 animations
#  from squirrel_frames.tres.
#
#  SCENE SETUP
#  -----------
#  CharacterBody2D (this script)
#  ├── AnimatedSprite2D     (assign squirrel_frames.tres)
#  ├── CollisionShape2D     (CapsuleShape2D, e.g. 24 wide x 80 tall)
#  └── HitboxPivot (Node2D)              <- pivots with facing
#      └── AttackHitbox (Area2D)
#          └── CollisionShape2D          (disabled by default; enabled by anim)
#
#  INPUT MAP ACTIONS (add these in Project Settings -> Input Map)
#  ------------------------------------------------------------
#  move_left   - A / Left Arrow
#  move_right  - D / Right Arrow
#  jump        - Space            (optional, used to cancel crouch)
#  crouch      - Ctrl / S         (hold)
#  slide       - Shift            (tap while running)
#  slash       - Left Mouse / J
#  stab        - Right Mouse / K
# ============================================================================

# ---- tuning ---------------------------------------------------------------
@export var walk_speed     : float = 120.0
@export var run_speed      : float = 220.0
@export var run_threshold  : float = 0.85   # |input| above this => run
@export var slide_speed    : float = 320.0
@export var slide_decel    : float = 600.0  # px/s^2 while sliding
@export var crouch_speed   : float = 50.0
@export var gravity        : float = 980.0
@export var jump_velocity  : float = -340.0
@export var attack_lock    : bool  = true   # can't change state mid-swing

# ---- references -----------------------------------------------------------
@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_pivot : Node2D = get_node_or_null("HitboxPivot")
@onready var attack_hitbox : Area2D = get_node_or_null("HitboxPivot/AttackHitbox")

# ---- state ----------------------------------------------------------------
enum State { IDLE, WALK, RUN, CROUCH, SLIDE, SLASH, STAB }
var state : State = State.IDLE
var facing : int = 1   # 1 right, -1 left
var slide_dir : int = 1

# Signals other scripts can listen to
signal state_changed(new_state: State)
signal attack_landed(target: Node)


# ============================================================================
func _ready() -> void:
	if sprite == null:
		push_error("Squirrel needs an AnimatedSprite2D child.")
		return
	if not sprite.animation_finished.is_connected(_on_anim_finished):
		sprite.animation_finished.connect(_on_anim_finished)
	if attack_hitbox:
		attack_hitbox.monitoring = false
		if not attack_hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			attack_hitbox.body_entered.connect(_on_hitbox_body_entered)
	_enter_state(State.IDLE)


func _physics_process(delta: float) -> void:
	# gravity always applies
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.IDLE, State.WALK, State.RUN:
			_handle_ground_movement()
			_handle_action_input()
		State.CROUCH:
			_handle_crouch()
		State.SLIDE:
			_handle_slide(delta)
		State.SLASH, State.STAB:
			# locked in attack: decelerate quickly, no horizontal input
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if not attack_lock:
				_handle_action_input()

	move_and_slide()
	_update_facing()


# ============================================================================
#                          INPUT / MOVEMENT HANDLERS
# ============================================================================
func _handle_ground_movement() -> void:
	var input_x : float = Input.get_axis("move_left", "move_right")

	# attacks and slides override movement; check those first
	if Input.is_action_just_pressed("slash"):
		_start_attack(State.SLASH); return
	if Input.is_action_just_pressed("stab"):
		_start_attack(State.STAB); return
	if Input.is_action_pressed("crouch"):
		_enter_state(State.CROUCH); return
	if Input.is_action_just_pressed("slide") and state == State.RUN and is_on_floor():
		_start_slide(); return

	# horizontal motion
	if absf(input_x) > 0.01:
		var speed : float = run_speed if absf(input_x) > run_threshold else walk_speed
		velocity.x = input_x * speed
		_enter_state(State.RUN if absf(input_x) > run_threshold else State.WALK)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 800.0 * get_physics_process_delta_time())
		_enter_state(State.IDLE)


func _handle_action_input() -> void:
	# called from idle/walk/run; keeps quick attack tap responsive
	pass  # already covered above; placeholder for future combo logic


func _handle_crouch() -> void:
	var input_x : float = Input.get_axis("move_left", "move_right")
	velocity.x = input_x * crouch_speed

	# attacks still available from crouch
	if Input.is_action_just_pressed("slash"):
		_start_attack(State.SLASH); return
	if Input.is_action_just_pressed("stab"):
		_start_attack(State.STAB); return

	# release crouch -> back to grounded states
	if not Input.is_action_pressed("crouch"):
		_enter_state(State.IDLE)


func _handle_slide(delta: float) -> void:
	# Decay slide speed; end slide when slow or anim finishes (anim_finished handler).
	velocity.x = move_toward(velocity.x, 0.0, slide_decel * delta)
	# Allow attack-cancel out of slide for a "slide attack" feel
	if Input.is_action_just_pressed("slash"):
		_start_attack(State.SLASH); return
	if Input.is_action_just_pressed("stab"):
		_start_attack(State.STAB); return


# ============================================================================
#                              STATE ENTRY
# ============================================================================
func _enter_state(new_state: State) -> void:
	if state == new_state:
		return
	# disable hitbox when leaving an attack state
	if (state == State.SLASH or state == State.STAB) and attack_hitbox:
		attack_hitbox.monitoring = false

	state = new_state
	emit_signal("state_changed", state)

	match state:
		State.IDLE:   sprite.play("idle")
		State.WALK:   sprite.play("walk")
		State.RUN:    sprite.play("run")
		State.CROUCH: sprite.play("crouch")
		State.SLIDE:  sprite.play("slide")
		State.SLASH:  sprite.play("slash")
		State.STAB:   sprite.play("stab")


func _start_slide() -> void:
	slide_dir = facing
	velocity.x = slide_dir * slide_speed
	_enter_state(State.SLIDE)


func _start_attack(which: State) -> void:
	_enter_state(which)
	# Sprite.frame_changed fires per-frame; the handler toggles the hitbox
	# on during active frames and off otherwise.
	if attack_hitbox and not sprite.frame_changed.is_connected(_on_attack_frame):
		sprite.frame_changed.connect(_on_attack_frame)


# ============================================================================
#                          ANIM EVENT HOOKS
# ============================================================================
func _on_anim_finished() -> void:
	match state:
		State.SLASH, State.STAB:
			# disconnect frame listener and return to ground state
			if sprite.frame_changed.is_connected(_on_attack_frame):
				sprite.frame_changed.disconnect(_on_attack_frame)
			if attack_hitbox: attack_hitbox.monitoring = false
			_enter_state(State.IDLE)
		State.SLIDE:
			_enter_state(State.CROUCH if Input.is_action_pressed("crouch") else State.IDLE)
		State.CROUCH:
			# 'crouch' is non-looping (stand -> mid -> low), then it just holds.
			pass


func _on_attack_frame() -> void:
	# Slash active frames: 2 and 3   (the swing + follow-through)
	# Stab  active frame : 2         (full thrust extension)
	if attack_hitbox == null:
		return
	match state:
		State.SLASH:
			attack_hitbox.monitoring = (sprite.frame == 2 or sprite.frame == 3)
		State.STAB:
			attack_hitbox.monitoring = (sprite.frame == 2)
		_:
			attack_hitbox.monitoring = false


func _on_hitbox_body_entered(body: Node) -> void:
	# Hook for your enemies. Use groups or duck-typing for damage.
	emit_signal("attack_landed", body)
	if body.has_method("take_damage"):
		var dmg : int = 2 if state == State.SLASH else 3   # stab hits harder
		body.take_damage(dmg, global_position)


# ============================================================================
#                              FACING
# ============================================================================
func _update_facing() -> void:
	# Don't flip while sliding/attacking (commit to the direction we started in)
	if state == State.SLIDE or state == State.SLASH or state == State.STAB:
		sprite.flip_h = (facing == -1)
		if hitbox_pivot:
			hitbox_pivot.scale.x = float(facing)
		return

	if velocity.x > 5.0:
		facing = 1
	elif velocity.x < -5.0:
		facing = -1
	sprite.flip_h = (facing == -1)
	if hitbox_pivot:
		hitbox_pivot.scale.x = float(facing)
