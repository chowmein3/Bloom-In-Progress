extends Node2D
## Draws the grass and tilled soil from assets/tiles/ground.png: one row of
## 16px tiles per season; columns are 4 grass looks, dry soil, wet soil.

const Assets := preload("res://scripts/assets.gd")

const TILE := 16
const GRASS_COLUMNS: Array[int] = [0, 1, 0, 2, 1, 0, 3, 1]  # mostly plain, a few with tufts or a flower

var _tiles: Texture2D = Assets.texture("res://assets/tiles/ground.png")


func _ready() -> void:
	GameState.cell_changed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.plant_removed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.day_advanced.connect(func(_s: Dictionary) -> void: queue_redraw())
	GameState.state_reloaded.connect(queue_redraw)


func _draw() -> void:
	var row: int = TimeManager.season()
	for y in GameState.WORLD_SIZE.y:
		for x in GameState.WORLD_SIZE.x:
			var cell := Vector2i(x, y)
			var where := Rect2(x * TILE, y * TILE, TILE, TILE)
			var column: int = GRASS_COLUMNS[hash(cell) % GRASS_COLUMNS.size()]
			draw_texture_rect_region(_tiles, where, Rect2(column * TILE, row * TILE, TILE, TILE))
			if GameState.soil.has(cell):
				column = 5 if bool(GameState.soil[cell]["watered"]) else 4
				draw_texture_rect_region(_tiles, where, Rect2(column * TILE, row * TILE, TILE, TILE))
