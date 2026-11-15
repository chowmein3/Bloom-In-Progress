extends CanvasLayer
## The shared garden journal (J): the Heart Tree's progress and one entry per
## plant, filled in as the garden discovers it.

const PAPER := Color(0.98, 0.91, 0.74)
const WOOD := Color(0.42, 0.26, 0.15)
const CREAM := Color(0.3, 0.18, 0.12)  # main text
const GOLD := Color(0.75, 0.28, 0.2)  # headings and earned milestones
const DIM := Color(0.55, 0.42, 0.32)
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
const MILESTONES: Array[String] = ["Planted", "Bloomed", "Radiant"]

var player: Node2D

var _root: Control
var _tree_label: Label
var _tree_fill: ColorRect
var _grid: GridContainer


func _ready() -> void:
	layer = 15
	visible = false
	var theme := Theme.new()
	theme.default_font_size = 7
	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = WOOD
	style.set_content_margin_all(5)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	var title: Label = _text("Garden Journal", GOLD)
	title.add_theme_font_size_override("font_size", 10)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_text("J or Esc to close", DIM))
	box.add_child(header)

	var tree_row := HBoxContainer.new()
	tree_row.add_theme_constant_override("separation", 5)
	_tree_label = _text("", CREAM)
	tree_row.add_child(_tree_label)
	var bar := ColorRect.new()
	bar.color = Color(0.82, 0.7, 0.52)
	bar.custom_minimum_size = Vector2(80, 5)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tree_fill = ColorRect.new()
	_tree_fill.color = Color(1.0, 0.56, 0.7)
	_tree_fill.size = Vector2(0, 5)
	bar.add_child(_tree_fill)
	tree_row.add_child(bar)
	box.add_child(tree_row)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 3)
	box.add_child(_grid)

	GameState.journal_changed.connect(_rebuild)
	GameState.tree_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)


func _text(content: String, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", color)
	return label


func _unhandled_input(event: InputEvent) -> void:
	if player == null or bool(player.get("in_menu")):
		return
	if event.is_action_pressed("toggle_journal") or (visible and event.is_action_pressed("close")):
		visible = not visible
		player.set("reading", visible)
		Sound.play("page")
		if visible:
			_rebuild()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if not visible:
		return
	var goal: int = GameState.tree_next_goal()
	var love: int = int(GameState.tree["love"])
	var stage: int = GameState.tree_stage()
	if goal > 0:
		var from: int = GameState.TREE_STAGE_LOVE[stage]
		_tree_label.text = "%s   love %d / %d" % [GameState.TREE_STAGE_NAMES[stage], love, goal]
		_tree_fill.size.x = 80.0 * (love - from) / (goal - from)
	else:
		_tree_label.text = "%s   fully grown, love %d" % [GameState.TREE_STAGE_NAMES[stage], love]
		_tree_fill.size.x = 80.0

	for child: Node in _grid.get_children():
		child.queue_free()
	for id: String in GameState.species.keys():
		_grid.add_child(_entry(id))


func _entry(id: String) -> Control:
	var d: Resource = GameState.species[id]
	var level: int = GameState.journal_level(id)
	var known: bool = level >= GameState.JOURNAL_PLANTED
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(142, 0)

	# The bloom frame of its sprite sheet; a dark shape until it has bloomed.
	var icon := TextureRect.new()
	var frame := AtlasTexture.new()
	frame.atlas = load("res://assets/sprites/plants/%s.png" % id)
	frame.region = Rect2(d.days_per_stage.size() * 16, 0, 16, 24)
	icon.texture = frame
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(16, 24)
	if level < GameState.JOURNAL_BLOOMED:
		icon.modulate = Color(0.3, 0.18, 0.12, 0.55)
	row.add_child(icon)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", -1)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 3)
	top.add_child(_text(d.display_name if known else "? ? ?", GOLD if known else DIM))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	for i in MILESTONES.size():  # three pips: planted, bloomed, radiant
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(4, 4)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = GOLD if level > i else Color(0.82, 0.7, 0.52)
		pip.tooltip_text = MILESTONES[i]
		top.add_child(pip)
	lines.add_child(top)

	var seasons: Array = []
	for s: int in d.seasons:
		seasons.append(SEASONS[s])
	var facts: String = "%s, %d days" % [" & ".join(seasons), d.total_days()]
	if d.regrows:
		facts += ", regrows"
	lines.add_child(_text(facts if known else "Not planted yet", CREAM if known else DIM))
	var note: String = "Help it bloom to learn more"
	if level >= GameState.JOURNAL_BLOOMED:
		note = d.blurb
	elif not known:
		note = "A gift from the Heart Tree, perhaps" if GameState.seed_count(id) == 0 else "You have seeds for this one"
	var blurb: Label = _text(note, DIM)
	blurb.add_theme_font_size_override("font_size", 6)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(118, 0)
	lines.add_child(blurb)
	row.add_child(lines)
	return row
