extends Node2D
## The bed's covers, and whoever is tucked under them. The bed itself is part
## of the room picture; this draws sleepers' heads on the pillows (host on the
## left, partner on the right) and then the blanket over them.
## Origin is the bottom-centre of the bed.

const Assets := preload("res://scripts/assets.gd")
const Effects := preload("res://scripts/effects.gd")
const TILE := 16

var _blankets: Array[Texture2D] = []
var _heads: Dictionary = {}  # slot -> player sheet
var _sleepers: Array = []
var _blink: int = 0
## A goodnight kiss (sometimes, as the night falls): who leans over, how far
## (0-1), and how long the little heart has been floating (-1: none).
var _kiss_by: int = 0
var _lean: float = 0.0
var _heart: float = -1.0


func _ready() -> void:
	for level in GameState.ROOMS.size():
		_blankets.append(Assets.texture("res://assets/sprites/blanket_%d.png" % level))
	for slot in [1, 2]:
		_heads[slot] = Assets.player_texture(slot)
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
		_lean = 0.0
		_heart = -1.0
	queue_redraw()


## As the night begins to fall, one may lean over and kiss the other: a
## little heart floats up between them just as it happens.
func _on_bedtime(kiss_by: int) -> void:
	if kiss_by <= 0 or _sleepers.size() < 2:
		return
	_kiss_by = kiss_by
	var tween: Tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(self, "_lean", 1.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _heart = 0.0)
	tween.tween_interval(0.7)
	tween.tween_property(self, "_lean", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	if _heart >= 0.0:
		_heart += delta
		if _heart > 1.8:
			_heart = -1.0
	if _lean > 0.0 or _heart >= 0.0:
		queue_redraw()  # the kiss is happening
	var blink: int = int(Time.get_ticks_msec() / 750.0)  # the Zzz bobbing and the sleepers breathing
	if blink != _blink and not _sleepers.is_empty():
		_blink = blink
		queue_redraw()


func _draw() -> void:
	# The one leaning over for a kiss is drawn last, so their head is in front.
	var order: Array = _sleepers.duplicate()
	if order.has(_kiss_by):
		order.erase(_kiss_by)
		order.append(_kiss_by)
	var top: float = -19.0
	for slot: int in order:
		var side: int = clampi(slot, 1, 2) - 1
		# These sheets have no sleeping row; tuck the front-facing head under the covers.
		var head: Rect2 = Assets.player_head_frame(slot)
		var head_size: Vector2 = head.size * minf(18.0 / head.size.x, 13.0 / head.size.y)
		# Breathing slowly: each sleeper sinks a pixel into the pillow and back.
		var breath: float = 1.0 if int(Time.get_ticks_msec() / 1500.0 + side * 0.5) % 2 == 1 else 0.0
		var head_position := Vector2(-8 + side * 16 - head_size.x / 2.0, -19 - head_size.y + breath)
		if slot == _kiss_by:  # leaning over towards the other pillow, lifting a little
			head_position += Vector2((1.0 if side == 0 else -1.0) * 6.0, -2.0) * _lean
		top = minf(top, head_position.y)
		draw_texture_rect_region(_heads[clampi(slot, 1, 2)], Rect2(head_position.round(), head_size), head)
	draw_texture(_blankets[GameState.home_level()], Vector2(-16, -19))
	for slot: int in _sleepers:
		if _lean > 0.0 or _heart >= 0.0:
			break  # no snoring mid-kiss
		Effects.zzz(self, -8 + (clampi(slot, 1, 2) - 1) * 16 + 4, -40 - _blink % 2, 0.9)
	if _heart >= 0.0:  # floating up from between them, fading as it goes
		var rise: float = _heart * 9.0
		var alpha: float = clampf(1.0 - maxf(_heart - 0.9, 0.0) / 0.9, 0.0, 1.0)
		Effects.heart(self, 0.0, top - 4.0 - rise, alpha)
