extends CanvasLayer
## The (deliberately over-the-top) show that plays when the clock tower
## changes the time: the sky flickers through day and night, the sun and moon
## chase each other round a giant spinning clock, calendar pages fly past,
## everything shakes, a white flash, and then a calm little announcement.
## Sizes are in game units (320x180).

const SIZE := Vector2(320, 180)
const CENTRE := Vector2(160, 92)
const LENGTH := 4.2
const FLASH_AT := 2.5
const SKIES: Array[Color] = [Color(0.45, 0.72, 0.95), Color(0.98, 0.62, 0.35), Color(0.12, 0.1, 0.3), Color(0.95, 0.62, 0.75)]
const CREAM := Color(1.0, 0.97, 0.88)
const INK := Color(0.2, 0.14, 0.23)
const SHOUTS: Array[String] = ["THE CLOCK TOWER AWAKENS", "TIME ITSELF BENDS!", "THE SEASONS SPIN!", "HOLD ON TO YOUR HAT!"]

var player: Node2D
var playing: bool = false

var _t: float = 0.0
var _canvas: Control
var _font: Font


func _ready() -> void:
	layer = 12
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	visible = false
	GameState.time_warped.connect(play)


func play() -> void:
	_t = 0.0
	playing = true
	visible = true
	if player != null:
		player.set("frozen", true)


func _process(delta: float) -> void:
	if not playing:
		return
	_t += delta
	if _t >= LENGTH:
		playing = false
		visible = false
		if player != null:
			player.set("frozen", false)
	_canvas.queue_redraw()


func _text(words: String, at: Vector2, font_size: int, color: Color) -> void:
	var width: float = _font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var from := Vector2(at.x - width / 2.0, at.y)
	_canvas.draw_string_outline(_font, from, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, INK)
	_canvas.draw_string(_font, from, words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _paint() -> void:
	if not playing:
		return
	if _t < FLASH_AT:
		_storm()
	var flash: float = 0.0
	if _t >= FLASH_AT - 0.15 and _t < FLASH_AT:
		flash = (_t - (FLASH_AT - 0.15)) / 0.15
	elif _t >= FLASH_AT:
		flash = clampf(1.0 - (_t - FLASH_AT) / 0.7, 0.0, 1.0)
	if flash > 0.0:
		_canvas.draw_set_transform(Vector2.ZERO)
		_canvas.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(1, 1, 1, flash))
	if _t >= FLASH_AT + 0.2:
		_aftermath()


