extends Node2D
## Builds the garden scene in code: ground, plants, players, camera, HUD and
## the start menu, and starts solo / hosted / joined games.
##
## To skip the menu, pass a mode after "--" on the command line:
##   godot --path . -- --solo | --host | --join=192.168.1.20

const Ground := preload("res://scripts/ground.gd")
const PlantView := preload("res://scripts/plant_view.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Rain := preload("res://scripts/rain.gd")
const Menu := preload("res://scripts/menu.gd")
const TILE := 16

var player: Node2D
var hud: CanvasLayer
var menu: CanvasLayer
var remote_players: Dictionary = {}  # slot -> Player node
var _entities: Node2D
var _views: Dictionary = {}  # Vector2i -> PlantView
var _light: CanvasModulate


func _ready() -> void:
	_setup_input()
	add_child(Ground.new())

	var cursor := ColorRect.new()
	cursor.color = Color(1, 1, 1, 0.22)
	cursor.size = Vector2(TILE, TILE)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cursor_holder := Node2D.new()
	cursor_holder.add_child(cursor)
	add_child(cursor_holder)

	# Plants and players share a y-sorted layer so you can walk behind plants.
	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)

	player = Player.new()
	player.player_id = Net.local_id()
	player.cursor = cursor_holder
	player.position = Vector2(13.5 * TILE, 5 * TILE)
	_entities.add_child(player)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = GameState.WORLD_SIZE.x * TILE
	camera.limit_bottom = GameState.WORLD_SIZE.y * TILE
	player.add_child(camera)

	_light = CanvasModulate.new()
	add_child(_light)

	var rain_layer := CanvasLayer.new()
	rain_layer.layer = 5
	rain_layer.add_child(Rain.new())
	add_child(rain_layer)

	hud = Hud.new()
	hud.player = player
	add_child(hud)

	menu = Menu.new()
	add_child(menu)
	menu.solo_pressed.connect(start_solo)
	menu.host_pressed.connect(start_host)
	menu.join_pressed.connect(start_join)
	Net.welcomed.connect(_on_welcomed)
	Net.join_failed.connect(_on_join_failed)
	Net.session_ended.connect(_on_session_ended)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.player_state.connect(_on_player_state)
	TimeManager.paused = true  # the clock waits behind the menu
	hud.visible = false

	GameState.plant_added.connect(_add_view)
	GameState.plant_removed.connect(_remove_view)
	GameState.plant_petted.connect(func(cell: Vector2i) -> void:
		if _views.has(cell):
			_views[cell].show_love())
	GameState.cell_changed.connect(_refresh_view)
	GameState.day_advanced.connect(func(_s: Dictionary) -> void: _refresh_all())
	GameState.state_reloaded.connect(_rebuild_views)
	TimeManager.time_changed.connect(_update_light)
	_rebuild_views()
	_update_light()

	for arg: String in OS.get_cmdline_user_args():
		if arg == "--solo":
			start_solo()
		elif arg == "--host":
			start_host()
		elif arg.begins_with("--join="):
			start_join(arg.trim_prefix("--join="))


# ------------------------------------------------------------ starting play

func start_solo() -> void:
	_begin()


func start_host() -> void:
	var err: Error = Net.host_game()
	if err != OK:
		menu.call("set_status", "Couldn't host. Is another copy already hosting?")
		return
	_begin()
	var addresses: Array[String] = Net.lan_addresses()
	var where: String = addresses[0] if not addresses.is_empty() else "this computer's address"
	hud.call("set_status", "Hosting. Partner joins:\n%s" % where)
	hud.call("show_message", "Your garden is open. Waiting for your partner...", 6.0)


func start_join(address: String) -> void:
	if Net.join_game(address) != OK:
		menu.call("set_status", "That address doesn't look right")
		return
	menu.call("set_status", "Knocking on the garden gate...")
	menu.call("set_busy", true)


