extends Node2D
## The land around the garden, seen where the camera goes past its edge, all
## on the same ground as the garden and changing with the seasons: a rocky
## cliff along the top (with a trail up through a gap) and down the left
## side, woods on the raised land and on the cliff top, and a fenced meadow
## on the right. The woods along the bottom are forest_front.gd.
## This node draws the ground-level parts (grass, trails, cliff, the shade
## under the tree tops); `decorate()` adds the trees, tree tops and fences.
## Nothing out here can be walked on: the garden ends at its edge.

const Assets := preload("res://scripts/assets.gd")
const SceneryView := preload("res://scripts/scenery_view.gd")

const TILE := 16
const REACH := 8  # tiles of land drawn past each edge (more than the camera shows)
const CLIFF_TOP := -40.0  # the cliff piece's top, in pixels (it is 40 tall)
## Tree tops: one in roughly every SPACING x SPACING patch, nudged at random.
const SPACING := 13.0
## The shade between tree tops, by season: a little darker than the leaves.
const SHADE: Array[Color] = [Color("#4a8f50"), Color("#3a7a45"), Color("#a8602e"), Color("#c9d2d9")]

var _tiles: Texture2D = Assets.texture("res://assets/tiles/ground.png")
var _cliff: Texture2D = Assets.texture("res://assets/sprites/scenery/cliff.png")
var _trail: Texture2D = Assets.texture("res://assets/sprites/scenery/trail.png")
var _side: Texture2D = Assets.texture("res://assets/sprites/scenery/cliff_side.png")
var _season: int = -1


func _ready() -> void:
	TimeManager.time_changed.connect(_check_season)
	GameState.state_reloaded.connect(_on_reloaded)


func _check_season() -> void:
	if TimeManager.season() != _season:
		queue_redraw()
		get_tree().call_group("scenery", "show_season")


func _on_reloaded() -> void:
	queue_redraw()
	get_tree().call_group("scenery", "show_season")


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
	# The same grass as the garden all round it: it is all one level.
	for y in range(-REACH, size.y + REACH):
		for x in range(-REACH, size.x + REACH):
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			var column: int = [0, 1, 0, 2][hash(Vector2i(x, y)) % 4]
			draw_texture_rect_region(_tiles, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(column * TILE, _season * TILE, TILE, TILE))
	# A leafy shade where the tree tops are, so gaps between them never show
	# bare grass (it sits under the tops' inner edge, which hides its border).
	var leaves: Color = SHADE[_season]
	var far: float = REACH * TILE
	var w: float = size.x * TILE
	var h: float = size.y * TILE
	draw_rect(Rect2(-far, -60, far - 66, h + 80), leaves)
	draw_rect(Rect2(-far, -far - 40, w + far * 2, far - 30), leaves)
	# Trails leading off the edges, on under the trees.
	for cell: Vector2i in GameState.TRAILS:
		if not GameState.in_bounds(cell):
			draw_texture_rect_region(_trail, Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), Rect2(trail_mask(cell) * TILE, _season * TILE, TILE, TILE))
	# The cliff right along the top, with a gap where the trail climbs out.
	for tx in range(0, size.x + REACH):
		if GameState.TRAILS.has(Vector2i(tx, -1)):
			continue
		var part: int = absi(hash(tx)) % 2  # two plain faces, mixed
		if GameState.TRAILS.has(Vector2i(tx + 1, -1)):
			part = 3  # the cliff ends to the right
		elif GameState.TRAILS.has(Vector2i(tx - 1, -1)):
			part = 2  # and starts again to the left
		draw_texture_rect_region(_cliff, Rect2(tx * TILE, CLIFF_TOP, TILE, 40), Rect2(part * TILE, _season * 40, TILE, 40))
	# The left side is raised land too: its rocky edge runs down beside the
	# garden, from the top cliff to the woods along the bottom.
	var y: float = CLIFF_TOP
	while y < h + TILE * 2:
		draw_texture_rect_region(_side, Rect2(-TILE, y, TILE, 32), Rect2(0, _season * 32, TILE, 32))
		y += 32
	draw_rect(Rect2(0, 0, 3, h), Color(0, 0, 0, 0.14))  # its shadow on the garden


