extends Node2D
## Draws one plant from the data in GameState.plants, using its sprite sheet
## at assets/sprites/plants/<species id>.png (16x24 frames: seed, growing
## stages, in bloom, radiant, resting). Origin is the bottom-centre of the tile.

const Assets := preload("res://scripts/assets.gd")

const Effects := preload("res://scripts/effects.gd")
const FRAME := Vector2(16, 24)
const DORMANT_TINT := Color(0.62, 0.6, 0.68)

static var _tops: Dictionary = {}  # "species:frame" -> icon height, worked out once

var cell: Vector2i
var _texture: Texture2D
var _bob: int = 0
var _heart: float = 0.0
var _splash: float = 0.0
var _phase: float = 0.0
var _was_watered: bool = false
var _blink: int = 0


func _ready() -> void:
	_phase = float(hash(cell) % 100) / 10.0
	if GameState.plants.has(cell):
		_texture = Assets.texture("res://assets/sprites/plants/%s.png" % GameState.plants[cell]["species"])
		_was_watered = bool(GameState.soil[cell]["watered"])


func _process(delta: float) -> void:
	if not GameState.plants.has(cell):
		return
	var redraw: bool = false
	if _heart > 0.0:
		_heart -= delta
		redraw = true
	if _splash > 0.0:
		_splash -= delta * 2.0
		redraw = true
	var now: float = Time.get_ticks_msec() / 1000.0
	var bob: int = 0
	if GameState.plant_is_mature(cell) and not bool(GameState.plants[cell]["dormant"]):
		bob = int(round(sin(now * 2.5 + _phase) * 0.6))
	var blink: int = int(now * 1.5 + _phase) % 2  # slow tick for the little icons
	if bob != _bob or blink != _blink:
		_bob = bob
		_blink = blink
		redraw = true
	if redraw:
		queue_redraw()


func refresh() -> void:
	if GameState.plants.has(cell):
		var watered: bool = bool(GameState.soil[cell]["watered"])
		if watered and not _was_watered:
			_splash = 1.0
		_was_watered = watered
	queue_redraw()


## Happy wiggle plus a floating heart.
func show_love() -> void:
	_heart = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "rotation", 0.2, 0.08)
	tween.tween_property(self, "rotation", -0.2, 0.12)
	tween.tween_property(self, "rotation", 0.1, 0.1)
	tween.tween_property(self, "rotation", 0.0, 0.1)


## Where a mood icon should sit for this frame of this plant's sheet: a few
## pixels above its topmost drawn pixel (plants differ a lot in height).
func _icon_height(species_id: String, frame: int) -> float:
	var key: String = "%s:%d" % [species_id, frame]
	if not _tops.has(key):
		var first_row: int = int(FRAME.y) - 4
		var image: Image = _texture.get_image()
		if image != null:
			for y in int(FRAME.y):
				var found: bool = false
				for x in int(FRAME.x):
					if image.get_pixel(frame * int(FRAME.x) + x, y).a > 0.1:
						found = true
						break
				if found:
					first_row = y
					break
		_tops[key] = -23.0 + first_row - 7.0
	return _tops[key]


func _draw() -> void:
	if not GameState.plants.has(cell) or _texture == null:
		return
	var p: Dictionary = GameState.plants[cell]
	var d: Resource = GameState.species[p["species"]]
	var stage: int = GameState.plant_stage(cell)
	var last: int = d.days_per_stage.size()
	var dormant: bool = bool(p["dormant"])
	var frame: int = mini(stage, last)
	if stage >= last:
		if d.regrows and not GameState.plant_is_ripe(cell):
			frame = last + 2  # resting after being picked
		elif GameState.plant_is_radiant(cell) and not dormant:
			frame = last + 1
	var tint: Color = DORMANT_TINT if dormant else Color.WHITE
	draw_texture_rect_region(_texture, Rect2(Vector2(-8, -23 - _bob), FRAME), Rect2(Vector2(frame * FRAME.x, 0), FRAME), tint)

	# Little mood icons above the plant.
	var top: float = _icon_height(str(p["species"]), frame) - _bob
	if _heart > 0.0:
		var rise: float = (1.0 - _heart) * 8.0
		var alpha: float = clampf(_heart * 2.0, 0.0, 1.0)
		if p["petted_by"].size() >= 2:  # a duet: both of you loved it today
			Effects.heart(self, -4, top - rise, alpha)
			Effects.note(self, 5, top - rise - 2, alpha)
		else:
			Effects.heart(self, 0, top - rise, alpha)
	elif dormant:
		Effects.zzz(self, 5, top + 2 - _blink, 0.85)
	elif not bool(GameState.soil[cell]["watered"]):
		Effects.droplet(self, 0, top + 1 - _blink, 0.9)
	if _splash > 0.0:
		var spread: float = (1.0 - _splash) * 7.0
		var blue := Color(0.6, 0.85, 1.0, _splash)
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(side * (2.0 + spread) - 1, -6 - spread * 0.8, 2, 2), blue)
			draw_rect(Rect2(side * (1.0 + spread * 0.5) - 1, -9 - spread, 1, 2), blue)