## The build-up: everything before the flash.
func _storm() -> void:
	var rush: float = clampf(_t / FLASH_AT, 0.0, 1.0)  # 0 -> 1 as it builds
	var shake: float = 1.0 + rush * 5.0
	_canvas.draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))

	# The sky races through days and nights, faster and faster.
	var turn: float = _t * _t * 2.2
	var sky: Color = SKIES[int(turn) % SKIES.size()].lerp(SKIES[(int(turn) + 1) % SKIES.size()], fmod(turn, 1.0))
	_canvas.draw_rect(Rect2(Vector2(-10, -10), SIZE + Vector2(20, 20)), Color(sky, clampf(_t * 3.0, 0.0, 0.93)))

	# Streaks of stars.
	for i in 26:
		var y: float = fposmod(i * 37.0, SIZE.y)
		var x: float = fposmod(i * 53.0 - _t * (220.0 + i * 30.0) * (0.3 + rush), SIZE.x + 40.0) - 20.0
		_canvas.draw_line(Vector2(x, y), Vector2(x + 6.0 + rush * 22.0, y), Color(1, 1, 1, 0.55), 1.0)

	# The sun and the moon chase each other around.
	var orbit: float = _t * _t * 3.0
	var sun: Vector2 = CENTRE + Vector2.from_angle(orbit) * Vector2(120, 62)
	var moon: Vector2 = CENTRE + Vector2.from_angle(orbit + PI) * Vector2(120, 62)
	_canvas.draw_circle(sun, 11, Color(1.0, 0.85, 0.3))
	for ray in 8:
		_canvas.draw_line(sun + Vector2.from_angle(ray * TAU / 8.0 + orbit) * 13.0, sun + Vector2.from_angle(ray * TAU / 8.0 + orbit) * 18.0, Color(1.0, 0.85, 0.3), 2.0)
	_canvas.draw_circle(moon, 9, Color(0.95, 0.93, 0.8))
	_canvas.draw_circle(moon + Vector2(4, -3), 8, sky)

	# Calendar pages torn off and flung across the screen.
	for i in 9:
		var along: float = fposmod(_t * (0.5 + i * 0.13) * (1.0 + rush * 2.0) + i * 0.37, 1.3) - 0.15
		var page := Vector2(along * SIZE.x, 30.0 + fposmod(i * 47.0, 120.0) + sin(_t * 6.0 + i) * 8.0)
		_canvas.draw_set_transform(page + Vector2(randf_range(-shake, shake), 0), sin(_t * 9.0 + i * 2.0) * 0.6)
		_canvas.draw_rect(Rect2(-6, -7, 12, 14), INK)
		_canvas.draw_rect(Rect2(-5, -6, 10, 12), CREAM)
		_canvas.draw_rect(Rect2(-5, -6, 10, 3), Color(0.85, 0.3, 0.25))
		_canvas.draw_rect(Rect2(-2, 0, 4, 1), INK)
		_canvas.draw_rect(Rect2(-2, 2, 4, 1), INK)
	_canvas.draw_set_transform(Vector2(randf_range(-shake, shake), randf_range(-shake, shake)))

	# A giant clock whose hands have lost all self-control.
	var size: float = 30.0 + sin(_t * 14.0) * 2.0 * rush
	_canvas.draw_circle(CENTRE, size + 4.0, INK)
	_canvas.draw_circle(CENTRE, size + 2.0, Color(0.55, 0.37, 0.23))
	_canvas.draw_circle(CENTRE, size - 2.0, CREAM)
	for tick in 12:
		var out: Vector2 = Vector2.from_angle(tick * TAU / 12.0)
		_canvas.draw_line(CENTRE + out * (size - 7.0), CENTRE + out * (size - 3.0), INK, 1.5)
	var hands: float = _t * _t * 14.0
	_canvas.draw_line(CENTRE, CENTRE + Vector2.from_angle(-hands * 0.37) * (size - 14.0), INK, 3.0)
	_canvas.draw_line(CENTRE, CENTRE + Vector2.from_angle(hands) * (size - 6.0), Color(0.8, 0.28, 0.2), 2.0)
	_canvas.draw_circle(CENTRE, 2.5, INK)

	# Shouting.
	var shout: String = SHOUTS[mini(int(_t / (FLASH_AT / SHOUTS.size())), SHOUTS.size() - 1)]
	_canvas.draw_set_transform(Vector2(randf_range(-shake, shake) * 1.5, randf_range(-shake, shake)), sin(_t * 20.0) * 0.02 * shake)
	_text(shout, Vector2(160, 30 + sin(_t * 11.0) * 2.0), 14 + int(rush * 4.0), Color(1.0, 0.92, 0.4))
	_canvas.draw_set_transform(Vector2.ZERO)
	if _t > 1.2:
		_text("(this is completely normal)", Vector2(160, 168), 6, Color(1, 1, 1, 0.8))


## After the flash: calm, as if nothing happened.
func _aftermath() -> void:
	_canvas.draw_set_transform(Vector2.ZERO)
	var since: float = _t - (FLASH_AT + 0.2)
	var fade: float = clampf(since / 0.25, 0.0, 1.0) * clampf((LENGTH - _t) / 0.3, 0.0, 1.0)
	var when: String = "%s %d, Year %d  -  %s" % [TimeManager.season_name(), TimeManager.day_of_season(), TimeManager.year(), TimeManager.time_string()]
	var width: float = maxf(_font.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 20.0, 110.0)
	var box := Rect2(160 - width / 2.0, 66, width, 40)
	_canvas.draw_rect(box.grow(1), Color(0.42, 0.26, 0.15, fade))
	_canvas.draw_rect(box, Color(0.98, 0.91, 0.74, fade))
	_canvas.draw_string(_font, Vector2(box.position.x, 79), "It is now", HORIZONTAL_ALIGNMENT_CENTER, width, 7, Color(0.55, 0.42, 0.32, fade))
	_canvas.draw_string(_font, Vector2(box.position.x, 92), when, HORIZONTAL_ALIGNMENT_CENTER, width, 10, Color(0.75, 0.28, 0.2, fade))
	if since > 0.6:
		_canvas.draw_string(_font, Vector2(box.position.x, 102), "...ahem. Carry on.", HORIZONTAL_ALIGNMENT_CENTER, width, 6, Color(0.3, 0.18, 0.12, fade))
