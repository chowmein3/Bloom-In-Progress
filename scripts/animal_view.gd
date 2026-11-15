extends Node2D
## One chicken or cow standing on its spot. Shows a droplet-like "hungry"
## mark until fed, and a heart when petted. Origin: bottom-centre of the tile.

const Assets := preload("res://scripts/assets.gd")
const Effects := preload("res://scripts/effects.gd")

var index: int = 0
var _texture: Texture2D
var _pets: int = 0
var _heart: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	var kind: String = GameState.animals[index]["kind"]
	_texture = Assets.texture("res://assets/sprites/items/%s.png" % kind)
	_pets = GameState.animals[index]["petted_by"].size()
	_phase = index * 1.7


func refresh() -> void:
	if index >= GameState.animals.size():
		return
	var pets: int = GameState.animals[index]["petted_by"].size()
	if pets > _pets:
		_heart = 1.0
	_pets = pets
	queue_redraw()


func _process(delta: float) -> void:
	if _heart > 0.0:
		_heart -= delta
	queue_redraw()


func _draw() -> void:
	if index >= GameState.animals.size():
		return
	var hop: float = absf(sin(Time.get_ticks_msec() / 500.0 + _phase)) * 1.5
	draw_rect(Rect2(-5, -2, 10, 2), Color(0, 0, 0, 0.15))
	draw_texture(_texture, Vector2(-8, -16 - hop))
	if _heart > 0.0:
		Effects.heart(self, 0, -24 - (1.0 - _heart) * 8.0, clampf(_heart * 2.0, 0.0, 1.0))
	elif not bool(GameState.animals[index]["fed"]):
		draw_rect(Rect2(-1, -24, 2, 4), Color(0.95, 0.75, 0.3))  # a hungry "!"
		draw_rect(Rect2(-1, -19, 2, 2), Color(0.95, 0.75, 0.3))