## Adds the standing things round the garden. Full trees go in `layer` (the
## y-sorted layer the players walk in): a row or two on the raised land to
## the left and on the cliff top, and a scattering in the fenced meadow on
## the right. Behind those rows, the woods are just tree tops (the same trees'
## crowns, at full colour) packed together in a layer of their own drawn
## right under `layer`, so the first trees always stand in front of them.
## Placement is random but the same every time.
static func decorate(layer: Node2D) -> void:
	var size: Vector2i = GameState.WORLD_SIZE
	var w: float = size.x * TILE
	var h: float = size.y * TILE
	var far: float = REACH * TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var tops := Node2D.new()
	tops.name = "TreeTops"
	tops.y_sort_enabled = true
	layer.add_sibling(tops)
	layer.get_parent().move_child(tops, layer.get_index())
	var trees: Dictionary = {"pine": 5, "oak": 5, "maple": 4, "birch": 2, "cherry": 2, "apple": 1}
	var crowns: Dictionary = {"pine": 4, "oak": 4, "maple": 3, "birch": 2, "cherry": 2}
	# Left side, up on the raised land: two uneven rows of trees, then tree
	# tops packed behind them (at the height a whole tree's leaves would be).
	_row(layer, rng, Vector2(-27, -20), Vector2(-27, h + 20), 3.0, 17.0, 26.0, trees)
	_row(layer, rng, Vector2(-44, -30), Vector2(-44, h + 20), 4.0, 18.0, 28.0, trees)
	_tops(tops, rng, Rect2(-far, -20, far - 58, h + 60), crowns)
	# The bottom is the near woods' leaves (forest_front.gd), drawn over all.
	# On top of the cliff: a row on the ledge, then tree tops.
	_row(layer, rng, Vector2(-far, -47), Vector2(w + far, -47), 3.0, 16.0, 26.0, trees)
	_tops(tops, rng, Rect2(-far, -far - 40, w + far * 2, far - 18), crowns)
	# Right side: a fence down the edge and an open meadow with a few trees.
	for fy in size.y:
		_add(layer, "fence_upright", Vector2(w + 8, fy * TILE + 16), false, Color.WHITE)
	var placed: Array[Vector2] = []
	for i in 70:
		var at := Vector2(rng.randf_range(w + 22, w + far), rng.randf_range(16, h + 4)).round()
		if placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < 34.0):
			continue
		placed.append(at)
		var kind: String = _pick(rng, {"oak": 3, "maple": 2, "pine": 2, "birch": 2, "cherry": 1, "apple": 1, "bush": 3, "boulder": 1})
		_add(layer, kind, at, rng.randf() < 0.5, Color.WHITE)


## A line of trees from `from` to `to`, `gap_min` to `gap_max` apart and
## nudged up to `wobble` either way, leaving the trails clear.
static func _row(layer: Node2D, rng: RandomNumberGenerator, from: Vector2, to: Vector2, wobble: float, gap_min: float, gap_max: float, weights: Dictionary) -> void:
	var along: Vector2 = (to - from).normalized()
	var across := Vector2(along.y, -along.x)
	var d: float = rng.randf_range(0.0, gap_max)
	var length: float = from.distance_to(to)
	while d < length:
		var at: Vector2 = (from + along * d + across * rng.randf_range(-wobble, wobble)).round()
		if not _on_trail(at):
			var kind: String = _pick(rng, weights) if rng.randf() > 0.12 else "bush"
			_add(layer, kind, at, rng.randf() < 0.5, Color.WHITE)
		d += rng.randf_range(gap_min, gap_max)


## Packs `area` with tree tops (one per SPACING square, nudged at random),
## over a leafy shade drawn on the ground so no gap shows bare grass.
static func _tops(layer: Node2D, rng: RandomNumberGenerator, area: Rect2, weights: Dictionary) -> void:
	var row: int = 0
	var y: float = area.position.y + SPACING / 2.0
	while y < area.end.y:
		var x: float = area.position.x + (SPACING / 2.0 if row % 2 == 0 else SPACING)
		while x < area.end.x:
			var at := Vector2(x + rng.randf_range(-0.4, 0.4) * SPACING, y + rng.randf_range(-0.4, 0.4) * SPACING).round()
			var kind: String = _pick(rng, weights)
			var flip: bool = rng.randf() < 0.5
			if not _on_trail(at):
				_add(layer, kind + "_crown", at, flip, Color.WHITE)
			x += SPACING
		y += SPACING
		row += 1


static func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total: int = 0
	for kind: String in weights.keys():
		total += int(weights[kind])
	var pick: int = rng.randi_range(1, total)
	for option: String in weights.keys():
		pick -= int(weights[option])
		if pick <= 0:
			return option
	return weights.keys()[0]


## Whether a tree standing at `at` would hide a trail leading off the map:
## on it, or just below it with its leaves hanging over.
static func _on_trail(at: Vector2) -> bool:
	for cell: Vector2i in GameState.TRAILS:
		if GameState.in_bounds(cell):
			continue
		var middle: float = cell.x * TILE + TILE / 2.0
		if absf(at.x - middle) < 17.0 and at.y > cell.y * TILE - 4 and at.y < (cell.y + 1) * TILE + 36:
			return true
	return false


static func _add(layer: Node2D, kind: String, at: Vector2, flip: bool, tint: Color) -> void:
	var view := SceneryView.new()
	view.kind = kind
	view.position = at
	view.flip_h = flip and not kind.begins_with("fence")
	view.modulate = tint
	layer.add_child(view)
