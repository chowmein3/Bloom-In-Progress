extends Node2D
## A gardener. Origin is at the feet. The local one reads the keyboard and
## makes world changes through GameState.request_*(); a remote one (the
## partner in co-op) just follows the positions sent over the network.
##
## The inside of the home is far off to the right of the garden in the same
## space, so going indoors is a jump in position (see GameState.INTERIOR_ORIGIN).

const Assets := preload("res://scripts/assets.gd")
const Effects := preload("res://scripts/effects.gd")
const Settings := preload("res://scripts/settings.gd")
const ToolArt := preload("res://scripts/tool_art.gd")

signal loadout_changed
signal area_changed  # stepped indoors or back out
signal shop_requested  # used the shopkeeper's stall
signal clock_requested  # used the clock tower
signal bin_requested  # opened the shipping bin
signal bake_requested  # used the oven
signal mail_requested
signal board_requested
signal villager_requested  # spoke to today's visitor
signal fish_requested  # cast the rod into the pond
signal acted  # swung a tool or used a hand (for the little animation)

const TILE := 16
const SPEED := 64.0
const SPRINT := 1.75  # times faster while Shift is held
const WALK_CYCLE: Array[int] = [0, 1, 2, 3]  # neutral, stride A, neutral, stride B
const TOOLS: Array[String] = ["Hoe", "Watering Can", "Seeds", "Item", "Fishing Rod", "Pickaxe", "Axe"]
const PICK_TOOL := 5
const AXE_TOOL := 6
const ITEM_TOOL := 3  # the slot that holds something from the backpack
const ROD_TOOL := 4
## Points around the feet that must all be on walkable tiles.
const FOOTPRINT: Array[Vector2] = [Vector2(-4, -1), Vector2(4, -1), Vector2(-4, -6), Vector2(4, -6)]

var player_id: int = 1
var facing := Vector2i(0, 1)
var tool_index: int = 0
var seed_id: String = "sunpuff"
var item_id: String = ""  # the placeable thing or meal in the item slot
## The hot bar: the first four slots of this player's bag (keys 7, 8, 9, 0),
## filled by dragging things there in the backpack.
var quick: Array:
	get: return GameState.bag_slots().slice(0, GameState.HOT_SLOTS)
var quick_index: int = -1  # which hot bar slot is in hand, or -1
var _last_cell := Vector2i(-999, -999)  # to pick up dropped things once per step onto them
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
var _lunge: float = 0.0  # 1 -> 0 after using a tool or hand
var _swings: int = 0  # how many times we have acted; sent so partners see it
var _acted_with: int = -1  # the tool just used, or -1 for a bare hand
var _swing: float = 0.0  # 1 -> 0 while a tool is being swung (or the can poured)
var _swing_tool: int = -1
var _tools: Texture2D
var _emote: int = -1
var _emote_time: float = 0.0
var _icons: Texture2D


func _ready() -> void:
	_remote_pos = position
	_hats = Assets.texture("res://assets/sprites/hats.png")
	GameState.economy_changed.connect(queue_redraw)
	GameState.state_reloaded.connect(queue_redraw)
	_icons = Assets.texture("res://assets/sprites/ui_icons.png")
	Net.names_changed.connect(queue_redraw)
	Net.emote.connect(func(slot: int, index: int) -> void:
		if slot == player_id:
			_emote = index
			_emote_time = 2.5)
	_tools = Assets.texture("res://assets/sprites/tools.png")
	acted.connect(func() -> void:
		_lunge = 1.0
		_swings += 1
		_start_swing(_acted_with))
	if not is_remote:
		GameState.register_player(player_id)


