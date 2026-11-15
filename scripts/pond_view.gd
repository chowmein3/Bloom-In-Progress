extends Node2D
## The fishing pond: water with slow ripples, lily pads and a bobbing float
## while someone is fishing. Drawn flat, under the players.

const TILE := 16
const WATER := Color(0.36, 0.62, 0.86)
const DEEP := Color(0.28, 0.5, 0.78)
const BANK := Color(0.32, 0.46, 0.3)

var fishing: bool = false  # the local player has a line in the water
var bite: bool = false

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var area := Rect2(GameState.POND_RECT.position * TILE, GameState.POND_RECT.size * TILE)
	var frozen: bool = TimeManager.season() == 3
	draw_rect(area.grow(1), BANK)
	draw_rect(area, Color(0.78, 0.9, 0.97) if frozen else WATER)
	draw_rect(area.grow(-6), Color(0.7, 0.85, 0.95) if frozen else DEEP)
	for i in 7:  # ripples drifting across
		var y: float = area.position.y + 5.0 + i * 6.0
		var x: float = area.position.x + fposmod(i * 23.0 + _t * (6.0 + i), area.size.x - 12.0)
		draw_rect(Rect2(x, y, 6, 1), Color(1, 1, 1, 0.35))
	if not frozen:
		for pad: Vector2 in [Vector2(10, 9), Vector2(58, 34), Vector2(66, 8)]:
			draw_circle(area.position + pad, 3.5, Color(0.3, 0.62, 0.36))
			draw_rect(Rect2(area.position + pad + Vector2(-1, -4), Vector2(2, 3)), WATER)
		draw_circle(area.position + Vector2(58, 34), 1.5, Color(1.0, 0.6, 0.75))
	if fishing:
		var bob := area.get_center() + Vector2(0, sin(_t * (14.0 if bite else 3.0)) * (2.5 if bite else 1.0))
		draw_circle(bob, 4.0 + sin(_t * 4.0), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(bob + Vector2(-1, -3), Vector2(3, 3)), Color(0.88, 0.38, 0.35))
		draw_rect(Rect2(bob + Vector2(-1, 0), Vector2(3, 2)), Color.WHITE)
