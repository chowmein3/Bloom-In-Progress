extends Node2D
## Screen-space weather: rain when it rains, otherwise a few drifting petals
## (spring), fireflies (summer nights), leaves (fall) or snowflakes (winter).

const PETAL := Color(1.0, 0.75, 0.85, 0.85)
const LEAF_A := Color(0.9, 0.5, 0.2, 0.9)
const LEAF_B := Color(0.8, 0.3, 0.2, 0.9)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if TimeManager.raining:
		var color := Color(0.75, 0.85, 1.0, 0.5)
		for i in 60:
			var x: float = fposmod(float(i * 53 % 340) - _t * 40.0, 340.0) - 10.0
			var y: float = fposmod(float(i * 97 % 200) + _t * 220.0, 200.0) - 10.0
			draw_line(Vector2(x, y), Vector2(x - 2, y + 5), color, 1.0)
		return
	match TimeManager.season():
		0:
			_drift(10, 14.0, 9.0, PETAL, PETAL, Vector2(2, 1))
		1:
			if TimeManager.minutes >= 19 * 60:
				for i in 9:
					var glow: float = 0.5 + 0.5 * sin(_t * 2.0 + i * 1.7)
					var pos := Vector2(fposmod(i * 71.0 + sin(_t * 0.4 + i) * 20.0, 320.0), fposmod(i * 43.0 + cos(_t * 0.3 + i * 2.0) * 14.0, 150.0) + 10.0)
					draw_rect(Rect2(pos, Vector2(1, 1)), Color(1.0, 0.95, 0.5, glow))
					draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.95, 0.5, glow * 0.25))
		2:
			_drift(9, 20.0, 14.0, LEAF_A, LEAF_B, Vector2(2, 2))
		3:
			_drift(26, 6.0, 16.0, Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.6), Vector2(1, 1))


## `count` specks falling down the screen, swaying sideways as they go.
func _drift(count: int, sideways: float, fall: float, a: Color, b: Color, speck: Vector2) -> void:
	for i in count:
		var x: float = fposmod(i * 67.0 + _t * sideways + sin(_t * 0.9 + i) * 8.0, 330.0) - 5.0
		var y: float = fposmod(i * 41.0 + _t * (fall + i % 4 * 2.0), 190.0) - 5.0
		draw_rect(Rect2(Vector2(floorf(x), floorf(y)), speck), a if i % 2 == 0 else b)
