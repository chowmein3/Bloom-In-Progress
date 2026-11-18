extends Node2D
## One thing standing on a garden tile: debris, or something a player placed
## (fence, sprinkler, lantern). Stepping stones are flat and drawn by the
## ground instead. Origin is the bottom-centre of the tile.

const Assets := preload("res://scripts/assets.gd")

var kind: String = ""
var _texture: Texture2D
var _tree: Texture2D  # three 32x40 frames: young, grown, with fruit


func _ready() -> void:
	if kind == "dropped":  # something a player dropped: its picture, bobbing
		var here := Vector2i(int(floor(position.x / 16.0)), int(floor((position.y - 1.0) / 16.0)))
		var key: String = str(GameState.objects.get(here, {}).get("key", ""))
		var id: String = GameState.base_of(key.get_slice(":", 1))
		_texture = Assets.texture("res://assets/sprites/items/%s%s.png" % [id, "_seeds" if key.begins_with("seed:") else ""])
		return
	_texture = Assets.texture("res://assets/sprites/items/%s.png" % kind)
	if GameState.TREES.has(kind):
		_tree = Assets.texture("res://assets/sprites/fruit_tree_%s.png" % GameState.TREES[kind])
	if kind == "lantern" or kind == "lamp":
		TimeManager.time_changed.connect(queue_redraw)
	if kind == "mailbox":
		GameState.mail_changed.connect(queue_redraw)
		GameState.state_reloaded.connect(queue_redraw)


func _process(_delta: float) -> void:
	if GameState.MACHINES.has(kind) or kind == "mailbox" or kind == "dropped":
		queue_redraw()  # for the little bobbing marks


func _draw() -> void:
	if (kind == "lantern" or kind == "lamp") and TimeManager.minutes >= 18 * 60:  # lit from dusk
		draw_circle(Vector2(0, -10), 22, Color(1.0, 0.85, 0.45, 0.12))
		draw_circle(Vector2(0, -10), 13, Color(1.0, 0.9, 0.55, 0.16))
	var here := Vector2i(int(floor(position.x / 16.0)), int(floor((position.y - 1.0) / 16.0)))
	if kind == "dropped":
		var hover: float = sin(Time.get_ticks_msec() / 300.0 + position.x) * 1.5
		draw_circle(Vector2(0, -3), 4.5, Color(0, 0, 0, 0.18))  # shadow
		if _texture != null:
			draw_texture_rect(_texture, Rect2(-6, -16 + hover, 12, 12), false)
		var count: int = int(GameState.objects.get(here, {}).get("count", 1))
		if count > 1:
			var font: Font = ThemeDB.fallback_font
			draw_string_outline(font, Vector2(1, -4 + hover), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, 2, Color(0.2, 0.15, 0.2))
			draw_string(font, Vector2(1, -4 + hover), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color.WHITE)
		return
	if _tree != null and int(GameState.objects.get(here, {}).get("age", 0)) > 0:
		var growing: Dictionary = GameState.objects[here]
		var frame: int = 0
		if int(growing["age"]) >= GameState.TREE_GROW_DAYS:
			frame = 2 if bool(growing.get("fruit", false)) else 1
		draw_texture_rect_region(_tree, Rect2(-16, -40, 32, 40), Rect2(frame * 32, 0, 32, 40))
	elif _texture != null:
		draw_texture(_texture, Vector2(-8, -16))
	var bob: float = sin(Time.get_ticks_msec() / 250.0) * 1.5
	if kind == "mailbox" and not GameState.mail.is_empty():
		draw_rect(Rect2(-1, -25 + bob, 2, 5), Color(0.95, 0.75, 0.3))  # "!": a letter is waiting
		draw_rect(Rect2(-1, -19 + bob, 2, 2), Color(0.95, 0.75, 0.3))
	if GameState.MACHINES.has(kind):
		var machine: Dictionary = GameState.objects.get(here, {})
		if bool(machine.get("ready", false)):
			draw_rect(Rect2(-1, -25 + bob, 2, 5), Color(0.5, 0.9, 0.45))  # ready to collect
			draw_rect(Rect2(-1, -19 + bob, 2, 2), Color(0.5, 0.9, 0.45))
		elif int(machine.get("busy", 0)) > 0:
			for dot in int(machine["busy"]):  # a dot per day still to go
				draw_rect(Rect2(-4 + dot * 4, -20, 2, 2), Color(1, 1, 1, 0.8))
