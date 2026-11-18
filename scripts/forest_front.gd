extends Node2D
## The woods along the bottom of the garden, seen the way farm games show the
## trees nearest the viewer: a mass of shadowy leaves drawn over everything,
## with a puffy, bright leafy edge that wanders up and down (and hangs over
## the pond), and a few tree tops rising above it. Changes with the seasons.

const Assets := preload("res://scripts/assets.gd")

const TILE := 16
const REACH := 10  # tiles drawn past each side and below
## Trees whose tops rise above the leafy edge, and how tall their crowns are.
const RISING: Dictionary = {"cherry": 28, "maple": 33, "oak": 30, "pine": 44, "birch": 29}

var _fill: Array[Texture2D] = []
var _rim: Texture2D = Assets.texture("res://assets/sprites/scenery/leaf_rim.png")  # six 64x40 mounds (small to big), a row per season
var _crowns: Dictionary = {}
var _season: int = -1


func _ready() -> void:
	z_index = 3  # over the players and everything else in the garden
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for season in 4:
		_fill.append(Assets.texture("res://assets/sprites/scenery/front_leaves_%d.png" % season))
	for kind: String in RISING.keys():
		_crowns[kind] = Assets.texture("res://assets/sprites/scenery/%s_crown.png" % kind)
	TimeManager.time_changed.connect(func() -> void:
		if TimeManager.season() != _season:
			queue_redraw())
	GameState.state_reloaded.connect(queue_redraw)


## Where the leafy edge is at `x`: just below the garden, wandering a little,
## and reaching up over the pond in the bottom-left corner.
static func edge_y(x: float) -> float:
	var h: float = GameState.WORLD_SIZE.y * TILE
	var pond_x: float = GameState.POND_RECT.get_center().x * TILE
	var over_pond: float = 15.0 * exp(-pow((x - pond_x) / 46.0, 2.0))
	return h + 14.0 + 9.0 * sin(x * 0.029 + 0.4) + 5.0 * sin(x * 0.083 + 1.7) + 2.5 * sin(x * 0.23 + 0.5) - over_pond


func _draw() -> void:
	_season = TimeManager.season()
	var left: float = -REACH * TILE
	var right: float = GameState.WORLD_SIZE.x * TILE + REACH * TILE
	var bottom: float = GameState.WORLD_SIZE.y * TILE + REACH * TILE
	# The shadowy leaves, filling everything below the edge.
	var points := PackedVector2Array()
	var x: float = left
	while x <= right:
		points.append(Vector2(x, edge_y(x) + 8.0))
		x += 4.0
	points.append(Vector2(right, bottom))
	points.append(Vector2(left, bottom))
	var uvs := PackedVector2Array()
	for p: Vector2 in points:
		uvs.append(p / 64.0)
	draw_colored_polygon(points, Color.WHITE, uvs, _fill[_season])
	var rng := RandomNumberGenerator.new()
	# A few trees whose tops rise above the edge (the rest of them is hidden).
	rng.seed = 77
	x = left + rng.randf_range(0, 60)
	while x < right:
		var kind: String = RISING.keys()[rng.randi_range(0, RISING.size() - 1)]
		var crown: Texture2D = _crowns[kind]
		var size := Vector2(crown.get_width() / 4.0, crown.get_height())
		var foot: float = edge_y(x) + 10.0
		draw_texture_rect_region(crown, Rect2(Vector2(x - size.x / 2.0, foot - size.y), size), Rect2(_season * size.x, 0, size.x, size.y))
		x += rng.randf_range(70, 150)
	# The puffy leafy edge, in front of those.
	rng.seed = 78
	x = left
	while x < right:
		var shape: int = rng.randi_range(0, 5)
		var top: float = edge_y(x + 32.0) - 26.0 + rng.randf_range(-4.0, 4.0)
		draw_texture_rect_region(_rim, Rect2(x, top, 64, 40), Rect2(shape * 64, _season * 40, 64, 40))
		x += rng.randf_range(10, 30)
