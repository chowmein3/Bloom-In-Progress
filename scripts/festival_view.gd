extends Node2D
## Festival decorations. On a festival day, bunting is strung from the clock
## tower's roof to the home's roof to the stall's awning (so it hangs above the
## buildings, not across the yard). From PARTY_START the party is on: the
## flags sway and confetti drifts over the yard.

const TILE := 16
const PARTY_START := 17 * 60  # 5pm
const FLAGS: Array[Color] = [Color(0.95, 0.45, 0.45), Color(1.0, 0.83, 0.3), Color(0.4, 0.75, 0.7), Color(0.75, 0.55, 0.9)]

var _t: float = 0.0


func _ready() -> void:
	z_index = 6  # above the roofs


func partying() -> bool:
	return GameState.festival_today() != -1 and TimeManager.minutes >= PARTY_START


func _process(delta: float) -> void:
	visible = GameState.festival_today() != -1
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var tower := Vector2((GameState.TOWER_RECT.position.x + 1) * TILE, 3)
	var home := Vector2((GameState.TENT_RECT.position.x + 1.5) * TILE, 9)
	var stall := Vector2((GameState.STALL_RECT.position.x + 1.5) * TILE, 5)
	_swag(tower, home, 0)
	_swag(home, stall, 2)
	if not partying():
		return
	var yard := Rect2(6 * TILE, 3 * TILE, 15 * TILE, 5 * TILE)
	for i in 40:  # confetti
		var x: float = yard.position.x + fposmod(i * 37.0 + sin(_t * 0.8 + i) * 10.0, yard.size.x)
		var y: float = yard.position.y - 20.0 + fposmod(i * 23.0 + _t * (14.0 + i % 5 * 3.0), yard.size.y + 20.0)
		draw_rect(Rect2(floorf(x), floorf(y), 2, 1 + i % 2), FLAGS[i % FLAGS.size()])


## A sagging string of flags from one rooftop to the next.
func _swag(from: Vector2, to: Vector2, colour_offset: int) -> void:
	var count: int = 9
	var sway: float = sin(_t * 3.0) * (1.5 if partying() else 0.4)
	var last: Vector2 = from
	for i in range(1, count + 1):
		var along: float = float(i) / count
		var point: Vector2 = from.lerp(to, along) + Vector2(0, sin(along * PI) * 7.0)
		draw_line(last, point, Color(0.3, 0.2, 0.16), 1.0)
		if i < count:
			draw_colored_polygon(PackedVector2Array([point + Vector2(-2.5, 0), point + Vector2(2.5, 0), point + Vector2(sway, 6)]), FLAGS[(i + colour_offset) % FLAGS.size()])
		last = point
