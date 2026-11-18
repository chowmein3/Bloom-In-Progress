extends Sprite2D
## A tree, bush, boulder, stump, log or fence from assets/sprites/scenery/,
## showing the frame for the current season (spring, summer, fall, winter).
## Its position is the bottom-centre of what it stands on. Every one is in
## the "scenery" group; border_view.gd tells the group when the season turns.

const Assets := preload("res://scripts/assets.gd")

## How tall each whole tree is, so its top alone can sit at the same height.
const TREE_HEIGHT: Dictionary = {"oak": 44, "maple": 48, "birch": 46, "cherry": 44, "pine": 48, "apple": 44}

var kind: String = "oak"


func _ready() -> void:
	texture = Assets.texture("res://assets/sprites/scenery/%s.png" % kind)
	hframes = 4
	centered = false
	var size := Vector2(texture.get_width() / 4.0, texture.get_height())
	# A log lies across two tiles, from its own tile to the right. A tree top
	# sits where the whole tree's leaves would be, its trunk hidden below.
	offset = Vector2(-8, -size.y) if kind == "log" else Vector2(-size.x / 2.0, -size.y)
	if kind.ends_with("_crown"):
		offset.y = -float(TREE_HEIGHT[kind.trim_suffix("_crown")])
	add_to_group("scenery")
	show_season()


func show_season() -> void:
	frame = TimeManager.season()