## Latest position of a remote player, from the network.
func remote_update(pos: Vector2, new_facing: Vector2i, moving: bool, tool: int = 0, swings: int = 0) -> void:
	if swings != _swings:
		_swings = swings
		_lunge = 1.0  # they just used a tool or their hand
		_start_swing(swings % 8 - 1)  # which tool rides along in the count
	if tool != tool_index:
		tool_index = tool
		queue_redraw()
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
	if _lunge > 0.0:
		_lunge = maxf(0.0, _lunge - delta * 6.0)
		queue_redraw()
	if _swing > 0.0:
		_swing = maxf(0.0, _swing - delta * (2.4 if _swing_tool == 1 else 3.6))
		queue_redraw()
	if _emote_time > 0.0:
		_emote_time -= delta
		queue_redraw()
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
		# The count of actions carries the last tool used too (8 per action).
		Net.send_player_state(position, facing, dir != Vector2.ZERO, tool_index, _swings * 8 + _acted_with + 1)
	if busy:
		if _walk != 0.0:
			_walk = 0.0
			queue_redraw()
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
			# Going in is done by hand (F on the door or cave mouth). Walking
			# down off the door mat or ladder goes back out.
			if step.y > 0.0 and indoors() and GameState.is_exit_mat(cell()):
				go_outside()
		var stride_before: int = int(_walk * 4.5)
		_walk += delta * pace
		if int(_walk * 4.5) != stride_before:
			Sound.play("step")  # one soft footfall per step of the walk cycle
		queue_redraw()
	elif _walk != 0.0:
		_walk = 0.0
		queue_redraw()
	# Walking over something dropped picks it up.
	if cell() != _last_cell:
		_last_cell = cell()
		if GameState.object_kind(_last_cell) == "dropped":
			GameState.request_harvest(player_id, _last_cell)
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


## Climb down into the mine, onto the foot of the ladder.
func go_into_mine() -> void:
	var floor: Rect2i = GameState.mine_floor()
	position = Vector2((floor.position.x + floor.size.x / 2.0) * TILE, floor.end.y * TILE - 2.0)
	facing = Vector2i.UP
	_arrived()


## Step out to just below the home's door (or the mine's mouth).
func go_outside() -> void:
	var door: Vector2i = GameState.home_door()
	if GameState.is_in_mine(cell()):
		door = Vector2i(GameState.MINE_RECT.position.x, GameState.MINE_RECT.end.y - 1)
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
	elif event.is_action_pressed("interact"):
		use_hand()
	elif event.is_action_pressed("next_seed"):
		if tool_index == ITEM_TOOL:
			cycle_item()
		else:
			cycle_seed()
	elif event.is_action_pressed("cycle_tool"):
		var next: int = (tool_index + 1) % TOOLS.size()
		if next == PICK_TOOL and GameState.upgrade_level("pickaxe") < 1:
			next = (next + 1) % TOOLS.size()  # skip the pickaxe until one is bought
		select_tool(next)
	else:
		for i in TOOLS.size():
			if event.is_action_pressed("tool_%d" % (i + 1)):
				select_tool(i)
		for i in GameState.HOT_SLOTS:
			if event.is_action_pressed("quick_%d" % (i + 1)):
				select_quick(i)


func select_tool(index: int) -> void:
	if index == PICK_TOOL and GameState.upgrade_level("pickaxe") < 1:
		return  # not bought yet
	quick_index = -1
	tool_index = index
	loadout_changed.emit()


## Move a seed packet or item ("seed:<id>" / "item:<id>") from the backpack
## to hot bar slot `slot`, or with "" put that slot's stack back in the bag.
func set_quick(slot: int, key: String) -> void:
	var slots: Array = GameState.bag_slots()
	if slot < 0 or slot >= GameState.HOT_SLOTS:
		return
	if key == "":
		if slots[slot] != "":
			GameState.request_move_slot(player_id, slot, slots.find("", GameState.HOT_SLOTS))
	elif slots.has(key):
		GameState.request_move_slot(player_id, slots.find(key), slot)
	loadout_changed.emit()


## Drop the whole stack of `key` on the tile ahead.
func drop(key: String) -> bool:
	return GameState.request_drop(player_id, key, target_cell())


## Take what is in a quick slot in hand.
func select_quick(slot: int) -> void:
	var hot: Array = quick
	if slot < 0 or slot >= hot.size() or str(hot[slot]) == "":
		return
	var key: String = hot[slot]
	var id: String = key.get_slice(":", 1)
	if key.begins_with("seed:"):
		seed_id = id
		tool_index = 2
	else:
		item_id = id
		tool_index = ITEM_TOOL
	quick_index = slot
	loadout_changed.emit()


## Hold these seeds (from the backpack) and switch to the seed tool.
func hold_seed(id: String) -> void:
	seed_id = id
	select_tool(2)


## Hold a placeable thing or a meal (from the backpack) in the item slot.
func hold_item(id: String) -> void:
	item_id = id
	select_tool(ITEM_TOOL)


## Things from the backpack that can be held: placeables, mulch and meals.
func holdable_items() -> Array:
	var out: Array = []
	for id: String in GameState.ITEMS.keys():
		if GameState.item_count(id) > 0 and ["place", "soil", "meal", "decor"].has(str(GameState.ITEMS[id]["kind"])):
			out.append(id)
	return out


