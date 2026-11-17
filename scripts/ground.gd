extends Node2D
## Draws the grass and tilled soil from assets/tiles/ground.png: one row of
## 16px tiles per season; columns are 4 grass looks, dry soil, wet soil.

const Assets := preload("res://scripts/assets.gd")

const TILE := 16
const GRASS_COLUMNS: Array[int] = [0, 1, 0, 2, 1, 0, 3, 1]  # mostly plain, a few with tufts or a flower

var _tiles: Texture2D = Assets.texture("res://assets/tiles/ground.png")
var _path: Texture2D = Assets.texture("res://assets/sprites/items/path.png")


func _ready() -> void:
	GameState.cell_changed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.object_changed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.plant_removed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.day_advanced.connect(func(_s: Dictionary) -> void: queue_redraw())
	GameState.state_reloaded.connect(queue_redraw)


func _draw() -> void:
	var row: int = TimeManager.season()
	# Woodland floor all round the garden, seen where the camera goes past the edge.
	var world := Vector2(GameState.WORLD_SIZE * TILE)
	draw_rect(Rect2(Vector2(-96, -80), world + Vector2(192, 160)), [Color(0.3, 0.52, 0.3), Color(0.25, 0.47, 0.24), Color(0.5, 0.42, 0.24), Color(0.72, 0.78, 0.84)][row])
	for y in GameState.WORLD_SIZE.y:
		for x in GameState.WORLD_SIZE.x:
			var cell := Vector2i(x, y)
			var where := Rect2(x * TILE, y * TILE, TILE, TILE)
			var column: int = GRASS_COLUMNS[hash(cell) % GRASS_COLUMNS.size()]
			if (x >= 28 or y >= 18) and hash(cell) % 5 == 0:
				column = 3  # the outer land is a meadow: more flowers
			draw_texture_rect_region(_tiles, where, Rect2(column * TILE, row * TILE, TILE, TILE))
			if GameState.soil.has(cell):
				column = 5 if bool(GameState.soil[cell]["watered"]) else 4
				draw_texture_rect_region(_tiles, where, Rect2(column * TILE, row * TILE, TILE, TILE))
				if bool(GameState.soil[cell].get("mulch", false)):  # rich dark crumbs
					draw_rect(Rect2(where.position + Vector2(2, 2), Vector2(12, 12)), Color(0.2, 0.12, 0.08, 0.35))
					for speck in 5:
						var h: int = hash(cell * (speck + 3))
						draw_rect(Rect2(where.position + Vector2(3 + h % 10, 3 + (h >> 5) % 10), Vector2(1, 1)), Color(0.55, 0.8, 0.4))
			elif GameState.object_kind(cell) == "path":
				draw_texture(_path, where.position)
