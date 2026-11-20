extends Node2D
## The bed's covers, and whoever is tucked under them. The bed itself is part
## of the room picture; this draws sleepers' heads on the pillows (host on the
## left, partner on the right) and then the blanket over them.
## Origin is the bottom-centre of the bed.

const Assets := preload("res://scripts/assets.gd")
const Effects := preload("res://scripts/effects.gd")
const TILE := 16
## The goodnight kiss, drawn frame by frame in kiss_<slot>.png (see
## tools/kiss_pixels.py): 32x32 frames whose top-left is at KISS_ORIGIN.
const KISS_ORIGIN := Vector2(-16, -40)
const KISS_SIZE := 32
## Its steps, [frame, seconds]: frame 0 is lying as usual. He turns to her,
## sits up, leans over and kisses her (the heart pops up on frame
## KISS_FRAME), then settles back down.
const KISS_STEPS: Array = [
	[0, 0.3], [1, 0.3], [2, 0.12], [3, 0.14], [4, 0.2], [5, 0.12],
	[6, 0.75],
	[5, 0.12], [4, 0.15], [3, 0.12], [2, 0.12], [1, 0.2],
]
const KISS_FRAME := 6
## How many rows the covers on that side are turned down in each frame
## (blanket_<level>_turned.png has a frame per row).
const TURNED: Array[int] = [0, 1, 2, 5, 5, 5, 5]

var _blankets: Array[Texture2D] = []
var _turned: Array[Texture2D] = []
var _heads: Dictionary = {}  # slot -> player sheet
var _kiss_sheets: Dictionary = {}  # slot -> its kiss frames, for those drawn so far
var _sleepers: Array = []
var _blink: int = 0
## A goodnight kiss (sometimes, as the night falls): who leans over, how far
## into it we are (-1: none), and how long the little heart has been
## floating (-1: none).
var _kiss_by: int = 0
var _kiss_time: float = -1.0
var _heart: float = -1.0


func _ready() -> void:
	for level in GameState.ROOMS.size():
		_blankets.append(Assets.texture("res://assets/sprites/blanket_%d.png" % level))
		_turned.append(Assets.texture("res://assets/sprites/blanket_%d_turned.png" % level))
	for slot in [1, 2]:
		_heads[slot] = Assets.player_texture(slot)
		var path: String = "res://assets/sprites/kiss_%d.png" % slot
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_kiss_sheets[slot] = Assets.texture(path)
	GameState.sleepers_changed.connect(_refresh)
	GameState.bedtime_started.connect(_on_bedtime)
	GameState.economy_changed.connect(_refresh)
	GameState.state_reloaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var bed: Rect2i = GameState.bed_rect()
	position = Vector2((bed.position.x + 1) * TILE, bed.end.y * TILE)
	_sleepers = GameState.sleeping.keys()
	if _sleepers.size() < 2:  # someone got up (or it's morning): no kiss
		_kiss_by = 0
		_kiss_time = -1.0
		_heart = -1.0
	queue_redraw()


## As the night begins to fall, one may sit up and lean over to kiss the
## other: a little heart floats up between them just as it happens.
func _on_bedtime(kiss_by: int) -> void:
	if kiss_by <= 0 or _sleepers.size() < 2:
		return
	if not _kiss_sheets.has(kiss_by):
		kiss_by = 1  # only his side is drawn so far: he leans over to her
	if not _kiss_sheets.has(kiss_by) or not _sleepers.has(kiss_by):
		return
	_kiss_by = kiss_by
	_kiss_time = 0.0
	_heart = -1.0
	queue_redraw()


## The frame of the kiss `seconds` in (0 once it is over).
static func kiss_frame_at(seconds: float) -> int:
	var t: float = 0.0
	for step: Array in KISS_STEPS:
		t += float(step[1])
		if seconds < t:
			return int(step[0])
	return 0


