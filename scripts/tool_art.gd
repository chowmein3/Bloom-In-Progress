extends RefCounted
## Where each tool (Player.TOOLS) is drawn in assets/sprites/tools.png:
## 16x16, columns hoe, can, seed bag, rod, pickaxe, axe (the item slot has no
## picture), rows by upgrade tier for the hoe and can. Every tool's grip is at
## pixel (3, 13) (3, 9 when small), so the player's hands can hold it there.

const COLUMNS: Array[int] = [0, 1, 2, -1, 3, 4, 5]
const GRIP := Vector2(3, 13)
## assets/sprites/tools_held.png: the same tools at 12x12 for the hands.
const HELD := 12
const HELD_GRIP := Vector2(3, 9)


static func frame(index: int) -> Rect2:
	var column: int = COLUMNS[clampi(index, 0, COLUMNS.size() - 1)]
	var tier: int = 0
	if index == 0:
		tier = GameState.upgrade_level("hoe")
	elif index == 1:
		tier = GameState.upgrade_level("can")
	return Rect2(column * 16, mini(tier, 2) * 16, 16, 16)


## The smaller picture of tool `index` held in the hands.
static func held_frame(index: int) -> Rect2:
	var big: Rect2 = frame(index)
	return Rect2(big.position / 16.0 * HELD, Vector2(HELD, HELD))
