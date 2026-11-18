extends Node2D
## The land around the garden, seen where the camera goes past its edge: a
## rocky cliff along the top (with a trail up through a gap) and woods on
## every side, all on the same ground as the garden and changing with the
## seasons. This node draws the ground-level parts (grass, trails, cliff);
## `decorate()` adds the trees, bushes and fence to the y-sorted layer the
## players walk in, so every tree is drawn the same way as the garden's own.
## Nothing out here can be walked on: the garden ends at its edge.

const Assets := preload("res://scripts/assets.gd")
const SceneryView := preload("res://scripts/scenery_view.gd")

const TILE := 16
const REACH := 8  # tiles of land drawn past each edge (more than the camera shows)
const CLIFF_TOP := -40.0  # the cliff piece's top, in pixels (it is 40 tall)
## The woods behind each edge row: a tree in roughly every patch this big.
const WOODS_SPACING := 27.0

var _tiles: Texture2D = Assets.texture("res://assets/tiles/ground.png")
var _cliff: Texture2D = Assets.texture("res://assets/sprites/scenery/cliff.png")
var _trail: Texture2D = Assets.texture("res://assets/sprites/scenery/trail.png")
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
	# Trails leading off the edges.
	for cell: Vector2i in GameState.TRAILS:
		if not GameState.in_bounds(cell):
			draw_texture_rect_region(_trail, Rect2(Vector2(cell * TILE), Vector2(TILE, TILE)), Rect2(trail_mask(cell) * TILE, _season * TILE, TILE, TILE))
	# The cliff right along the top, with a gap where the trail climbs out.
	for tx in range(-REACH, size.x + REACH):
		if GameState.TRAILS.has(Vector2i(tx, -1)):
			continue
		var part: int = absi(hash(tx)) % 2  # two plain faces, mixed
		if GameState.TRAILS.has(Vector2i(tx + 1, -1)):
			part = 3  # the cliff ends to the right
		elif GameState.TRAILS.has(Vector2i(tx - 1, -1)):
			part = 2  # and starts again to the left
		draw_texture_rect_region(_cliff, Rect2(tx * TILE, CLIFF_TOP, TILE, 40), Rect2(part * TILE, _season * 40, TILE, 40))


## Adds the standing things round the garden to `layer` (the y-sorted layer
## the players walk in): woods down the sides and along the bottom, more on
## the cliff top, and a fence along the bottom edge. Along each edge a close
## row of trees with bushes and rocks between their trunks makes a solid
## border; the woods behind it are lighter. Trees are scattered with kinds
## picked at random (the same every time), so nothing repeats.
static func decorate(layer: Node2D) -> void:
	var size: Vector2i = GameState.WORLD_SIZE
	var w: float = size.x * TILE
	var h: float = size.y * TILE
	var far: float = REACH * TILE
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var woods: Dictionary = {"pine": 6, "oak": 5, "maple": 4, "birch": 2, "cherry": 2, "apple": 1}
	# Down both sides: the edge row, then lighter woods behind it.
	_edge(layer, rng, Vector2(-8, 4), Vector2(-8, h + 26), 4.0, woods)
	_woods(layer, rng, Rect2(-far, -4, far - 22, h + 40), woods, WOODS_SPACING)
	_edge(layer, rng, Vector2(w + 8, 4), Vector2(w + 8, h + 26), -4.0, woods)
	_woods(layer, rng, Rect2(w + 22, -4, far - 22, h + 40), woods, WOODS_SPACING)
	# Along the bottom: a fence, bushes and rocks by it, then the edge row
	# and lighter woods behind.
	for fx in range(-1, size.x + 1):
		if not GameState.TRAILS.has(Vector2i(fx, size.y)):
			_add(layer, "fence", Vector2(fx * TILE + 8, h + 9), false, Color.WHITE)
	_edge(layer, rng, Vector2(-30, h + 30), Vector2(w + 30, h + 30), -5.0, woods)
	_woods(layer, rng, Rect2(-far, h + 46, w + far * 2, far - 40), woods, WOODS_SPACING)
	# On top of the cliff (their roots on the grass above it, not on the rock).
	_edge(layer, rng, Vector2(-far, -47), Vector2(w + far, -47), 3.0, woods)
	_woods(layer, rng, Rect2(-far, -far, w + far * 2, far + CLIFF_TOP - 22), woods, WOODS_SPACING)


## A close row of trees from `from` to `to`, with a bush, rock or stump
## between most pairs of trunks (set `toward` pixels nearer the garden), so
## the edge reads as solid.
static func _edge(layer: Node2D, rng: RandomNumberGenerator, from: Vector2, to: Vector2, toward: float, weights: Dictionary) -> void:
	var along: Vector2 = (to - from).normalized()
	var across := Vector2(along.y, -along.x)
	if absf(along.x) > 0.5:
		across = Vector2(0, 1)  # rows across the screen: "toward" is up or down
	var length: float = from.distance_to(to)
	var d: float = rng.randf_range(0.0, 10.0)
	var phase: float = rng.randf_range(0.0, TAU)
	while d < length:
		# The row wanders in and out (a slow wave plus a random step), and every
		# so often a tree stands a little further back, so it never reads as a line.
		var wander: float = 6.0 * sin(d * 0.045 + phase) + rng.randf_range(-5.0, 5.0)
		if rng.randf() < 0.3:
			wander -= absf(toward) * 2.5 * signf(toward) if toward != 0.0 else 8.0
		var at: Vector2 = (from + along * d + across * wander).round()
		if not _on_trail(at):
			_add(layer, _pick(rng, weights), at, rng.randf() < 0.5, _tint(rng))
		var gap: float = rng.randf_range(12.0, 24.0)
		var between: Vector2 = (from + along * (d + gap / 2.0) + across * (toward + wander * 0.5 + rng.randf_range(-3.0, 3.0))).round()
		if rng.randf() < 0.8 and not _on_trail(between):
			_add(layer, ["bush", "bush", "bush", "boulder", "stump"][rng.randi_range(0, 4)], between, rng.randf() < 0.5, Color.WHITE)
		d += gap


## Fills `area` with lighter woods: one tree per `spacing` square, nudged at
## random, leaving the trails clear where they run through.
static func _woods(layer: Node2D, rng: RandomNumberGenerator, area: Rect2, weights: Dictionary, spacing: float) -> void:
	var row: int = 0
	var y: float = area.position.y + spacing / 2.0
	while y < area.end.y:
		var x: float = area.position.x + (spacing / 2.0 if row % 2 == 0 else spacing)
		while x < area.end.x:
			var at := Vector2(x + rng.randf_range(-0.4, 0.4) * spacing, y + rng.randf_range(-0.4, 0.4) * spacing).round()
			var kind: String = _pick(rng, weights)
			var flip: bool = rng.randf() < 0.5
			var tint: Color = _tint(rng)
			if rng.randf() > 0.05 and not _on_trail(at):
				_add(layer, kind, at, flip, tint)
			x += spacing
		y += spacing
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


static func _tint(rng: RandomNumberGenerator) -> Color:
	var shade: float = rng.randf_range(0.94, 1.0)
	return Color(shade, shade, shade)


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
	view.flip_h = flip and kind != "fence"
	view.modulate = tint
	layer.add_child(view)
