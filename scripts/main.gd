extends Node2D
## Builds the garden scene in code: ground, plants, player, camera, HUD.

const Ground := preload("res://scripts/ground.gd")
const PlantView := preload("res://scripts/plant_view.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Rain := preload("res://scripts/rain.gd")
const TILE := 16

var player: Node2D
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
	player.position = Vector2(21.5 * TILE, 5 * TILE)
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

	var hud := Hud.new()
	hud.player = player
	add_child(hud)

	GameState.plant_added.connect(_add_view)
	GameState.plant_removed.connect(_remove_view)
	GameState.plant_petted.connect(func(cell: Vector2i) -> void: _views[cell].show_love())
	GameState.cell_changed.connect(_refresh_view)
	GameState.day_advanced.connect(func(_s: Dictionary) -> void: _refresh_all())
	GameState.state_reloaded.connect(_rebuild_views)
	TimeManager.time_changed.connect(_update_light)
	_rebuild_views()
	_update_light()


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
