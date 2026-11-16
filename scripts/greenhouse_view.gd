extends Node2D
## The greenhouse: a glass frame over a patch of garden. Drawn above the
## plants as pale glass with white beams; you walk and garden inside as usual.

const TILE := 16


func _ready() -> void:
	z_index = 5
	GameState.economy_changed.connect(_refresh)
	GameState.state_reloaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = GameState.upgrade_level("greenhouse") > 0
	queue_redraw()


func _draw() -> void:
	var area := Rect2(GameState.GREENHOUSE_RECT.position * TILE, GameState.GREENHOUSE_RECT.size * TILE)
	var beam := Color(0.95, 0.98, 1.0, 0.9)
	draw_rect(area, Color(0.75, 0.92, 1.0, 0.16))
	draw_rect(Rect2(area.position, Vector2(area.size.x, 10)), Color(0.85, 0.96, 1.0, 0.3))  # the roof's near edge
	draw_rect(area, beam, false, 2.0)
	for x in range(1, GameState.GREENHOUSE_RECT.size.x):
		if x % 2 == 0:
			draw_line(area.position + Vector2(x * TILE, 0), area.position + Vector2(x * TILE, area.size.y), Color(beam, 0.45), 1.0)
	draw_line(area.position + Vector2(0, 10), area.position + Vector2(area.size.x, 10), Color(beam, 0.6), 1.0)
	# A gap in the bottom edge reads as the door.
	draw_rect(Rect2(area.position + Vector2(area.size.x / 2.0 - 8, area.size.y - 2), Vector2(16, 3)), Color(0.75, 0.92, 1.0, 0.5))
