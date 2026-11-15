extends Node2D
## A gardener. Origin is at the feet. The local one reads the keyboard and
## makes world changes through GameState.request_*(); a remote one (the
## partner in co-op) just follows the positions sent over the network.
##
## The inside of the home is far off to the right of the garden in the same
## space, so going indoors is a jump in position (see GameState.INTERIOR_ORIGIN).

const Assets := preload("res://scripts/assets.gd")

signal loadout_changed
signal area_changed  # stepped indoors or back out
signal shop_requested  # used the shopkeeper's stall
signal clock_requested  # used the clock tower

const TILE := 16
const SPEED := 64.0
const SPRINT := 1.75  # times faster while Shift is held
const WALK_CYCLE: Array[int] = [1, 0, 2, 0]  # sheet columns: left foot, together, right foot, together
const TOOLS: Array[String] = ["Hoe", "Watering Can", "Seeds", "Hands", "Basket"]
## Points around the feet that must all be on walkable tiles.
const FOOTPRINT: Array[Vector2] = [Vector2(-4, -1), Vector2(4, -1), Vector2(-4, -6), Vector2(4, -6)]

var player_id: int = 1
var facing := Vector2i(0, 1)
var tool_index: int = 0
var seed_id: String = "sunpuff"
var frozen: bool = false  # during the night fade
var in_menu: bool = true  # until a game is started
var reading: bool = false  # while the journal, backpack or shop is open
var is_remote: bool = false
var cursor: Node2D  # highlights the tile the player will act on

var _walk: float = 0.0
var _send_in: float = 0.0
var _remote_pos: Vector2
var _remote_moving: bool = false
var _remote_sprinting: bool = false
var _texture: Texture2D
var _texture_slot: int = -1
var _hats: Texture2D


func _ready() -> void:
	_remote_pos = position
	_hats = Assets.texture("res://assets/sprites/hats.png")
	GameState.economy_changed.connect(queue_redraw)
	GameState.state_reloaded.connect(queue_redraw)
	if not is_remote:
		GameState.register_player(player_id)


## Latest position of a remote player, from the network.
func remote_update(pos: Vector2, new_facing: Vector2i, moving: bool) -> void:
	_remote_sprinting = moving and pos.distance_to(_remote_pos) > SPEED * 0.05 * 1.3
	_remote_pos = pos
	_remote_moving = moving
	if new_facing != facing:
		facing = new_facing
		queue_redraw()


func cell() -> Vector2i:
	return _cell_at(position + Vector2(0, -1))


func target_cell() -> Vector2i:
	return cell() + facing


func indoors() -> bool:
	return GameState.is_indoors(cell())


func _cell_at(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / TILE)), int(floor(point.y / TILE)))


func _process(delta: float) -> void:
	# Players in bed are drawn by the bed (bed_view.gd), tucked in.
	visible = not GameState.is_sleeping(player_id)
	if is_remote:
		if position.distance_to(_remote_pos) > 48.0:
			position = _remote_pos  # they went through the door
		else:
			position = position.lerp(_remote_pos, minf(1.0, delta * 15.0))
		if _remote_moving:
			_walk += delta * (SPRINT if _remote_sprinting else 1.0)
			queue_redraw()
		elif _walk != 0.0:
			_walk = 0.0
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
		var pace: float = SPRINT if Input.is_action_pressed("sprint") else 1.0
		var step: Vector2 = dir.normalized() * SPEED * pace * delta
		_try_move(Vector2(step.x, 0))
		if not _try_move(Vector2(0, step.y)):
			# Walking into the home's door goes in; walking down off the mat goes out.
			if step.y < 0.0 and not indoors() and _cell_at(position + Vector2(0, step.y - 6.0)) == GameState.home_door():
				go_inside()
			elif step.y > 0.0 and indoors() and GameState.is_exit_mat(cell()):
				go_outside()
		_walk += delta * pace
		queue_redraw()
	elif _walk != 0.0:
		_walk = 0.0
		queue_redraw()
	if cursor != null:
		cursor.position = Vector2(target_cell() * TILE)
		cursor.visible = GameState.in_bounds(target_cell())


func _try_move(step: Vector2) -> bool:
	var to: Vector2 = position + step
	for corner: Vector2 in FOOTPRINT:
		if not GameState.can_walk(_cell_at(to + corner)):
			return false
	position = to
	return true


## Step through the door onto the mat inside.
func go_inside() -> void:
	var floor: Rect2i = GameState.room_floor()
	position = Vector2((floor.position.x + floor.size.x / 2.0) * TILE, floor.end.y * TILE - 2.0)
	facing = Vector2i.UP
	_arrived()


## Step out to just below the home's door.
func go_outside() -> void:
	var door: Vector2i = GameState.home_door()
	position = Vector2((door.x + 0.5) * TILE, (door.y + 1) * TILE + 10.0)
	facing = Vector2i.DOWN
	_arrived()


## Stand beside the bed (where you wake after dozing off outdoors).
func go_to_bedside() -> void:
	var bed: Rect2i = GameState.bed_rect()
	position = Vector2((bed.end.x + 0.5) * TILE, bed.end.y * TILE - 4.0)
	facing = Vector2i.LEFT
	_arrived()


func _arrived() -> void:
	_remote_pos = position
	queue_redraw()
	Net.send_player_state(position, facing, false)
	area_changed.emit()


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


## Hold these seeds (from the backpack) and switch to the seed tool.
func hold_seed(id: String) -> void:
	seed_id = id
	select_tool(2)


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
	if indoors():
		if GameState.is_bed(target):
			GameState.request_sleep(player_id)
		elif facing == Vector2i.DOWN and GameState.is_exit_mat(cell()):
			go_outside()
		return
	if GameState.is_tent(target):
		go_inside()
		return
	if GameState.is_stall(target):
		shop_requested.emit()
		return
	if GameState.is_tower(target):
		clock_requested.emit()
		return
	if GameState.is_tree(target) and tool_index != 1 and tool_index != 3:
		GameState.notice.emit("The Heart Tree likes water (2) and hugs (4)")
		return
	match tool_index:
		0: GameState.request_till(player_id, target, facing)
		1: GameState.request_water(player_id, target, facing)
		2: GameState.request_plant(player_id, target, seed_id)
		3: GameState.request_pet(player_id, target)
		4: GameState.request_harvest(player_id, target)


## Sprite sheet: assets/sprites/player_<slot>.png, 16x24 frames, 3 columns
## (standing, left foot, right foot) by rows facing down, up, left, right
## (then asleep).
## The hat being worn is drawn on top from assets/sprites/hats.png.
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
	var column: int = WALK_CYCLE[int(_walk * 9.0) % WALK_CYCLE.size()] if _walk > 0.0 else 0
	draw_rect(Rect2(-5, -2, 10, 3), Color(0, 0, 0, 0.18))  # shadow
	draw_texture_rect_region(_texture, Rect2(-8, -23, 16, 24), Rect2(column * 16, row * 24, 16, 24))
	var hat: int = GameState.HAT_ORDER.find(GameState.hat_of(player_id))
	if hat >= 0 and _hats != null:
		draw_texture_rect_region(_hats, Rect2(-8, -23, 16, 12), Rect2(hat * 16, 0, 16, 12))
