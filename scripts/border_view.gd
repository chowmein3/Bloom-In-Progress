extends Node2D
## The land around the garden, seen where the camera goes past its edge:
## a rocky cliff along the top (with a trail up through a gap), tree lines
## down the sides, a fence along the bottom, and deep forest beyond, all
## changing with the seasons. Draws the ground-level parts; `decorate()` adds
## the standing trees, bushes, boulders and fence posts to the y-sorted layer.
## Nothing out here can be walked on: the garden ends at its edge.

const Assets := preload("res://scripts/assets.gd")
const SceneryView := preload("res://scripts/scenery_view.gd")

const TILE := 16
const SIDE := 2  # tiles of open woodland floor beside the garden before the forest
const TOP := 4  # rows above the garden: the cliff (2) and a grassy ledge (2)
const BOTTOM := 2
const FAR := 60  # how far the forest goes on, for very wide windows
const CLIFF_TOP := -40.0  # the cliff piece's top, in pixels (it is 40 tall)

var _tiles: Texture2D = Assets.texture("res://assets/tiles/ground.png")
var _cliff: Texture2D = Assets.texture("res://assets/sprites/scenery/cliff.png")
var _edge: Texture2D = Assets.texture("res://assets/sprites/scenery/canopy_edge.png")  # six 48x44 shapes, a row per season
var _trail: Texture2D = Assets.texture("res://assets/sprites/scenery/trail.png")
var _canopy: Array[Texture2D] = []
var _season: int = -1


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # the forest tiles fill big areas
	for season in 4:
		_canopy.append(Assets.texture("res://assets/sprites/scenery/canopy_%d.png" % season))
	TimeManager.time_changed.connect(_check_season)
	GameState.state_reloaded.connect(queue_redraw)


func _check_season() -> void:
	if TimeManager.season() != _season:
		queue_redraw()


## Which sides of a trail tile join another (1 up, 2 right, 4 down, 8 left):
## the column in trail.png.
static func trail_mask(cell: Vector2i) -> int:
	var mask: int = 0
	for side: Array in [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]:
		if GameState.TRAILS.has(cell + side[0]):
			mask |= int(side[1])
	return mask


func _draw() -> void:
	_season = TimeManager.season()
	var size: Vector2i = GameState.WORLD_SIZE
	var world := Vector2(size * TILE)
	# Woodland floor in the band round the garden, a shade darker than the yard.
	for y in range(-TOP, size.y + BOTTOM):
		for x in range(-SIDE, size.x + SIDE):
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			var column: int = [0, 1, 0, 2][hash(Vector2i(x, y)) % 4]
			draw_texture_rect_region(_tiles, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(column * TILE, _season * TILE, TILE, TILE), Color(0.86, 0.9, 0.86))
	# Trails leading off the edges.
	for cell: Vector2i in GameState.TRAILS:
		if not GameState.in_bounds(cell):
			draw_texture_rect_region(_trail, Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), Rect2(trail_mask(cell) * TILE, _season * TILE, TILE, TILE))
	# Deep forest all round, beyond the band.
	var canopy: Texture2D = _canopy[_season]
	var far: float = FAR * TILE
	var left: float = -SIDE * TILE
	var right: float = world.x + SIDE * TILE
	var top: float = -TOP * TILE
	var bottom: float = world.y + BOTTOM * TILE
	var gaps: Array[float] = []  # where trails go into the forest
	for cell: Vector2i in GameState.TRAILS:
		if cell.y == -TOP - 1 or cell.y == size.y + BOTTOM:
			gaps.append(cell.x * TILE)
	draw_texture_rect(canopy, Rect2(-far, -far, far * 2 + world.x, far + top), true)
	draw_texture_rect(canopy, Rect2(-far, bottom, far * 2 + world.x, far), true)
	draw_texture_rect(canopy, Rect2(-far, top, far + left, bottom - top), true)
	draw_texture_rect(canopy, Rect2(right, top, far, bottom - top), true)
	for cell: Vector2i in GameState.TRAILS:  # the trail runs on under the trees a little
		if cell.y < -TOP or cell.y >= size.y + BOTTOM:
			draw_texture_rect_region(_trail, Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), Rect2(trail_mask(cell) * TILE, _season * TILE, TILE, TILE), Color(0.75, 0.75, 0.75))
	# Leafy crowns round off the forest's edge, in two uneven layers: a darker
	# one further back, then one at the edge (none over the trails).
	var rng := RandomNumberGenerator.new()
	for layer in 2:
		rng.seed = 41 + layer
		var tint := Color(0.8, 0.82, 0.8) if layer == 0 else Color.WHITE
		var back: float = 10.0 if layer == 0 else 0.0
		var x: float = left - 30
		while x < right + 10:
			if not _near(gaps, x + 24):
				_clump(rng, Vector2(x, top - 30 - back + rng.randf_range(-5, 5)), tint)
				_clump(rng, Vector2(x, bottom - 14 + back + rng.randf_range(-5, 5)), tint)
			x += rng.randf_range(12, 26)
		var y: float = top - 30
		while y < bottom:
			_clump(rng, Vector2(left - 34 - back + rng.randf_range(-5, 5), y), tint)
			_clump(rng, Vector2(right - 14 + back + rng.randf_range(-5, 5), y), tint)
			y += rng.randf_range(11, 22)
	# The cliff along the top, with a gap where the trail climbs out.
	var cliff_row: float = _season * 40
	for tx in range(-SIDE, size.x + SIDE):
		if GameState.TRAILS.has(Vector2i(tx, -1)):
			continue
		var part: int = (tx * 7 + 3) % 2  # two plain faces, mixed
		if GameState.TRAILS.has(Vector2i(tx + 1, -1)):
			part = 3  # the cliff ends to the right
		elif GameState.TRAILS.has(Vector2i(tx - 1, -1)):
			part = 2  # and starts again to the left
		draw_texture_rect_region(_cliff, Rect2(tx * TILE, CLIFF_TOP, TILE, 40), Rect2(part * TILE, cliff_row, TILE, 40))


