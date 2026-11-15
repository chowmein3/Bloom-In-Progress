extends Node2D
## One thing standing on a garden tile: debris, or something a player placed
## (fence, sprinkler, lantern). Stepping stones are flat and drawn by the
## ground instead. Origin is the bottom-centre of the tile.

const Assets := preload("res://scripts/assets.gd")

var kind: String = ""
var _texture: Texture2D


func _ready() -> void:
	_texture = Assets.texture("res://assets/sprites/items/%s.png" % kind)
	if kind == "lantern" or kind == "lamp":
		TimeManager.time_changed.connect(queue_redraw)


func _draw() -> void:
	if (kind == "lantern" or kind == "lamp") and TimeManager.minutes >= 18 * 60:  # lit from dusk
		draw_circle(Vector2(0, -10), 22, Color(1.0, 0.85, 0.45, 0.12))
		draw_circle(Vector2(0, -10), 13, Color(1.0, 0.9, 0.55, 0.16))
	if _texture != null:
		draw_texture(_texture, Vector2(-8, -16))
