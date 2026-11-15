extends RefCounted
## Tiny pixel icons shared by the plant and Heart Tree views. Each draws onto
## `node` (call from its _draw) centred on x, with its top at y.

const DARK := Color(0.2, 0.14, 0.23)


static func heart(node: CanvasItem, x: float, y: float, alpha: float = 1.0) -> void:
	var red := Color(1, 0.4, 0.55, alpha)
	node.draw_rect(Rect2(x - 3, y, 2, 1), red)
	node.draw_rect(Rect2(x + 1, y, 2, 1), red)
	node.draw_rect(Rect2(x - 3, y + 1, 6, 2), red)
	node.draw_rect(Rect2(x - 2, y + 3, 4, 1), red)
	node.draw_rect(Rect2(x - 1, y + 4, 2, 1), red)
	node.draw_rect(Rect2(x - 2, y + 1, 1, 1), Color(1, 0.8, 0.85, alpha))


static func droplet(node: CanvasItem, x: float, y: float, alpha: float = 1.0) -> void:
	var blue := Color(0.45, 0.75, 1.0, alpha)
	node.draw_rect(Rect2(x - 2, y - 1, 4, 5), Color(DARK, alpha))
	node.draw_rect(Rect2(x - 1, y - 2, 2, 1), Color(DARK, alpha))
	node.draw_rect(Rect2(x - 1, y - 1, 2, 4), blue)
	node.draw_rect(Rect2(x - 1, y + 1, 1, 1), Color(0.85, 0.95, 1.0, alpha))


static func zzz(node: CanvasItem, x: float, y: float, alpha: float = 1.0) -> void:
	var c := Color(0.92, 0.92, 1.0, alpha)
	node.draw_rect(Rect2(x - 2, y, 4, 1), c)
	node.draw_rect(Rect2(x, y + 1, 1, 1), c)
	node.draw_rect(Rect2(x - 1, y + 2, 1, 1), c)
	node.draw_rect(Rect2(x - 2, y + 3, 4, 1), c)


static func note(node: CanvasItem, x: float, y: float, alpha: float = 1.0) -> void:
	var c := Color(1.0, 0.88, 0.45, alpha)
	node.draw_rect(Rect2(x, y, 1, 5), c)
	node.draw_rect(Rect2(x + 1, y, 2, 2), c)
	node.draw_rect(Rect2(x - 2, y + 4, 3, 2), c)
