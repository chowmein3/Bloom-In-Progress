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


## A string of flags across the yard on festival days.
func _draw_bunting() -> void:
	const FLAGS: Array[Color] = [Color(0.95, 0.45, 0.45), Color(1.0, 0.83, 0.3), Color(0.4, 0.75, 0.7), Color(0.75, 0.55, 0.9)]
	var from := Vector2(GameState.TOWER_RECT.end.x * TILE, 52)
	var to := Vector2(GameState.STALL_RECT.position.x * TILE, 52)
	var count: int = 14
	for i in count:
		var along: float = (i + 0.5) / count
		var at: Vector2 = from.lerp(to, along) + Vector2(0, sin(along * PI) * 5.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(3, 0), at + Vector2(0, 6)]), FLAGS[i % FLAGS.size()])
	for i in count:
		var a0: float = float(i) / count
		var a1: float = float(i + 1) / count
		draw_line(from.lerp(to, a0) + Vector2(0, sin(a0 * PI) * 5.0), from.lerp(to, a1) + Vector2(0, sin(a1 * PI) * 5.0), Color(0.3, 0.2, 0.16), 1.0)


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
				if bool(GameState.soil[cell].get("mulch", false)):  # rich dark crumbs
					draw_rect(Rect2(where.position + Vector2(2, 2), Vector2(12, 12)), Color(0.2, 0.12, 0.08, 0.35))
					for speck in 5:
						var h: int = hash(cell * (speck + 3))
						draw_rect(Rect2(where.position + Vector2(3 + h % 10, 3 + (h >> 5) % 10), Vector2(1, 1)), Color(0.55, 0.8, 0.4))
			elif GameState.object_kind(cell) == "path":
				draw_texture(_path, where.position)
	if GameState.festival_today() != -1:
		_draw_bunting()
