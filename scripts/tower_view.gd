extends Node2D
## The clock tower. Its hands show the real time in the garden, and spin
## wildly while time is being changed. Origin is the bottom-centre.

const Assets := preload("res://scripts/assets.gd")
const FACE := Vector2(-0.5, -27.5)  # centre of the clock face, from the origin
const DARK := Color(0.2, 0.14, 0.23)

var _texture: Texture2D = Assets.texture("res://assets/sprites/tower.png")
var _spin: float = 0.0  # seconds of wild spinning left


func _ready() -> void:
	TimeManager.time_changed.connect(queue_redraw)
	GameState.time_warped.connect(func() -> void: _spin = 2.6)


func _process(delta: float) -> void:
	if _spin > 0.0:
		_spin -= delta
		queue_redraw()


func _draw() -> void:
	draw_texture(_texture, Vector2(-16, -48))
	var minutes: float = float(TimeManager.minutes)
	if _spin > 0.0:
		minutes += pow(2.6 - _spin, 2.0) * 4000.0
	var minute_angle: float = fmod(minutes, 60.0) / 60.0 * TAU - PI / 2.0
	var hour_angle: float = fmod(minutes / 60.0, 12.0) / 12.0 * TAU - PI / 2.0
	draw_line(FACE, FACE + Vector2.from_angle(hour_angle) * 3.0, DARK, 1.2)
	draw_line(FACE, FACE + Vector2.from_angle(minute_angle) * 5.0, Color(0.75, 0.28, 0.2), 1.0)
