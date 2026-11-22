extends Node2D
## The town's ground (assets/sprites/town_<season>.png, painted by
## tools/make_art.py from GameState.TOWN_MAP), with the river glinting, spray
## at the foot of the waterfall and a float bobbing when someone fishes the
## river. Drawn flat at GameState.TOWN_ORIGIN, under everyone. decorate() adds
## what stands up (buildings, props, trees, the woods round the edge) to the
## y-sorted layer, and people() the townsfolk and villagers who stand about.

const Assets := preload("res://scripts/assets.gd")
const BorderView := preload("res://scripts/border_view.gd")
const TILE := 16
## Props in town_props.png: a 32x32 frame each, in this order, base on the bottom row.
const PROPS: Array[String] = ["fountain", "bench", "lamp", "telescope", "board", "hive", "lumber", "barrel", "crate", "signpost", "planter"]

var fishing: bool = false  # the local player has a line in the river
var bite: bool = false
var spot := Vector2i.ZERO  # the river tile the line is in
var _grounds: Array[Texture2D] = []
var _season: int = -1
var _t: float = 0.0
var _glints: Array[Vector2] = []  # river tiles that catch the light, in town pixels
var _falls: Array[Vector2] = []


func _ready() -> void:
	position = Vector2(GameState.TOWN_ORIGIN * TILE)
	for season in 4:
		_grounds.append(Assets.texture("res://assets/sprites/town_%d.png" % season))
	for y in GameState.TOWN_SIZE.y:
		for x in GameState.TOWN_SIZE.x:
			var tile: String = GameState.TOWN_MAP[y][x]
			if tile == "~" and (x * 7 + y * 13) % 5 == 0:
				_glints.append(Vector2(x * TILE, y * TILE))
			elif tile == "w":
				_falls.append(Vector2(x * TILE, y * TILE))


func _process(delta: float) -> void:
	_t += delta
	if TimeManager.season() != _season or int(_t * 6.0) != int((_t - delta) * 6.0):
		queue_redraw()


func _draw() -> void:
	_season = TimeManager.season()
	draw_texture(_grounds[_season], Vector2.ZERO)
	var frozen: bool = _season == 3
	# Sunlight on the river: little glints that come and go.
	for i in _glints.size():
		var phase: float = fmod(_t * 0.7 + i * 0.37, 1.0)
		if phase < 0.5:
			var at: Vector2 = _glints[i] + Vector2(3 + (i * 5) % 9, 4 + (i * 3) % 8)
			var alpha: float = sin(phase * TAU) * (0.35 if not frozen else 0.15)
			draw_rect(Rect2(at, Vector2(3, 1)), Color(1, 1, 1, alpha))
	# The waterfall: streaks running down, and spray at its foot.
	for i in _falls.size():
		var top: Vector2 = _falls[i]
		for k in 3:
			var y: float = fmod(_t * 40.0 + k * 6.0 + i * 3.0, TILE)
			draw_rect(Rect2(top + Vector2(2 + k * 5, y), Vector2(1, 4)), Color(1, 1, 1, 0.5 if not frozen else 0.25))
		if int(top.y / TILE) == 2:
			var puff: float = 1.5 + sin(_t * 5.0 + i) * 1.0
			draw_circle(top + Vector2(8, 17), 4.0 + puff, Color(1, 1, 1, 0.28 if not frozen else 0.12))
	if fishing:
		var bob := Vector2((spot - GameState.TOWN_ORIGIN) * TILE) + Vector2(8, 8) + Vector2(0, sin(_t * (14.0 if bite else 3.0)) * (2.5 if bite else 1.0))
		draw_circle(bob, 4.0 + sin(_t * 4.0), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(bob + Vector2(-1, -3), Vector2(3, 3)), Color(0.88, 0.38, 0.35))
		draw_rect(Rect2(bob + Vector2(-1, 0), Vector2(3, 2)), Color.WHITE)


## The bottom-centre of a town tile, in world pixels.
static func foot(local: Vector2i) -> Vector2:
	return Vector2((GameState.TOWN_ORIGIN + local) * TILE) + Vector2(8, 16)


