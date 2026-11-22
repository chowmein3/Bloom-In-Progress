extends Node
## Two-player check using the real game scene. Start two copies, host first:
##   godot --headless --path . res://tests/coop_test.tscn -- host
##   godot --headless --path . res://tests/coop_test.tscn -- guest
## Add relay=ws://127.0.0.1:8799 to connect through a relay (relay/server.js)
## by invite code, the way players in different homes do.
## Add an output folder as a second argument (and drop --headless) to also
## save a picture from each side. tests/run_coop_test.sh does all of this.

const HOST := 1
const GUEST := 2
const HOST_CELL := Vector2i(13, 5)  # the tile in front of the host's start spot
const TREE_CELL := Vector2i(9, 4)
const GUEST_CELL := Vector2i(15, 5)  # the tile in front of the guest's start spot
const DROP_CELL := Vector2i(4, 14)  # where the host drops stone for the guest

var role: String = "host"
var out_dir: String = ""
var save_file: String = ""
var heard: Array = []  # emotes and chat lines received
var kisses: Array = []  # who leaned over for a goodnight kiss, each bedtime
var failures: int = 0
var main: Node


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	# Never touch the real relay from a test: local network unless relay= says otherwise.
	Net.stop_lookup()
	Net.relay_url = ""
	GameState.wild_growth = false  # no surprise debris where a test wants to dig
	var plain: Array[String] = []
	for arg: String in args:
		if arg.begins_with("relay="):
			Net.relay_url = arg.trim_prefix("relay=")
		else:
			plain.append(arg)
	if plain.size() > 0:
		role = plain[0]
	if plain.size() > 1:
		out_dir = plain[1]
	Net.port = 24999
	Net.use_upnp = false  # no router to talk to in a test
	TimeManager.rain_chance = 0.0
	GameState.rng.seed = 1
	GameState.kiss_chance = 1.0  # so the goodnight kiss always happens and can be checked
	GameState.bedtime_started.connect(func(by: int) -> void: kisses.append(by))
	save_file = "user://coop_test_%s.json" % role
	GameState.save_path = save_file
	GameState.new_game()
	Net.my_name = "%s Tester" % role.capitalize()
	Net.chat.connect(func(_slot: int, text: String) -> void: heard.append("chat:" + text))
	Net.emote.connect(func(_slot: int, index: int) -> void: heard.append("emote:%d" % index))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	if role == "host":
		await _run_host()
	else:
		await _run_guest()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	print("%s: %s" % [role.to_upper(), "ALL CHECKS PASSED" if failures == 0 else "%d FAILED" % failures])
	get_tree().quit(1 if failures > 0 else 0)


