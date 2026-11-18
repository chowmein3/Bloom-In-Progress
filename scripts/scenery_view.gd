extends Sprite2D
## A tree, bush, boulder, stump, log or fence from assets/sprites/scenery/,
## showing the frame for the current season (spring, summer, fall, winter).
## Its position is the bottom-centre of what it stands on. Every one is in
## the "scenery" group; border_view.gd tells the group when the season turns.

const Assets := preload("res://scripts/assets.gd")

var kind: String = "oak"


func _ready() -> void:
	texture = Assets.texture("res://assets/sprites/scenery/%s.png" % kind)
	hframes = 4
	centered = false
	var size := Vector2(texture.get_width() / 4.0, texture.get_height())
	# A log lies across two tiles, from its own tile to the right.
	offset = Vector2(-8, -size.y) if kind == "log" else Vector2(-size.x / 2.0, -size.y)
	add_to_group("scenery")
	show_season()


func show_season() -> void:
	frame = TimeManager.season()


## Hit by the axe: a quick shiver.
func shake() -> void:
	var home: float = position.x
	var tween: Tween = create_tween()
	for i in 4:
		tween.tween_property(self, "position:x", home + (2.0 if i % 2 == 0 else -2.0) * (1.0 - i * 0.2), 0.04)
	tween.tween_property(self, "position:x", home, 0.04)


## Cut down: a tree topples over (to the right or left) from its foot, bounces
## and fades; a stump or log breaks apart. Returns the seconds until it is
## down, when the wood it leaves should appear.
func fall(to_right: bool) -> float:
	remove_from_group("scenery")
	var tween: Tween = create_tween()
	if kind == "stump" or kind == "log":
		tween.tween_property(self, "scale", Vector2(1.2, 0.3), 0.25).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
		tween.tween_callback(queue_free)
		return 0.25
	var side: float = 1.0 if to_right else -1.0
	tween.tween_property(self, "rotation", side * 0.08, 0.15)  # a creak first
	tween.tween_property(self, "rotation", side * PI / 2.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", side * (PI / 2.0 - 0.12), 0.08)  # bounce
	tween.tween_property(self, "rotation", side * PI / 2.0, 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
	return 0.8
