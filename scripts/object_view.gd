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
	if kind == "mailbox":
		GameState.mail_changed.connect(queue_redraw)
		GameState.state_reloaded.connect(queue_redraw)


func _process(_delta: float) -> void:
	if GameState.MACHINES.has(kind) or kind == "mailbox":
		queue_redraw()  # for the little bobbing marks


func _draw() -> void:
	if (kind == "lantern" or kind == "lamp") and TimeManager.minutes >= 18 * 60:  # lit from dusk
		draw_circle(Vector2(0, -10), 22, Color(1.0, 0.85, 0.45, 0.12))
		draw_circle(Vector2(0, -10), 13, Color(1.0, 0.9, 0.55, 0.16))
	if _texture != null:
		draw_texture(_texture, Vector2(-8, -16))
	var bob: float = sin(Time.get_ticks_msec() / 250.0) * 1.5
	if kind == "mailbox" and not GameState.mail.is_empty():
		draw_rect(Rect2(-1, -25 + bob, 2, 5), Color(0.95, 0.75, 0.3))  # "!": a letter is waiting
		draw_rect(Rect2(-1, -19 + bob, 2, 2), Color(0.95, 0.75, 0.3))
	if GameState.MACHINES.has(kind):
		var here := Vector2i(int(floor(position.x / 16.0)), int(floor((position.y - 1.0) / 16.0)))
		var machine: Dictionary = GameState.objects.get(here, {})
		if bool(machine.get("ready", false)):
			draw_rect(Rect2(-1, -25 + bob, 2, 5), Color(0.5, 0.9, 0.45))  # ready to collect
			draw_rect(Rect2(-1, -19 + bob, 2, 2), Color(0.5, 0.9, 0.45))
		elif int(machine.get("busy", 0)) > 0:
			for dot in int(machine["busy"]):  # a dot per day still to go
				draw_rect(Rect2(-4 + dot * 4, -20, 2, 2), Color(1, 1, 1, 0.8))
