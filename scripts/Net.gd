extends Node
# Networking autoload. Owns the ENet peer, the lobby player registry, and the
# RPCs that keep both sides in sync. Host is always peer id 1.

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 4
const CHARACTERS: Array[String] = ["marine", "demon"]
const GAME_SCENE_PATH: String = "res://scenes/Main.tscn"
const MENU_SCENE_PATH: String = "res://scenes/MainMenu.tscn"

signal player_list_changed()
signal connection_failed()
signal disconnected()
signal game_started()
signal player_late_joined(peer_id: int)  # host-side: a new peer entered Main mid-run
signal host_discovered(ip: String, port: int)

# LAN discovery — host broadcasts a tiny UDP beacon on a separate port so
# clients on the same network can auto-fill the host's IP without typing.
const DISCOVERY_PORT: int = 7778
const DISCOVERY_MAGIC: String = "JS_LAN_DISCOVERY"
const DISCOVERY_INTERVAL: float = 1.0

var _disc_broadcaster: PacketPeerUDP = null
var _disc_listener: PacketPeerUDP = null
var _disc_timer: float = 0.0
var discovered_hosts: Dictionary = {}  # "ip:port" -> {ip, port, last_seen_ms}

# peer_id -> {"name": String, "character": String, "ready": bool}
var players: Dictionary = {}

var local_name: String = "Player"
var local_character: String = "marine"
var is_host: bool = false
var in_game: bool = false
# Host-generated seed used by ProceduralLevel so every peer gets identical
# rooms. Defaults to 0 (deterministic) before the first level transition.
var current_seed: int = 0

func _ready() -> void:
	set_process(true)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

var last_error: String = ""
var _host_port: int = DEFAULT_PORT

func host(port: int, player_name: String) -> bool:
	local_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		last_error = "create_server failed (err %d) — port %d likely in use" % [err, port]
		push_warning("[Net] " + last_error)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	_host_port = port
	players.clear()
	players[1] = _make_entry(local_name, local_character, false)
	player_list_changed.emit()
	last_error = ""
	start_discovery_broadcast()
	return true

func join(ip: String, port: int, player_name: String) -> bool:
	local_name = player_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		last_error = "create_client failed (err %d) for %s:%d" % [err, ip, port]
		push_warning("[Net] " + last_error)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	last_error = ""
	return true

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	in_game = false
	stop_discovery_broadcast()
	player_list_changed.emit()

# --- LAN discovery ---------------------------------------------------------

func start_discovery_broadcast() -> void:
	if _disc_broadcaster != null:
		return
	var bc := PacketPeerUDP.new()
	bc.set_broadcast_enabled(true)
	var err := bc.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	if err != OK:
		push_warning("[Net] discovery broadcaster setup failed: %d" % err)
		return
	_disc_broadcaster = bc
	_disc_timer = 0.0  # send first beacon immediately

func stop_discovery_broadcast() -> void:
	if _disc_broadcaster != null:
		_disc_broadcaster.close()
		_disc_broadcaster = null

func start_discovery_listen() -> void:
	if _disc_listener != null:
		return
	var ls := PacketPeerUDP.new()
	var err := ls.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("[Net] discovery listener bind failed: %d (another instance listening?)" % err)
		return
	_disc_listener = ls
	discovered_hosts.clear()

func stop_discovery_listen() -> void:
	if _disc_listener != null:
		_disc_listener.close()
		_disc_listener = null
	discovered_hosts.clear()

func _process(delta: float) -> void:
	if _disc_broadcaster != null:
		_disc_timer -= delta
		if _disc_timer <= 0.0:
			_disc_timer = DISCOVERY_INTERVAL
			var msg := "%s|%d" % [DISCOVERY_MAGIC, _host_port]
			_disc_broadcaster.put_packet(msg.to_utf8_buffer())
	if _disc_listener != null:
		while _disc_listener.get_available_packet_count() > 0:
			var data := _disc_listener.get_packet()
			var text := data.get_string_from_utf8()
			var parts := text.split("|")
			if parts.size() >= 2 and parts[0] == DISCOVERY_MAGIC:
				var ip: String = _disc_listener.get_packet_ip()
				var port := int(parts[1])
				_record_discovered(ip, port)

func _record_discovered(ip: String, port: int) -> void:
	var key := "%s:%d" % [ip, port]
	var now := Time.get_ticks_msec()
	if discovered_hosts.has(key):
		discovered_hosts[key].last_seen_ms = now
		return
	discovered_hosts[key] = {"ip": ip, "port": port, "last_seen_ms": now}
	host_discovered.emit(ip, port)

func set_local_character(c: String) -> void:
	if not (c in CHARACTERS):
		return
	local_character = c
	var id := multiplayer.get_unique_id()
	if not players.has(id):
		return
	players[id].character = c
	_sync_player_state.rpc(id, players[id])

func set_local_ready(r: bool) -> void:
	var id := multiplayer.get_unique_id()
	if not players.has(id):
		return
	players[id].ready = r
	_sync_player_state.rpc(id, players[id])

func can_start() -> bool:
	if not is_host:
		return false
	if players.is_empty():
		return false
	for p in players.values():
		if not p.ready:
			return false
	return true

func start_game() -> void:
	if not is_host or not can_start():
		return
	_start_game_rpc.rpc()

func _make_entry(n: String, c: String, r: bool) -> Dictionary:
	return {"name": n, "character": c, "ready": r}

# --- Multiplayer callbacks ---

func _on_peer_connected(id: int) -> void:
	# Server-only: seed the new client with the existing registry.
	if not is_host:
		return
	for pid in players:
		_register_player.rpc_id(id, pid, players[pid])
	if in_game:
		# Late join: add a default registry entry for the newcomer and pull
		# them into the game scene. They'll ack when their Main is ready.
		var entry := _make_entry("Player_%d" % id, "marine", true)
		players[id] = entry
		_register_player.rpc(id, entry)
		_late_join_enter.rpc_id(id)

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		player_list_changed.emit()

func _on_connected_to_server() -> void:
	var id := multiplayer.get_unique_id()
	var data := _make_entry(local_name, local_character, false)
	players[id] = data
	player_list_changed.emit()
	_register_player.rpc(id, data)

func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	connection_failed.emit()

func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	in_game = false
	disconnected.emit()

# --- RPCs ---

@rpc("any_peer", "call_local", "reliable")
func _register_player(id: int, data: Dictionary) -> void:
	players[id] = data
	player_list_changed.emit()

@rpc("any_peer", "call_local", "reliable")
func _sync_player_state(id: int, data: Dictionary) -> void:
	players[id] = data
	player_list_changed.emit()

@rpc("authority", "call_local", "reliable")
func _start_game_rpc() -> void:
	in_game = true
	game_started.emit()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

@rpc("authority", "reliable")
func _late_join_enter() -> void:
	# Sent by host to a peer that connected mid-run. Pull them into Main.
	in_game = true
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

@rpc("any_peer", "reliable")
func client_main_ready() -> void:
	# Called by clients (including late joiners) once their Main is set up.
	# Host uses this to decide whether to spawn that peer's player now.
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	player_late_joined.emit(sender)