func _begin() -> void:
	menu.visible = false
	hud.visible = true
	menu.call("set_busy", false)
	menu.call("set_status", "")
	player.set("player_id", Net.local_id())
	player.set("in_menu", false)
	player.queue_redraw()
	# Only the garden's owner runs the clock; a guest follows the host's.
	TimeManager.paused = not Net.is_host()
	hud.call("set_status", "")
	hud.call("refresh")


func _on_welcomed() -> void:
	player.position = Vector2(15.5 * TILE, 5 * TILE)
	_begin()
	hud.call("set_status", "Visiting partner's garden")


func _on_join_failed() -> void:
	menu.call("set_busy", false)
	menu.call("set_status", "Couldn't reach that garden. Check the address\nand that your partner is hosting.")


func _on_session_ended(was_host: bool) -> void:
	for slot: int in remote_players.keys():
		remote_players[slot].queue_free()
	remote_players.clear()
	if was_host:
		return
	player.set("player_id", Net.local_id())
	player.set("in_menu", true)
	TimeManager.paused = true
	menu.visible = true
	hud.visible = false
	menu.call("set_busy", false)
	menu.call("set_status", "The connection to your partner's garden was lost")


func _on_player_joined(slot: int) -> void:
	if remote_players.has(slot):
		return
	var other: Node2D = Player.new()
	other.is_remote = true
	other.player_id = slot
	other.position = Vector2(14.5 * TILE, 5 * TILE)
	_entities.add_child(other)
	remote_players[slot] = other
	hud.call("show_message", "Your partner is here!", 4.0)
	if Net.is_host():
		hud.call("set_status", "Partner connected")


func _on_player_left(slot: int) -> void:
	if not remote_players.has(slot):
		return
	remote_players[slot].queue_free()
	remote_players.erase(slot)
	hud.call("show_message", "Your partner left the garden", 4.0)
	if Net.online and Net.is_host():
		hud.call("set_status", "Hosting. Waiting for partner")


func _on_player_state(slot: int, pos: Vector2, facing: Vector2i, moving: bool) -> void:
	if remote_players.has(slot):
		remote_players[slot].call("remote_update", pos, facing, moving)


func _rebuild_views() -> void:
	for cell: Vector2i in _views.keys():
		_views[cell].queue_free()
	_views.clear()
	for cell: Vector2i in GameState.plants.keys():
		_add_view(cell)


func _add_view(cell: Vector2i) -> void:
	var view := PlantView.new()
	view.cell = cell
	view.position = Vector2(cell * TILE) + Vector2(8, 15)
	_entities.add_child(view)
	_views[cell] = view


func _remove_view(cell: Vector2i) -> void:
	if _views.has(cell):
		_views[cell].queue_free()
		_views.erase(cell)


func _refresh_view(cell: Vector2i) -> void:
	if _views.has(cell):
		_views[cell].refresh()


func _refresh_all() -> void:
	for cell: Vector2i in _views.keys():
		_views[cell].refresh()


## Warm daylight, purple dusk from 5pm, blue night from 8pm.
func _update_light() -> void:
	var m: float = float(TimeManager.minutes)
	var day := Color(1, 1, 1)
	var dusk := Color(0.85, 0.7, 0.85)
	var night := Color(0.45, 0.5, 0.78)
	var color: Color = day
	if m >= 20 * 60:
		color = dusk.lerp(night, clampf((m - 20 * 60) / 120.0, 0.0, 1.0))
	elif m >= 17 * 60:
		color = day.lerp(dusk, (m - 17 * 60) / 180.0)
	if TimeManager.raining:
		color = color * Color(0.82, 0.86, 0.95)
	_light.color = color


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("use", [KEY_SPACE, KEY_E])
	_bind("next_seed", [KEY_Q])
	_bind("cycle_tool", [KEY_TAB])
	_bind("toggle_help", [KEY_H])
	for i in 5:
		_bind("tool_%d" % (i + 1), [KEY_1 + i])


func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key as Key
		InputMap.action_add_event(action, event)