func cycle_item() -> void:
	var ids: Array = holdable_items()
	if not ids.is_empty():
		item_id = ids[(ids.find(item_id) + 1) % ids.size()]
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


## What a bare hand would do to the tile ahead ("" for nothing):
## sleep, leave, enter, shop, clock, bin, hug, pet, pick, lift.
func hand_action() -> String:
	var target: Vector2i = target_cell()
	var me: String = str(player_id)
	if indoors():
		if GameState.is_bed(target):
			return "sleep"
		if GameState.ORES.has(GameState.object_kind(target)):
			return ""  # rocks need the pickaxe
		if GameState.object_kind(target) == "oven":
			return "bake"
		if GameState.objects.has(target):
			return "lift"
		if facing == Vector2i.DOWN and GameState.is_exit_mat(cell()):
			return "leave"
		return ""
	if GameState.is_tent(target):
		return "enter"
	if GameState.is_stall(target):
		return "shop"
	if GameState.is_tower(target):
		return "clock"
	if GameState.is_bin(target):
		return "bin"
	if GameState.is_mine_entrance(target):
		return "mine"
	if target == GameState.MAILBOX_CELL:
		return "mail"
	if target == GameState.BOARD_CELL:
		return "board"
	if GameState.MACHINES.has(GameState.object_kind(target)):
		var machine: Dictionary = GameState.objects[target]
		if bool(machine.get("ready", false)):
			return "collect"
		if int(machine.get("busy", 0)) > 0:
			return "wait"
		return "fill" if GameState.machine_input(GameState.object_kind(target)) != "" else "lift"
	if target == GameState.VISITOR_CELL and GameState.visitor_today() != "":
		return "talk"
	var animal: int = GameState.animal_at(target)
	if animal >= 0:
		if not bool(GameState.animals[animal]["fed"]):
			return "feed"
		return "" if GameState.animals[animal]["petted_by"].has(me) else "stroke"
	if GameState.object_kind(target) == "oven":
		return "bake"
	if GameState.TREES.has(GameState.object_kind(target)):
		return "pick" if bool(GameState.objects[target].get("fruit", false)) else ("lift" if int(GameState.objects[target].get("age", 0)) == 0 else "")
	if GameState.is_tree(target):
		return "" if GameState.tree["hugged_by"].has(me) else "hug"
	if GameState.objects.has(target):
		return "lift"
	if GameState.plants.has(target):
		# Love first; a plant you've already petted today can be picked.
		if not GameState.plants[target]["petted_by"].has(me):
			return "pet"
		if GameState.plant_is_ripe(target):
			return "pick"
	return ""


## Short words for the HUD, e.g. "pet" or "pick".
func hand_hint() -> String:
	var action: String = hand_action()
	var target: Vector2i = target_cell()
	match action:
		"sleep": return "get in"
		"leave": return "go out"
		"enter", "mine": return "go in"
		"shop": return "talk"
		"clock", "bin", "mail": return "open"
		"board": return "read"
		"wait": return "check"
		"lift": return "clear" if GameState.DEBRIS.has(GameState.object_kind(target)) else "pick up"
	return action


## The hand key (F / right click): do whatever a bare hand can do here.
func use_hand() -> void:
	var target: Vector2i = target_cell()
	match hand_action():
		"sleep": GameState.request_sleep(player_id)
		"leave": go_outside()
		"enter": go_inside()
		"shop": shop_requested.emit()
		"clock": clock_requested.emit()
		"bin": bin_requested.emit()
		"mine": go_into_mine()
		"bake": bake_requested.emit()
		"mail": mail_requested.emit()
		"board": board_requested.emit()
		"collect", "fill", "wait": GameState.request_harvest(player_id, target)
		"talk": villager_requested.emit()
		"feed", "stroke": GameState.request_tend(player_id, target)
		"hug", "pet": GameState.request_pet(player_id, target)
		"pick", "lift": GameState.request_harvest(player_id, target)
		_: return
	_acted_with = -1
	acted.emit()


