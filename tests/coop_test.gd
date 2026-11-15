extends Node
## Two-player check using the real game scene. Start two copies, host first:
##   godot --headless --path . res://tests/coop_test.tscn -- host
##   godot --headless --path . res://tests/coop_test.tscn -- guest
## Add an output folder as a second argument (and drop --headless) to also
## save a picture from each side. tests/run_coop_test.sh does all of this.

const HOST := 1
const GUEST := 2
const HOST_CELL := Vector2i(13, 5)  # the tile in front of the host's start spot
const TREE_CELL := Vector2i(9, 4)
const GUEST_CELL := Vector2i(15, 5)  # the tile in front of the guest's start spot

var role: String = "host"
var out_dir: String = ""
var save_file: String = ""
var failures: int = 0
var main: Node


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		role = args[0]
	if args.size() > 1:
		out_dir = args[1]
	Net.port = 24999
	TimeManager.rain_chance = 0.0
	GameState.rng.seed = 1
	save_file = "user://coop_test_%s.json" % role
	GameState.save_path = save_file
	GameState.new_game()
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
	main.call("start_host")
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

	_expect(await _until(func() -> bool: return GameState.plants.has(GUEST_CELL), 10.0), "guest's planting reaches the host")
	_expect(await _until(func() -> bool: return GameState.plants[HOST_CELL]["petted_by"].has("2"), 10.0), "guest petted the host's plant")
	_expect(await _until(func() -> bool: return GameState.tree["hugged_by"].size() == 2, 10.0), "both players hugged the Heart Tree")
	_expect(GameState.get_energy(GUEST) == 96, "guest's energy is tracked by the host (2 till, 1 plant, 1 water)")
	var guest_node: Node2D = main.get("remote_players")[GUEST]
	_expect(await _until(func() -> bool: return guest_node.position.x < 15.4 * 16, 10.0), "guest's movement shows on the host's screen")
	await _shot("coop_host")

	GameState.request_sleep(HOST)
	_expect(TimeManager.day_index == 0 and GameState.is_sleeping(HOST), "day waits while only the host is in bed")
	_expect(await _until(func() -> bool: return TimeManager.day_index == 1, 15.0), "day ends once both are in bed")
	_check_morning()
	_expect(FileAccess.file_exists(save_file), "host saved the garden")
	_expect(await _until(func() -> bool: return Net.slots().size() == 1, 15.0), "host notices the guest leaving")
	_expect(main.get("remote_players").is_empty(), "guest's character is removed")


func _run_guest() -> void:
	main.call("start_join", "127.0.0.1")
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
	_expect(GameState.seed_count("moonbell") == 3 and GameState.seed_count("sunpuff") == 5, "shared seed bag stays in step")
	_expect(GameState.get_energy(GUEST) == 96, "guest sees their own energy")
	await _hold(KEY_A, 0.4)  # walk left so the host can see us move

	_expect(await _until(func() -> bool: return GameState.is_sleeping(HOST), 15.0), "guest sees the host go to bed")
	_expect(TimeManager.day_index == 0, "day has not ended yet")
	await _wait(0.3)
	await _shot("coop_guest")
	GameState.request_sleep(GUEST)
	_expect(await _until(func() -> bool: return TimeManager.day_index == 1, 10.0), "day ends for the guest too")
	_check_morning()
	_expect(GameState.save_path == "" and not FileAccess.file_exists(save_file), "guest does not save the host's garden")
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