## Buildings, props, the town's trees and the woods round its edge, added to
## the y-sorted `layer` so players walk behind them.
static func decorate(layer: Node2D) -> void:
	for id: String in GameState.TOWN_BUILDINGS.keys():
		var rect: Rect2i = GameState.TOWN_BUILDINGS[id]
		var house := Sprite2D.new()
		house.texture = Assets.texture("res://assets/sprites/town_%s.png" % id)
		house.centered = false
		house.offset = Vector2(-house.texture.get_width() / 2.0, -house.texture.get_height())
		house.position = Vector2((GameState.TOWN_ORIGIN + rect.position) * TILE) + Vector2(rect.size.x * TILE / 2.0, rect.size.y * TILE)
		layer.add_child(house)
	var props: Texture2D = Assets.texture("res://assets/sprites/town_props.png")
	for at: Vector2i in GameState.TOWN_PROPS.keys():
		var kind: String = GameState.TOWN_PROPS[at]
		var size: Vector2i = GameState.TOWN_PROP_SIZES.get(kind, Vector2i.ONE)
		var prop := Sprite2D.new()
		prop.texture = props
		prop.region_enabled = true
		prop.region_rect = Rect2(PROPS.find(kind) * 32, 0, 32, 32)
		prop.centered = false
		prop.offset = Vector2(-16, -32)
		prop.position = Vector2((GameState.TOWN_ORIGIN + at) * TILE) + Vector2(size.x * TILE / 2.0, size.y * TILE)
		layer.add_child(prop)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for at: Vector2i in GameState.TOWN_TREES.keys():
		BorderView._add(layer, GameState.TOWN_TREES[at], foot(at) + Vector2(rng.randi_range(-2, 2), 0), rng.randf() < 0.5, BorderView._tint(rng))
	# The woods: a tree on every woods tile at the edge of the town (and on
	# every other one further in), nudged about so they never line up.
	var woods: Dictionary = {"pine": 6, "oak": 5, "maple": 4, "birch": 2, "cherry": 1}
	var size: Vector2i = GameState.TOWN_SIZE
	for y in range(-2, size.y + 3):
		for x in range(-3, size.x + 3):
			var here := Vector2i(x, y)
			if _tile(here) != "T":
				continue
			var edge: bool = false
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1)]:
				if _tile(here + side) != "T":
					edge = true
			if not edge and (x + y) % 2 != 0:
				continue
			var nudge := Vector2(rng.randi_range(-4, 4), rng.randi_range(-3, 3))
			BorderView._add(layer, BorderView._pick(rng, woods), foot(here) + nudge, rng.randf() < 0.5, BorderView._tint(rng))
			if edge and rng.randf() < 0.45:
				BorderView._add(layer, ["bush", "bush", "boulder"][rng.randi_range(0, 2)], foot(here) + Vector2(rng.randi_range(-8, 8), 4), rng.randf() < 0.5, Color.WHITE)


## The map letter at a town tile; woods all round the outside, except where
## the river and the trail run off the edge.
static func _tile(local: Vector2i) -> String:
	var clamped := Vector2i(clampi(local.x, 0, GameState.TOWN_SIZE.x - 1), clampi(local.y, 0, GameState.TOWN_SIZE.y - 1))
	if clamped != local:
		var edge: String = GameState.TOWN_MAP[clamped.y][clamped.x]
		return edge if edge == "~" or edge == "w" or edge == "," else "T"
	return GameState.TOWN_MAP[local.y][local.x]


## A sprite for each of the townsfolk and villagers, in `layer`; refresh()
## puts whoever is about where they are now (in town or in a room).
static func people(layer: Node2D) -> Dictionary:
	var out: Dictionary = {}
	for id: String in GameState.TOWNSFOLK.keys() + GameState.VILLAGERS.keys():
		var who := Sprite2D.new()
		who.texture = Assets.texture("res://assets/sprites/keeper_town.png" if id == "bristle" else "res://assets/sprites/villager_%s.png" % id)
		who.centered = false
		who.offset = Vector2(-8, -23)
		who.visible = false
		layer.add_child(who)
		out[id] = who
	return out


static func refresh(sprites: Dictionary) -> void:
	var here: Dictionary = GameState.people_in_town()
	for id: String in sprites.keys():
		sprites[id].visible = here.has(id)
		if here.has(id):
			sprites[id].position = Vector2(here[id] * TILE) + Vector2(8, 15)
