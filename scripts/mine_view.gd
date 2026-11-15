extends Node2D
## The inside of the mine: a rough cave floor and walls with a ladder mat at
## the bottom middle. Its rocks are ordinary object views. Sits at
## GameState.MINE_ORIGIN.

const TILE := 16
const FLOOR := Color(0.36, 0.32, 0.4)
const WALL := Color(0.22, 0.19, 0.27)


func _ready() -> void:
	position = Vector2(GameState.MINE_ORIGIN * TILE)


func centre() -> Vector2:
	return position + Vector2(GameState.MINE_SIZE.x * TILE, (GameState.MINE_SIZE.y + 2) * TILE) / 2.0


func _draw() -> void:
	var size := Vector2(GameState.MINE_SIZE.x * TILE, (GameState.MINE_SIZE.y + 2) * TILE)
	draw_rect(Rect2(-400, -300, 1000, 800), Color(0.07, 0.06, 0.1))
	draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0.13, 0.11, 0.17))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 32)), WALL)
	draw_rect(Rect2(Vector2(0, 32), Vector2(size.x, size.y - 32)), FLOOR)
	for i in 70:  # pebbles and cracks
		var h: int = hash(Vector2i(i, 7))
		var at := Vector2(h % int(size.x), 34 + (h >> 8) % int(size.y - 36))
		draw_rect(Rect2(at, Vector2(2, 1)), FLOOR.darkened(0.2) if i % 2 == 0 else FLOOR.lightened(0.12))
	for i in 14:  # wall texture and a few sparkles
		var h: int = hash(Vector2i(i, 3))
		draw_rect(Rect2(h % int(size.x), (h >> 6) % 28, 5, 2), WALL.lightened(0.1))
	for i in 6:
		var h: int = hash(Vector2i(i, 11))
		draw_rect(Rect2(h % int(size.x), 4 + (h >> 5) % 22, 1, 1), Color(0.8, 0.7, 1.0))
	# The ladder out, on the middle two tiles of the bottom row.
	var middle: float = GameState.MINE_SIZE.x * TILE / 2.0
	draw_rect(Rect2(middle - 14, size.y - 14, 28, 14), Color(0.16, 0.13, 0.2))
	for x: float in [middle - 8, middle + 6]:
		draw_rect(Rect2(x, size.y - 14, 2, 14), Color(0.6, 0.42, 0.26))
	for y in 4:
		draw_rect(Rect2(middle - 8, size.y - 12 + y * 3.5, 16, 1), Color(0.6, 0.42, 0.26))
