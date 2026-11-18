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
var _edge: Texture2D = Assets.texture("res://assets/sprites/scenery/canopy_edge.png")
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
	# Leafy clumps round off the forest's edge (none over the trails).
	var clump := Rect2(_season * 40, 0, 40, 36)
	var x: float = left - 8
	while x < right:
		var h: int = hash(int(x))
		if not _near(gaps, x + 20):
			draw_texture_rect_region(_edge, Rect2(x, top - 26 + h % 5, 40, 36), clump)
			draw_texture_rect_region(_edge, Rect2(x, bottom - 12 + h % 6, 40, 36), clump)
		x += 22 + h % 7
	var y: float = top - 20
	while y < bottom:
		var h: int = hash(int(y) + 7)
		draw_texture_rect_region(_edge, Rect2(left - 30 + h % 5, y, 40, 36), clump)
		draw_texture_rect_region(_edge, Rect2(right - 10 - h % 5, y, 40, 36), clump)
		y += 20 + h % 6
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


func _near(points: Array[float], x: float) -> bool:
	for p: float in points:
		if absf(p + TILE / 2.0 - x) < 26.0:
			return true
	return false


## Adds the standing things round the garden to `layer` (the y-sorted layer
## the players walk in): tree lines down the sides, trees on the cliff top,
## and a fence with boulders and bushes along the bottom.
static func decorate(layer: Node2D) -> void:
	var size: Vector2i = GameState.WORLD_SIZE
	var kinds: Array[String] = ["oak", "pine", "maple", "pine", "birch", "oak", "cherry", "pine", "apple"]
	# Down both sides, two staggered rows of trees with bushes and rocks between.
	for side: int in [0, 1]:
		var y: float = -2.0
		var n: int = side * 5
		while y < size.y + 2:
			var h: int = absi(hash(Vector2i(side, int(y * 10))))
			var near_x: float = -0.6 * TILE if side == 0 else size.x * TILE + 0.6 * TILE
			var far_x: float = -1.7 * TILE if side == 0 else size.x * TILE + 1.7 * TILE
			_add(layer, kinds[n % kinds.size()], Vector2(far_x + (h % 7) - 3, y * TILE + 16), h % 2 == 0)
			if h % 3 != 0:
				_add(layer, kinds[(n + 4) % kinds.size()], Vector2(near_x + (h % 5) - 2, (y + 0.9) * TILE + 16), h % 4 == 0)
			else:
				_add(layer, ["bush", "boulder", "stump"][h % 3], Vector2(near_x, (y + 1.1) * TILE + 16), h % 2 == 1)
			y += 1.6 + float(h % 4) * 0.2
			n += 1
	# On the ledge above the cliff.
	var x: float = -1.0
	var m: int = 2
	while x < size.x + 1:
		var h: int = absi(hash(Vector2i(int(x * 10), -9)))
		if absf(x - 22.5) > 1.6:  # leave the trail clear
			if h % 4 == 0:
				_add(layer, "bush", Vector2((x + 0.5) * TILE, CLIFF_TOP + 2), h % 2 == 0)
			else:
				_add(layer, kinds[m % kinds.size()], Vector2((x + 0.5) * TILE + (h % 5), CLIFF_TOP - 4 - (h % 6)), h % 2 == 0)
		x += 1.5 + float(h % 3) * 0.4
		m += 1
	# A fence along the bottom, gapped where the trail leaves, then boulders,
	# bushes and stumps among the first trees.
	for fx in range(-1, size.x + 1):
		if not GameState.TRAILS.has(Vector2i(fx, size.y)):
			_add(layer, "fence", Vector2(fx * TILE + 8, size.y * TILE + 9), false)
	var bx: float = -1.0
	var k: int = 0
	while bx < size.x + 1:
		var h: int = absi(hash(Vector2i(int(bx * 10), 99)))
		if absf(bx - 20.5) > 1.4:
			if h % 3 == 0:
				_add(layer, kinds[k % kinds.size()], Vector2((bx + 0.5) * TILE + (h % 5), (size.y + 1.4) * TILE + (h % 4)), h % 2 == 0)
			else:
				_add(layer, ["boulder", "bush", "stump", "bush"][h % 4], Vector2((bx + 0.5) * TILE, (size.y + 1.2) * TILE), h % 2 == 1)
		bx += 1.3 + float(h % 3) * 0.5
		k += 1


static func _add(layer: Node2D, kind: String, at: Vector2, flip: bool) -> void:
	var view := SceneryView.new()
	view.kind = kind
	view.position = at
	view.flip_h = flip and kind != "fence"
	layer.add_child(view)
