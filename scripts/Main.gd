extends Node2D

@onready var health_bar: Control = $HUD/MarginContainer/VBoxContainer/HealthBar
@onready var health_fill: ColorRect = $HUD/MarginContainer/VBoxContainer/HealthBar/Fill
@onready var health_damage_lag: ColorRect = $HUD/MarginContainer/VBoxContainer/HealthBar/DamageLag
@onready var health_label: Label = $HUD/MarginContainer/VBoxContainer/HealthBar/HealthLabel
@onready var jetpack_fill: ColorRect = $HUD/MarginContainer/VBoxContainer/JetpackBar/Fill
@onready var jetpack_label: Label = $HUD/MarginContainer/VBoxContainer/JetpackBar/FuelLabel
@onready var weapon_label: Label = $HUD/MarginContainer/VBoxContainer/WeaponLabel

const HEALTH_BAR_INNER_W: float = 188.0
const JETPACK_BAR_INNER_W: float = 188.0
const JETPACK_COL_FULL := Color(1.0, 0.78, 0.15)
const JETPACK_COL_LOW  := Color(1.0, 0.42, 0.10)
const HEALTH_COL_HIGH := Color(0.30, 0.85, 0.35)
const HEALTH_COL_MID  := Color(0.95, 0.78, 0.20)
const HEALTH_COL_LOW  := Color(0.95, 0.30, 0.20)

var _health_fill_tween: Tween = null
var _health_lag_tween: Tween = null
@onready var score_label: Label = $HUD/MarginContainer/VBoxContainer/ScoreLabel
@onready var grenade_label: Label = $HUD/MarginContainer/VBoxContainer/GrenadeLabel
@onready var message_label: Label = $HUD/CenterContainer/MessageLabel
@onready var hint_label: Label = $HUD/HintLabel

const LEVEL_SCENE := preload("res://scenes/Level.tscn")
const PROC_LEVEL_SCENE := preload("res://scenes/ProceduralLevel.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/PauseMenu.tscn")
const COIN_SCENE := preload("res://scenes/Coin.tscn")
const DEATH_PLANE_MARGIN: float = 160.0

# Konami code easter egg: ↑↑↓↓←→←→ → coin shower
const KONAMI := [KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT]
var _konami_progress: int = 0

const UPGRADES := [
	{"id": "max_hp",      "name": "Combat Stims",  "desc": "+2 Max HP"},
	{"id": "attack",      "name": "AP Rounds",      "desc": "+1 Bash Damage"},
	{"id": "speed",       "name": "Servo Legs",     "desc": "+20% Speed"},
	{"id": "heal_now",    "name": "Field Medkit",   "desc": "Restore 3 HP"},
	{"id": "grenade_cd",  "name": "Fast Loader",    "desc": "Grenade CD -25%"},
	{"id": "invincibility","name": "Ceramic Plate", "desc": "+0.5s I-Frames"},
]

const GRENADE_COLORS := [
	Color(1.0, 0.72, 0.2),
	Color(1.0, 0.42, 0.08),
	Color(0.35, 0.88, 1.0),
]

var player: Player = null
var spawn_position: Vector2
var _level: Node = null
var _pause_menu: CanvasLayer = null
@onready var players_root: Node2D = $Players
@onready var spawner: MultiplayerSpawner = $Players/MultiplayerSpawner
@onready var projectiles_root: Node2D = $Projectiles
@onready var projectile_spawner: MultiplayerSpawner = $Projectiles/MultiplayerSpawner

