extends Node
## Walks through the title and pause menus in the real game scene:
## new garden, pause, return to title, load, host, failed join, delete.
##   godot --headless --path . res://tests/menu_test.tscn
## Add an output folder after "--" (and drop --headless) to save pictures.

var failures: int = 0
var out_dir: String = ""
var main: Node
var menu: CanvasLayer


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	Net.port = 24998
	Net.use_upnp = false
	Net.stop_lookup()
	Net.relay_url = ""  # never touch the real relay from a test
	GameState.wild_growth = false  # no surprise debris where a test wants to dig
	TimeManager.rain_chance = 0.0
	GameState.saves_dir = "user://menu_test_saves"
	for old: Dictionary in GameState.list_gardens():
		GameState.delete_garden(old["path"])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	menu = main.get("menu")
	var player: Node2D = main.get("player")
	await _wait(0.2)

	print("title")
	_expect(menu.visible and _screen() == "title", "the game opens on the title menu")
	_expect(_has("New") and _has("Load") and _has("Co-op") and _has("Exit"), "with New, Load, Co-op and Exit")
	_expect(bool(player.get("in_menu")) and TimeManager.paused, "the game waits behind it")
	await _shot("menu_title")

	print("new garden")
	_click("New")
	_expect(_screen() == "new", "New asks for a garden name")
	_field().text = "Willow Bend"
	await _shot("menu_new")
	_click("Start")
	_expect(not menu.visible and not bool(player.get("in_menu")), "Start begins play")
	_expect(GameState.garden_name == "Willow Bend" and FileAccess.file_exists(GameState.save_path), "in a named, saved garden")
	_expect(not TimeManager.paused and main.get("hud").visible, "the clock runs and the HUD shows")
	GameState.request_till(1, Vector2i(4, 9))
	GameState.request_plant(1, Vector2i(4, 9), "sunpuff")  # planted soil never reverts to grass
	GameState.request_sleep(1)
	await _wait(2.0)

	print("pause")
	await _tap(KEY_ESCAPE)
	_expect(menu.visible and _screen() == "pause", "Esc opens the pause menu")
	_expect(bool(player.get("in_menu")) and TimeManager.paused, "which stops the player and, alone, the clock")
	await _shot("menu_pause")
	await _tap(KEY_ESCAPE)
	_expect(not menu.visible and not TimeManager.paused, "Esc again resumes")
	await _tap(KEY_ESCAPE)
	_click("Return to title")
	_expect(_screen() == "title" and GameState.save_path == "" and GameState.soil.is_empty(), "Return to title closes the garden")

	print("load")
	_click("Load")
	_expect(_screen() == "load" and _has("Willow Bend\nSpring 2, Year 1"), "Load lists the garden with its date")
	await _shot("menu_load")
	_click("Willow Bend")
	_expect(not menu.visible and TimeManager.day_index == 1 and GameState.soil.has(Vector2i(4, 9)), "choosing it brings the garden back")

	print("co-op")
	await _tap(KEY_ESCAPE)
	_click("Return to title")
	_click("Co-op")
	_expect(_screen() == "coop" and _has("Host") and _has("Join"), "Co-op offers Host and Join")
	await _shot("menu_coop")
	_click("Host")
	_expect(_has("Host a new garden") and _has("Willow Bend"), "Host offers a new garden or a saved one")
	_click("Willow Bend")
	_expect(not menu.visible and Net.online and Net.is_host() and GameState.soil.has(Vector2i(4, 9)), "hosting a saved garden opens it for a partner")
	await _tap(KEY_ESCAPE)
	_expect(not TimeManager.paused, "pausing while hosting leaves the clock running")
	_click("Return to title")
	_expect(not Net.online and _screen() == "title", "returning to title stops hosting")

	_click("Co-op")
	_click("Host")
	_click("Host a new garden")
	_field().text = "Second Plot"
	_click("Start")
	_expect(Net.online and GameState.garden_name == "Second Plot", "hosting a new garden creates and opens it")
	await _tap(KEY_ESCAPE)
	_click("Return to title")

	_click("Co-op")
	_click("Join")
	_expect(_screen() == "join", "Join asks for an address")
	_field().text = ""
	_field().text_changed.emit("")
	_click("Join")
	_expect(_status() != "", "an empty address is refused")
	_field().text = "127.0.0.1"
	_field().text_changed.emit("127.0.0.1")
	_click("Join")
	_expect(_status().begins_with("Knocking"), "joining shows that it is connecting")
	await _wait(9.0)
	_expect(menu.visible and not Net.online and _status().begins_with("Couldn't reach"), "an unreachable garden is reported and the menu stays usable")
	_click("Back")
	_click("Back")

	print("invite codes (relay set up)")
	const Settings := preload("res://scripts/settings.gd")
	Net.relay_url = "ws://127.0.0.1:9"  # nothing listens here; only the screens are checked
	Settings.remember_garden("ABCDEF", "Partner Plot")
	_click("Co-op")
	_click("Join")
	_expect(_has("Partner Plot  (not open)"), "a garden joined before is listed, marked not open")
	_expect(_buttons().any(func(b: Node) -> bool: return str(b.get("text")).begins_with("Partner Plot") and bool(b.get("disabled"))), "and can't be clicked until its host opens it")
	_expect(_field().placeholder_text == "ABC-DEF", "a new garden is joined by invite code, not address")
	_field().text_changed.emit("abc")
	_click("Join")
	_expect(_status().begins_with("Invite codes are six"), "a short code is refused")
	Net.open_gardens = {"ABCDEF": {"name": "Partner Plot", "full": false}}
	Net.open_gardens_changed.emit()
	_expect(_buttons().any(func(b: Node) -> bool: return str(b.get("text")) == "Partner Plot" and not bool(b.get("disabled"))), "when the host opens it, it becomes one click")
	Settings.forget_garden("ABCDEF")
	_click("Back")
	_click("Back")
	Net.stop_lookup()
	Net.relay_url = ""

	print("delete")
	_click("Load")
	_expect(GameState.list_gardens().size() == 2, "both gardens are on the list")
	_click("Delete")
	_expect(GameState.list_gardens().size() == 2 and _has("Sure?"), "Delete asks first")
	_click("Sure?")
	_click("Delete")
	_click("Sure?")
	_expect(GameState.list_gardens().is_empty() and _has("Back"), "confirmed deletes remove the gardens")

	print("\n%s" % ("MENU TEST PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _screen() -> String:
	return str(menu.get("screen"))


func _status() -> String:
	return str((menu.get("_status") as Label).text)


func _buttons() -> Array[Node]:
	return menu.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())


func _has(text: String) -> bool:
	return _buttons().any(func(b: Node) -> bool: return str(b.get("text")).begins_with(text))


func _field() -> LineEdit:
	var fields: Array[Node] = menu.find_children("*", "LineEdit", true, false).filter(func(f: Node) -> bool: return not f.is_queued_for_deletion())
	return fields[0] as LineEdit


## Presses the first enabled button whose label starts with `text`.
func _click(text: String) -> void:
	for button: Node in _buttons():
		if str(button.get("text")).begins_with(text) and not bool(button.get("disabled")):
			button.emit_signal("pressed")
			return
	_expect(false, "button '%s' is there to press" % text)


func _expect(cond: bool, label: String) -> void:
	print("  %s  %s" % ["ok  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _tap(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(0.1)


func _shot(shot_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	await _wait(0.1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