func _run_host() -> void:
	# Something already in the garden, to prove a late joiner receives it.
	GameState.request_till(HOST, Vector2i(10, 8))
	GameState.garden_name = "Test Garden"
	GameState.garden_code = "TESTAB"
	main.call("start_host")
	if Net.relay_enabled():
		_expect(await _until(func() -> bool: return Net.via_relay and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 15.0), "host opened the garden on the relay")
	TimeManager.paused = true
	_expect(await _until(func() -> bool: return Net.slots().size() == 2, 30.0), "guest joined")
	_expect(main.get("remote_players").has(GUEST), "guest's character appears on the host's screen")

	await _tap(KEY_SPACE)  # hoe, from the keyboard
	_expect(GameState.soil.has(HOST_CELL), "host tilled with a key press")
	GameState.request_plant(HOST, HOST_CELL, "sunpuff")
	GameState.request_water(HOST, HOST_CELL)
	GameState.request_pet(HOST, HOST_CELL)
	GameState.request_water(HOST, TREE_CELL)
	GameState.request_pet(HOST, TREE_CELL)
	_expect(int(GameState.bag_of(GUEST).get("coins", 0)) == GameState.START_COINS and GameState.bag_of(GUEST)["seeds"].has("sunpuff"), "the guest got their own bag, with seeds and a purse")
	GameState.bag_of(GUEST)["produce"]["sunpuff"] = 2  # something for the guest to sell
	GameState.inventory_changed.emit()
	GameState.items["stone"] = 2  # something to give the guest
	GameState.produce["sunpuff"] = 2  # something to sell
	GameState.request_sell(HOST, "sunpuff", 2)
	_expect(GameState.coins == 160 and int(GameState.bag_of(GUEST)["coins"]) == GameState.START_COINS, "the host's sale pays only the host")
	_expect(GameState.request_drop(HOST, "item:stone", DROP_CELL) and GameState.item_count("stone") == 0, "the host drops their stone for the guest")
	for swing in 3:
		GameState.request_chop(HOST, Vector2i(30, 2))
	_expect(GameState.felled.has(Vector2i(30, 2)) and GameState.object_kind(Vector2i(30, 2)) == "dropped", "the host cuts down an oak")

	_expect(await _until(func() -> bool: return GameState.plants.has(GUEST_CELL), 10.0), "guest's planting reaches the host")
	_expect(await _until(func() -> bool: return Net.names.get(GUEST, "") == "Guest Tester", 10.0), "host learns the guest's name")
	_expect(await _until(func() -> bool: return heard.has("chat:hello from the guest") and heard.has("emote:1"), 10.0), "the guest's emote and chat line arrive")
	_expect(await _until(func() -> bool: return GameState.plants[HOST_CELL]["petted_by"].has("2"), 10.0), "guest petted the host's plant")
	_expect(await _until(func() -> bool: return GameState.tree["hugged_by"].size() == 2, 10.0), "both players hugged the Heart Tree")
	_expect(GameState.get_energy(GUEST) <= 96, "guest's energy is tracked by the host")
	var guest_node: Node2D = main.get("remote_players")[GUEST]
	_expect(await _until(func() -> bool: return guest_node.position.x < 15.4 * 16, 10.0), "guest's movement shows on the host's screen")
	_expect(await _until(func() -> bool: return GameState.hat_of(GUEST) == "flower" and int(GameState.bag_of(GUEST)["coins"]) == 10, 10.0), "guest's hat purchase reaches the host, paid from the guest's own purse")
	_expect(GameState.coins == 160, "the host's purse is untouched")
	_expect(await _until(func() -> bool: return GameState.object_kind(Vector2i(3, 14)) == "path", 10.0), "a stepping stone the guest crafted and placed appears for the host")
	_expect(not GameState.objects.has(DROP_CELL) and int(GameState.bag_of(GUEST)["items"].get("stone", 0)) == 1 and GameState.item_count("stone") == 0, "the guest picked up the stone and used it")
	_expect(await _until(func() -> bool: return int(GameState.friends.get("maple", {}).get("points", 0)) == 10, 10.0), "the guest's chat with today's visitor counts for the shared friendship")
	_expect(await _until(func() -> bool: return GameState.stats["fish"].size() >= 1 and GameState.bin.is_empty() and not GameState.bag_of(GUEST)["bin"].is_empty(), 10.0), "the guest's catches (pond and river) are tallied, and one lands in the guest's part of the shipping bin")
	await _shot("coop_host")

	# Bedtime: both go indoors and get into the bed.
	_expect(await _until(func() -> bool: return GameState.is_indoors(Vector2i(guest_node.position / 16.0)), 10.0), "host sees the guest go indoors")
	main.get("player").call("go_inside")
	GameState.request_sleep(HOST)
	_expect(TimeManager.day_index == 0 and GameState.is_sleeping(HOST), "day waits while only the host is in bed")
	_expect(await _until(func() -> bool: return GameState.sleeping.size() == 2, 15.0) and TimeManager.day_index == 0, "both are tucked in together before the night falls")
	_expect(await _until(func() -> bool: return TimeManager.day_index == 1, 15.0), "day ends once both are in bed")
	_expect(kisses.size() == 1 and (kisses[0] == HOST or kisses[0] == GUEST), "as the night fell, one leaned over to kiss the other")
	_check_morning()
	_expect(GameState.coins == 160 and int(GameState.bag_of(GUEST)["coins"]) > 10, "the night's sale paid the guest, not the host")
	_expect(FileAccess.file_exists(save_file), "host saved the garden")
	_expect(await _until(func() -> bool: return TimeManager.season() == 2 and TimeManager.minutes == 20 * 60 and TimeManager.day_of_season() == 5, 15.0), "the guest's clock tower change reaches the host")
	_expect(await _until(func() -> bool: return Net.slots().size() == 1, 15.0), "host notices the guest leaving")
	_expect(main.get("remote_players").is_empty(), "guest's character is removed")


func _run_guest() -> void:
	if Net.relay_enabled():
		await _join_by_code()
	else:
		await _join_by_discovery()
	await _after_join()


func _join_by_code() -> void:
	# See the garden is open, then join with nothing but its invite code.
	Net.start_lookup(["TESTAB", "NOSUCH"])
	_expect(await _until(func() -> bool: return Net.open_gardens.has("TESTAB"), 20.0), "guest sees the garden is open, by invite code")
	_expect(not Net.open_gardens.has("NOSUCH") and Net.open_gardens.get("TESTAB", {}).get("name", "") == "Test Garden", "with its name, and no garden for an unknown code")
	main.call("start_join", "code:TESTAB")


