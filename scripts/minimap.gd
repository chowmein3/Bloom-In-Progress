extends Control
## A small map of the whole garden (2 pixels per tile): soil, plants, the
## tent, the Heart Tree and both players.

const SCALE := 1.4  # 40 tiles across in 56 units
const TILE := 16.0
const GRASS: Array[Color] = [Color(0.47, 0.76, 0.4), Color(0.37, 0.69, 0.33), Color(0.79, 0.64, 0.31), Color(0.89, 0.93, 0.95)]
const PLAYER_COLORS: Array[Color] = [Color(0.31, 0.5, 0.82), Color(0.88, 0.45, 0.62)]
const DARK := Color(0.2, 0.14, 0.23)

var player: Node2D
var remote_players: Dictionary = {}  # slot -> Player node (shared with main.gd)

var _since: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(GameState.WORLD_SIZE) * SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_since += delta
	if _since >= 0.15 and is_visible_in_tree():
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	if player != null and bool(player.call("in_town")):
		_draw_town()
		return
	draw_rect(Rect2(Vector2.ZERO, size), GRASS[TimeManager.season()])
	for cell: Vector2i in GameState.soil.keys():
		var wet: bool = bool(GameState.soil[cell]["watered"])
		draw_rect(Rect2(Vector2(cell) * SCALE, Vector2(SCALE, SCALE)), Color(0.42, 0.27, 0.19) if wet else Color(0.66, 0.47, 0.29))
	for cell: Vector2i in GameState.plants.keys():
		var color := Color(0.2, 0.5, 0.25)
		if GameState.plant_is_radiant(cell):
			color = Color(1.0, 0.95, 0.6)
		elif GameState.plant_is_mature(cell):
			color = Color(1.0, 0.5, 0.7)
		draw_rect(Rect2(Vector2(cell) * SCALE, Vector2(SCALE, SCALE)), color)
	var tent := Rect2(GameState.TENT_RECT)
	draw_rect(Rect2(tent.position * SCALE, tent.size * SCALE), Color(0.94, 0.54, 0.47))
	for water: Vector2i in GameState.POND_CELLS:
		draw_rect(Rect2(Vector2(water) * SCALE, Vector2(SCALE, SCALE)), Color(0.36, 0.62, 0.86))
	var tower := Rect2(GameState.TOWER_RECT)
	draw_rect(Rect2(tower.position * SCALE, tower.size * SCALE), Color(0.55, 0.42, 0.75))
	var stall := Rect2(GameState.STALL_RECT)
	draw_rect(Rect2(stall.position * SCALE, stall.size * SCALE), Color(0.25, 0.65, 0.63))
	var tree := Rect2(GameState.TREE_RECT)
	draw_rect(Rect2(tree.position * SCALE, tree.size * SCALE), Color(0.25, 0.55, 0.35))
	draw_rect(Rect2(tree.position * SCALE + Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.56, 0.7))
	for slot: int in remote_players.keys():
		_marker(remote_players[slot], slot)
	if player != null:
		_marker(player, int(player.get("player_id")))


## In town: the town's map instead (paths, plaza, river, woods, buildings).
func _draw_town() -> void:
	var scale: float = minf(size.x / GameState.TOWN_SIZE.x, size.y / GameState.TOWN_SIZE.y)
	var colours: Dictionary = {"T": Color(0.2, 0.42, 0.25), ",": Color(0.79, 0.64, 0.42), "#": Color(0.72, 0.68, 0.62),
		"~": Color(0.36, 0.62, 0.86), "w": Color(0.75, 0.88, 0.96), "=": Color(0.6, 0.42, 0.27), "^": Color(0.5, 0.44, 0.38),
		"s": Color(0.72, 0.68, 0.62), "*": Color(0.85, 0.6, 0.78)}
	draw_rect(Rect2(Vector2.ZERO, size), GRASS[TimeManager.season()])
	for y in GameState.TOWN_SIZE.y:
		for x in GameState.TOWN_SIZE.x:
			var tile: String = GameState.TOWN_MAP[y][x]
			if colours.has(tile):
				draw_rect(Rect2(Vector2(x, y) * scale, Vector2(scale, scale) + Vector2(0.05, 0.05)), colours[tile])
	for id: String in GameState.TOWN_BUILDINGS.keys():
		var rect: Rect2i = GameState.TOWN_BUILDINGS[id]
		draw_rect(Rect2(Vector2(rect.position) * scale, Vector2(rect.size) * scale), Color(0.75, 0.38, 0.3) if not id.begins_with("home") else Color(0.9, 0.62, 0.4))
	for slot: int in remote_players.keys():
		_marker(remote_players[slot], slot, scale)
	if player != null:
		_marker(player, int(player.get("player_id")), scale)


func _marker(who: Node2D, slot: int, town_scale: float = 0.0) -> void:
	var in_town: bool = GameState.is_in_town(Vector2i((who.position / TILE).floor()))
	if not who.visible or (town_scale > 0.0) != in_town or who.position.x > GameState.WORLD_SIZE.x * TILE:
		return  # in bed, indoors, or in the other place
	var at: Vector2 = (who.position / TILE * SCALE).floor() - Vector2(1, 2)
	if town_scale > 0.0:
		at = ((who.position / TILE - Vector2(GameState.TOWN_ORIGIN)) * town_scale).floor() - Vector2(1, 2)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(4, 4)), DARK)
	draw_rect(Rect2(at, Vector2(2, 2)), PLAYER_COLORS[(maxi(slot, 1) - 1) % PLAYER_COLORS.size()])
