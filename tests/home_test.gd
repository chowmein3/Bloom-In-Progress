extends Node
const Settings := preload("res://scripts/settings.gd")
## Plays through the home, bed, shop and backpack in the real game scene,
## using key presses for everything a player does with the keyboard.
##   godot --headless --path . res://tests/home_test.tscn
## Add an output folder after "--" (and drop --headless) to save pictures.

const P := 1
var failures: int = 0
var out_dir: String = ""
var main: Node
var player: Node2D


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	Net.stop_lookup()
	Net.relay_url = ""  # never touch the real relay from a test
	GameState.wild_growth = false  # no surprise debris where a test wants to dig
	TimeManager.rain_chance = 0.0
	GameState.save_path = "user://home_test_save.json"
	GameState.new_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.call("start_solo")
	TimeManager.paused = true
	player = main.get("player")
	var hud: CanvasLayer = main.get("hud")
	await _wait(0.2)

	print("going inside")
	_expect(not player.call("indoors"), "the game starts out in the garden")
	await _hold(KEY_W, 1.2)
	_expect(not player.call("indoors") and str(player.call("hand_hint")) == "go in", "walking up to the tent stops at the door; the hand offers to go in")
	await _tap(KEY_F)
	_expect(player.call("indoors"), "F on the door goes inside")
	_expect(GameState.can_walk(player.call("cell")), "standing on the room's floor")
	await _wait(0.2)
	await _shot("home_1_tent_inside")

	print("the bed")
	await _hold(KEY_W, 0.75)
	await _hold(KEY_A, 1.5)
	_expect(GameState.is_bed(player.call("target_cell")), "walked over to face the bed")
	# For the picture only: show both pillows taken, as in co-op.
	GameState.sleeping = {1: true, 2: true}
	GameState.sleepers_changed.emit()
	await _wait(0.3)
	_expect(not player.visible, "a player in bed is under the covers, not standing")
	await _shot("home_2_both_in_bed")
	GameState.sleeping = {}
	GameState.sleepers_changed.emit()
	await _wait(0.1)
	await _tap(KEY_SPACE)
	_expect(TimeManager.day_index == 1, "getting into bed ends the day (alone, at once)")
	await _wait(2.0)
	_expect(player.visible and player.call("indoors"), "and you wake up beside the bed")

	print("going outside")
	await _hold(KEY_D, 0.3)
	_key(KEY_S, true)  # walk down until through the door, then let go
	for i in 60:
		if not player.call("indoors"):
			break
		await get_tree().process_frame
		await _wait(0.03)
	_key(KEY_S, false)
	await _wait(0.1)
	_expect(not player.call("indoors"), "walking down off the door mat goes back outside")
	_expect(player.call("cell") == GameState.home_door() + Vector2i(0, 1), "arriving just below the door")

	print("the shop")
	GameState.produce["sunpuff"] = 3  # something to sell
	GameState.inventory_changed.emit()
	await _hold(KEY_D, 1.25)
	await _hold(KEY_W, 0.2)
	_expect(GameState.is_stall(player.call("target_cell")), "walked over to face the stall")
	await _tap(KEY_SPACE)
	var shop: CanvasLayer = _screen("shop.gd")
	_expect(shop.visible and bool(player.get("reading")), "Space at the stall opens the shop")
	await _shot("home_3_shop_sell")
	_click(shop, "Sell all")
	_expect(GameState.coins == 190 and int(GameState.produce["sunpuff"]) == 0, "Sell all turns three sunpuffs into 90 coins")
	_click(shop, "Seeds")
	await _wait(0.1)
	await _shot("home_4_shop_seeds")
	_click(shop, "Buy 5")
	_expect(GameState.coins == 140 and GameState.seed_count("sunpuff") == 11, "Buy 5 adds five sunpuff seeds for 50")
	_click(shop, "Tools")
	_expect(_button(shop, "Buy") != null and _button(shop, "Buy").disabled, "tools the purse can't cover are greyed out")
	GameState.coins = 2500
	GameState.economy_changed.emit()
	_click(shop, "Buy")
	_expect(GameState.upgrade_level("hoe") == 1, "with enough coins the Sturdy Hoe can be bought")
	_click(shop, "Hats")
	await _wait(0.1)
	await _shot("home_5_shop_hats")
	_click(shop, "Buy")
	_expect(GameState.hat_of(P) == "flower", "a bought hat goes straight on")
	_click(shop, "Home")
	_click(shop, "Buy")
	_expect(GameState.home_level() == 1, "the Cabin can be bought")
	await _tap(KEY_ESCAPE)
	_expect(not shop.visible and not bool(player.get("reading")) and not main.get("menu").visible, "Esc closes the shop without opening the pause menu")
	_expect(int(str((hud.get("_coins") as Label).text)) == GameState.coins, "the HUD shows the purse")

	print("the backpack")
	await _tap(KEY_E)
	var bag: CanvasLayer = _screen("inventory.gd")
	_expect(bag.visible and bool(player.get("reading")), "E opens the backpack")
	await _wait(0.1)
	await _shot("home_6_backpack")
	var slots: Array[Node] = bag.find_children("*", "GridContainer", true, false)[0].get_children()
	(slots[1] as Button).emit_signal("pressed")  # the second seed packet
	_expect(str(player.get("seed_id")) == "moonbell" and int(player.get("tool_index")) == 2, "clicking a seed packet holds those seeds")
	# Dragging moves whole stacks: within the backpack, onto the hot bar, or out to drop it.
	var hot: int = GameState.HOT_SLOTS
	var first: String = bag.get("_order")[hot]
	var second: String = bag.get("_order")[hot + 1]
	var held: Variant = bag.call("_drag_from_bag", Vector2.ZERO, hot)
	_expect(typeof(held) == TYPE_DICTIONARY and str(held["key"]) == first, "a backpack slot can be picked up")
	bag.call("_drop_on_bag", Vector2.ZERO, held, hot + 1)
	_expect(str(bag.get("_order")[hot]) == second and str(bag.get("_order")[hot + 1]) == first, "dropping it on another slot swaps the two")
	bag.call("_drop_on_bag", Vector2.ZERO, {"key": first, "from": hot + 1}, hot + 7)
	_expect(str(bag.get("_order")[hot + 7]) == first and str(bag.get("_order")[hot + 1]) == "", "it can be moved to an empty slot")
	var packets: int = GameState.bag_count(first)
	bag.call("_drop_on_bag", Vector2.ZERO, {"key": first, "from": hot + 7}, 0)
	_expect(str(bag.get("_order")[0]) == first and str(bag.get("_order")[hot + 7]) == "" and str(player.get("quick")[0]) == first, "dropping on the hot bar moves the stack there")
	_expect(GameState.bag_count(first) == packets and bag.get("_order").count(first) == 1, "the whole stack moved, nothing was copied")
	GameState.items["stone"] = 2
	GameState.inventory_changed.emit()
	var stone_at: int = bag.get("_order").find("item:stone")
	_expect(not bool(bag.call("_can_drop", Vector2.ZERO, {"key": "item:stone", "from": stone_at}, 1)), "stone can't go on the hot bar")
	await _tap(KEY_E)
	await _tap(KEY_8)
	_expect(int(player.get("quick_index")) == 0 and int(player.get("tool_index")) == 2 and "seed:" + str(player.get("seed_id")) == first, "8 picks the first hot bar slot and holds those seeds")
	await _tap(KEY_1)
	_expect(int(player.get("quick_index")) == -1, "choosing a tool leaves the hot bar slot")
	_expect(not GameState.can_drop_on(player.call("target_cell")), "nothing can be dropped onto the stall")
	await _hold(KEY_S, 0.05)  # turn round to open ground
	var ahead: Vector2i = player.call("target_cell")
	bag.call("_drop_outside", Vector2.ZERO, {"key": "item:stone", "from": bag.get("_order").find("item:stone")})
	_expect(GameState.object_kind(ahead) == "dropped" and GameState.item_count("stone") == 0, "dragging stone out of the backpack drops it on the tile ahead")
	await _tap(KEY_E)
	await _tap(KEY_J)
	_expect(not _screen("journal.gd").visible, "another screen can't open on top")
	await _tap(KEY_E)
	_expect(not bag.visible and not bool(player.get("reading")), "E closes it again")
	var stone_cell: Vector2i = player.call("target_cell")
	await _hold_dir(stone_cell)
	_expect(not GameState.objects.has(stone_cell) and GameState.item_count("stone") == 2, "walking over the dropped stone picks it back up")

	print("a better hoe")
	await _hold(KEY_S, 0.9)
	await _tap(KEY_1)
	var front: Vector2i = player.call("target_cell")
	await _tap(KEY_SPACE)
	_expect(GameState.soil.has(front) and GameState.soil.has(front + Vector2i(0, 1)) and GameState.soil.has(front + Vector2i(0, 2)), "one swing of the Sturdy Hoe tills three tiles ahead")

	print("crafting, placing, cooking")
	GameState.items = {"stone": 4, "wood": 4, "fiber": 3}  # as if gathered
	GameState.produce["moonbell"] = 2
	GameState.xp = 40  # gardening level 2
	GameState.inventory_changed.emit()
	await _tap(KEY_E)
	_click(bag, "Crafting")
	await _wait(0.1)
	await _shot("home_6b_crafting")
	_expect(_row_button(bag, "Garden Lantern").disabled and not _row_button(bag, "Sprinkler").disabled, "recipes above the gardening level are locked; the sprinkler is open at level 2")
	_row_button(bag, "Sprinkler").emit_signal("pressed")
	_row_button(bag, "Fence").emit_signal("pressed")
	_expect(GameState.item_count("sprinkler") == 1 and GameState.item_count("fence") == 1 and GameState.item_count("stone") == 1 and GameState.item_count("wood") == 0, "Make turns materials into a sprinkler and a fence")
	_click(bag, "Kitchen")
	await _wait(0.1)
	_row_button(bag, "Moonbell Tea").emit_signal("pressed")
	_expect(GameState.item_count("tea") == 1, "with the Cabin's stove, two moonbells cook into tea")
	await _shot("home_6c_kitchen")
	_click(bag, "Items")
	await _wait(0.1)
	for slot: Node in bag.find_children("*", "GridContainer", true, false)[0].get_children():
		if slot is Button and (slot as Button).icon != null and str((slot as Button).icon.resource_path).ends_with("sprinkler.png"):
			slot.emit_signal("pressed")
	_expect(str(player.get("item_id")) == "sprinkler" and int(player.get("tool_index")) == 3, "clicking the sprinkler holds it in the item slot")
	await _tap(KEY_E)
	await _hold(KEY_A, 0.15)
	var spot: Vector2i = player.call("target_cell")
	await _tap(KEY_SPACE)
	_expect(GameState.object_kind(spot) == "sprinkler" and GameState.item_count("sprinkler") == 0, "Space sets the held sprinkler down on the tile ahead")
	_expect(not GameState.can_walk(spot), "and it stands in the way like any solid thing")
	await _tap(KEY_Q)
	_expect(str(player.get("item_id")) != "sprinkler", "Q moves on to the next thing in the backpack")
	player.call("hold_item", "tea")
	GameState.energy[P] = 50
	await _tap(KEY_SPACE)
	_expect(GameState.get_energy(P) == 80 and GameState.item_count("tea") == 0, "Space with a meal in hand eats it for energy")
	await _wait(0.2)
	await _shot("home_6d_sprinkler")
	await _tap(KEY_F)
	_expect(not GameState.objects.has(spot) and GameState.item_count("sprinkler") == 1, "F picks the sprinkler back up by hand")
	await _tap(KEY_4)
	await _hold(KEY_S, 0.15)

	print("hands")
	var pet_spot := Vector2i(6, 12)
	GameState.request_till(P, pet_spot)
	GameState.request_plant(P, pet_spot, "sunpuff")
	GameState.plants[pet_spot]["days_grown"] = 9  # fully grown, for the test
	GameState.cell_changed.emit(pet_spot)
	player.position = Vector2((pet_spot.x + 0.5) * 16, pet_spot.y * 16 - 14)  # in the tile above it
	await _hold(KEY_S, 0.15)
	_expect(player.call("target_cell") == pet_spot and str(player.call("hand_hint")) == "pet", "facing a plant, the hand offers to pet it")
	await _tap(KEY_F)
	_expect(GameState.plants[pet_spot]["petted_by"].has("1"), "F pets it with no tool chosen for the job")
	_expect(str(player.call("hand_hint")) == "pick", "once petted, a ripe plant can be picked")
	await _wait(0.3)
	await _shot("home_6e_hand_hint")
	await _tap(KEY_1)
	await _tap(KEY_SPACE)
	_expect(not GameState.plants.has(pet_spot) and GameState.total_of("sunpuff") >= 1, "Space with the hoe in hand picks it too, since the hoe has nothing to do there")

	print("the axe")
	var oak := Vector2i(19, 9)
	player.position = Vector2((oak.x + 0.5) * 16, oak.y * 16 - 14)  # in the tile above it
	await _hold(KEY_S, 0.1)
	GameState.energy[P] = 60
	await _tap(KEY_7)
	_expect(int(player.get("tool_index")) == 6 and player.call("target_cell") == oak, "7 takes the axe, facing the oak")
	await _tap(KEY_SPACE)
	await _tap(KEY_SPACE)
	_expect(GameState.scenery_at(oak) == "oak", "it shakes but stands after two swings")
	await _tap(KEY_SPACE)
	_expect(GameState.scenery_at(oak) == "" and GameState.object_kind(oak) == "dropped", "the third fells it, leaving wood")
	var stack: Node2D = main.get("_things")[oak]
	_expect(stack.modulate.a < 0.5, "the wood waits until the tree has fallen")
	await _wait(0.3)
	await _shot("home_6f_timber")
	await _wait(0.8)
	_expect(stack.modulate.a > 0.9, "then pops up")
	var wood: int = GameState.item_count("wood")
	await _hold(KEY_S, 0.3)
	_expect(GameState.item_count("wood") > wood, "walking onto it picks the wood up")

	print("fishing")
	player.position = Vector2((GameState.POND_RECT.position.x - 0.5) * 16, (GameState.POND_RECT.position.y + 1) * 16 + 10)
	await _hold(KEY_D, 0.15)
	_expect(GameState.is_pond(player.call("target_cell")), "standing at the pond's edge, facing the water")
	await _tap(KEY_5)
	GameState.energy[P] = 60
	var rod: CanvasLayer = _screen("fishing.gd")
	await _tap(KEY_SPACE)
	_expect(str(rod.get("stage")) == "wait" and bool(player.get("reading")), "Space with the rod casts a line")
	for i in 100:
		if str(rod.get("stage")) == "bite":
			break
		await _wait(0.05)
	await _shot("home_6f_bite")
	await _tap(KEY_SPACE)
	_expect(str(rod.get("stage")) == "reel", "Space on the bite hooks the fish")
	await _shot("home_6g_reel")
	for i in 600:  # press only when the marker is on the green
		if str(rod.get("stage")) != "reel":
			break
		if absf(float(rod.get("_marker")) - float(rod.get("_zone"))) < 0.05:
			_key(KEY_SPACE, true)
			await get_tree().process_frame
			_key(KEY_SPACE, false)
		await get_tree().process_frame
	await _wait(0.2)
	var caught: String = ""
	for id: String in GameState.FISH:
		if GameState.item_count(id) > 0:
			caught = id
	_expect(caught != "" and str(rod.get("stage")) == "" and not bool(player.get("reading")), "three good pulls land a fish (%s)" % caught)
	_expect(GameState.get_energy(P) == 58, "a cast costs 2 energy")

	print("shipping bin")
	player.position = Vector2((GameState.BIN_CELL.x + 0.5) * 16, (GameState.BIN_CELL.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	_expect(GameState.is_bin(player.call("target_cell")), "standing below the shipping bin")
	await _tap(KEY_F)
	var bin_screen: CanvasLayer = _screen("bin.gd")
	_expect(bin_screen.visible, "F opens the bin")
	_click(bin_screen, "Add all")
	await _wait(0.1)
	await _shot("home_6h_bin")
	_expect(not GameState.bin.is_empty(), "Add all drops something in")
	await _tap(KEY_ESCAPE)
	var owed: int = 0
	for id: String in GameState.bin.keys():
		owed += GameState.sell_price_of(id) * int(GameState.bin[id])
	var purse_then: int = GameState.coins
	GameState.goals_done = []
	for goal: Dictionary in GameState.GOALS:
		GameState.goals_done.append(goal["id"])  # keep goal prizes out of this sum
	GameState.end_day(false)
	_expect(GameState.coins == purse_then + owed and owed > 0, "overnight the bin pays out (%d coins)" % owed)
	await _wait(2.6)
	GameState.goals_done = ["cabin"]

	print("decor and goals")
	GameState.coins = 1000
	GameState.request_buy_item(P, "armchair", 1)
	GameState.request_buy_item(P, "rug", 1)
	GameState.request_buy_item(P, "lamp", 1)
	var floor_at: Vector2i = GameState.room_floor().position
	GameState.request_place(P, floor_at + Vector2i(6, 3), "rug")
	GameState.request_place(P, floor_at + Vector2i(7, 3), "armchair")
	GameState.request_place(P, floor_at + Vector2i(4, 1), "lamp")
	player.call("go_inside")
	await _wait(0.3)
	await _shot("home_6i_decor")
	_expect(GameState.can_walk(floor_at + Vector2i(6, 3)) and not GameState.can_walk(floor_at + Vector2i(7, 3)), "indoors, the rug is walkable and the armchair is not")
	player.call("go_outside")
	await _tap(KEY_J)
	var journal: CanvasLayer = _screen("journal.gd")
	_click(journal, "Goals")
	await _wait(0.1)
	await _shot("home_6j_goals")
	_expect(journal.find_children("*", "Label", true, false).any(func(l: Node) -> bool: return str(l.get("text")).begins_with("Home Sweet Home  (done)")), "the journal's Goals page marks the Cabin goal done")
	_click(journal, "Fish")
	await _wait(0.1)
	await _tap(KEY_J)

	print("animals")
	GameState.coins = 3000
	GameState.request_buy_upgrade(P, "coop")
	GameState.request_buy_animal(P, "chicken")
	GameState.request_buy_item(P, "feed", 2)
	var hen: Vector2i = GameState.animal_cell(0)
	player.position = Vector2((hen.x + 0.5) * 16, (hen.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	_expect(player.call("target_cell") == hen and str(player.call("hand_hint")) == "feed", "facing a hungry hen, the hand offers to feed her")
	await _tap(KEY_F)
	_expect(bool(GameState.animals[0]["fed"]) and str(player.call("hand_hint")) == "stroke", "F feeds her; next it offers a stroke")
	await _tap(KEY_SPACE)
	_expect(GameState.animals[0]["petted_by"].has("1"), "Space with a tool that has nothing to do strokes her")
	await _wait(0.3)
	await _shot("home_6k_coop")

	print("a visitor")
	GameState.request_set_time(P, 0, 9 * 60, false)
	await _wait(4.5)
	var guest_at: Vector2i = GameState.VISITOR_CELL
	player.position = Vector2((guest_at.x + 0.5) * 16, (guest_at.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	_expect(str(player.call("hand_hint")) == "talk", "Maple is visiting and can be talked to")
	GameState.produce["moonbell"] = 1
	await _tap(KEY_F)
	var chat: CanvasLayer = _screen("villager.gd")
	_expect(chat.visible and bool(GameState.friends["maple"]["talked"]), "F opens a chat, which counts as the day's talk")
	await _wait(0.1)
	await _shot("home_6l_villager")
	_click(chat, "Give")
	_expect(bool(GameState.friends["maple"]["gifted"]) and int(GameState.friends["maple"]["points"]) >= 50, "Give hands over a gift and friendship grows")
	await _tap(KEY_ESCAPE)

	print("the mine")
	var bar: Array = main.get("hud").get("_slots")
	await _tap(KEY_6)
	_expect(not (bar[5] as Control).visible and int(player.get("tool_index")) != 5, "with no pickaxe bought, its slot is hidden and 6 does nothing")
	GameState.request_buy_upgrade(P, "pickaxe")
	await _wait(0.1)
	_expect((bar[5] as Control).visible, "buying one from Bristle adds the slot")
	var mouth := Vector2i(GameState.MINE_RECT.position.x, GameState.MINE_RECT.end.y)
	player.position = Vector2((mouth.x + 0.5) * 16, mouth.y * 16 + 12)
	await _hold(KEY_W, 0.5)
	_expect(not player.call("indoors") and str(player.call("hand_hint")) == "go in", "walking up to the cave mouth stops there")
	await _tap(KEY_SPACE)
	_expect(GameState.is_in_mine(player.call("cell")), "Space (the hand, as the tool has nothing to do) goes down into the mine")
	await _wait(0.3)
	await _shot("home_6m_mine")
	var rock := Vector2i(-1, -1)
	for at: Vector2i in GameState.objects.keys():
		if GameState.is_in_mine(at) and GameState.can_walk(at + Vector2i(0, 1)):
			rock = at
	player.position = Vector2((rock.x + 0.5) * 16, (rock.y + 2) * 16 - 2)
	await _hold(KEY_W, 0.1)
	_expect(player.call("target_cell") == rock, "standing below a rock")
	await _tap(KEY_F)
	_expect(GameState.objects.has(rock), "a bare hand can't break it")
	await _tap(KEY_6)
	await _tap(KEY_SPACE)
	_expect(not GameState.objects.has(rock), "the pickaxe (6) does")
	player.call("go_into_mine")
	_key(KEY_S, true)
	for i in 40:
		if not player.call("indoors"):
			break
		await _wait(0.03)
	_key(KEY_S, false)
	_expect(not player.call("indoors") and player.call("cell").x == GameState.MINE_RECT.position.x, "walking down the ladder tile comes back out at the cave mouth")
	await _tap(KEY_1)

	print("machines, mail and the board")
	GameState.items["jar"] = 1
	GameState.produce["sunpuff"] = 4
	var jar_at := Vector2i(6, 14)
	GameState.request_place(P, jar_at, "jar")
	player.position = Vector2((jar_at.x + 0.5) * 16, (jar_at.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	_expect(str(player.call("hand_hint")) == "fill", "facing an empty jar with harvest to spare, the hand offers to fill it")
	await _tap(KEY_F)
	_expect(int(GameState.objects[jar_at].get("busy", 0)) == 2 and str(player.call("hand_hint")) == "check", "F fills it and it starts working")
	GameState.end_day(false)
	GameState.end_day(false)
	await _wait(4.0)
	_expect(str(player.call("hand_hint")) == "collect", "two mornings later it offers jam")
	await _shot("home_6n_jar")
	await _tap(KEY_F)
	_expect(GameState.item_count("jam") == 1, "F collects the jam")
	var box_at: Vector2i = GameState.MAILBOX_CELL
	player.position = Vector2((box_at.x + 0.5) * 16, (box_at.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	GameState.mail = [{"from": "Bristle", "text": "A test letter.", "gift": {"coins": 25}}]
	GameState.mail_changed.emit()
	await _tap(KEY_F)
	var post: CanvasLayer = _screen("notices.gd")
	_expect(post.visible and str(post.get("mode")) == "mail", "F at the mailbox opens the letters")
	await _wait(0.1)
	await _shot("home_6o_mail")
	var before_gift: int = GameState.coins
	_click(post, "Take gift")
	_expect(GameState.coins == before_gift + 25 and GameState.mail.is_empty(), "Take gift empties the letter into the purse")
	await _tap(KEY_ESCAPE)
	var board_at: Vector2i = GameState.BOARD_CELL
	player.position = Vector2((board_at.x + 0.5) * 16, (board_at.y + 1) * 16 + 10)
	await _hold(KEY_W, 0.15)
	GameState.quests = [{"who": "maple", "id": "jam", "count": 1, "coins": 200, "days": 3}]
	GameState.mail_changed.emit()
	await _tap(KEY_F)
	_expect(post.visible and str(post.get("mode")) == "quests", "F at the notice board opens the requests")
	await _wait(0.1)
	await _shot("home_6p_board")
	_click(post, "Hand in")
	_expect(GameState.item_count("jam") == 0 and GameState.quests.is_empty(), "Hand in gives Maple her jam")
	await _tap(KEY_ESCAPE)

	print("greenhouse and emotes")
	GameState.coins = 4000
	GameState.request_buy_upgrade(P, "greenhouse")
	var glass: Vector2i = GameState.GREENHOUSE_RECT.position + Vector2i(2, 1)
	GameState.request_till(P, glass)
	GameState.seeds["frostwhisker"] = 1
	_expect(GameState.request_plant(P, glass, "frostwhisker"), "a winter plant goes into the greenhouse in spring")
	player.position = Vector2((glass.x + 1.5) * 16, (glass.y + 2) * 16)
	await _tap(KEY_T)
	await _tap(KEY_1)
	_expect(int(player.get("_emote")) == 0 and float(player.get("_emote_time")) > 1.0 and int(player.get("tool_index")) != 0 or int(player.get("_emote")) == 0, "T then 1 shows a heart above your head")
	await _wait(0.2)
	await _shot("home_6q_greenhouse")
	await _wait(2.6)

	print("the cabin")
	await _wait(0.2)
	await _shot("home_7_cabin_outside")
	player.call("go_inside")
	await _wait(0.3)
	_expect(GameState.can_walk(player.call("cell")) and GameState.room_size() == Vector2i(10, 6), "the bigger room can be walked into")
	await _shot("home_8_cabin_inside")

	print("sprinting")
	player.call("go_outside")
	await _wait(0.2)
	var from: float = player.position.x
	await _hold(KEY_D, 0.4)
	var walked: float = player.position.x - from
	from = player.position.x
	_key(KEY_SHIFT, true)
	await _hold(KEY_D, 0.4)
	_key(KEY_SHIFT, false)
	var ran: float = player.position.x - from
	_expect(walked > 15.0 and ran > walked * 1.5, "holding Shift covers the ground much faster (%d vs %d units)" % [int(ran), int(walked)])

	print("the clock tower")
	_key(KEY_SHIFT, true)
	_key(KEY_A, true)  # run left until below the tower
	for i in 200:
		if player.position.x <= 137.0:
			break
		await get_tree().process_frame
	_key(KEY_A, false)
	_key(KEY_SHIFT, false)
	await _hold(KEY_W, 0.3)
	_expect(GameState.is_tower(player.call("target_cell")), "ran over to face the clock tower")
	await _wait(0.2)
	await _shot("home_9_tower")
	await _tap(KEY_SPACE)
	var clock: CanvasLayer = _screen("clock.gd")
	_expect(clock.visible and bool(player.get("reading")), "Space at the tower opens the clock screen")
	_click(clock, "Fall")
	_click(clock, "Night")
	_click(clock, "+")
	_click(clock, "Winter")
	_expect(_button(clock, "Rain") == null, "winter offers no rain")
	_click(clock, "Fall")
	_click(clock, "Rain")
	await _wait(0.1)
	await _shot("home_10_clock")
	var day_before: int = TimeManager.day_of_season()
	_click(clock, "CHANGE TIME!")
	var warp: CanvasLayer = _screen("time_warp.gd")
	_expect(TimeManager.season() == 2 and TimeManager.minutes == 23 * 60 and TimeManager.day_of_season() == day_before + 1, "CHANGE TIME! jumps to the chosen fall night")
	_expect(TimeManager.raining, "with the rain that was asked for")
	_expect(not clock.visible and bool(warp.get("playing")) and bool(player.get("frozen")), "and the show begins, holding the player still")
	await _wait(0.9)
	await _shot("home_11_warp_a")
	await _wait(1.0)
	await _shot("home_12_warp_b")
	await _wait(1.1)
	await _shot("home_13_warp_c")
	for i in 80:
		if not bool(warp.get("playing")):
			break
		await _wait(0.1)
	_expect(not bool(warp.get("playing")) and not bool(player.get("frozen")), "when it ends the player can move again")
	await _wait(0.2)
	await _shot("home_14_fall_night")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://home_test_save.json"))
	print("\n%s" % ("HOME TEST PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


## The pop-up screen whose script file is `file`.
func _screen(file: String) -> CanvasLayer:
	for child: Node in main.get_children():
		if child.get_script() != null and str(child.get_script().resource_path).ends_with(file):
			return child
	return null


func _button(screen: Node, text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and str(node.get("text")).begins_with(text):
			return node
	return null


## The button on the list row of `screen` whose title starts with `title`.
func _row_button(screen: Node, title: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		if node.is_queued_for_deletion() or not node.get_parent() is HBoxContainer:
			continue
		for label: Node in node.get_parent().find_children("*", "Label", true, false):
			if str(label.get("text")).begins_with(title):
				return node
	return null


## Presses the first enabled button on `screen` whose label starts with `text`.
func _click(screen: Node, text: String) -> void:
	for node: Node in screen.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion() and str(node.get("text")).begins_with(text) and not bool(node.get("disabled")):
			node.emit_signal("pressed")
			return
	_expect(false, "button '%s' is there to press" % text)


func _expect(cond: bool, label: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(key: Key) -> void:
	_key(key, true)
	await _wait(0.1)
	_key(key, false)
	await _wait(0.1)


## Walk towards the tile ahead until standing on `goal`, then step back.
func _hold_dir(goal: Vector2i) -> void:
	var player: Node2D = get_tree().root.find_children("*", "Node2D", true, false).filter(func(n: Node) -> bool: return n.get("player_id") != null and not bool(n.get("is_remote")))[0]
	var keys: Dictionary = {Vector2i.UP: KEY_W, Vector2i.DOWN: KEY_S, Vector2i.LEFT: KEY_A, Vector2i.RIGHT: KEY_D}
	var back: Dictionary = {Vector2i.UP: KEY_S, Vector2i.DOWN: KEY_W, Vector2i.LEFT: KEY_D, Vector2i.RIGHT: KEY_A}
	var way: Vector2i = player.get("facing")
	_key(keys[way], true)
	for i in 60:
		if player.call("cell") == goal:
			break
		await get_tree().process_frame
	_key(keys[way], false)
	await _wait(0.1)
	await _hold(back[way], 0.3)
	await _hold(keys[way], 0.05)  # face the way we were facing again


func _hold(key: Key, seconds: float) -> void:
	_key(key, true)
	await _wait(seconds)
	_key(key, false)
	await _wait(0.1)


func _shot(shot_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
