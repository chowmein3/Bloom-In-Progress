extends Node2D
## The fishing pond (GameState.POND_CELLS): a smooth, organic shape made
## from its tiles, with a muddy bank, light shallows at the edge, deep water in the
## middle, slow ripples, lily pads, reeds and a bobbing float while someone
## is fishing. Drawn flat, under the players. The woods' leaves along the
## bottom of the garden hang over its far side.

const TILE := 16
const BANK := Color(0.33, 0.3, 0.2)
const SHALLOW := Color(0.47, 0.74, 0.9)
const WATER := Color(0.33, 0.6, 0.85)
const DEEP := Color(0.25, 0.47, 0.76)
const ICE := [Color(0.62, 0.66, 0.68), Color(0.86, 0.93, 0.97), Color(0.78, 0.89, 0.96), Color(0.7, 0.83, 0.93)]
const MARGIN := 1  # tiles round the pond in its picture, for the bank
const LEVELS: Array[float] = [0.36, 0.48, 0.6, 0.8]  # bank, shallows, water, deep
const PADS: Array[Vector2i] = [Vector2i(2, 21), Vector2i(6, 22), Vector2i(4, 24)]
const REEDS: Array[Vector2i] = [Vector2i(1, 21), Vector2i(7, 23), Vector2i(2, 25)]

var fishing: bool = false  # the local player has a line in the water
var bite: bool = false

var _t: float = 0.0
var _looks: Array = [null, null]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var frozen: bool = TimeManager.season() == 3
	var cells: Array[Vector2i] = GameState.POND_CELLS
	draw_texture(_shape(1 if frozen else 0), Vector2((GameState.POND_RECT.position - Vector2i(MARGIN, MARGIN)) * TILE))
	if frozen:
		for cell: Vector2i in [Vector2i(3, 21), Vector2i(5, 23)]:  # glints on the ice
			draw_rect(Rect2(Vector2(cell * TILE) + Vector2(3, 7), Vector2(9, 1)), Color(1, 1, 1, 0.7))
	else:
		for i in cells.size():  # ripples drifting across
			if i % 3 != 0:
				continue
			var at := Vector2(cells[i] * TILE)
			var x: float = fposmod(_t * (4.0 + i % 4) + i * 7.0, 10.0)
			draw_rect(Rect2(at + Vector2(3 + x, 6 + i % 5), Vector2(4, 1)), Color(1, 1, 1, 0.3))
		for pad: Vector2i in PADS:
			var at := Vector2(pad * TILE) + Vector2(8, 8)
			draw_circle(at, 3.5, Color(0.3, 0.62, 0.36))
			draw_rect(Rect2(at + Vector2(-1, -4), Vector2(2, 3)), WATER)
		draw_circle(Vector2(PADS[1] * TILE) + Vector2(8, 8), 1.5, Color(1.0, 0.6, 0.75))
	for reed: Vector2i in REEDS:  # cattails standing in the shallows
		var foot := Vector2(reed * TILE) + Vector2(4, 13)
		for k in 3:
			var x: float = foot.x + k * 3
			var tall: float = 7.0 + (k * 5 + reed.x) % 4
			draw_rect(Rect2(x, foot.y - tall, 1, tall), Color(0.36, 0.55, 0.3) if not frozen else Color(0.55, 0.5, 0.42))
			if k != 1:
				draw_rect(Rect2(x - 0.5, foot.y - tall - 1, 2, 3), Color(0.45, 0.3, 0.2))
	if fishing:
		var middle := Vector2(GameState.POND_RECT.get_center() * TILE)
		var bob := middle + Vector2(0, sin(_t * (14.0 if bite else 3.0)) * (2.5 if bite else 1.0))
		draw_circle(bob, 4.0 + sin(_t * 4.0), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(bob + Vector2(-1, -3), Vector2(3, 3)), Color(0.88, 0.38, 0.35))
		draw_rect(Rect2(bob + Vector2(-1, 0), Vector2(3, 2)), Color.WHITE)


## The pond's shape as a picture: its tiles, scaled up smoothly so the shore
## curves, coloured by depth (bank, shallows, water, deep). Made once per look
## (0 open water, 1 frozen).
func _shape(look: int) -> Texture2D:
	if _looks[look] == null:
		var bounds: Rect2i = GameState.POND_RECT.grow(MARGIN)
		var mask := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_L8)
		for cell: Vector2i in GameState.POND_CELLS:
			mask.set_pixel(cell.x - bounds.position.x, cell.y - bounds.position.y, Color.WHITE)
		mask.resize(bounds.size.x * TILE, bounds.size.y * TILE, Image.INTERPOLATE_CUBIC)
		var colours: Array = ICE if look == 1 else [BANK, SHALLOW, WATER, DEEP]
		var picture := Image.create(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8)
		for y in mask.get_height():
			for x in mask.get_width():
				var depth: float = mask.get_pixel(x, y).r + 0.05 * sin(x * 0.7 + y * 0.3) * cos(y * 0.55)
				for level in range(LEVELS.size() - 1, -1, -1):
					if depth > LEVELS[level]:
						picture.set_pixel(x, y, colours[level])
						break
		_looks[look] = ImageTexture.create_from_image(picture)
	return _looks[look]
