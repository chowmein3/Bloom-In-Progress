extends Node2D
## Draws one plant from the data in GameState.plants (placeholder art).
## Origin is the bottom-centre of the plant's tile.

const DARK := Color(0.16, 0.12, 0.2)
const DORMANT_TINT := Color(0.55, 0.5, 0.45)

var cell: Vector2i
var _bob: int = 0
var _heart: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	_phase = float(hash(cell) % 100) / 10.0


func _process(delta: float) -> void:
	if not GameState.plants.has(cell):
		return
	if _heart > 0.0:
		_heart -= delta
		queue_redraw()
	var bob: int = 0
	if GameState.plant_is_mature(cell) and not bool(GameState.plants[cell]["dormant"]):
		bob = int(round(sin(Time.get_ticks_msec() / 400.0 + _phase) * 0.6))
	if bob != _bob:
		_bob = bob
		queue_redraw()


func refresh() -> void:
	queue_redraw()


## Happy wiggle plus a floating heart.
func show_love() -> void:
	_heart = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation", 0.2, 0.08)
	tween.tween_property(self, "rotation", -0.2, 0.12)
	tween.tween_property(self, "rotation", 0.1, 0.1)
	tween.tween_property(self, "rotation", 0.0, 0.1)


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _draw() -> void:
	if not GameState.plants.has(cell):
		return
	var p: Dictionary = GameState.plants[cell]
	var d: Resource = GameState.species[p["species"]]
	var stage: int = GameState.plant_stage(cell)
	var last: int = d.days_per_stage.size()
	var dormant: bool = bool(p["dormant"])
	var radiant: bool = GameState.plant_is_radiant(cell)
	var ripe: bool = GameState.plant_is_ripe(cell)
	var leaf: Color = d.leaf_color
	var bloom: Color = d.radiant_color if radiant else d.bloom_color
	if dormant:
		leaf = leaf.lerp(DORMANT_TINT, 0.6)
		bloom = bloom.lerp(DORMANT_TINT, 0.6)

	if stage == 0:
		_px(-3, -5, 2, 2, Color(0.9, 0.82, 0.6))
		_px(1, -3, 2, 2, Color(0.9, 0.82, 0.6))
	elif stage < last:
		var h: int = 2 + stage * 3
		_px(-1, -h - 1, 2, h, leaf)
		_px(-3, -h, 2, 2, leaf.lightened(0.15))
		_px(1, -h + 1, 2, 2, leaf.lightened(0.15))
		if stage == last - 1:
			_px(-2, -h - 4, 4, 3, bloom.darkened(0.25))  # bud
	else:
		var b: int = -_bob
		var happy: bool = int(p["happiness"]) >= 50
		match d.shape:
			"mushroom":
				_px(-2, -7, 4, 6, Color(0.95, 0.9, 0.8))
				_px(-6, -12 + b, 12, 5, bloom)
				_px(-4, -14 + b, 8, 2, bloom)
				_px(-4, -11 + b, 2, 2, Color.WHITE)
				_px(2, -13 + b, 2, 2, Color.WHITE)
				_face(-2, -6, happy, dormant)
			"bush":
				_px(-6, -11 + b, 12, 10, leaf)
				_px(-4, -13 + b, 8, 2, leaf)
				_px(-5, -10 + b, 3, 2, leaf.lightened(0.15))
				if ripe:
					_px(-5, -6 + b, 2, 2, bloom)
					_px(3, -9 + b, 2, 2, bloom)
					_px(0, -12 + b, 2, 2, bloom)
				_face(-2, -8 + b, happy, dormant)
			_:
				_px(-1, -10, 2, 9, leaf)
				_px(-4, -6, 3, 2, leaf.lightened(0.15))
				_px(1, -8, 3, 2, leaf.lightened(0.15))
				_px(-4, -18 + b, 8, 8, bloom)
				_px(-5, -16 + b, 10, 4, bloom)
				_px(-2, -17 + b, 4, 6, bloom.lightened(0.25))
				_face(-2, -15 + b, happy, dormant)
		if radiant and not dormant:
			var tick: int = int(Time.get_ticks_msec() / 400.0 + _phase) % 2
			_px(-7 + tick * 2, -17, 1, 1, Color.WHITE)
			_px(6 - tick * 2, -12, 1, 1, Color.WHITE)
			_px(-6, -8 - tick * 2, 1, 1, Color.WHITE)

	if _heart > 0.0:
		var hy: int = -24 - int((1.0 - _heart) * 8.0)
		var red := Color(1, 0.35, 0.5, clampf(_heart * 2.0, 0.0, 1.0))
		_px(-3, hy, 2, 1, red)
		_px(1, hy, 2, 1, red)
		_px(-3, hy + 1, 6, 2, red)
		_px(-2, hy + 3, 4, 1, red)
		_px(-1, hy + 4, 2, 1, red)


## Two eyes and a mouth, 4px wide starting at (x, y).
func _face(x: int, y: int, happy: bool, asleep: bool) -> void:
	if asleep:
		_px(x, y + 1, 1, 1, DARK)
		_px(x + 3, y + 1, 1, 1, DARK)
		return
	_px(x, y, 1, 2, DARK)
	_px(x + 3, y, 1, 2, DARK)
	if happy:
		_px(x + 1, y + 3, 2, 1, DARK)