static func kiss_length() -> float:
	var t: float = 0.0
	for step: Array in KISS_STEPS:
		t += float(step[1])
	return t


func kiss_frame() -> int:
	return kiss_frame_at(_kiss_time) if _kiss_time >= 0.0 else 0


func _process(delta: float) -> void:
	if _kiss_time >= 0.0:
		var before: int = kiss_frame()
		_kiss_time += delta
		var now: int = kiss_frame()
		if now == KISS_FRAME and before != KISS_FRAME:
			_heart = 0.0  # just as their faces meet
		if _kiss_time >= kiss_length():
			_kiss_time = -1.0
		if now != before:
			queue_redraw()
	if _heart >= 0.0:
		_heart += delta
		if _heart > 1.8:
			_heart = -1.0
		queue_redraw()
	var blink: int = int(Time.get_ticks_msec() / 750.0)  # the Zzz bobbing and the sleepers breathing
	if blink != _blink and not _sleepers.is_empty():
		_blink = blink
		queue_redraw()


func _draw() -> void:
	var frame: int = kiss_frame()
	for slot: int in _sleepers:
		if slot == _kiss_by and frame > 0:
			continue  # sitting up: drawn from the kiss frames below
		var side: int = clampi(slot, 1, 2) - 1
		# These sheets have no sleeping row; tuck the front-facing head under the covers.
		var head: Rect2 = Assets.player_head_frame(slot)
		var head_size: Vector2 = head.size * minf(18.0 / head.size.x, 13.0 / head.size.y)
		# Breathing slowly: each sleeper sinks a pixel into the pillow and back.
		var breath: float = 1.0 if int(Time.get_ticks_msec() / 1500.0 + side * 0.5) % 2 == 1 else 0.0
		var head_position := Vector2(-8 + side * 16 - head_size.x / 2.0, -19 - head_size.y + breath)
		draw_texture_rect_region(_heads[clampi(slot, 1, 2)], Rect2(head_position.round(), head_size), head)
	var level: int = GameState.home_level()
	var turned: int = TURNED[frame]
	if turned > 0:  # the covers slide down as they sit up
		draw_texture_rect_region(_turned[level], Rect2(-16, -19, 32, 19), Rect2((turned - 1) * 32, 0, 32, 19))
	else:
		draw_texture(_blankets[level], Vector2(-16, -19))
	if frame > 0:
		if frame >= 2:
			_draw_dent(level)
		draw_texture_rect_region(_kiss_sheets[_kiss_by], Rect2(KISS_ORIGIN, Vector2(KISS_SIZE, KISS_SIZE)), Rect2((frame - 1) * KISS_SIZE, 0, KISS_SIZE, KISS_SIZE))
	for slot: int in _sleepers:
		if _kiss_time >= 0.0 or _heart >= 0.0:
			break  # no snoring mid-kiss
		Effects.zzz(self, -8 + (clampi(slot, 1, 2) - 1) * 16 + 4, -40 - _blink % 2, 0.9)
	if _heart >= 0.0:  # popping up over their heads, floating away and fading
		var rise: float = _heart * 9.0
		var alpha: float = clampf(1.0 - maxf(_heart - 0.9, 0.0) / 0.9, 0.0, 1.0)
		Effects.heart(self, 5.0, -37.0 - rise, alpha)


## The hollow left in the pillow by a head that just lifted off it.
func _draw_dent(level: int) -> void:
	var pillow := Vector2(-13, -29) if level == 0 else Vector2(-12, -28)  # see bed() in tools/make_art.py
	var shadow := Color(0.42, 0.36, 0.5, 0.22)
	draw_rect(Rect2(pillow + Vector2(3, 2), Vector2(4, 1)), shadow)
	draw_rect(Rect2(pillow + Vector2(2, 3), Vector2(6, 1)), Color(shadow, 0.14))
	draw_rect(Rect2(pillow + Vector2(3, 4), Vector2(4, 1)), Color(shadow, 0.08))
