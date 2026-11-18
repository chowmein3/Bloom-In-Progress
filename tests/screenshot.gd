extends Node
## Plays a short scripted session in the real game scene and saves pictures.
## Run (needs a display):  godot --path . res://tests/screenshot.tscn -- <output folder>

const P := 1
var out_dir: String = "user://"
var failures: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	TimeManager.paused = true
	Net.stop_lookup()
	Net.relay_url = ""  # never touch the real relay from a test
	GameState.wild_growth = false  # no surprise debris where a test wants to dig
	TimeManager.rain_chance = 0.0
	GameState.save_path = "user://screenshot_save.json"
	GameState.new_game()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.call("start_solo")
	TimeManager.paused = true
	var player: Node2D = main.get("player")
	await _frames(5)

	# Drive the player with real key presses: walk down, till, plant, water, pet.
	await _hold(KEY_S, 0.6)
	var start: Vector2i = player.call("target_cell")
	await _tap(KEY_SPACE)
	_expect(GameState.soil.has(start), "key press tilled the tile in front")
	await _tap(KEY_3)
	await _tap(KEY_SPACE)
	_expect(GameState.plants.has(start), "key press planted a seed")
	await _tap(KEY_2)
	await _tap(KEY_SPACE)
	_expect(bool(GameState.soil[start]["watered"]), "key press watered it")
	await _tap(KEY_F)
	_expect(not GameState.plants[start]["petted_by"].is_empty(), "key press petted it")
	await _frames(8)
	await _shot("1_first_seed")

	# Fill out a little garden through the same request API the player uses.
	var kinds: Array[String] = ["sunpuff", "moonbell", "dewcup", "moonbell", "dewcup"]
	for i in kinds.size():
		var cell := Vector2i(9 + i * 2, 8)
		GameState.request_till(P, cell)
		GameState.request_plant(P, cell, kinds[i])
	for day in 9:
		for cell: Vector2i in GameState.plants.keys():
			GameState.request_water(P, cell)
			if cell.x != 9:
				GameState.request_pet(P, cell)
		GameState.request_water(P, Vector2i(9, 4))
		GameState.request_pet(P, Vector2i(9, 4))
		if day == 4:
			await _wait(2.0)
			await _shot("2_growing")
		GameState.end_day(false)
		GameState.request_till(P, Vector2i(9 + day, 10))
	await _wait(2.0)
	for cell: Vector2i in GameState.plants.keys():
		GameState.request_water(P, cell)
	GameState.request_pet(P, Vector2i(11, 8))
	await _frames(10)
	await _shot("3_in_bloom")

	# The journal, opened with its key.
	await _tap(KEY_J)
	await _frames(5)
	await _shot("5_journal")
	await _tap(KEY_J)

	# A peek at later seasons and a grown Heart Tree (set directly, for the picture only).
	GameState.tree["love"] = 300
	for season in [2, 3]:
		TimeManager.day_index = season * 28 + 4
		for cell: Vector2i in GameState.plants.keys():
			GameState.plants[cell]["dormant"] = season == 3
		GameState.state_reloaded.emit()
		await _wait(0.5)
		await _shot("6_season_%d" % season)
	TimeManager.day_index = 12
	GameState.state_reloaded.emit()

	TimeManager.rain_chance = 1.0
	GameState.end_day(false)
	TimeManager.minutes = 19 * 60
	TimeManager.time_changed.emit()
	await _wait(2.0)
	await _shot("4_rainy_evening")

	# A festival evening: bunting on the buildings, the party in the yard.
	TimeManager.raining = false
	TimeManager.rain_chance = 0.0
	TimeManager.day_index = 0
	while GameState.festival_today() == -1:
		TimeManager.day_index += 1
	TimeManager.minutes = 17 * 60 + 30
	TimeManager.time_changed.emit()
	GameState.state_reloaded.emit()
	for spot: Vector2 in [Vector2(14, 5), Vector2(3, 3), Vector2(34, 21), Vector2(4, 22)]:
		player.position = spot * 16.0 + Vector2(8, 8)
		await _wait(1.5)
		await _shot("7_festival_%d_%d" % [int(spot.x), int(spot.y)])
	# The backpack with its hot bar row, then the oven tab.
	GameState.items["oven"] = 1
	GameState.items["flour"] = 3
	GameState.inventory_changed.emit()
	player.call("set_quick", 0, "item:oven")
	player.call("set_quick", 1, "seed:moonbell")
	player.set("facing", Vector2i.DOWN)
	player.call("drop", "item:flour")
	await _wait(0.5)
	await _shot("8_dropped")
	await _tap(KEY_E)
	await _frames(6)
	await _shot("9_backpack")
	await _tap(KEY_E)

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://screenshot_save.json"))
	print("SCREENSHOTS DONE" if failures == 0 else "%d CHECKS FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _expect(cond: bool, label: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


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
	await _frames(3)
	_key(key, false)
	await _frames(3)


func _hold(key: Key, seconds: float) -> void:
	_key(key, true)
	await get_tree().create_timer(seconds).timeout
	_key(key, false)
	await _frames(2)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(shot_name + ".png"))