## One leafy crown from canopy_edge.png (six shapes), with its top-left at `at`.
func _clump(rng: RandomNumberGenerator, at: Vector2, tint: Color) -> void:
	var shape: int = rng.randi_range(0, 5)
	var shade: float = rng.randf_range(0.9, 1.04)
	draw_texture_rect_region(_edge, Rect2(at, Vector2(48, 44)), Rect2(shape * 48, _season * 44, 48, 44), Color(tint.r * shade, tint.g * shade, tint.b * shade))


func _near(points: Array[float], x: float) -> bool:
	for p: float in points:
		if absf(p + TILE / 2.0 - x) < 26.0:
			return true
	return false


## Adds the standing things round the garden to `layer` (the y-sorted layer
## the players walk in): woods down the sides, trees on the cliff top, and a
## fence with boulders, bushes and trees along the bottom. Things are
## scattered at random (the same every time) with a little space each, so
## there is no repeating pattern.
static func decorate(layer: Node2D) -> void:
	var size: Vector2i = GameState.WORLD_SIZE
	var w: float = size.x * TILE
	var h: float = size.y * TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var placed: Array[Vector2] = []
	var trees: Dictionary = {"pine": 5, "oak": 4, "maple": 3, "birch": 2, "cherry": 2, "apple": 1}
	var small: Dictionary = {"bush": 5, "boulder": 2, "stump": 2}
	# Down both sides: a deep, uneven band of trees with bushes among them.
	for band: Rect2 in [Rect2(-30, -36, 28, h + 60), Rect2(w + 2, -36, 28, h + 60)]:
		_scatter(layer, rng, placed, band, trees, 13.0, 140)
		_scatter(layer, rng, placed, band.grow_individual(0, 0, 0, 0), small, 9.0, 40)
	# Along the ledge above the cliff, leaving the trail clear.
	var trail_x: float = 22.5 * TILE
	for ledge: Rect2 in [Rect2(-16, -62, trail_x - 30, 18), Rect2(trail_x + 14, -62, w - trail_x - 14 + 16, 18)]:
		_scatter(layer, rng, placed, ledge, trees, 15.0, 80)
		_scatter(layer, rng, placed, Rect2(ledge.position.x, -44, ledge.size.x, 3), {"bush": 3, "boulder": 1}, 12.0, 30)
	# A fence along the bottom, gapped where the trail leaves.
	for fx in range(-1, size.x + 1):
		if not GameState.TRAILS.has(Vector2i(fx, size.y)):
			_add(layer, "fence", Vector2(fx * TILE + 8, h + 9), false, Color.WHITE)
	var out_x: float = 20.5 * TILE
	for strip: Rect2 in [Rect2(-16, h + 16, out_x - 30, 16), Rect2(out_x + 14, h + 16, w - out_x - 14 + 16, 16)]:
		_scatter(layer, rng, placed, Rect2(strip.position.x, h + 22, strip.size.x, 14), trees, 18.0, 80)
		_scatter(layer, rng, placed, strip, {"bush": 5, "boulder": 2, "stump": 1}, 14.0, 25)


## Tries `tries` random spots in `area` and puts something (picked by
## weight) on each that is at least `space` from everything already there.
static func _scatter(layer: Node2D, rng: RandomNumberGenerator, placed: Array[Vector2], area: Rect2, weights: Dictionary, space: float, tries: int) -> void:
	var total: int = 0
	for kind: String in weights.keys():
		total += int(weights[kind])
	for i in tries:
		var at := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var crowded: bool = false
		for other: Vector2 in placed:
			if other.distance_to(at) < space:
				crowded = true
				break
		if crowded:
			continue
		var pick: int = rng.randi_range(1, total)
		var kind: String = ""
		for option: String in weights.keys():
			pick -= int(weights[option])
			if pick <= 0:
				kind = option
				break
		var shade: float = rng.randf_range(0.86, 1.0)
		var tint := Color(shade * rng.randf_range(0.96, 1.02), shade, shade * rng.randf_range(0.95, 1.02))
		placed.append(at.round())
		_add(layer, kind, at.round(), rng.randf() < 0.5, tint)


static func _add(layer: Node2D, kind: String, at: Vector2, flip: bool, tint: Color) -> void:
	var view := SceneryView.new()
	view.kind = kind
	view.position = at
	view.flip_h = flip and kind != "fence"
	view.modulate = tint
	layer.add_child(view)
