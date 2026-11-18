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


func _ready() -> void:
	for level in GameState.ROOMS.size():
		_blankets.append(Assets.texture("res://assets/sprites/blanket_%d.png" % level))
	for slot in [1, 2]:
		_heads[slot] = Assets.player_texture(slot)
	GameState.sleepers_changed.connect(_refresh)
	GameState.economy_changed.connect(_refresh)
	GameState.state_reloaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var bed: Rect2i = GameState.bed_rect()
	position = Vector2((bed.position.x + 1) * TILE, bed.end.y * TILE)
	_sleepers = GameState.sleeping.keys()
	queue_redraw()


func _process(_delta: float) -> void:
	var blink: int = int(Time.get_ticks_msec() / 700.0) % 2
	if blink != _blink and not _sleepers.is_empty():
		_blink = blink
		queue_redraw()


func _draw() -> void:
	for slot: int in _sleepers:
		var side: int = clampi(slot, 1, 2) - 1
		# These sheets have no sleeping row; tuck the front-facing head under the covers.
		var head: Rect2 = Assets.player_head_frame(slot)
		var head_size: Vector2 = head.size * minf(18.0 / head.size.x, 13.0 / head.size.y)
		var head_position := Vector2(-8 + side * 16 - head_size.x / 2.0, -19 - head_size.y)
		draw_texture_rect_region(_heads[clampi(slot, 1, 2)], Rect2(head_position, head_size), head)
	draw_texture(_blankets[GameState.home_level()], Vector2(-16, -19))
	for slot: int in _sleepers:
		Effects.zzz(self, -8 + (clampi(slot, 1, 2) - 1) * 16 + 4, -40 - _blink, 0.9)
