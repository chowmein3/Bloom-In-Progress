extends Node2D
## The inside of the home: one picture per home level
## (assets/sprites/room_<level>.png) on a dark surround. Sits at
## GameState.INTERIOR_ORIGIN, far to the right of the garden.

const Assets := preload("res://scripts/assets.gd")
const TILE := 16

var _rooms: Array[Texture2D] = []


func _ready() -> void:
	position = Vector2(GameState.INTERIOR_ORIGIN * TILE)
	for level in GameState.ROOMS.size():
		_rooms.append(Assets.texture("res://assets/sprites/room_%d.png" % level))
	GameState.economy_changed.connect(queue_redraw)
	GameState.state_reloaded.connect(queue_redraw)


## Middle of the current room, for the camera.
func centre() -> Vector2:
	var size: Vector2i = GameState.room_size()
	return position + Vector2(size.x * TILE, (size.y + 2) * TILE) / 2.0


func _draw() -> void:
	draw_rect(Rect2(-400, -300, 1000, 800), Color(0.1, 0.08, 0.13))
	var room: Texture2D = _rooms[GameState.home_level()]
	draw_rect(Rect2(Vector2(-2, -2), room.get_size() + Vector2(4, 4)), Color(0.26, 0.17, 0.12))
	draw_texture(room, Vector2.ZERO)