## The tool key (Space / left click): use the held tool on the tile ahead.
## When the tool has nothing to do there, the hand takes over, so picking,
## petting and opening things never need a particular tool.
func use_tool() -> void:
	var target: Vector2i = target_cell()
	var hand: String = hand_action()
	if ["sleep", "leave", "enter", "shop", "clock", "bin", "mine", "talk", "mail", "board", "bake"].has(hand):
		use_hand()
		return
	var open_ground: bool = GameState.in_bounds(target) and not GameState.is_blocked(target) and not GameState.soil.has(target) and not GameState.objects.has(target)
	var done: bool = true
	match tool_index:
		0:
			done = open_ground
			if done:
				GameState.request_till(player_id, target, facing)
		1:
			done = GameState.is_tree(target) or (GameState.soil.has(target) and (hand == "" or not bool(GameState.soil[target]["watered"])))
			if done:
				GameState.request_water(player_id, target, facing)
		2:
			done = GameState.soil.has(target) and not GameState.plants.has(target)
			if done:
				GameState.request_plant(player_id, target, seed_id)
		ITEM_TOOL:
			done = _use_item(target, hand)
		ROD_TOOL:
			done = GameState.is_pond(target)
			if done:
				fish_requested.emit()
		PICK_TOOL:
			done = GameState.ORES.has(GameState.object_kind(target))
			if done:
				GameState.request_mine(player_id, target)
		AXE_TOOL:
			done = GameState.can_chop(target)
			if done:
				GameState.request_chop(player_id, target)
	if done:
		_acted_with = tool_index
		acted.emit()
	elif hand != "":
		use_hand()
	elif tool_index == ROD_TOOL:
		GameState.notice.emit("Face the pond to cast")
	elif tool_index == AXE_TOOL:
		GameState.notice.emit("Nothing to chop here. The axe cuts trees, stumps and logs")
	elif tool_index == PICK_TOOL:
		GameState.notice.emit("Nothing to break here. Rocks and ore are in the mine")


## Eats the held meal or sets the held thing down. False when it had
## nothing to do here (so the hand can act instead).
func _use_item(target: Vector2i, hand: String) -> bool:
	if GameState.item_count(item_id) < 1:
		var others: Array = holdable_items()
		if others.is_empty():
			if hand == "":
				GameState.notice.emit("Nothing to use. Make something in the backpack (E)")
			return false
		item_id = others[0]
		loadout_changed.emit()
	var kind: String = GameState.ITEMS[item_id]["kind"]
	if kind == "meal":
		GameState.request_eat(player_id, item_id)
		return true
	if kind == "soil":
		if not GameState.soil.has(target) or bool(GameState.soil[target].get("mulch", false)):
			return false
	elif hand != "":
		return false  # something is already there: let the hand deal with it
	GameState.request_place(player_id, target, item_id)
	return true


