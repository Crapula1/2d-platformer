extends Node

# Networked lobby state. Owns the MultiplayerPeer and the per-slot character
# selections that drive the CharacterSelect UI.
#
# Slot model: slots are indexed 0..max_players-1. Each slot is owned by a peer
# id (1 = host, others assigned in join order). The local peer is allowed to
# change its own slot's selection; the host is the authority on slot ownership
# and ready/start transitions.
#
# Singleplayer is modeled as a 1-slot "offline" lobby that skips the peer
# entirely — that way the CharacterSelect scene only has one code path.

signal slots_changed
signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal start_game

const DEFAULT_PORT := 7654
const MAX_PLAYERS := 4

enum Mode { OFFLINE, HOST, CLIENT }

var mode: int = Mode.OFFLINE
var max_players: int = 1
# slot index -> { peer_id:int, character_id:String, ready:bool, name:String }
var slots: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_offline() -> void:
	_reset_peer()
	mode = Mode.OFFLINE
	max_players = 1
	slots = [_make_slot(1)]
	slots_changed.emit()

func start_host(port: int = DEFAULT_PORT, max_p: int = MAX_PLAYERS) -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_p)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	max_players = max_p
	slots.clear()
	for i in max_p:
		slots.append(_make_slot(0))
	# Host always owns slot 0.
	slots[0]["peer_id"] = 1
	slots_changed.emit()
	return OK

func start_client(address: String, port: int = DEFAULT_PORT) -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	slots.clear()
	slots_changed.emit()
	return OK

func leave() -> void:
	_reset_peer()
	mode = Mode.OFFLINE
	max_players = 1
	slots = [_make_slot(1)]
	slots_changed.emit()

func local_peer_id() -> int:
	if mode == Mode.OFFLINE:
		return 1
	return multiplayer.get_unique_id()

func is_host() -> bool:
	return mode == Mode.HOST or mode == Mode.OFFLINE

func local_slot_index() -> int:
	var pid := local_peer_id()
	for i in slots.size():
		if slots[i]["peer_id"] == pid:
			return i
	return -1

# --- Selection API ---------------------------------------------------------

# Called by CharacterSelect when the local player picks a character. Routes
# through the host so authority stays in one place.
func request_select(character_id: String) -> void:
	if mode == Mode.OFFLINE:
		_apply_select(local_peer_id(), character_id)
		slots_changed.emit()
		return
	if is_host():
		_apply_select(local_peer_id(), character_id)
		_broadcast_slots()
	else:
		_rpc_request_select.rpc_id(1, character_id)

func request_ready(is_ready: bool) -> void:
	if mode == Mode.OFFLINE:
		_apply_ready(local_peer_id(), is_ready)
		slots_changed.emit()
		_check_all_ready()
		return
	if is_host():
		_apply_ready(local_peer_id(), is_ready)
		_broadcast_slots()
		_check_all_ready()
	else:
		_rpc_request_ready.rpc_id(1, is_ready)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_select(character_id: String) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_select(sender, character_id)
	_broadcast_slots()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_ready(is_ready: bool) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	_apply_ready(sender, is_ready)
	_broadcast_slots()
	_check_all_ready()

@rpc("authority", "call_remote", "reliable")
func _rpc_push_slots(serialized: Array) -> void:
	slots = serialized
	slots_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_start_game() -> void:
	start_game.emit()

func _apply_select(peer_id: int, character_id: String) -> void:
	if not CharacterDB.is_unlocked(character_id):
		return
	for s in slots:
		if s["peer_id"] == peer_id:
			s["character_id"] = character_id
			s["ready"] = false  # changing selection drops ready
			return

func _apply_ready(peer_id: int, is_ready: bool) -> void:
	for s in slots:
		if s["peer_id"] == peer_id:
			s["ready"] = is_ready
			return

func _broadcast_slots() -> void:
	slots_changed.emit()
	if mode == Mode.HOST:
		_rpc_push_slots.rpc(slots)

func _check_all_ready() -> void:
	if not is_host():
		return
	var active := 0
	for s in slots:
		if s["peer_id"] != 0:
			active += 1
			if not s["ready"]:
				return
	if active == 0:
		return
	# All filled slots are ready — start.
	if mode == Mode.HOST:
		_rpc_start_game.rpc()
	start_game.emit()

# --- Peer event handlers ---------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	# Find an empty slot for the new peer.
	for i in slots.size():
		if slots[i]["peer_id"] == 0:
			slots[i]["peer_id"] = peer_id
			break
	player_joined.emit(peer_id)
	_broadcast_slots()

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	for s in slots:
		if s["peer_id"] == peer_id:
			s["peer_id"] = 0
			s["ready"] = false
			s["character_id"] = CharacterDB.CHARACTERS[0]["id"]
	player_left.emit(peer_id)
	_broadcast_slots()

func _on_connected_to_server() -> void:
	pass  # Slots arrive via _rpc_push_slots from the host.

func _on_connection_failed() -> void:
	leave()

func _on_server_disconnected() -> void:
	leave()

# --- Helpers ---------------------------------------------------------------

func _make_slot(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"character_id": CharacterDB.CHARACTERS[0]["id"],
		"ready": false,
	}

func _reset_peer() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
