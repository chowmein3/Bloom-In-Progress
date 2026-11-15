extends Node2D
## A gardener. Origin is at the feet. The local one reads the keyboard and
## makes world changes through GameState.request_*(); a remote one (the
## partner in co-op) just follows the positions sent over the network.

const Assets := preload("res://scripts/assets.gd")

signal loadout_changed

const TILE := 16
const SPEED := 64.0
const TOOLS: Array[String] = ["Hoe", "Watering Can", "Seeds", "Hands", "Basket"]

var player_id: int = 1
var facing := Vector2i(0, 1)
var tool_index: int = 0
var seed_id: String = "sunpuff"
var frozen: bool = false  # during the night fade
var in_menu: bool = true  # until a game is started
var reading: bool = false  # while the journal is open
var is_remote: bool = false
var cursor: Node2D  # highlights the tile the player will act on

var _walk: float = 0.0
var _send_in: float = 0.0
var _remote_pos: Vector2
var _remote_moving: bool = false
var _texture: Texture2D
var _texture_slot: int = -1


func _ready() -> void:
	_remote_pos = position
	if not is_remote:
		GameState.register_player(player_id)


## Latest position of a remote player, from the network.
func remote_update(pos: Vector2, new_facing: Vector2i, moving: bool) -> void:
	_remote_pos = pos
	_remote_moving = moving
	if new_facing != facing:
		facing = new_facing
		queue_redraw()


func cell() -> Vector2i:
	return Vector2i(int(floor(position.x / TILE)), int(floor((position.y - 1.0) / TILE)))


func target_cell() -> Vector2i:
	return cell() + facing


func _process(delta: float) -> void:
	# Players in bed are inside the tent.
	visible = not GameState.is_sleeping(player_id)
	if is_remote:
		position = position.lerp(_remote_pos, minf(1.0, delta * 15.0))
		if _remote_moving:
			_walk += delta
			queue_redraw()
		return
	var busy: bool = frozen or in_menu or reading or not visible
	var dir := Vector2.ZERO
	if not busy:
		dir = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	_send_in -= delta
	if _send_in <= 0.0:
		_send_in = 0.05
		Net.send_player_state(position, facing, dir != Vector2.ZERO)
	if busy:
		if cursor != null:
			cursor.visible = false
		return
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing = Vector2i(int(signf(dir.x)), 0)
		else:
			facing = Vector2i(0, int(signf(dir.y)))
		var step: Vector2 = dir.normalized() * SPEED * delta
		_try_move(Vector2(step.x, 0))
		_try_move(Vector2(0, step.y))
		_walk += delta
		queue_redraw()
	elif _walk != 0.0:
		_walk = 0.0
		queue_redraw()
	if cursor != null:
		cursor.position = Vector2(target_cell() * TILE)
		cursor.visible = GameState.in_bounds(target_cell())


func _try_move(step: Vector2) -> void:
	var world: Vector2 = Vector2(GameState.WORLD_SIZE * TILE)
	var np: Vector2 = position + step
	np.x = clampf(np.x, 5.0, world.x - 5.0)
	np.y = clampf(np.y, 8.0, world.y)
	var c := Vector2i(int(floor(np.x / TILE)), int(floor((np.y - 1.0) / TILE)))
	if GameState.is_blocked(c):
		return
	position = np


func _unhandled_input(event: InputEvent) -> void:
	if is_remote or frozen or in_menu or reading:
		return
	if GameState.is_sleeping(player_id):
		if event.is_action_pressed("use"):
			GameState.request_sleep(player_id)  # get back up
		return
	if event.is_action_pressed("use"):
		use_tool()
	elif event.is_action_pressed("next_seed"):
		cycle_seed()
	elif event.is_action_pressed("cycle_tool"):
		select_tool((tool_index + 1) % TOOLS.size())
	else:
		for i in TOOLS.size():
			if event.is_action_pressed("tool_%d" % (i + 1)):
				select_tool(i)


func select_tool(index: int) -> void:
	tool_index = index
	loadout_changed.emit()


func cycle_seed() -> void:
	var ids: Array = GameState.species.keys()
	var start: int = ids.find(seed_id)
	# Prefer the next species we actually have seeds for.
	for i in range(1, ids.size() + 1):
		var id: String = ids[(start + i) % ids.size()]
		if GameState.seed_count(id) > 0:
			seed_id = id
			break
	tool_index = 2
	loadout_changed.emit()


func use_tool() -> void:
	var target: Vector2i = target_cell()
	if GameState.is_tent(target):
		GameState.request_sleep(player_id)
		return
	if GameState.is_tree(target) and tool_index != 1 and tool_index != 3:
		GameState.notice.emit("The Heart Tree likes water (2) and hugs (4)")
		return
	match tool_index:
		0: GameState.request_till(player_id, target)
		1: GameState.request_water(player_id, target)
		2: GameState.request_plant(player_id, target, seed_id)
		3: GameState.request_pet(player_id, target)
		4: GameState.request_harvest(player_id, target)


## Sprite sheet: assets/sprites/player_<slot>.png, 16x24 frames, 2 columns
## (standing, stepping) by 4 rows (facing down, up, left, right).
func _draw() -> void:
	if _texture == null or _texture_slot != player_id:
		_texture_slot = player_id
		_texture = Assets.texture("res://assets/sprites/player_%d.png" % clampi(player_id, 1, 2))
	var row: int = 0
	if facing == Vector2i(0, -1):
		row = 1
	elif facing.x < 0:
		row = 2
	elif facing.x > 0:
		row = 3
	var column: int = int(_walk * 8.0) % 2
	draw_rect(Rect2(-5, -2, 10, 3), Color(0, 0, 0, 0.18))  # shadow
	draw_texture_rect_region(_texture, Rect2(-8, -23, 16, 24), Rect2(column * 16, row * 24, 16, 24))