func _ready() -> void:
	if not RunState.is_run_active:
		RunState.start_new_run()

	if RunState.depth > 0:
		_level = PROC_LEVEL_SCENE.instantiate()
	else:
		_level = LEVEL_SCENE.instantiate()

	add_child(_level)
	move_child(_level, 0)

	spawner.spawn_function = _spawn_player_node
	projectile_spawner.spawn_function = _spawn_projectile_node
	players_root.child_entered_tree.connect(_on_player_entered)
	Net.player_late_joined.connect(_on_player_late_joined)
	Net.player_list_changed.connect(_reconcile_players)

	await get_tree().process_frame

	spawn_position = _find_spawn_position()

	for goal in get_tree().get_nodes_in_group("goal"):
		goal.reached.connect(_on_level_exit)

	for exit_node in get_tree().get_nodes_in_group("exit"):
		exit_node.exited.connect(_on_level_exit)

	message_label.text = ""
	hint_label.text = "WASD: Move  |  Space: Jump  |  RClick: Shoot  |  1/2: Weapon  |  J/LClick: Bash  |  G: Grenade  |  Q: Cycle  |  R: Restart  |  Esc: Menu"

	# Solo (no active peer) and host (peer + is_server) both need to spawn;
	# clients just wait for the host to spawn them through the spawner.
	if not multiplayer.has_multiplayer_peer():
		_spawn_all_players()
	elif multiplayer.is_server():
		await get_tree().create_timer(0.5).timeout
		_spawn_all_players()
	else:
		Net.client_main_ready.rpc_id(1)

func _find_spawn_position() -> Vector2:
	if _level == null:
		return Vector2(80, 380)
	var m := _level.find_child("PlayerSpawn", true, false) as Node2D
	return m.global_position if m != null else Vector2(80, 380)

func _spawn_all_players() -> void:
	if Net.players.is_empty():
		Net.players[1] = {"name": "Player", "character": "marine", "ready": true}
	var has_peer := multiplayer.has_multiplayer_peer()
	var i := 0
	for peer_id in Net.players.keys():
		if players_root.has_node("P_%d" % int(peer_id)):
			i += 1
			continue
		var entry: Dictionary = Net.players[peer_id]
		var offset := Vector2(i * 32, 0)
		var data := {
			"peer": int(peer_id),
			"character": String(entry.character),
			"x": spawn_position.x + offset.x,
			"y": spawn_position.y + offset.y,
		}
		if has_peer:
			spawner.spawn(data)
		else:
			# Solo run: no multiplayer peer means spawner.spawn() doesn't
			# materialize a node. Build it directly and parent it so the
			# existing _on_player_entered hookup still fires.
			var node := _spawn_player_node(data)
			players_root.add_child(node)
		i += 1

func _spawn_player_node(data: Dictionary) -> Node:
	var scene_path: String = "res://scenes/PlayerDemon.tscn" if String(data.get("character", "marine")) == "demon" else "res://scenes/Player.tscn"
	var p := (load(scene_path) as PackedScene).instantiate()
	var peer_id := int(data.get("peer", 1))
	p.name = "P_%d" % peer_id
	p.set_multiplayer_authority(peer_id)
	p.position = Vector2(float(data.get("x", 80.0)), float(data.get("y", 380.0)))
	return p

func _spawn_projectile_node(data: Dictionary) -> Node:
	var kind: String = String(data.get("kind", "bullet"))
	var scene_path := "res://scenes/HomingMissile.tscn" if kind == "missile" else "res://scenes/Bullet.tscn"
	var n := (load(scene_path) as PackedScene).instantiate()
	n.position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	n.set_multiplayer_authority(1)
	if n.has_method("net_setup"):
		n.net_setup(data)
	return n

