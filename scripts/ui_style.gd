extends RefCounted
## The shared parchment-and-wood look for pop-up screens (backpack, shop).

const PAPER := Color(0.98, 0.91, 0.74)
const SLOT := Color(0.93, 0.8, 0.58)
const WOOD := Color(0.42, 0.26, 0.15)
const INK := Color(0.3, 0.18, 0.12)
const ACCENT := Color(0.75, 0.28, 0.2)
const FAINT := Color(0.55, 0.42, 0.32)


static func box(fill: Color, edge: Color = WOOD, margin: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(1)
	style.set_border_width_all(1)
	style.border_color = edge
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = mini(margin, 1)
	style.content_margin_bottom = mini(margin, 1)
	return style


static func theme(font_size: int = 6) -> Theme:
	var look := Theme.new()
	look.default_font_size = font_size
	look.set_color("font_color", "Label", INK)
	look.set_stylebox("normal", "Button", box(SLOT))
	look.set_stylebox("hover", "Button", box(Color(1.0, 0.95, 0.8)))
	look.set_stylebox("pressed", "Button", box(Color(0.85, 0.7, 0.48)))
	look.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
	look.set_stylebox("disabled", "Button", box(Color(0.9, 0.84, 0.72), Color(0.7, 0.6, 0.5)))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		look.set_color(state, "Button", INK)
	look.set_color("font_disabled_color", "Button", Color(0.62, 0.52, 0.44))
	return look


## A full-screen dim with a centred parchment panel; returns the panel.
static func popup(root: Control, dim: float = 0.5) -> PanelContainer:
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.14, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var panel := PanelContainer.new()
	var style: StyleBoxFlat = box(PAPER)
	style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	return panel


static func label(text: String, color: Color = INK, font_size: int = 0) -> Label:
	var made := Label.new()
	made.text = text
	made.add_theme_color_override("font_color", color)
	if font_size > 0:
		made.add_theme_font_size_override("font_size", font_size)
	return made


## A picture cut out of a sprite sheet.
static func picture(sheet: Texture2D, region: Rect2) -> TextureRect:
	var frame := AtlasTexture.new()
	frame.atlas = sheet
	frame.region = region
	var shown := TextureRect.new()
	shown.texture = frame
	shown.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	shown.custom_minimum_size = region.size
	shown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shown


static func spacer() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return gap
