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
signal player_state(slot: int, pos: Vector2, facing: Vector2i, moving: bool, tool: int, swings: int)
signal names_changed  # someone told us their name
signal emote(slot: int, index: int)
signal chat(slot: int, text: String)
signal relay_ready  # host: the garden is open on the relay; partners can join by invite code
signal relay_failed(reason: String)  # host: the relay could not be reached or refused us
signal open_gardens_changed  # open_gardens changed while looking up invite codes
signal gardens_changed  # found_gardens changed while looking for hosts
signal internet_ready(address: String)  # the router opened a door for us; partners can use this address

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 2
const HOST_SLOT := 1
const RelayPeer := preload("res://scripts/relay_peer.gd")
const Settings := preload("res://scripts/settings.gd")
const JOIN_TIMEOUT := 8.0
const RELAY_JOIN_TIMEOUT := 75.0  # a sleeping free relay can take a minute to wake
const RELAY_RETRIES := 6
const LOOKUP_EVERY := 4.0
const DISCOVERY_PORT := 24566  # hosts announce themselves here on the local network
const BEACON_TAG := "BLOOM1"
const BEACON_EVERY := 1.0
const FOUND_FOR := 4.0  # forget a host this long after its last announcement

var online: bool = false
var port: int = DEFAULT_PORT
## What each player calls themselves: slot -> name.
var names: Dictionary = {}
## This player's name, from the settings screen.
var my_name: String = str(Settings.read().get("name", "Gardener"))
## Address of the relay server (relay/server.js) that lets partners connect
## with an invite code and no router setup. "" = not set up; co-op then uses
## the local network or a typed address. Set in project.godot: bloom/relay_url.
var relay_url: String = str(ProjectSettings.get_setting("bloom/relay_url", ""))
## True while the current session runs through the relay.
var via_relay: bool = false
## Gardens open on the relay right now, among the codes passed to
## start_lookup(): code -> {"name", "full"}.
var open_gardens: Dictionary = {}
## Why the last join attempt failed: "", not_open, full, bad_code, unreachable, timeout.
var last_join_error: String = ""
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
var _relay_code: String = ""
var _relay_name: String = ""
var _relay_tries: int = 0
var _relay_retry_in: float = -1.0
var _lookup: WebSocketPeer
var _lookup_codes: Array = []
var _lookup_in: float = 0.0
var _lookup_once: bool = false
var _upnp: UPNP
var _upnp_thread: Thread
var _upnp_port: int = 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if relay_enabled():
		start_lookup([])  # wakes a sleeping relay early; the Join screen passes real codes
		_lookup_once = true


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


func relay_enabled() -> bool:
	return relay_url.strip_edges() != ""


## Host through the relay: partners join with the garden's invite code from
## anywhere. Play starts at once; relay_ready or relay_failed follows.
func host_online(code: String, garden_name: String) -> Error:
	_relay_code = code
	_relay_name = garden_name
	_relay_tries = 0
	return _open_relay_room()


func _open_relay_room() -> Error:
	var peer := RelayPeer.new()
	var err: Error = peer.start_host(_relay_socket_url(), _relay_code, _relay_name)
	if err != OK:
		return err
	peer.opened.connect(func() -> void:
		_relay_tries = 0
		relay_ready.emit())
	peer.failed.connect(_on_relay_host_failed)
	multiplayer.multiplayer_peer = peer
	online = true
	via_relay = true
	_slot = HOST_SLOT
	_peer_slots = {1: HOST_SLOT}
	return OK


func _on_relay_host_failed(reason: String) -> void:
	# Carry on playing alone; try the relay again a few times in the background.
	for peer_id: int in _peer_slots.keys():
		if peer_id != 1:
			var slot: int = _peer_slots[peer_id]
			_peer_slots.erase(peer_id)
			player_left.emit(slot)
	var code: String = _relay_code
	var garden_name: String = _relay_name
	var tries: int = _relay_tries
	_reset()
	_relay_code = code
	_relay_name = garden_name
	_relay_tries = tries + 1
	if (reason == "unreachable" or reason == "lost") and _relay_tries <= RELAY_RETRIES:
		_relay_retry_in = 5.0
	else:
		_relay_code = ""
	relay_failed.emit(reason)


## Join a partner's garden by its invite code, through the relay.
func join_online(code: String) -> Error:
	stop_discovery()
	stop_lookup()
	last_join_error = ""
	var peer := RelayPeer.new()
	var err: Error = peer.start_join(_relay_socket_url(), code)
	if err != OK:
		return err
	peer.failed.connect(func(reason: String) -> void:
		if online and not is_host():
			var joining: bool = _slot == 0
			var others: Array = _peer_slots.values()
			var mine: int = _slot
			_reset()
			if joining:
				last_join_error = reason
				join_failed.emit()
			else:
				for slot: int in others:
					if slot != mine:
						player_left.emit(slot)
				session_ended.emit(false))
	multiplayer.multiplayer_peer = peer
	online = true
	via_relay = true
	_slot = 0
	_peer_slots = {}
	_start_join_timer(RELAY_JOIN_TIMEOUT)
	return OK


