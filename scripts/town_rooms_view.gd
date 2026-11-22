extends Node2D
## The rooms inside the town's buildings: each one's picture
## (assets/sprites/town_room_<id>.png, painted by tools/town_art.py from
## GameState.TOWN_ROOMS) at its place in the grid, and in the museum each
## donation on show in its own case.

const Assets := preload("res://scripts/assets.gd")
const TILE := 16

var _rooms: Dictionary = {}  # building id -> picture


func _ready() -> void:
	for id: String in GameState.TOWN_ROOMS.keys():
		_rooms[id] = Assets.texture("res://assets/sprites/town_room_%s.png" % id)
	GameState.economy_changed.connect(queue_redraw)
	GameState.state_reloaded.connect(queue_redraw)


## Middle of a building's room, for the camera.
func centre(id: String) -> Vector2:
	var floor: Rect2i = GameState.town_room_floor(id)
	return Vector2(GameState.town_room_origin(id) * TILE) + Vector2(floor.size.x * TILE, (floor.size.y + 2) * TILE) / 2.0


func _draw() -> void:
	for id: String in _rooms.keys():
		var at := Vector2(GameState.town_room_origin(id) * TILE)
		var picture: Texture2D = _rooms[id]
		draw_rect(Rect2(at - Vector2(2, 2), picture.get_size() + Vector2(4, 4)), Color(0.26, 0.17, 0.12))
		draw_texture(picture, at)
	for cell: Vector2i in GameState.town_room_spots("museum", "M"):
		var shown: String = GameState.museum_case(cell)
		if shown != "":
			draw_texture_rect(Assets.texture("res://assets/sprites/items/%s.png" % GameState.base_of(shown)), Rect2(Vector2(cell * TILE) + Vector2(3, -2), Vector2(10, 10)), false)
