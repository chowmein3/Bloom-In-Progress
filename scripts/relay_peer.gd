extends MultiplayerPeerExtension
## A two-player network connection that goes through the relay server in
## relay/server.js. Both games connect out to the relay, so no router setup
## or IP address is needed. The host is always peer 1 and the guest peer 2.
##
## Use start_host() or start_join(), hand the peer to
## multiplayer.multiplayer_peer, and watch `ready_changed` / `failed`.

signal opened  # host: the relay accepted our room; guest: we are in the room
signal failed(reason: String)  # not_open, full, already_hosted, unreachable, ...

const HOST_ID := 1
const GUEST_ID := 2

var garden_name: String = ""  # guest: the host's garden name, once joined

var _socket := WebSocketPeer.new()
var _hosting: bool = false
var _hello: Dictionary = {}
var _said_hello: bool = false
var _status: MultiplayerPeer.ConnectionStatus = MultiplayerPeer.CONNECTION_DISCONNECTED
var _incoming: Array[PackedByteArray] = []
var _partner_here: bool = false
var _refusing: bool = false
var _channel: int = 0
var _mode: MultiplayerPeer.TransferMode = MultiplayerPeer.TRANSFER_MODE_RELIABLE


func start_host(url: String, code: String, room_name: String) -> Error:
	_hosting = true
	_hello = {"t": "host", "code": code, "name": room_name}
	return _connect(url)


func start_join(url: String, code: String) -> Error:
	_hosting = false
	_hello = {"t": "join", "code": code}
	return _connect(url)


func _connect(url: String) -> Error:
	_socket.inbound_buffer_size = 1 << 20
	_socket.outbound_buffer_size = 1 << 20
	var err: Error = _socket.connect_to_url(url)
	if err == OK:
		_status = MultiplayerPeer.CONNECTION_CONNECTING
	return err


func _other() -> int:
	return GUEST_ID if _hosting else HOST_ID


func _fail(reason: String) -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var was_linked: bool = _partner_here
	_partner_here = false
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_socket.close()
	if was_linked:
		peer_disconnected.emit(_other())
	failed.emit(reason)


func _poll() -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	_socket.poll()
	var state: WebSocketPeer.State = _socket.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSED:
		_fail("unreachable" if not _said_hello or _status == MultiplayerPeer.CONNECTION_CONNECTING else "lost")
		return
	if state != WebSocketPeer.STATE_OPEN:
		return
	if not _said_hello:
		_said_hello = true
		_socket.send_text(JSON.stringify(_hello))
	while _socket.get_available_packet_count() > 0:
		var data: PackedByteArray = _socket.get_packet()
		if _socket.was_string_packet():
			_on_message(data.get_string_from_utf8())
		elif _partner_here:
			_incoming.append(data)


func _on_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	match str(message.get("t", "")):
		"hosting":
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			opened.emit()
		"joined":
			garden_name = str(message.get("name", ""))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			_partner_here = true
			opened.emit()
			peer_connected.emit(HOST_ID)
		"peer_joined":
			if _refusing:
				return
			_partner_here = true
			_incoming.clear()
			peer_connected.emit(GUEST_ID)
		"peer_left":
			if _hosting:
				if _partner_here:
					_partner_here = false
					_incoming.clear()
					peer_disconnected.emit(GUEST_ID)
			else:
				_fail("lost")
		"error":
			_fail(str(message.get("reason", "unknown")))


# ------------------------------------------- MultiplayerPeer interface

func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	return _incoming.pop_front() if not _incoming.is_empty() else PackedByteArray()


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if not _partner_here or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	return _socket.send(buffer, WebSocketPeer.WRITE_MODE_BINARY)


func _get_max_packet_size() -> int:
	return 1 << 18


func _get_packet_peer() -> int:
	return _other()


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_target_peer(_peer: int) -> void:
	pass  # there is only ever one other player


func _is_server() -> bool:
	return _hosting


func _get_unique_id() -> int:
	return HOST_ID if _hosting else GUEST_ID


func _is_server_relay_supported() -> bool:
	return false


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _disconnect_peer(_peer: int, _force: bool) -> void:
	if not _hosting:
		_close()


func _close() -> void:
	_partner_here = false
	_incoming.clear()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	_socket.close()
