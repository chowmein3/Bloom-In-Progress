extends Node2D
## The fishing pond: water with slow ripples, lily pads and a bobbing float
## while someone is fishing. Drawn flat, under the players.

const TILE := 16
const WATER := Color(0.36, 0.62, 0.86)
const DEEP := Color(0.28, 0.5, 0.78)
const BANK := Color(0.36, 0.33, 0.34)  # the dark edge of the stony shore

var fishing: bool = false  # the local player has a line in the water
var bite: bool = false

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var area := Rect2(GameState.POND_RECT.position * TILE, GameState.POND_RECT.size * TILE)
	var frozen: bool = TimeManager.season() == 3
	# A rounded, stony shore inside the pond's tiles, then shallows and deep water.
	_rounded(area, 12.0, BANK)
	_rounded(area.grow(-1), 11.0, Color(0.62, 0.58, 0.5))
	_rounded(area.grow(-3), 9.0, Color(0.78, 0.9, 0.97) if frozen else WATER)
	_rounded(area.grow(-9), 6.0, Color(0.7, 0.85, 0.95) if frozen else DEEP)
	for i in 14:  # stones along the bank
		var along: float = float(i) / 14.0
		var at: Vector2 = _shore_point(area.grow(-2), along)
		var inner: Rect2 = area.grow(-12)
		if at.distance_to(Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))) > 11.0:
			continue  # round the corners, not on them
		var r: float = 1.5 + float(hash(i) % 3) * 0.5
		draw_circle(at, r + 0.6, Color(0.36, 0.33, 0.34))
		draw_circle(at, r, Color(0.66, 0.64, 0.66) if hash(i) % 2 == 0 else Color(0.56, 0.54, 0.58))
		draw_rect(Rect2(at + Vector2(-r * 0.5, -r * 0.6), Vector2(1, 1)), Color(0.85, 0.84, 0.86))
	if frozen:
		draw_rect(Rect2(area.position + Vector2(14, 12), Vector2(10, 1)), Color(1, 1, 1, 0.7))
		draw_rect(Rect2(area.position + Vector2(40, 30), Vector2(14, 1)), Color(1, 1, 1, 0.7))
	for i in 7:  # ripples drifting across
		var y: float = area.position.y + 5.0 + i * 6.0
		var x: float = area.position.x + fposmod(i * 23.0 + _t * (6.0 + i), area.size.x - 12.0)
		if not frozen:
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


## A rectangle with round corners.
func _rounded(rect: Rect2, radius: float, colour: Color) -> void:
	draw_rect(rect.grow_individual(-radius, 0, -radius, 0), colour)
	draw_rect(rect.grow_individual(0, -radius, 0, -radius), colour)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var inward := Vector2(radius if corner.x == rect.position.x else -radius, radius if corner.y == rect.position.y else -radius)
		draw_circle(corner + inward, radius, colour)


## A point `along` (0-1) the edge of `rect`, going round clockwise.
func _shore_point(rect: Rect2, along: float) -> Vector2:
	var perimeter: float = 2.0 * (rect.size.x + rect.size.y)
	var d: float = along * perimeter
	if d < rect.size.x:
		return rect.position + Vector2(d, 0)
	d -= rect.size.x
	if d < rect.size.y:
		return Vector2(rect.end.x, rect.position.y + d)
	d -= rect.size.y
	if d < rect.size.x:
		return Vector2(rect.end.x - d, rect.end.y)
	return Vector2(rect.position.x, rect.end.y - (d - rect.size.x))
