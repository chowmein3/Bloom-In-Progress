extends Node
## Saves a picture of the whole garden and its border, for checking scenery.
## Run (needs a display):
##   godot --path . res://tests/map_shot.tscn -- <output folder> [blocked]
## One picture per season; with "blocked", tiles that can't be walked on are
## tinted red so collisions can be compared with what is drawn.

var out_dir: String = "user://"
var show_blocked: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	show_blocked = args.has("blocked")
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
	for layer: Node in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var player: Node2D = main.get("player")
	player.position = Vector2(GameState.WORLD_SIZE * 16) / 2.0 + Vector2(0, 40)
	var camera: Camera2D = player.get_child(player.get_child_count() - 1) as Camera2D
	for child: Node in player.get_children():
		if child is Camera2D:
			camera = child
	camera.limit_left = -10000
	camera.limit_top = -10000
	camera.limit_right = 10000
	camera.limit_bottom = 10000
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(GameState.WORLD_SIZE * 16) / 2.0
	var view: Vector2 = get_viewport().get_visible_rect().size
	var fit: float = minf(view.x / (GameState.WORLD_SIZE.x * 16 + 160), view.y / (GameState.WORLD_SIZE.y * 16 + 120))
	camera.zoom = Vector2(fit, fit)
	if show_blocked:
		var marks := Node2D.new()
		marks.z_index = 100
		marks.draw.connect(func() -> void:
			for y in GameState.WORLD_SIZE.y:
				for x in GameState.WORLD_SIZE.x:
					if not GameState.can_walk(Vector2i(x, y)):
						marks.draw_rect(Rect2(x * 16, y * 16, 16, 16), Color(1, 0, 0, 0.3)))
		main.add_child(marks)
	for season in 4:
		TimeManager.day_index = season * 28 + 3
		TimeManager.time_changed.emit()
		GameState.state_reloaded.emit()
		for i in 20:
			await get_tree().process_frame
		camera.global_position = Vector2(GameState.WORLD_SIZE * 16) / 2.0
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("map_%d%s.png" % [season, "_blocked" if show_blocked else ""]))
	print("MAP SHOTS DONE")
	get_tree().quit()
