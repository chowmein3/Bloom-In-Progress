extends Node
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
	_expect(player.call("indoors"), "walking up into the tent's door goes inside")
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
	var slots: Array[Node] = bag.find_children("*", "Button", true, false)
	(slots[1] as Button).emit_signal("pressed")  # the second seed packet
	_expect(str(player.get("seed_id")) == "moonbell" and int(player.get("tool_index")) == 2, "clicking a seed packet holds those seeds")
	await _tap(KEY_J)
	_expect(not _screen("journal.gd").visible, "another screen can't open on top")
	await _tap(KEY_E)
	_expect(not bag.visible and not bool(player.get("reading")), "E closes it again")

	print("a better hoe")
	await _hold(KEY_S, 0.9)
	await _tap(KEY_1)
	var front: Vector2i = player.call("target_cell")
	await _tap(KEY_SPACE)
	_expect(GameState.soil.has(front) and GameState.soil.has(front + Vector2i(0, 1)) and GameState.soil.has(front + Vector2i(0, 2)), "one swing of the Sturdy Hoe tills three tiles ahead")

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
