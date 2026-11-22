extends Node
## Saves a picture of the whole garden and its border, for checking scenery.
## Run (needs a display):
##   godot --path . res://tests/map_shot.tscn -- <output folder> [blocked] [town] [HH:MM]
## One picture per season; with "blocked", tiles that can't be walked on are
## tinted red so collisions can be compared with what is drawn. With "town",
## the town up the trail instead of the garden (town_<season>.png). A time
## such as 17:10 shows everyone where their routine puts them then (noon
## otherwise).

var out_dir: String = "user://"
var show_blocked: bool = false
var area := Rect2i(Vector2i.ZERO, GameState.WORLD_SIZE)  # in tiles


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	show_blocked = args.has("blocked")
	var town: bool = args.has("town")
	if town:
		area = Rect2i(GameState.TOWN_ORIGIN, GameState.TOWN_SIZE)
	Net.stop_lookup()
	Net.relay_url = ""
	GameState.wild_growth = false
	TimeManager.rain_chance = 0.0
	GameState.save_path = ""
	GameState.new_game()
	get_window().size = Vector2i(1600, 1080)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	main.call("start_solo")
	TimeManager.paused = true
	TimeManager.minutes = 12 * 60
	for arg: String in args:
		if arg.contains(":"):
			TimeManager.minutes = int(arg.get_slice(":", 0)) * 60 + int(arg.get_slice(":", 1))
	for layer: Node in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var player: Node2D = main.get("player")
	var middle: Vector2 = Vector2(area.position * 16) + Vector2(area.size * 16) / 2.0
	player.position = middle + Vector2(0, 40)
	if town:
		player.position = Vector2(GameState.town_arrival() * 16) + Vector2(16, 14)
	var camera: Camera2D = player.get_child(player.get_child_count() - 1) as Camera2D
	for child: Node in player.get_children():
		if child is Camera2D:
			camera = child
	camera.limit_left = -10000
	camera.limit_top = -10000
	camera.limit_right = 10000
	camera.limit_bottom = 10000
	camera.position_smoothing_enabled = false
	camera.global_position = middle
	var view: Vector2 = get_viewport().get_visible_rect().size
	var margin := Vector2(0, 0) if town else Vector2(160, 120)
	var fit: float = minf(view.x / (area.size.x * 16 + margin.x), view.y / (area.size.y * 16 + margin.y))
	camera.zoom = Vector2(fit, fit)
	if show_blocked:
		var marks := Node2D.new()
		marks.z_index = 100
		marks.draw.connect(func() -> void:
			for y in range(area.position.y, area.end.y):
				for x in range(area.position.x, area.end.x):
					if not GameState.can_walk(Vector2i(x, y)):
						marks.draw_rect(Rect2(x * 16, y * 16, 16, 16), Color(1, 0, 0, 0.3)))
		main.add_child(marks)
	for season in 4:
		TimeManager.day_index = season * 28 + 3
		TimeManager.time_changed.emit()
		GameState.state_reloaded.emit()
		for i in 20:
			await get_tree().process_frame
		camera.global_position = middle
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%d%s.png" % ["town" if town else "map", season, "_blocked" if show_blocked else ""]))
	print("MAP SHOTS DONE")
	get_tree().quit()
