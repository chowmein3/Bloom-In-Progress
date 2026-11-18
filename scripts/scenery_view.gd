extends Sprite2D
## A tree, bush, boulder, stump, log or fence from assets/sprites/scenery/,
## showing the frame for the current season (spring, summer, fall, winter).
## Its position is the bottom-centre of what it stands on.

const Assets := preload("res://scripts/assets.gd")

var kind: String = "oak"
var _season: int = -1


func _ready() -> void:
	texture = Assets.texture("res://assets/sprites/scenery/%s.png" % kind)
	hframes = 4
	centered = false
	var size := Vector2(texture.get_width() / 4.0, texture.get_height())
	# A log lies across two tiles, from its own tile to the right.
	offset = Vector2(-8, -size.y) if kind == "log" else Vector2(-size.x / 2.0, -size.y)
	TimeManager.time_changed.connect(_show_season)
	GameState.state_reloaded.connect(_show_season)
	_show_season()


func _show_season() -> void:
	var season: int = TimeManager.season()
	if season != _season:
		_season = season
		frame = season
