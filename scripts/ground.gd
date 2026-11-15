extends Node2D
## Draws the grass, tilled soil and the tent (placeholder art).

const TILE := 16
const GRASS: Array[Color] = [
	Color(0.47, 0.73, 0.4),  # spring
	Color(0.36, 0.66, 0.3),  # summer
	Color(0.74, 0.6, 0.32),  # fall
	Color(0.86, 0.9, 0.95),  # winter
]
const SOIL_DRY := Color(0.6, 0.42, 0.26)
const SOIL_WET := Color(0.36, 0.24, 0.16)


func _ready() -> void:
	GameState.cell_changed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.plant_removed.connect(func(_c: Vector2i) -> void: queue_redraw())
	GameState.day_advanced.connect(func(_s: Dictionary) -> void: queue_redraw())
	GameState.state_reloaded.connect(queue_redraw)


func _draw() -> void:
	var base: Color = GRASS[TimeManager.season()]
	for y in GameState.WORLD_SIZE.y:
		for x in GameState.WORLD_SIZE.x:
			var cell := Vector2i(x, y)
			var origin := Vector2(x * TILE, y * TILE)
			var h: int = hash(cell)
			draw_rect(Rect2(origin, Vector2(TILE, TILE)), base.darkened(0.04 * (h % 3)))
			# A couple of grass tufts so the ground isn't flat.
			draw_rect(Rect2(origin + Vector2(h % 13 + 1, (h >> 4) % 13 + 1), Vector2(1, 2)), base.darkened(0.18))
			draw_rect(Rect2(origin + Vector2((h >> 8) % 13 + 1, (h >> 12) % 13 + 1), Vector2(1, 1)), base.lightened(0.2))
			if GameState.soil.has(cell):
				var c: Color = SOIL_WET if bool(GameState.soil[cell]["watered"]) else SOIL_DRY
				draw_rect(Rect2(origin + Vector2(1, 1), Vector2(14, 14)), c)
				for row in 3:
					draw_rect(Rect2(origin + Vector2(2, 4 + row * 4), Vector2(12, 1)), c.darkened(0.2))
	_draw_tent()


func _draw_tent() -> void:
	var r := Rect2(GameState.TENT_RECT.position * TILE, GameState.TENT_RECT.size * TILE)
	var top := Vector2(r.position.x + r.size.x / 2.0, r.position.y - 6)
	var left := Vector2(r.position.x, r.end.y)
	var right := Vector2(r.end.x, r.end.y)
	draw_colored_polygon(PackedVector2Array([top, right, left]), Color(0.93, 0.5, 0.42))
	draw_colored_polygon(PackedVector2Array([top, Vector2(top.x + 8, r.end.y), Vector2(top.x - 8, r.end.y)]), Color(0.35, 0.22, 0.3))
	draw_line(top, left, Color(0.7, 0.33, 0.3), 1.0)
	draw_line(top, right, Color(0.7, 0.33, 0.3), 1.0)
	# little flag
	draw_rect(Rect2(top + Vector2(0, -6), Vector2(1, 6)), Color(0.4, 0.3, 0.25))
	draw_rect(Rect2(top + Vector2(1, -6), Vector2(4, 3)), Color(1, 0.85, 0.3))