func spawn_projectile(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
		projectile_spawner.spawn(data)

func _on_player_late_joined(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if players_root.has_node("P_%d" % peer_id):
		return
	var entry: Dictionary = Net.players.get(peer_id, {"character": "marine"})
	spawner.spawn({
		"peer": peer_id,
		"character": String(entry.get("character", "marine")),
		"x": spawn_position.x,
		"y": spawn_position.y,
	})

func _reconcile_players() -> void:
	for child in players_root.get_children():
		if not (child is Player):
			continue
		var nname: String = child.name
		if not nname.begins_with("P_"):
			continue
		var pid: int = int(nname.substr(2))
		if not Net.players.has(pid):
			child.queue_free()

func _on_player_entered(node: Node) -> void:
	if not (node is Player):
		return
	var p := node as Player
	await get_tree().process_frame
	# In solo (no multiplayer peer) is_multiplayer_authority() can be false on
	# every player because get_unique_id() returns 0; treat "no peer" as local.
	var is_local: bool = (not multiplayer.has_multiplayer_peer()) or p.is_multiplayer_authority()
	if not is_local:
		return
	player = p
	if RunState.depth > 0:
		RunState.apply_to_player(player)
	player.health_changed.connect(_on_health_changed)
	player.score_changed.connect(_on_score_changed)
	player.died.connect(_on_player_died)
	player.grenade_changed.connect(_on_grenade_changed)
	player.jetpack_changed.connect(_on_jetpack_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.shotgun_shells_changed.connect(_on_shotgun_shells_changed)
	_on_health_changed(player.current_health, player.max_health)
	_on_score_changed(player.score)
	_on_grenade_changed(Player.GRENADE_NAMES[player.grenade_type], player.grenade_count)
	_on_jetpack_changed(player._jetpack_fuel, player.jetpack_duration)
	_on_weapon_changed(Player.WEAPON_NAMES[player.weapon])
	_on_shotgun_shells_changed(player._shotgun_shells, player.shotgun_capacity)
	if _level != null and _level.has_method("apply_camera_limits_for_room"):
		_level.apply_camera_limits_for_room(player, 0)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not is_instance_valid(_pause_menu):
		_open_pause_menu()
		return

	if Input.is_action_just_pressed("restart"):
		# Only host can restart the run in MP; solo runs locally.
		if (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server():
			if multiplayer.has_multiplayer_peer():
				rpc("net_reload_run")
			else:
				net_reload_run()
		return

	if Input.is_action_just_pressed("ui_cancel"):
		if not multiplayer.has_multiplayer_peer():
			get_tree().change_scene_to_file(Net.MENU_SCENE_PATH)
		elif multiplayer.is_server():
			rpc("net_return_to_lobby")
		return

	if player == null or player.is_dead:
		return

	var death_y: float = get_viewport_rect().size.y + DEATH_PLANE_MARGIN
	if player.global_position.y > death_y:
		player.take_damage(99, player.global_position)

@rpc("authority", "call_local", "reliable")
func net_reload_run() -> void:
	RunState.start_new_run()
	get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func net_apply_upgrade_and_advance(upg_id: String, new_seed: int) -> void:
	if player != null:
		RunState.save_from_player(player)
	RunState.apply_upgrade(upg_id)
	RunState.advance_depth()
	Net.current_seed = new_seed
	_fade_and_load()

@rpc("authority", "call_local", "reliable")
func net_show_upgrade(upgrade_ids: PackedStringArray) -> void:
	_show_upgrade_screen_with(upgrade_ids)

@rpc("authority", "call_local", "reliable")
func net_return_to_lobby() -> void:
	Net.in_game = false
	for pid in Net.players:
		Net.players[pid].ready = false
	Net.player_list_changed.emit()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

const _EXPLOSIVE_EFFECT_SCENE = preload("res://scenes/ExplosiveEffect.tscn")
const _FIRE_ZONE_SCENE        = preload("res://scenes/FireZone.tscn")
const _ELECTRIC_ZONE_SCENE    = preload("res://scenes/ElectricZone.tscn")

@rpc("any_peer", "call_local", "reliable")
func net_spawn_explosion(pos: Vector2) -> void:
	var fx := _EXPLOSIVE_EFFECT_SCENE.instantiate() as Node2D
	add_child(fx)
	fx.global_position = pos

@rpc("any_peer", "call_local", "reliable")
func net_spawn_fire_zone(pos: Vector2) -> void:
	var fx := _FIRE_ZONE_SCENE.instantiate() as Node2D
	add_child(fx)
	fx.global_position = pos

@rpc("any_peer", "call_local", "reliable")
func net_spawn_electric_zone(pos: Vector2) -> void:
	var fx := _ELECTRIC_ZONE_SCENE.instantiate() as Node2D
	add_child(fx)
	fx.global_position = pos

func _on_health_changed(new_health: int, max_health: int) -> void:
	var pct: float = 0.0 if max_health <= 0 else clampf(float(new_health) / float(max_health), 0.0, 1.0)
	var target_w: float = HEALTH_BAR_INNER_W * pct
	health_label.text = "HP %d / %d" % [maxi(new_health, 0), max_health]

	# Color shifts: green > yellow > red as health drops
	var target_color: Color
	if pct > 0.55:
		target_color = HEALTH_COL_HIGH.lerp(HEALTH_COL_MID, (1.0 - pct) / 0.45)
	else:
		target_color = HEALTH_COL_MID.lerp(HEALTH_COL_LOW, clampf((0.55 - pct) / 0.55, 0.0, 1.0))

	# Fast fill tween — snappy on heal/damage
	if _health_fill_tween != null and _health_fill_tween.is_valid():
		_health_fill_tween.kill()
	_health_fill_tween = create_tween().set_parallel(true)
	_health_fill_tween.tween_property(health_fill, "offset_right", 2.0 + target_w, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_health_fill_tween.tween_property(health_fill, "color", target_color, 0.15)

	# Slow damage-lag bar — yellow trail that catches up after a beat (only on damage)
	var lag_right: float = health_damage_lag.offset_right
	var fill_right: float = 2.0 + target_w
	if lag_right > fill_right:
		# Damage taken — pause briefly, then catch up
		if _health_lag_tween != null and _health_lag_tween.is_valid():
			_health_lag_tween.kill()
		_health_lag_tween = create_tween()
		_health_lag_tween.tween_interval(0.25)
		_health_lag_tween.tween_property(health_damage_lag, "offset_right", fill_right, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		# Heal — snap up with the fill
		if _health_lag_tween != null and _health_lag_tween.is_valid():
			_health_lag_tween.kill()
		health_damage_lag.offset_right = fill_right

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Coins: " + str(new_score)

var _current_weapon_name: String = "RIFLE"
var _shotgun_shells_now: int = 0
var _shotgun_shells_max: int = 2

func _on_weapon_changed(name: String) -> void:
	_current_weapon_name = name
	# Tint to match the projectile color so the HUD reads at a glance
	if name == "SHOTGUN":
		weapon_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
	else:
		weapon_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	_refresh_weapon_label()

func _on_shotgun_shells_changed(shells: int, max_shells: int) -> void:
	_shotgun_shells_now = shells
	_shotgun_shells_max = max_shells
	_refresh_weapon_label()

func _refresh_weapon_label() -> void:
	if _current_weapon_name == "SHOTGUN":
		var pips := ""
		for i in _shotgun_shells_max:
			pips += "●" if i < _shotgun_shells_now else "○"
		weapon_label.text = "» SHOTGUN [%s]" % pips
	else:
		weapon_label.text = "» " + _current_weapon_name

func _on_jetpack_changed(fuel: float, max_fuel: float) -> void:
	var pct: float = 0.0 if max_fuel <= 0.0 else clampf(fuel / max_fuel, 0.0, 1.0)
	jetpack_fill.offset_right = 2.0 + JETPACK_BAR_INNER_W * pct
	jetpack_fill.color = JETPACK_COL_LOW.lerp(JETPACK_COL_FULL, pct)
	jetpack_label.text = "FUEL %d%%" % int(round(pct * 100.0))

func _on_grenade_changed(type_name: String, count: int) -> void:
	grenade_label.text = "[ " + type_name + "  x" + str(count) + " ]"
	if player != null:
		var idx: int = player.grenade_type
		grenade_label.add_theme_color_override("font_color", GRENADE_COLORS[idx])

func _on_player_died() -> void:
	message_label.text = "YOU DIED\nDepth %d | Score %d\nR to restart" % [RunState.depth, player.score if player else 0]
	message_label.modulate = Color(1.0, 0.3, 0.3)
	if player:
		player.set_physics_process(false)

func _on_level_exit() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if player == null or player.is_dead:
		return

	var shuffled: Array = UPGRADES.duplicate()
	shuffled.shuffle()
	var choice_ids: PackedStringArray = PackedStringArray()
	for upg in shuffled.slice(0, 3):
		choice_ids.append(String(upg["id"]))

	if player != null:
		player.set_physics_process(false)

	if multiplayer.has_multiplayer_peer():
		rpc("net_show_upgrade", choice_ids)
	else:
		net_show_upgrade(choice_ids)

func _show_upgrade_screen_with(upgrade_ids: PackedStringArray) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.10, 0.88)
	overlay.add_child(bg)

	var depth_label := Label.new()
	depth_label.text = "DEPTH %d  |  SCORE %d" % [RunState.depth, RunState.saved_score]
	depth_label.add_theme_font_size_override("font_size", 22)
	depth_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	depth_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	depth_label.add_theme_constant_override("outline_size", 4)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	depth_label.offset_top = 60.0
	depth_label.offset_bottom = 100.0
	overlay.add_child(depth_label)

	var title_label := Label.new()
	title_label.text = "CHOOSE AN UPGRADE"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 6)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 110.0
	title_label.offset_bottom = 160.0
	overlay.add_child(title_label)

	var by_id: Dictionary = {}
	for u in UPGRADES:
		by_id[u["id"]] = u
	var choices: Array = []
	for id in upgrade_ids:
		if by_id.has(id):
			choices.append(by_id[id])

	var is_host_local: bool = (not multiplayer.has_multiplayer_peer()) or multiplayer.is_server()

	var btn_w: float = 155.0
	var btn_h: float = 120.0
	var spacing: float = 20.0
	var total_w: float = btn_w * 3.0 + spacing * 2.0
	var start_x: float = (get_viewport_rect().size.x - total_w) * 0.5
	var btn_y: float = 220.0

	for i in range(choices.size()):
		var upg: Dictionary = choices[i] as Dictionary
		var btn := Button.new()
		btn.text = upg["name"] + "\n" + upg["desc"]
		btn.custom_minimum_size = Vector2(btn_w, btn_h)
		btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
		btn.offset_left = start_x + float(i) * (btn_w + spacing)
		btn.offset_top = btn_y
		btn.offset_right = start_x + float(i) * (btn_w + spacing) + btn_w
		btn.offset_bottom = btn_y + btn_h

		var normal_style := _make_stylebox(Color(0.10, 0.14, 0.22))
		var hover_style := _make_stylebox(Color(0.22, 0.30, 0.45))
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_stylebox_override("focus", normal_style)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

		var upg_id: String = upg["id"]
		btn.disabled = not is_host_local
		btn.pressed.connect(func():
			overlay.queue_free()
			var new_seed := randi()
			if multiplayer.has_multiplayer_peer():
				rpc("net_apply_upgrade_and_advance", upg_id, new_seed)
			else:
				net_apply_upgrade_and_advance(upg_id, new_seed)
		)
		overlay.add_child(btn)

	if not is_host_local:
		var note := Label.new()
		note.text = "Host is choosing..."
		note.add_theme_font_size_override("font_size", 18)
		note.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.set_anchors_preset(Control.PRESET_TOP_WIDE)
		note.offset_top = 360.0
		note.offset_bottom = 400.0
		overlay.add_child(note)

func _fade_and_load() -> void:
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 20
	add_child(fade_layer)

	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color(0, 0, 0, 0)
	fade_layer.add_child(black)

	var tween := create_tween()
	tween.tween_property(black, "color", Color(0, 0, 0, 1), 0.4)
	tween.tween_callback(func():
		get_tree().reload_current_scene()
	)

func _open_pause_menu() -> void:
	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_menu)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KONAMI[_konami_progress]:
			_konami_progress += 1
			if _konami_progress >= KONAMI.size():
				_konami_progress = 0
				_trigger_coin_shower()
		else:
			# Resync — current key might be the first of a new attempt
			_konami_progress = 1 if event.keycode == KONAMI[0] else 0

func _trigger_coin_shower() -> void:
	if player == null or not is_instance_valid(player):
		return
	message_label.text = "★ JUNGLE BOUNTY ★"
	message_label.modulate = Color(1.0, 0.9, 0.3)
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(message_label):
			message_label.text = ""
			message_label.modulate = Color.WHITE
	)
	var origin: Vector2 = player.global_position
	for i in 18:
		var coin := COIN_SCENE.instantiate() as Node2D
		_level.add_child(coin)
		var spread: float = randf_range(-200.0, 200.0)
		var sky: Vector2 = origin + Vector2(spread, -240.0 - randf_range(0.0, 80.0))
		var ground: Vector2 = origin + Vector2(spread, -8.0)
		coin.global_position = sky
		# Fall to ground level — set start_y after the tween finishes so the
		# bob animation in Coin._process kicks in from the right baseline.
		var tw := coin.create_tween()
		tw.tween_property(coin, "global_position", ground, randf_range(0.55, 0.85)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			if is_instance_valid(coin):
				coin.start_y = coin.position.y
				coin.time = 0.0
		)

func _make_stylebox(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.40, 0.52, 0.68)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	return sb
