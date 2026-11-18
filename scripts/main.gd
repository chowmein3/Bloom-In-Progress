extends Node2D
## Builds the garden scene in code: ground, plants, players, camera, HUD and
## the start menu, and starts solo / hosted / joined games.
##
## The title menu picks the garden (GameState.create_garden / open_garden)
## before start_solo() or start_host() begins play in it.
##
## To skip the menu, pass a mode after "--" on the command line:
##   godot --path . -- --solo | --host | --join=192.168.1.20

const Assets := preload("res://scripts/assets.gd")

const Ground := preload("res://scripts/ground.gd")
const PlantView := preload("res://scripts/plant_view.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Rain := preload("res://scripts/rain.gd")
const Menu := preload("res://scripts/menu.gd")
const Settings := preload("res://scripts/settings.gd")
const TreeView := preload("res://scripts/tree_view.gd")
const Journal := preload("res://scripts/journal.gd")
const Interior := preload("res://scripts/interior.gd")
const BedView := preload("res://scripts/bed_view.gd")
const Inventory := preload("res://scripts/inventory.gd")
const Shop := preload("res://scripts/shop.gd")
const Clock := preload("res://scripts/clock.gd")
const ObjectView := preload("res://scripts/object_view.gd")
const PondView := preload("res://scripts/pond_view.gd")
const Fishing := preload("res://scripts/fishing.gd")
const Bin := preload("res://scripts/bin.gd")
const AnimalView := preload("res://scripts/animal_view.gd")
const MineView := preload("res://scripts/mine_view.gd")
const Villager := preload("res://scripts/villager.gd")
const Notices := preload("res://scripts/notices.gd")
const GreenhouseView := preload("res://scripts/greenhouse_view.gd")
const Social := preload("res://scripts/social.gd")
const FestivalView := preload("res://scripts/festival_view.gd")
const SceneryView := preload("res://scripts/scenery_view.gd")
const BorderView := preload("res://scripts/border_view.gd")
const ForestFront := preload("res://scripts/forest_front.gd")
const CAMERA_MARGIN := Vector2(64, 64)  # how far the view may go past the garden's edge
const TowerView := preload("res://scripts/tower_view.gd")
const TimeWarp := preload("res://scripts/time_warp.gd")
const TILE := 16

var player: Node2D
var hud: CanvasLayer
var menu: CanvasLayer
var remote_players: Dictionary = {}  # slot -> Player node
var _leaving: bool = false
var _interior: Node2D
var _home: Sprite2D
var _camera: Camera2D
var _weather: CanvasLayer
var _entities: Node2D
var _views: Dictionary = {}  # Vector2i -> PlantView
var _things: Dictionary = {}  # Vector2i -> ObjectView
var _flats: Node2D
var _mine: Node2D
var _coop: Sprite2D
var _barn: Sprite2D
var _visitor: Sprite2D
var _animal_views: Array = []
var _greeted: Dictionary = {}  # slots whose arrival has been announced by name
var _light: CanvasModulate


func _ready() -> void:
	_setup_input()
	add_child(BorderView.new())  # the land round the garden, under everything
	add_child(Ground.new())
	_interior = Interior.new()
	add_child(_interior)
	_mine = MineView.new()
	add_child(_mine)
	var pond := PondView.new()
	add_child(pond)
	_flats = Node2D.new()  # rugs and other flat things: above the floor, under everyone
	add_child(_flats)

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

	# The home, stall, bed and Heart Tree stand in the same layer as the
	# players, sorted by their base.
	_home = Sprite2D.new()
	_home.centered = false
	_home.offset = Vector2(-24, -48)
	_home.position = Vector2((GameState.TENT_RECT.position.x + GameState.TENT_RECT.size.x / 2.0) * TILE, GameState.TENT_RECT.end.y * TILE)
	_entities.add_child(_home)
	var stall := Sprite2D.new()
	stall.texture = Assets.texture("res://assets/sprites/stall.png")
	stall.centered = false
	stall.offset = Vector2(-24, -48)
	stall.position = Vector2((GameState.STALL_RECT.position.x + GameState.STALL_RECT.size.x / 2.0) * TILE, GameState.STALL_RECT.end.y * TILE)
	_entities.add_child(stall)
	_entities.add_child(BedView.new())
	_coop = _standing("res://assets/sprites/coop.png", GameState.COOP_RECT, Vector2(-24, -40))
	_barn = _standing("res://assets/sprites/barn.png", GameState.BARN_RECT, Vector2(-24, -40))
	_standing("res://assets/sprites/mine.png", GameState.MINE_RECT, Vector2(-16, -32))
	for fixed: Array in [["mailbox", GameState.MAILBOX_CELL], ["board", GameState.BOARD_CELL]]:
		var post := ObjectView.new()
		post.kind = fixed[0]
		post.position = Vector2(fixed[1] * TILE) + Vector2(8, 16)
		_entities.add_child(post)
	add_child(GreenhouseView.new())
	add_child(FestivalView.new())
	# The land's own trees, bushes and boulders, then the woods, cliff and
	# fence all round the edge.
	for at: Vector2i in GameState.SCENERY.keys():
		var standing := SceneryView.new()
		standing.kind = GameState.SCENERY[at]
		standing.position = Vector2(at * TILE) + Vector2(8, 16)
		standing.flip_h = hash(at) % 2 == 0 and standing.kind != "log"
		_entities.add_child(standing)
	BorderView.decorate(_entities)
	add_child(ForestFront.new())  # the near woods along the bottom, over everything
	_visitor = Sprite2D.new()
	_visitor.centered = false
	_visitor.offset = Vector2(-8, -23)
	_visitor.position = Vector2(GameState.VISITOR_CELL * TILE) + Vector2(8, 15)
	_entities.add_child(_visitor)
	var bin_box := Sprite2D.new()
	bin_box.texture = Assets.texture("res://assets/sprites/items/bin.png")
	bin_box.centered = false
	bin_box.offset = Vector2(-8, -16)
	bin_box.position = Vector2(GameState.BIN_CELL * TILE) + Vector2(8, 16)
	_entities.add_child(bin_box)
	var tower := TowerView.new()
	tower.position = Vector2((GameState.TOWER_RECT.position.x + GameState.TOWER_RECT.size.x / 2.0) * TILE, GameState.TOWER_RECT.end.y * TILE)
	_entities.add_child(tower)
	var tree := TreeView.new()
	tree.position = Vector2((GameState.TREE_RECT.position.x + GameState.TREE_RECT.size.x / 2.0) * TILE, GameState.TREE_RECT.end.y * TILE)
	_entities.add_child(tree)

	player = Player.new()
	player.player_id = Net.local_id()
	player.cursor = cursor_holder
	player.position = Vector2(13.5 * TILE, 5 * TILE)
	_entities.add_child(player)

	_camera = Camera2D.new()
	player.add_child(_camera)
	player.area_changed.connect(_on_area_changed)
	get_viewport().size_changed.connect(_on_area_changed)

	_light = CanvasModulate.new()
	add_child(_light)

	_weather = CanvasLayer.new()
	_weather.layer = 5
	_weather.add_child(Rain.new())
	add_child(_weather)

	hud = Hud.new()
	hud.player = player
	hud.remote_players = remote_players
	add_child(hud)

	var journal := Journal.new()
	journal.player = player
	add_child(journal)
	var inventory := Inventory.new()
	inventory.player = player
	add_child(inventory)
	var shop := Shop.new()
	shop.player = player
	add_child(shop)
	player.shop_requested.connect(shop.open)
	player.bake_requested.connect(inventory.open_tab.bind("Oven"))
	TimeManager.time_changed.connect(func() -> void:
		if GameState.festival_today() != -1 and TimeManager.minutes == FestivalView.PARTY_START:
			hud.call("show_message", "The %s party has begun in the yard!" % GameState.FESTIVALS[GameState.festival_today()]["name"], 6.0))
	var clock := Clock.new()
	clock.player = player
	add_child(clock)
	player.clock_requested.connect(clock.open)
	var bin_screen := Bin.new()
	bin_screen.player = player
	add_child(bin_screen)
	player.bin_requested.connect(bin_screen.open)
	var fishing := Fishing.new()
	fishing.player = player
	fishing.pond = pond
	add_child(fishing)
	player.fish_requested.connect(fishing.cast)
	var villager := Villager.new()
	villager.player = player
	add_child(villager)
	player.villager_requested.connect(villager.open)
	var notices := Notices.new()
	notices.player = player
	add_child(notices)
	player.mail_requested.connect(notices.open_mail)
	player.board_requested.connect(notices.open_board)
	var social := Social.new()
	social.player = player
	add_child(social)
	Net.chat.connect(func(slot: int, text: String) -> void: hud.call("show_message", "%s: %s" % [Net.name_of_slot(slot), text], 7.0))
	Net.names_changed.connect(func() -> void:
		for slot: int in Net.names.keys():
			if not _greeted.has(slot):
				_greeted[slot] = true
				hud.call("show_message", "%s is in the garden!" % Net.names[slot], 5.0))
	GameState.animals_changed.connect(_refresh_animals)
	GameState.state_reloaded.connect(_refresh_animals)
	TimeManager.time_changed.connect(_refresh_visitor)
	var warp := TimeWarp.new()
	warp.player = player
	add_child(warp)

	menu = Menu.new()
	add_child(menu)
	menu.new_chosen.connect(func(garden_name: String) -> void:
		GameState.create_garden(garden_name)
		start_solo())
	menu.load_chosen.connect(func(path: String) -> void:
		if GameState.open_garden(path):
			start_solo()
		else:
			menu.call("show_title", "That garden's save file couldn't be read"))
	menu.host_new_chosen.connect(func(garden_name: String) -> void:
		GameState.create_garden(garden_name)
		start_host())
	menu.host_load_chosen.connect(func(path: String) -> void:
		if GameState.open_garden(path):
			start_host()
		else:
			menu.call("show_title", "That garden's save file couldn't be read"))
	menu.join_chosen.connect(start_join)
	menu.resume_chosen.connect(_resume)
	menu.save_chosen.connect(GameState.save_game)
	if bool(Settings.read().get("fullscreen", false)) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	menu.title_chosen.connect(return_to_title)
	menu.exit_chosen.connect(func() -> void: get_tree().quit())
	Net.welcomed.connect(_on_welcomed)
	Net.join_failed.connect(_on_join_failed)
	Net.session_ended.connect(_on_session_ended)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.player_state.connect(_on_player_state)
	Net.relay_ready.connect(_on_relay_ready)
	Net.relay_failed.connect(_on_relay_failed)
	Net.internet_ready.connect(func(address: String) -> void:
		if remote_players.is_empty():
			hud.call("set_status", "Hosting. Partner joins:\nSame Wi-Fi: automatic\nElsewhere: %s" % address))
	TimeManager.paused = true  # the clock waits behind the menu
	hud.visible = false

	GameState.plant_added.connect(_add_view)
	GameState.plant_removed.connect(_remove_view)
	GameState.plant_petted.connect(func(cell: Vector2i) -> void:
		if _views.has(cell):
			_views[cell].show_love())
	GameState.cell_changed.connect(_refresh_view)
	GameState.object_changed.connect(_refresh_thing)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.economy_changed.connect(_on_area_changed)
	GameState.state_reloaded.connect(_on_area_changed)
	GameState.state_reloaded.connect(_rebuild_views)
	TimeManager.time_changed.connect(_update_light)
	_rebuild_views()
	_on_area_changed()

	# Shortcuts past the menu: --solo and --host use the most recent garden
	# (or make one), --join=<address> joins a partner.
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--solo" or arg == "--host":
			var gardens: Array[Dictionary] = GameState.list_gardens()
			if gardens.is_empty() or not GameState.open_garden(gardens[0]["path"]):
				GameState.create_garden("My Garden")
			if arg == "--solo":
				start_solo()
			else:
				start_host()
		elif arg.begins_with("--join="):
			start_join(arg.trim_prefix("--join="))


## Esc in game opens the pause menu (unless something else, like the journal,
## used the key first).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("close") and not menu.visible and not bool(player.get("reading")):
		menu.call("show_pause")
		player.set("in_menu", true)
		if not Net.online:
			TimeManager.paused = true  # in co-op the day carries on, as your partner is still playing
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("close") and menu.visible and str(menu.get("screen")) == "pause":
		_resume()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	menu.visible = false
	player.set("in_menu", false)
	TimeManager.paused = not Net.is_host()


## Leave the garden (and any co-op session) and show the title menu.
func return_to_title(status: String = "") -> void:
	_leaving = true
	Net.leave()
	_leaving = false
	_clear_remote_players()
	GameState.close_garden()
	player.set("player_id", Net.local_id())
	player.set("in_menu", true)
	player.position = Vector2(13.5 * TILE, 5 * TILE)
	player.queue_redraw()
	TimeManager.paused = true
	hud.visible = false
	menu.call("set_busy", false)
	menu.call("show_title", status)


func _clear_remote_players() -> void:
	for slot: int in remote_players.keys():
		remote_players[slot].queue_free()
	remote_players.clear()


# ------------------------------------------------------------ starting play

func start_solo() -> void:
	_begin()


func start_host() -> void:
	if Net.relay_enabled():
		# Through the relay: the partner joins from anywhere with the invite code.
		if Net.host_online(GameState.garden_code, GameState.garden_name) != OK:
			return_to_title("The meeting server's address looks wrong")
			return
		_begin()
		hud.call("set_status", "Opening the garden\ngate for your partner...")
		return
	var err: Error = Net.host_game()
	if err != OK:
		return_to_title("Couldn't host. Is another copy already hosting?")
		return
	_begin()
	var addresses: Array[String] = Net.lan_addresses()
	var where: String = addresses[0] if not addresses.is_empty() else "this computer's address"
	hud.call("set_status", "Hosting. Partner joins:\nSame Wi-Fi: automatic\n(or type %s)" % where)
	hud.call("show_message", "Your garden is open. Waiting for your partner...", 6.0)


func _on_relay_ready() -> void:
	var code: String = pretty_code(GameState.garden_code)
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(code)
	if remote_players.is_empty():
		hud.call("set_status", "Garden open. Invite code:\n%s  (copied)" % code)
		hud.call("show_message", "Garden open! Invite code %s is copied: paste it to your partner" % code, 8.0)


func _on_relay_failed(reason: String) -> void:
	match reason:
		"already_hosted":
			hud.call("set_status", "This garden is already\nopen on another computer")
		"unreachable", "lost":
			hud.call("set_status", "Can't reach the meeting\nserver. Trying again...")
		_:
			hud.call("set_status", "Couldn't open the garden\nfor a partner (%s)" % reason)


static func pretty_code(code: String) -> String:
	return "%s-%s" % [code.left(3), code.substr(3)] if code.length() == 6 else code


## `target` is "code:ABCDEF" (invite code, through the relay) or an address.
func start_join(target: String) -> void:
	GameState.close_garden()
	var by_code: bool = target.begins_with("code:")
	var err: Error = Net.join_online(target.trim_prefix("code:")) if by_code else Net.join_game(target)
	if err != OK:
		menu.call("set_status", "That doesn't look right")
		return
	menu.call("set_status", "Knocking on the garden gate...\n(the first knock of the day can take a minute)" if by_code else "Knocking on the garden gate...")
	menu.call("set_busy", true)


func _begin() -> void:
	menu.visible = false
	hud.visible = true
	menu.call("set_busy", false)
	menu.call("set_status", "")
	player.set("player_id", Net.local_id())
	player.set("in_menu", false)
	player.queue_redraw()
	# Only the garden's owner runs the clock; a guest follows the host's.
	TimeManager.paused = not Net.is_host()
	hud.call("set_status", "")
	hud.call("refresh")


func _on_welcomed() -> void:
	player.position = Vector2(15.5 * TILE, 5 * TILE)
	_begin()
	hud.call("set_status", "Visiting partner's garden")
	# Once the garden arrives we know its name and invite code: remember it, so
	# next time it is one click on the Join screen.
	GameState.state_reloaded.connect(func() -> void:
		if Net.online and not Net.is_host() and GameState.garden_code != "":
			Settings.remember_garden(GameState.garden_code, GameState.garden_name), CONNECT_ONE_SHOT)


func _on_join_failed() -> void:
	menu.call("set_busy", false)
	var why: String = "Couldn't reach that garden. Check the address\nand that your partner is hosting."
	match Net.last_join_error:
		"not_open":
			why = "That garden isn't open right now.\nAsk your partner to host it."
		"full":
			why = "Someone is already visiting that garden."
		"bad_code":
			why = "That invite code doesn't look right."
		"timeout", "unreachable", "lost":
			if Net.relay_enabled():
				why = "Couldn't reach the meeting server.\nCheck your internet and try again."
	menu.call("set_status", why)


func _on_session_ended(was_host: bool) -> void:
	if _leaving:
		return  # we chose to leave; return_to_title is handling it
	_clear_remote_players()
	if not was_host:
		return_to_title("The connection to your partner's garden was lost")


func _on_player_joined(slot: int) -> void:
	if remote_players.has(slot):
		return
	var other: Node2D = Player.new()
	other.is_remote = true
	other.player_id = slot
	other.position = Vector2(14.5 * TILE, 5 * TILE)
	_entities.add_child(other)
	remote_players[slot] = other
	Net.announce()  # tell the newcomer our name; theirs arrives the same way
	if Net.is_host():
		hud.call("set_status", "Partner connected")


func _on_player_left(slot: int) -> void:
	if not remote_players.has(slot):
		return
	remote_players[slot].queue_free()
	remote_players.erase(slot)
	hud.call("show_message", "%s left the garden" % Net.name_of_slot(slot), 4.0)
	_greeted.erase(slot)
	Net.names.erase(slot)
	if Net.online and Net.is_host():
		hud.call("set_status", "Garden open. Invite code:\n%s" % pretty_code(GameState.garden_code) if Net.via_relay else "Hosting. Waiting for partner")


func _on_player_state(slot: int, pos: Vector2, facing: Vector2i, moving: bool, tool: int, swings: int) -> void:
	if remote_players.has(slot):
		remote_players[slot].call("remote_update", pos, facing, moving, tool, swings)


## A building sprite standing on `rect`, sorted with the players.
func _standing(path: String, rect: Rect2i, offset: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Assets.texture(path)
	sprite.centered = false
	sprite.offset = offset
	sprite.position = Vector2((rect.position.x + rect.size.x / 2.0) * TILE, rect.end.y * TILE)
	_entities.add_child(sprite)
	return sprite


func _refresh_animals() -> void:
	if _animal_views.size() != GameState.animals.size():
		for view: Node in _animal_views:
			view.queue_free()
		_animal_views.clear()
		for i in GameState.animals.size():
			var view := AnimalView.new()
			view.index = i
			view.position = Vector2(GameState.animal_cell(i) * TILE) + Vector2(8, 15)
			_entities.add_child(view)
			_animal_views.append(view)
	for view: Node in _animal_views:
		view.call("refresh")


func _refresh_visitor() -> void:
	var who: String = GameState.visitor_today()
	_visitor.visible = who != ""
	if who != "":
		_visitor.texture = Assets.texture("res://assets/sprites/villager_%s.png" % who)


## Called when the player goes through the door, and when the home changes:
## fits the camera to the garden or to the room, and shows the right home.
func _on_area_changed() -> void:
	_home.texture = Assets.texture("res://assets/sprites/home_%d.png" % GameState.home_level())
	_coop.visible = GameState.upgrade_level("coop") > 0
	_barn.visible = GameState.upgrade_level("barn") > 0
	_refresh_visitor()
	var inside: bool = player.call("indoors")
	if inside:
		# Centre the room whatever shape the window is (it may be wider or
		# taller than 320x180 in fullscreen).
		var middle: Vector2 = _mine.call("centre") if GameState.is_in_mine(player.call("cell")) else _interior.call("centre")
		var half: Vector2 = get_viewport().get_visible_rect().size / 2.0
		_camera.limit_left = int(middle.x - half.x)
		_camera.limit_right = int(middle.x + half.x)
		_camera.limit_top = int(middle.y - half.y)
		_camera.limit_bottom = int(middle.y + half.y)
	else:
		# The view may run a little past the garden's edge into the woods, so
		# buildings along the top aren't hidden under the HUD.
		_camera.limit_left = int(-CAMERA_MARGIN.x)
		_camera.limit_top = int(-CAMERA_MARGIN.y)
		_camera.limit_right = GameState.WORLD_SIZE.x * TILE + int(CAMERA_MARGIN.x)
		_camera.limit_bottom = GameState.WORLD_SIZE.y * TILE + int(CAMERA_MARGIN.y)
	_camera.reset_smoothing()
	_weather.visible = not inside
	_update_light()


func _on_day_advanced(summary: Dictionary) -> void:
	_refresh_all()
	# Anyone who stayed up past 2am is carried to bed.
	var dozers: Array = summary.get("passed_out", [])
	if dozers.has(player.get("player_id")) and not bool(player.call("indoors")):
		player.call("go_to_bedside")


func _rebuild_views() -> void:
	for cell: Vector2i in _views.keys():
		_views[cell].queue_free()
	_views.clear()
	for cell: Vector2i in GameState.plants.keys():
		_add_view(cell)
	for cell: Vector2i in _things.keys():
		_things[cell].queue_free()
	_things.clear()
	for cell: Vector2i in GameState.objects.keys():
		_refresh_thing(cell)


## Keeps the standing things (debris, fences, sprinklers, lanterns) in step.
func _refresh_thing(cell: Vector2i) -> void:
	if _things.has(cell):
		_things[cell].queue_free()
		_things.erase(cell)
	var kind: String = GameState.object_kind(cell)
	if kind == "" or kind == "path":  # stepping stones are drawn flat by the ground
		return
	var thing := ObjectView.new()
	thing.kind = kind
	thing.position = Vector2(cell * TILE) + Vector2(8, 16)
	if bool(GameState.ITEMS.get(kind, {}).get("flat", false)):
		_flats.add_child(thing)
	else:
		_entities.add_child(thing)
	_things[cell] = thing


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


func _process(_delta: float) -> void:
	_update_light()  # every frame, so dusk deepens smoothly between clock ticks


## Warm daylight, purple dusk from 5pm, blue night from 8pm.
func _update_light() -> void:
	var m: float = TimeManager.exact_minutes()
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
	if player != null and bool(player.call("indoors")):
		color = Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.86, 0.7), clampf((m - 18 * 60) / 180.0, 0.0, 1.0))  # lamplight
		if GameState.is_in_mine(player.call("cell")):
			color = Color(0.8, 0.78, 0.92)  # cave gloom, whatever the hour
	_light.color = color


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("use", [KEY_SPACE])
	_bind("interact", [KEY_F])
	_bind_mouse("use", MOUSE_BUTTON_LEFT)
	_bind_mouse("interact", MOUSE_BUTTON_RIGHT)
	_bind("toggle_inventory", [KEY_E, KEY_I])
	_bind("sprint", [KEY_SHIFT])
	_bind("emote", [KEY_T])
	_bind("chat", [KEY_ENTER])
	_bind("next_seed", [KEY_Q])
	_bind("cycle_tool", [KEY_TAB])
	_bind("toggle_help", [KEY_H])
	_bind("toggle_journal", [KEY_J])
	_bind("toggle_music", [KEY_N])
	_bind("toggle_map", [KEY_M])
	_bind("close", [KEY_ESCAPE])
	for i in 6:
		_bind("tool_%d" % (i + 1), [KEY_1 + i])
	for i in 4:
		_bind("quick_%d" % (i + 1), [[KEY_7, KEY_8, KEY_9, KEY_0][i]])


func _bind_mouse(action: String, button: MouseButton) -> void:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return
	var click := InputEventMouseButton.new()
	click.button_index = button
	InputMap.action_add_event(action, click)


func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key as Key
		InputMap.action_add_event(action, event)
