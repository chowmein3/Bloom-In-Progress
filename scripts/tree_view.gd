extends Node2D
## Draws the Heart Tree from assets/sprites/heart_tree.png (five 48x64 frames,
## one per stage). Origin is the bottom-centre of its patch of ground.

const Assets := preload("res://scripts/assets.gd")

const Effects := preload("res://scripts/effects.gd")
const FRAME := Vector2(48, 64)

var _texture: Texture2D = Assets.texture("res://assets/sprites/heart_tree.png")
var _hugs: int = 0
var _heart: float = 0.0
var _blink: int = 0


func _ready() -> void:
	_hugs = GameState.tree["hugged_by"].size()
	GameState.tree_changed.connect(_on_tree_changed)
	GameState.state_reloaded.connect(_on_tree_changed)


func _on_tree_changed() -> void:
	var hugs: int = GameState.tree["hugged_by"].size()
	if hugs > _hugs:
		_heart = 1.0
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.06, 0.96), 0.1)
		tween.tween_property(self, "scale", Vector2(0.97, 1.04), 0.12)
		tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	_hugs = hugs
	queue_redraw()


func _process(delta: float) -> void:
	var blink: int = int(Time.get_ticks_msec() / 650.0) % 2
	if _heart > 0.0:
		_heart -= delta
		queue_redraw()
	elif blink != _blink:
		_blink = blink
		queue_redraw()


func _draw() -> void:
	var stage: int = GameState.tree_stage()
	draw_texture_rect_region(_texture, Rect2(Vector2(-24, -62), FRAME), Rect2(Vector2(stage * FRAME.x, 0), FRAME))
	var top: float = [-24.0, -34.0, -46.0, -58.0, -66.0][stage]
	if _heart > 0.0:
		var rise: float = (1.0 - _heart) * 8.0
		var alpha: float = clampf(_heart * 2.0, 0.0, 1.0)
		Effects.heart(self, -5 if _hugs >= 2 else 0, top - rise, alpha)
		if _hugs >= 2:
			Effects.heart(self, 6, top - rise - 3, alpha)
	elif not bool(GameState.tree["watered"]):
		Effects.droplet(self, 0, top + 1 - _blink, 0.9)
