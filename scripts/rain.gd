extends Node2D
## Simple screen-space rain streaks, shown while TimeManager.raining.

var _t: float = 0.0


func _process(delta: float) -> void:
	visible = TimeManager.raining
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var color := Color(0.75, 0.85, 1.0, 0.5)
	for i in 60:
		var x: float = fposmod(float(i * 53 % 340) - _t * 40.0, 340.0) - 10.0
		var y: float = fposmod(float(i * 97 % 200) + _t * 220.0, 200.0) - 10.0
		draw_line(Vector2(x, y), Vector2(x - 2, y + 5), color, 1.0)