func _join_by_discovery() -> void:
	# Find the host the way the Join screen does, without typing an address.
	Net.start_discovery()
	_expect(await _until(func() -> bool: return not Net.found_gardens.is_empty(), 10.0), "guest finds the host on the network by itself")
	var address: String = Net.found_gardens.keys()[0] if not Net.found_gardens.is_empty() else "127.0.0.1"
	var found: Dictionary = Net.found_gardens.get(address, {"name": "", "port": 24999, "full": false})
	_expect(found["name"] == "Test Garden" and not bool(found["full"]), "and sees its name and that there is room")
	main.call("start_join", "%s:%d" % [address, int(found["port"])])


func _after_join() -> void:
	_expect(await _until(func() -> bool: return Net.local_id() == GUEST, 15.0), "joined and given slot 2")
	_expect(await _until(func() -> bool: return GameState.soil.has(Vector2i(10, 8)), 5.0), "late joiner receives the existing garden")
	_expect(main.get("remote_players").has(HOST), "host's character appears on the guest's screen")

	await _tap(KEY_SPACE)  # hoe, from the keyboard, sent to the host
	_expect(await _until(func() -> bool: return GameState.soil.has(GUEST_CELL), 5.0), "guest tilled with a key press")
	GameState.request_plant(GUEST, GUEST_CELL, "moonbell")
	GameState.request_water(GUEST, GUEST_CELL)
	_expect(await _until(func() -> bool: return GameState.plants.has(GUEST_CELL), 5.0), "guest's plant comes back from the host")
	_expect(await _until(func() -> bool: return GameState.plants.has(HOST_CELL), 10.0), "host's planting reaches the guest")
	GameState.request_pet(GUEST, HOST_CELL)
	_expect(await _until(func() -> bool: return bool(GameState.tree["watered"]), 10.0), "guest sees the host water the Heart Tree")
	GameState.request_pet(GUEST, TREE_CELL)
	_expect(await _until(func() -> bool: return GameState.journal_level("moonbell") == 1 and GameState.journal_level("sunpuff") == 1, 10.0), "journal entries are shared")
	_expect(await _until(func() -> bool: return GameState.plants[HOST_CELL]["petted_by"].size() == 2, 10.0), "both players petted the same plant")
	_expect(GameState.seed_count("moonbell") == 3 and GameState.seed_count("sunpuff") == 6, "the guest's own seed bag: the host's planting didn't use it")
	_expect(GameState.get_energy(GUEST) == 96, "guest sees their own energy (2 till, 1 plant, 1 water)")
	_expect(await _until(func() -> bool: return int(GameState.produce.get("sunpuff", 0)) == 2, 10.0), "guest receives something to sell")
	_expect(GameState.coins == GameState.START_COINS, "the host's sale doesn't change the guest's purse")
	GameState.request_sell(GUEST, "sunpuff", 2)
	_expect(await _until(func() -> bool: return GameState.coins == 160, 10.0), "guest sells into their own purse")
	GameState.request_buy_hat(GUEST, "flower")
	_expect(await _until(func() -> bool: return GameState.hat_of(GUEST) == "flower" and GameState.coins == 10, 10.0), "guest buys a hat with their own coins and wears it")
	_expect(await _until(func() -> bool: return GameState.object_kind(DROP_CELL) == "dropped", 10.0), "guest sees the stone the host dropped")
	GameState.request_harvest(GUEST, DROP_CELL)
	_expect(await _until(func() -> bool: return GameState.item_count("stone") == 2 and not GameState.objects.has(DROP_CELL), 10.0), "guest picks it up into their own bag")
	GameState.request_craft(GUEST, "path")
	_expect(await _until(func() -> bool: return GameState.item_count("path") == 1, 10.0), "guest crafts a stepping stone")
	GameState.request_place(GUEST, Vector2i(3, 14), "path")
	_expect(await _until(func() -> bool: return GameState.object_kind(Vector2i(3, 14)) == "path", 10.0), "and places it in the garden")
	_expect(await _until(func() -> bool: return GameState.scenery_at(Vector2i(30, 2)) == "" and GameState.object_kind(Vector2i(30, 2)) == "dropped", 10.0), "guest sees the host's oak come down, leaving wood")
	_expect(await _until(func() -> bool: return Net.names.get(HOST, "") == "Host Tester", 10.0), "guest learns the host's name")
	Net.send_emote(1)
	Net.send_chat("hello from the guest")
	_expect(GameState.visitor_today() == "maple", "guest sees who is visiting today")
	GameState.request_talk(GUEST, "maple")
	_expect(await _until(func() -> bool: return GameState.hearts("maple") == 0 and int(GameState.friends.get("maple", {}).get("points", 0)) == 10, 10.0), "guest talks to the visitor and the friendship comes back from the host")
	GameState.request_fish(GUEST, true)
	var catch: Array = [""]
	_expect(await _until(func() -> bool:
		for id: String in GameState.FISH:
			if GameState.item_count(id) > 0:
				catch[0] = id
		return catch[0] != "", 10.0), "guest lands a fish and it comes back from the host")
	GameState.request_ship(GUEST, catch[0], 1)
	_expect(await _until(func() -> bool: return int(GameState.bin.get(catch[0], 0)) == 1, 10.0), "and ships it in their part of the bin")
	var before_river: Dictionary = GameState.items.duplicate()
	GameState.request_fish(GUEST, true, true)
	var river: Array = [""]
	_expect(await _until(func() -> bool:
		for id: String in GameState.RIVER_FISH + ["goldie"]:
			if GameState.item_count(id) > int(before_river.get(id, 0)):
				river[0] = id
		return river[0] != "", 10.0), "guest fishes the town's river")
	GameState.request_donate(GUEST, river[0])
	_expect(await _until(func() -> bool: return GameState.donated(river[0]), 10.0), "and gives the catch to the museum, which the host's town keeps")
	await _hold(KEY_A, 0.4)  # walk left so the host can see us move
	await _wait(0.5)
	main.get("player").call("go_inside")

	_expect(await _until(func() -> bool: return GameState.is_sleeping(HOST), 15.0), "guest sees the host go to bed")
	_expect(TimeManager.day_index == 0, "day has not ended yet")
	await _wait(0.3)
	await _shot("coop_guest")
	GameState.request_sleep(GUEST)
	_expect(await _until(func() -> bool: return GameState.sleeping.size() == 2, 5.0) and TimeManager.day_index == 0, "the guest sees both of them in bed before the night falls")
	_expect(await _until(func() -> bool: return TimeManager.day_index == 1, 10.0), "day ends for the guest too")
	_expect(kisses.size() == 1 and (kisses[0] == HOST or kisses[0] == GUEST), "the guest sees the same goodnight kiss")
	_check_morning()
	_expect(await _until(func() -> bool: return GameState.coins > 10, 5.0), "the night's sale paid the guest")
	_expect(GameState.save_path == "" and not FileAccess.file_exists(save_file), "guest does not save the host's garden")
	# The clock tower, used by the guest: both gardens jump together.
	GameState.request_set_time(GUEST, 2 * 28 + 4, 20 * 60, false)
	_expect(await _until(func() -> bool: return TimeManager.season() == 2 and TimeManager.minutes == 20 * 60, 10.0), "guest's clock tower change comes back from the host")
	_expect(await _until(func() -> bool: return bool(GameState.plants[HOST_CELL]["dormant"]), 10.0), "and the spring plant is dormant in fall on the guest's side")
	await _wait(2.5)
	await _shot("coop_guest_morning")


func _check_morning() -> void:
	var shared: Dictionary = GameState.plants[HOST_CELL]
	_expect(int(shared["days_grown"]) == 1, "watered plant grew overnight")
	_expect(int(shared["happiness"]) == 50 + 4 + 8 + 6, "duet bonus applied (mood 68)")
	_expect(shared["caretakers"].has("1") and shared["caretakers"].has("2"), "plant remembers both carers")
	_expect(int(GameState.plants[GUEST_CELL]["happiness"]) == 54, "guest's plant: watered, not petted (mood 54)")
	_expect(GameState.get_energy(GUEST) == 100 and GameState.get_energy(HOST) == 100, "both wake with full energy")
	_expect(GameState.sleeping.is_empty(), "nobody is marked asleep in the morning")
	_expect(int(GameState.tree["love"]) == 2 + 3 + 2 + 2, "Heart Tree love: 2 plants + watered + two hugs")


func _expect(cond: bool, label: String) -> void:
	print("  %s %s  %s" % [role, "ok  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _until(condition: Callable, timeout: float) -> bool:
	var waited: float = 0.0
	while waited < timeout:
		if condition.call():
			return true
		await get_tree().create_timer(0.05).timeout
		waited += 0.05
	return condition.call()


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