func _relay_socket_url() -> String:
	var url: String = relay_url.strip_edges()
	if url.begins_with("https://"):
		return "wss://" + url.trim_prefix("https://")
	if url.begins_with("http://"):
		return "ws://" + url.trim_prefix("http://")
	return url


## Keep asking the relay which of these invite codes are open right now
## (the Join screen uses this to light up a partner's garden).
func start_lookup(codes: Array) -> void:
	_lookup_codes = codes
	_lookup_once = false
	if not relay_enabled() or _lookup != null:
		return
	_lookup = WebSocketPeer.new()
	_lookup_in = 0.0
	if _lookup.connect_to_url(_relay_socket_url()) != OK:
		_lookup = null


func stop_lookup() -> void:
	if _lookup != null:
		_lookup.close()
		_lookup = null
	if not open_gardens.is_empty():
		open_gardens = {}
		open_gardens_changed.emit()


func _poll_lookup(delta: float) -> void:
	_lookup.poll()
	var state: WebSocketPeer.State = _lookup.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_lookup = null
		if not _lookup_once:
			start_lookup(_lookup_codes)  # the relay may still be waking; try again
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	while _lookup.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_lookup.get_packet().get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("t", "")) != "found":
			continue
		var now_open: Dictionary = {}
		for room: Variant in parsed.get("rooms", []):
			if typeof(room) == TYPE_DICTIONARY:
				now_open[str(room.get("code", ""))] = {"name": str(room.get("name", "")).left(24), "full": bool(room.get("full", false))}
		if now_open != open_gardens:
			open_gardens = now_open
			open_gardens_changed.emit()
		if _lookup_once:
			_lookup.close()
			_lookup = null
			return
	_lookup_in -= delta
	if _lookup_in <= 0.0:
		_lookup_in = LOOKUP_EVERY
		_lookup.send_text(JSON.stringify({"t": "find", "codes": _lookup_codes}))


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
	stop_lookup()
	last_join_error = ""
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(host, join_port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	_slot = 0
	_peer_slots = {}
	_start_join_timer(JOIN_TIMEOUT)
	return OK


func _start_join_timer(seconds: float) -> void:
	_attempt += 1
	var attempt: int = _attempt
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if attempt == _attempt and online and _slot == 0:
			_reset()
			last_join_error = "timeout"
			join_failed.emit())


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
func send_player_state(pos: Vector2, facing: Vector2i, moving: bool, tool: int = 0, swings: int = 0) -> void:
	if online and _slot != 0 and _peer_slots.size() > 1:
		_player_state.rpc(pos, facing, moving, tool, swings)


## The name to show for a player.
func name_of_slot(slot: int) -> String:
	if slot == _slot:
		return my_name
	return str(names.get(slot, "Your partner"))


## Tell everyone our name (after joining, or when someone new arrives).
func announce() -> void:
	if online and _slot != 0 and _peer_slots.size() > 1:
		_hello.rpc(my_name)


## Show an emote above our head, here and for our partner.
func send_emote(index: int) -> void:
	emote.emit(local_id(), index)
	if online and _slot != 0 and _peer_slots.size() > 1:
		_emote.rpc(index)


func send_chat(text: String) -> void:
	chat.emit(local_id(), text.left(60))
	if online and _slot != 0 and _peer_slots.size() > 1:
		_chat.rpc(text.left(60))


@rpc("any_peer", "call_remote", "reliable")
func _hello(their_name: String) -> void:
	var slot: int = slot_of(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	var is_new: bool = not names.has(slot)
	names[slot] = their_name.strip_edges().left(16) if their_name.strip_edges() != "" else "Gardener"
	names_changed.emit()
	if is_new:
		announce()  # so a newcomer learns our name too


@rpc("any_peer", "call_remote", "reliable")
func _emote(index: int) -> void:
	var slot: int = slot_of(multiplayer.get_remote_sender_id())
	if slot != 0 and index >= 0 and index < 6:
		emote.emit(slot, index)


@rpc("any_peer", "call_remote", "reliable")
func _chat(text: String) -> void:
	var slot: int = slot_of(multiplayer.get_remote_sender_id())
	if slot != 0:
		chat.emit(slot, text.left(60))


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
	if _lookup != null:
		_poll_lookup(delta)
	if _relay_retry_in > 0.0:
		_relay_retry_in -= delta
		if _relay_retry_in <= 0.0 and not online and _relay_code != "":
			_open_relay_room()
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
	names = {}
	via_relay = false
	_relay_code = ""
	_relay_retry_in = -1.0
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
	if via_relay:
		return  # the relay peer reports its own failures, with a reason
	_reset()
	last_join_error = "unreachable"
	join_failed.emit()


func _on_server_disconnected() -> void:
	if via_relay:
		return  # handled by the relay peer's `failed`
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
	announce()
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
func _player_state(pos: Vector2, facing: Vector2i, moving: bool, tool: int, swings: int) -> void:
	var slot: int = slot_of(multiplayer.get_remote_sender_id())
	if slot != 0:
		player_state.emit(slot, pos, facing, moving, tool, swings)
