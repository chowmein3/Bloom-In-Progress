extends Node
## Online co-op connection. One player hosts and owns the garden; the other
## joins by address. Players are known by a small stable "slot" number
## (host = 1, guest = 2) so plants can remember who cared for them between
## sessions.

signal welcomed  # guest only: the host accepted us and gave us a slot
signal join_failed
signal player_joined(slot: int)
signal player_left(slot: int)
signal session_ended(was_host: bool)
signal player_state(slot: int, pos: Vector2, facing: Vector2i, moving: bool)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 2
const HOST_SLOT := 1
const JOIN_TIMEOUT := 8.0

var online: bool = false
var port: int = DEFAULT_PORT

var _slot: int = HOST_SLOT
var _peer_slots: Dictionary = {}  # network peer id -> slot
var _attempt: int = 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## The local player's slot (1 when playing alone, 0 while still joining).
func local_id() -> int:
	return _slot


## True when this game owns the garden: playing alone, or hosting.
func is_host() -> bool:
	return multiplayer.is_server()


## Slots of everyone currently in the garden.
func slots() -> Array:
	if not online:
		return [HOST_SLOT]
	return _peer_slots.values()


func slot_of(peer_id: int) -> int:
	return int(_peer_slots.get(peer_id, 0))


func peer_of(slot: int) -> int:
	for peer_id: int in _peer_slots.keys():
		if int(_peer_slots[peer_id]) == slot:
			return peer_id
	return 0


func host_game() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	_slot = HOST_SLOT
	_peer_slots = {1: HOST_SLOT}
	return OK


func join_game(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	_slot = 0
	_peer_slots = {}
	_attempt += 1
	var attempt: int = _attempt
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(func() -> void:
		if attempt == _attempt and online and _slot == 0:
			_reset()
			join_failed.emit())
	return OK


func leave() -> void:
	if not online:
		return
	var was_host: bool = is_host()
	_reset()
	session_ended.emit(was_host)


## Addresses a partner on the same network can use to join this computer.
func lan_addresses() -> Array[String]:
	var out: Array[String] = []
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		out.append(address)
	return out


## Tell the other players where our character is (called a few times a second).
func send_player_state(pos: Vector2, facing: Vector2i, moving: bool) -> void:
	if online and _slot != 0 and _peer_slots.size() > 1:
		_player_state.rpc(pos, facing, moving)


func _reset() -> void:
	_attempt += 1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	_slot = HOST_SLOT
	_peer_slots = {}


func _on_peer_connected(peer_id: int) -> void:
	if not online or not is_host():
		return
	var slot: int = 0
	for candidate in range(HOST_SLOT + 1, MAX_PLAYERS + 1):
		if not _peer_slots.values().has(candidate):
			slot = candidate
			break
	if slot == 0:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id)
		return
	_peer_slots[peer_id] = slot
	_welcome.rpc_id(peer_id, slot, _peer_slots)
	_set_roster.rpc(_peer_slots)
	player_joined.emit(slot)


func _on_peer_disconnected(peer_id: int) -> void:
	if not online or not is_host() or not _peer_slots.has(peer_id):
		return
	var slot: int = _peer_slots[peer_id]
	_peer_slots.erase(peer_id)
	_set_roster.rpc(_peer_slots)
	player_left.emit(slot)


func _on_connection_failed() -> void:
	_reset()
	join_failed.emit()


func _on_server_disconnected() -> void:
	var others: Array = _peer_slots.values()
	var mine: int = _slot
	_reset()
	for slot: int in others:
		if slot != mine:
			player_left.emit(slot)
	session_ended.emit(false)


@rpc("authority", "call_remote", "reliable")
func _welcome(slot: int, roster: Dictionary) -> void:
	_slot = slot
	_peer_slots = roster
	welcomed.emit()
	for other: int in roster.values():
		if other != slot:
			player_joined.emit(other)


@rpc("authority", "call_remote", "reliable")
func _set_roster(roster: Dictionary) -> void:
	if _slot == 0:
		return
	var before: Array = _peer_slots.values()
	var after: Array = roster.values()
	_peer_slots = roster
	for slot: int in after:
		if slot != _slot and not before.has(slot):
			player_joined.emit(slot)
	for slot: int in before:
		if slot != _slot and not after.has(slot):
			player_left.emit(slot)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector2, facing: Vector2i, moving: bool) -> void:
	var slot: int = slot_of(multiplayer.get_remote_sender_id())
	if slot != 0:
		player_state.emit(slot, pos, facing, moving)
