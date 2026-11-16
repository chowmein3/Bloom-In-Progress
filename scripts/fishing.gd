extends CanvasLayer
## The fishing game. Cast, wait for a bite, press Space on the "!" to hook
## it, then press Space each time the marker crosses the green band to reel
## it in. Three good pulls land the fish; the host then decides which fish.

const Ui := preload("res://scripts/ui_style.gd")
const BAR := Rect2(100, 124, 120, 9)
const HITS_NEEDED := 3
const REEL_TIME := 9.0

var player: Node2D
var pond: Node2D
var stage: String = ""  # "", wait, bite, reel

var _t: float = 0.0
var _wait: float = 0.0
var _marker: float = 0.0
var _direction: float = 1.0
var _zone: float = 0.0
var _hits: int = 0
var _canvas: Control
var _font: Font


func _ready() -> void:
	layer = 14
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.size = Vector2(320, 180)  # drawn at 320x180, centred in the window
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	visible = false


func cast() -> void:
	if stage != "" or bool(player.get("reading")):
		return
	if GameState.get_energy(player.get("player_id")) < GameState.COST_FISH:
		GameState.notice.emit("Too tired to fish")
		return
	stage = "wait"
	_t = 0.0
	_wait = randf_range(1.2, 3.6)
	visible = true
	player.set("reading", true)
	pond.set("fishing", true)
	pond.set("bite", false)
	Sound.play("water")


func _finish(landed: bool, words: String) -> void:
	stage = ""
	visible = false
	player.set("reading", false)
	pond.set("fishing", false)
	if words != "":
		GameState.notice.emit(words)
	GameState.request_fish(player.get("player_id"), landed)


func _process(delta: float) -> void:
	if stage == "":
		return
	_canvas.position = (get_viewport().get_visible_rect().size - _canvas.size) / 2.0
	_t += delta
	match stage:
		"wait":
			if _t >= _wait:
				stage = "bite"
				_t = 0.0
				pond.set("bite", true)
				Sound.play("plant")
		"bite":
			if _t > 1.0:
				_finish(false, "Too slow... it swam off")
		"reel":
			var speed: float = 0.75 + _hits * 0.28
			_marker += _direction * speed * delta
			if _marker >= 1.0 or _marker <= 0.0:
				_marker = clampf(_marker, 0.0, 1.0)
				_direction = -_direction
			if _t > REEL_TIME:
				_finish(false, "The line went slack")
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if stage == "":
		return
	if event.is_action_pressed("close"):
		stage = ""
		visible = false
		player.set("reading", false)
		pond.set("fishing", false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match stage:
			"wait":
				_finish(false, "Pulled too early")
			"bite":
				stage = "reel"
				_t = 0.0
				_hits = 0
				_marker = 0.0
				_direction = 1.0
				_zone = randf_range(0.25, 0.7)
				pond.set("bite", false)
			"reel":
				if absf(_marker - _zone) <= 0.11:
					_hits += 1
					Sound.play("pick")
					if _hits >= HITS_NEEDED:
						_finish(true, "")
					else:
						_zone = randf_range(0.15, 0.85)
				else:
					_hits = maxi(_hits - 1, 0)
					Sound.play("soil")


func _words(text: String, y: float, size: int, color: Color) -> void:
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_canvas.draw_string_outline(_font, Vector2(160 - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.2, 0.14, 0.23))
	_canvas.draw_string(_font, Vector2(160 - width / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _paint() -> void:
	match stage:
		"wait":
			_words("Waiting for a bite" + ".".repeat(1 + int(_t * 2.0) % 3), 126, 7, Ui.PAPER)
			_words("(Esc to reel in)", 136, 5, Color(1, 1, 1, 0.7))
		"bite":
			_words("!", 112 + sin(_t * 30.0) * 2.0, 22, Color(1.0, 0.85, 0.3))
			_words("Press Space!", 130, 8, Ui.PAPER)
		"reel":
			_words("Press Space on the green", 118, 6, Ui.PAPER)
			_canvas.draw_rect(BAR.grow(2), Ui.WOOD)
			_canvas.draw_rect(BAR.grow(1), Ui.PAPER)
			_canvas.draw_rect(Rect2(BAR.position.x + (_zone - 0.11) * BAR.size.x, BAR.position.y, 0.22 * BAR.size.x, BAR.size.y), Color(0.45, 0.8, 0.4))
			_canvas.draw_rect(Rect2(BAR.position.x + _marker * BAR.size.x - 1.5, BAR.position.y - 2, 3, BAR.size.y + 4), Ui.ACCENT)
			for i in HITS_NEEDED:  # progress fish
				_canvas.draw_circle(Vector2(146 + i * 14, 142), 4, Color(0.36, 0.62, 0.86) if i < _hits else Color(0.3, 0.2, 0.16, 0.6))
