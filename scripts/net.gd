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
signal gardens_changed  # found_gardens changed while looking for hosts
signal internet_ready(address: String)  # the router opened a door for us; partners can use this address

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 2
const HOST_SLOT := 1
const JOIN_TIMEOUT := 8.0
const DISCOVERY_PORT := 24566  # hosts announce themselves here on the local network
const BEACON_TAG := "BLOOM1"
const BEACON_EVERY := 1.0
const FOUND_FOR := 4.0  # forget a host this long after its last announcement

var online: bool = false
var port: int = DEFAULT_PORT
## Ask the router (UPnP) to let a partner in from the internet while hosting.
var use_upnp: bool = true
## Hosts heard on the local network: address -> {"name", "port", "seen"}.
var found_gardens: Dictionary = {}
## This host's public address once the router has opened the port, else "".
var internet_address: String = ""

var _slot: int = HOST_SLOT
var _peer_slots: Dictionary = {}  # network peer id -> slot
var _attempt: int = 0
var _beacon: PacketPeerUDP
var _beacon_in: float = 0.0
var _listener: PacketPeerUDP
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port: int = 0


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
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon_in = 0.0
	if use_upnp and _upnp_thread == null:
		_upnp_thread = Thread.new()
		_upnp_thread.start(_open_router_port.bind(port))
	return OK


## `address` may end in ":port" for a host on a non-default port.
func join_game(address: String) -> Error:
	var host: String = address.strip_edges()
	var join_port: int = port
	var colon: int = host.rfind(":")
	if colon > 0 and host.count(":") == 1 and host.substr(colon + 1).is_valid_int():
		join_port = host.substr(colon + 1).to_int()
		host = host.left(colon)
	stop_discovery()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(host, join_port)
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


# ------------------------------------------------ finding each other

## Start listening for hosts on the local network (the Join screen does this).
func start_discovery() -> void:
	if _listener != null:
		return
	found_gardens.clear()
	_listener = PacketPeerUDP.new()
	if _listener.bind(DISCOVERY_PORT) != OK:
		_listener = null  # something else has the port; typing an address still works
	gardens_changed.emit()


func stop_discovery() -> void:
	if _listener != null:
		_listener.close()
		_listener = null


func _process(delta: float) -> void:
	if _beacon != null and online and is_host():
		_beacon_in -= delta
		if _beacon_in <= 0.0:
			_beacon_in = BEACON_EVERY
			var words: String = "%s|%d|%d|%s" % [BEACON_TAG, port, _peer_slots.size(), GameState.garden_name]
			# Everyone on the network, plus this computer for two copies on one machine.
			for target: String in ["255.255.255.255", "127.0.0.1"]:
				_beacon.set_dest_address(target, DISCOVERY_PORT)
				_beacon.put_packet(words.to_utf8_buffer())
	if _listener == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var changed: bool = false
	while _listener.get_available_packet_count() > 0:
		var parts: PackedStringArray = _listener.get_packet().get_string_from_utf8().split("|", true, 3)
		var from: String = _listener.get_packet_ip()
		if parts.size() != 4 or parts[0] != BEACON_TAG or not parts[1].is_valid_int() or not parts[2].is_valid_int():
			continue
		var known: bool = found_gardens.has(from)
		var entry: Dictionary = {"name": parts[3].left(24), "port": parts[1].to_int(), "full": parts[2].to_int() >= MAX_PLAYERS, "seen": now}
		if not known or found_gardens[from]["name"] != entry["name"] or found_gardens[from]["full"] != entry["full"]:
			changed = true
		found_gardens[from] = entry
	for address: String in found_gardens.keys():
		if now - float(found_gardens[address]["seen"]) > FOUND_FOR:
			found_gardens.erase(address)
			changed = true
	if changed:
		gardens_changed.emit()


## Runs on a thread: asks the home router to forward our port (UPnP) so a
## partner elsewhere can connect without anyone touching router settings.
func _open_router_port(host_port: int) -> void:
	var upnp := UPNP.new()
	var address: String = ""
	if upnp.discover(2000) == UPNP.UPNP_RESULT_SUCCESS and upnp.get_gateway() != null and upnp.get_gateway().is_valid_gateway():
		if upnp.add_port_mapping(host_port, host_port, "Bloom In Progress", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			address = upnp.query_external_address()
	_router_answered.call_deferred(upnp, host_port, address)


func _router_answered(upnp: UPNP, host_port: int, address: String) -> void:
	_upnp_thread.wait_to_finish()
	_upnp_thread = null
	if address == "":
		return
	if online and is_host():
		_upnp = upnp
		_upnp_port = host_port
		internet_address = address
		internet_ready.emit(address)
	else:
		upnp.delete_port_mapping(host_port, "UDP")  # we stopped hosting in the meantime


func _close_router_port() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(_upnp_port, "UDP")
		_upnp = null
	internet_address = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_router_port()


func _exit_tree() -> void:
	_close_router_port()
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()


func _reset() -> void:
	_attempt += 1
	_beacon = null
	_close_router_port()
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
