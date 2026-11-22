extends Node2D
## Festival decorations in the town plaza. On a festival day bunting hangs
## between the plaza's lamps, along its top and bottom. From GameState.PARTY_START the party is
## on: the lamps glow, the flags sway and something drifts over the plaza:
## petals at the Bloom Show, the fireflies you can catch on Firefly Night
## (GameState.fireflies()), leaves at the Harvest Fair and the sky lanterns
## sent up on Lantern Night.

const TILE := 16
const FLAGS: Array[Color] = [Color(0.95, 0.45, 0.45), Color(1.0, 0.83, 0.3), Color(0.4, 0.75, 0.7), Color(0.75, 0.55, 0.9)]
## The plaza's lamps (town tiles): NW, NE, SW, SE.
const LAMPS: Array[Vector2i] = [Vector2i(14, 15), Vector2i(29, 15), Vector2i(14, 24), Vector2i(29, 24)]
const PLAZA := Rect2i(13, 15, 18, 10)  # town tiles

var _t: float = 0.0


func _ready() -> void:
	z_index = 6  # above the roofs and people


func _process(delta: float) -> void:
	visible = GameState.festival_today() != -1
	if visible:
		_t += delta
		queue_redraw()


## A town tile's top-left corner, in world pixels.
func _at(local: Vector2) -> Vector2:
	return (Vector2(GameState.TOWN_ORIGIN) + local) * TILE


func _draw() -> void:
	var party: bool = GameState.party_on()
	var tops: Array[Vector2] = []
	for lamp: Vector2i in LAMPS:
		tops.append(_at(Vector2(lamp)) + Vector2(8, -9))
	if party:
		for top: Vector2 in tops:
			draw_circle(top, 10.0 + sin(_t * 2.0) * 0.8, Color(1.0, 0.85, 0.45, 0.16))
			draw_circle(top, 5.0, Color(1.0, 0.9, 0.55, 0.22))
	_swag(tops[0], tops[1], 0, party)
	_swag(tops[2], tops[3], 2, party)
	if not party:
		return
	var area := Rect2(_at(Vector2(PLAZA.position)), Vector2(PLAZA.size * TILE))
	match GameState.festival_today():
		0:  # petals
			_drift(area, 30, [Color(1.0, 0.75, 0.85), Color(1.0, 0.95, 0.95), Color(0.95, 0.6, 0.75)], 10.0)
		1:  # fireflies: the ones to catch, and a few more off over the edges
			for cell: Vector2i in GameState.fireflies():
				var spot: Vector2 = Vector2(cell * TILE) + Vector2(8, 6) + Vector2(sin(_t * 2.3 + cell.x), cos(_t * 1.9 + cell.y)) * 2.5
				var glow: float = 0.6 + sin(_t * 5.0 + cell.x * 3.0) * 0.4
				draw_circle(spot, 8.0, Color(0.95, 1.0, 0.5, 0.22 * glow))
				draw_circle(spot, 4.5, Color(0.95, 1.0, 0.55, 0.45 * glow))
				draw_circle(spot, 2.0, Color(1.0, 1.0, 0.75, 0.6 + 0.4 * glow))
			for i in 10:
				var x: float = area.position.x + fposmod(i * 53.0 + sin(_t * 0.5 + i) * 30.0, area.size.x)
				var y: float = area.position.y + fposmod(i * 31.0 + cos(_t * 0.4 + i * 2.0) * 20.0, area.size.y)
				draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(0.95, 1.0, 0.55, 0.35 + 0.3 * sin(_t * 4.0 + i)))
		2:  # leaves
			_drift(area, 24, [Color(0.9, 0.55, 0.25), Color(0.85, 0.35, 0.2), Color(0.95, 0.75, 0.3)], 8.0)
		3:  # sky lanterns rising from round the fountain
			var count: int = 3 + int(GameState.festival_state()["lanterns"])
			var fountain: Vector2 = _at(Vector2(22, 20))
			for i in count:
				var life: float = fposmod(_t * 0.06 + i * 0.37, 1.0)
				var spot: Vector2 = fountain + Vector2(sin(i * 2.1) * 70.0 + sin(_t * 0.7 + i) * 6.0, -life * 260.0)
				var fade: float = 1.0 - life
				draw_circle(spot, 6.0, Color(1.0, 0.7, 0.35, 0.18 * fade))
				draw_rect(Rect2(spot + Vector2(-2.5, -3), Vector2(5, 6)), Color(1.0, 0.62, 0.32, fade))
				draw_rect(Rect2(spot + Vector2(-1.5, -2), Vector2(3, 4)), Color(1.0, 0.88, 0.55, fade))


## Bits drifting down over the plaza, swaying as they fall.
func _drift(area: Rect2, count: int, colours: Array, speed: float) -> void:
	for i in count:
		var x: float = area.position.x + fposmod(i * 37.0 + sin(_t * 0.8 + i) * 10.0, area.size.x)
		var y: float = area.position.y - 20.0 + fposmod(i * 23.0 + _t * (speed + i % 5 * 3.0), area.size.y + 20.0)
		draw_rect(Rect2(floorf(x), floorf(y), 2, 1 + i % 2), colours[i % colours.size()])


## A sagging string of flags from one lamp to the next.
func _swag(from: Vector2, to: Vector2, colour_offset: int, party: bool) -> void:
	var count: int = maxi(int(from.distance_to(to) / 12.0), 4)
	var sway: float = sin(_t * 3.0) * (1.5 if party else 0.4)
	var sag: float = from.distance_to(to) * 0.06
	var last: Vector2 = from
	for i in range(1, count + 1):
		var along: float = float(i) / count
		var point: Vector2 = from.lerp(to, along) + Vector2(0, sin(along * PI) * sag)
		draw_line(last, point, Color(0.3, 0.2, 0.16), 1.0)
		if i < count:
			draw_colored_polygon(PackedVector2Array([point + Vector2(-2.5, 0), point + Vector2(2.5, 0), point + Vector2(sway, 6)]), FLAGS[(i + colour_offset) % FLAGS.size()])
		last = point