## Girl / boy poses are fitted to the world with feet at the origin.
## Assets supplies the shared character mapping and direction layout.
## The hat being worn is drawn on top from assets/sprites/hats.png.
func _draw() -> void:
	if _texture == null or _texture_slot != player_id:
		_texture_slot = player_id
		_texture = Assets.player_texture(player_id)
	var column: int = WALK_CYCLE[int(_walk * 9.0) % WALK_CYCLE.size()] if _walk > 0.0 else 0
	var body_rect: Rect2 = Assets.player_draw_rect(player_id, facing, column)
	draw_rect(Rect2(-5, -2, 10, 3), Color(0, 0, 0, 0.18))  # shadow
	# A quick lean towards the tile ahead when a tool or hand is used.
	var lean: Vector2 = Vector2(facing) * sin(_lunge * PI) * 3.0
	body_rect.position += lean
	var swinging: bool = _swing > 0.0 and _swing_tool >= 0 and _tools != null
	# Raised behind the head (or facing away), the tool goes behind the body.
	var behind: bool = swinging and (facing == Vector2i.UP or (_swing_tool != 1 and _tool_angle() < (-70.0 if facing == Vector2i.DOWN else -100.0)))
	if behind:
		_draw_tool(lean)
	draw_texture_rect_region(_texture, body_rect, Assets.player_frame(player_id, facing, column))
	var hat: int = GameState.HAT_ORDER.find(GameState.hat_of(player_id))
	if hat >= 0 and _hats != null:
		var hat_rect: Rect2 = Assets.player_hat_rect(player_id, facing, column)
		hat_rect.position += lean
		draw_texture_rect_region(_hats, hat_rect, Rect2(hat * 16, 0, 16, 12))
	if swinging and not behind:
		_draw_tool(lean)
	if is_remote:
		# Your partner's name, and a small picture of what they're holding.
		var font: Font = ThemeDB.fallback_font
		var label: String = Net.name_of_slot(player_id)
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		var label_y: float = minf(-27.0, body_rect.position.y - 4.0)
		draw_string_outline(font, Vector2(-width / 2.0, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, 2, Color(0.2, 0.14, 0.23))
		draw_string(font, Vector2(-width / 2.0, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(1, 0.97, 0.88))
		if tool_index != ITEM_TOOL and _tools != null:
			draw_texture_rect_region(_tools, Rect2(width / 2.0 + 1, label_y - 8.0, 9, 9), ToolArt.frame(tool_index))
	if _emote_time > 0.0 and _emote >= 0:
		var up: float = minf(-40.0, body_rect.position.y - 19.0) if is_remote else minf(-32.0, body_rect.position.y - 9.0)
		var fade: float = clampf(_emote_time * 2.0, 0.0, 1.0)
		draw_rect(Rect2(-7, up - 2, 14, 12), Color(1, 0.97, 0.88, fade))
		draw_rect(Rect2(-7, up - 2, 14, 12), Color(0.42, 0.26, 0.15, fade), false, 1.0)
		match _emote:
			0: Effects.heart(self, 0, up + 1, fade)
			1: Effects.note(self, 0, up + 1, fade)
			2: Effects.zzz(self, 0, up + 2, fade)
			3: draw_string(ThemeDB.fallback_font, Vector2(-2, up + 8), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.85, 0.3, 0.25, fade))
			4: draw_string(ThemeDB.fallback_font, Vector2(-3, up + 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.3, 0.45, 0.8, fade))
			5: Effects.droplet(self, 0, up + 3, fade)


## Tools that show in the hands when used (not seeds or held items).
const SWUNG: Array[int] = [0, 1, 4, 5, 6]


func _start_swing(tool: int) -> void:
	if SWUNG.has(tool):
		_swing = 1.0
		_swing_tool = tool


## The tool in the player's hands: swung over and down towards the tile
## ahead (a cast, for the rod), or for the watering can, tipped to pour.
## The tool pictures are drawn with the grip at the hands, then turned.
func _draw_tool(lean: Vector2) -> void:
	var progress: float = 1.0 - _swing
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var mirror: bool = facing.x < 0
	var frame: Rect2 = ToolArt.frame(_swing_tool)
	var hand := Vector2(3, -8)
	if facing.x != 0:
		hand = Vector2(3 * facing.x, -9)
	elif facing == Vector2i.UP:
		hand = Vector2(-1, -18)  # facing away: held up so it shows above the head
	var side: float = -1.0 if mirror else 1.0
	if _swing_tool == 1:
		# Hold the can out in front and tip it; water drips from the spout.
		var tip: float = clampf(eased * 2.0, 0.0, 1.0) * 0.7
		draw_set_transform(hand + lean + Vector2(2 * side, 2), tip * side, Vector2(side, 1))
		draw_texture_rect_region(_tools, Rect2(-7, -13, 16, 16), frame)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if progress > 0.35:
			for drop in 3:
				var fall: float = fposmod(progress * 30.0 + drop * 4.0, 10.0)
				draw_rect(Rect2(hand + lean + Vector2((11 + drop) * side, -5 + fall), Vector2(1, 2)), Color(0.55, 0.8, 1.0, 0.9))
		return
	var pose: float = _tool_angle()
	if pose <= -100.0:  # raised over the shoulder: hands up and back, so it shows above the head
		hand += Vector2(-4.0 * side, -7.0)
	# The picture points up-right (-45 degrees); turn it to the swing's angle.
	# Facing left, the same turn is mirrored (Godot mirrors after turning).
	var angle: float = deg_to_rad(pose + 45.0)
	draw_set_transform(hand + lean, angle, Vector2(-1, 1) if mirror else Vector2.ONE)
	draw_texture_rect_region(_tools, Rect2(-ToolArt.GRIP, Vector2(16, 16)), frame)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the swung tool points from the hands, in degrees (0 = ahead for a
## sideways swing, -90 = up). The tool is turned only in quarter turns, so
## its pixels stay crisp: three poses, like frames of a swing (raised behind
## the head, over the top, then down on the tile ahead). The tool pictures
## point up-right (-45), so the poses are -135, -45 and 45.
func _tool_angle() -> float:
	var progress: float = 1.0 - _swing
	var poses: Array[float] = [-135.0, -45.0, 45.0]
	if facing == Vector2i.UP:
		poses = [-135.0, -45.0, -45.0]  # facing away: up behind them the whole time
	if progress < 0.3:
		return poses[0]
	if progress < 0.55:
		return poses[1]
	return poses[2]
