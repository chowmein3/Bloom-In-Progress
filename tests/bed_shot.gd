extends Node
## Pictures of the bed at bedtime, for checking the goodnight kiss frame by
## frame (needs a window, so no --headless; xvfb-run works):
##   godot --path . res://tests/bed_shot.tscn -- <output folder> [film]
## Saves kiss_<home level>_<frame>.png, every frame of the kiss in each home.
## With "film", also film_<n>.png: the kiss as it plays in the tent, 20
## pictures a second, the screen darkening as it does in the game.

const Interior := preload("res://scripts/interior.gd")
const BedView := preload("res://scripts/bed_view.gd")
const ZOOM := 3.5
const AROUND := Rect2(-32, -26, 64, 46)  # game units round the bed's middle

var bed: Node2D
var camera: Camera2D
var dark: ColorRect


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir().path_join("bed_shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	GameState.save_path = ""
	GameState.new_game()
	add_child(Interior.new())
	bed = BedView.new()
	add_child(bed)
	bed.set_process(false)  # the pictures set the moment of the kiss themselves
	camera = Camera2D.new()
	camera.zoom = Vector2(ZOOM, ZOOM)
	add_child(camera)
	var layer := CanvasLayer.new()
	dark = ColorRect.new()
	dark.color = Color.BLACK
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.modulate.a = 0.0
	layer.add_child(dark)
	add_child(layer)
	GameState.sleeping = {1: true, 2: true}
	for level in GameState.ROOMS.size():
		GameState.upgrades["home"] = level
		GameState.economy_changed.emit()
		GameState.sleepers_changed.emit()
		camera.position = bed.position + Vector2(0, -16)
		for frame in BedView.TURNED.size():
			_show(_time_of(frame) if frame > 0 else -1.0)
			await _save(out_dir.path_join("kiss_%d_%d.png" % [level, frame]))
	if args.has("film"):
		GameState.upgrades["home"] = 0
		GameState.economy_changed.emit()
		GameState.sleepers_changed.emit()
		camera.position = bed.position + Vector2(0, -16)
		var fade: float = maxf(GameState.bedtime_fade - 0.3, 0.1)  # as hud.gd fades
		var n: int = 0
		var t: float = 0.0
		while t < GameState.bedtime_fade:
			_show(t)
			dark.modulate.a = 1.0 - cos(clampf(t / fade, 0.0, 1.0) * PI / 2.0)
			await _save(out_dir.path_join("film_%03d.png" % n))
			n += 1
			t += 0.05
	get_tree().quit()


## The middle of the step that shows `frame` on the way in.
func _time_of(frame: int) -> float:
	var t: float = 0.0
	for step: Array in BedView.KISS_STEPS:
		if int(step[0]) == frame:
			return t + float(step[1]) / 2.0
		t += float(step[1])
	return 0.0


## The kiss `seconds` in (or none, if negative), heart and all.
func _show(seconds: float) -> void:
	bed.set("_kiss_by", 1 if seconds >= 0.0 else 0)
	bed.set("_kiss_time", seconds if seconds < BedView.kiss_length() else -1.0)
	var heart_from: float = -1.0
	var t: float = 0.0
	for step: Array in BedView.KISS_STEPS:
		if int(step[0]) == BedView.KISS_FRAME:
			heart_from = t
			break
		t += float(step[1])
	var heart: float = seconds - heart_from if seconds >= heart_from and seconds >= 0.0 else -1.0
	bed.set("_heart", heart if heart <= 1.8 else -1.0)
	bed.queue_redraw()


func _save(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var scale: float = image.get_width() / 320.0 * ZOOM
	var middle := Vector2(image.get_size()) / 2.0
	var region := Rect2i(Vector2i(middle + AROUND.position * scale), Vector2i(AROUND.size * scale))
	image.get_region(region).save_png(path)
