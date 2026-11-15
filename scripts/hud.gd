extends CanvasLayer
## Clock, energy, tool bar, the "what am I looking at" line, help card and
## messages. Sizes are in game units (320x180); the window scales them up, so
## text stays sharp.

const TOOL_NAMES: Array[String] = ["Hoe", "Water", "Seeds", "Pet", "Pick"]
const HELP_ROWS: Array = [
	["WASD", "Move"],
	["Space", "Use tool"],
	["1 - 5", "Choose tool"],
	["Q", "Change seed"],
	["Tent", "Sleep (Space)"],
	["H", "Hide this help"],
]
const INK := Color(0.11, 0.09, 0.17, 0.86)
const CREAM := Color(1.0, 0.97, 0.88)
const GOLD := Color(1.0, 0.84, 0.4)

var player: Node2D

var _root: Control
var _clock: Label
var _energy_fill: ColorRect
var _banner: Label
var _message: Label
var _inspect: Label
var _seed_line: Label
var _slots: Array[PanelContainer] = []
var _help: PanelContainer
var _help_status: Label
var _help_chosen: bool = false
var _fade: ColorRect
var _fade_label: Label
var _message_time: float = 0.0


func _ready() -> void:
	layer = 10
	var theme := Theme.new()
	theme.default_font_size = 8
	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: date and time.
	_clock = _text("")
	var clock_panel: PanelContainer = _panel(_clock)
	clock_panel.position = Vector2(4, 4)

	# Top right: energy.
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 4)
	energy_row.add_child(_text("Energy"))
	var bar := ColorRect.new()
	bar.color = Color(0.25, 0.22, 0.32)
	bar.custom_minimum_size = Vector2(50, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_fill = ColorRect.new()
	_energy_fill.size = Vector2(50, 6)
	bar.add_child(_energy_fill)
	energy_row.add_child(bar)
	var energy_panel: PanelContainer = _panel(energy_row)
	energy_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	energy_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	energy_panel.offset_left = -4
	energy_panel.offset_right = -4
	energy_panel.offset_top = 4
	energy_panel.offset_bottom = 4

	# Top centre: co-op status banner and short messages.
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 2)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.position.y = 34
	_banner = _text("")
	_banner.add_theme_color_override("font_color", GOLD)
	_centered(top, _banner)
	_message = _text("")
	_centered(top, _message)

	# Bottom centre: what you're facing, seed choice, tool bar.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 2)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y -= 4
	_inspect = _text("")
	_centered(bottom, _inspect)
	_seed_line = _text("")
	_centered(bottom, _seed_line)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 2)
	bar_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(bar_row)
	for i in TOOL_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var number: Label = _text(str(i + 1))
		number.add_theme_color_override("font_color", GOLD)
		row.add_child(number)
		row.add_child(_text(TOOL_NAMES[i]))
		var slot := PanelContainer.new()
		slot.add_child(row)
		bar_row.add_child(slot)
		_slots.append(slot)

	# Right: how to play.
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 1)
	var title: Label = _text("How to play")
	title.add_theme_color_override("font_color", GOLD)
	help_box.add_child(title)
	for entry: Array in HELP_ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var key: Label = _text(entry[0])
		key.custom_minimum_size.x = 30
		key.add_theme_color_override("font_color", GOLD)
		row.add_child(key)
		row.add_child(_text(entry[1]))
		help_box.add_child(row)
	_help_status = _text("")
	_help_status.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	help_box.add_child(_help_status)
	_help = _panel(help_box)
	_help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BOTH
	_help.position.x -= 4

	# Night fade.
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.06, 0.14)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)
	_fade_label = _text("")
	_fade_label.add_theme_font_size_override("font_size", 12)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_label.modulate.a = 0.0
	_root.add_child(_fade_label)

	TimeManager.time_changed.connect(_update_clock)
	GameState.energy_changed.connect(func(_id: int) -> void: _update_energy())
	GameState.inventory_changed.connect(_update_tool)
	GameState.state_reloaded.connect(refresh)
	GameState.sleepers_changed.connect(_update_banner)
	GameState.notice.connect(show_message)
	GameState.day_advanced.connect(_on_day_advanced)
	Net.player_joined.connect(func(_s: int) -> void: _update_banner())
	Net.player_left.connect(func(_s: int) -> void: _update_banner())
	if player != null:
		player.connect("loadout_changed", _update_tool)
	refresh()


func _text(content: String) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", CREAM)
	return label


func _style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.3, 0.25, 0.4, 0.95) if selected else INK
	box.set_corner_radius_all(2)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	if selected:
		box.set_border_width_all(1)
		box.border_color = GOLD
	return box


func _panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(false))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_root.add_child(panel)
	return panel


## Puts `label` in its own dark panel inside `box`; the panel hides when empty.
func _centered(box: VBoxContainer, label: Label) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(false))
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.visible = false
	box.add_child(panel)


func _set_line(label: Label, content: String) -> void:
	if label.text == content:
		return
	label.text = content
	var panel := label.get_parent() as Control
	panel.visible = content != ""
	panel.reset_size()


func _process(delta: float) -> void:
	if player != null:
		_set_line(_inspect, GameState.describe_cell(player.call("target_cell")))
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_set_line(_message, "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help_chosen = true
		_help.visible = not _help.visible


func show_message(content: String, seconds: float = 3.0) -> void:
	_set_line(_message, content)
	_message_time = seconds


## Shown at the bottom of the help card, e.g. the address a partner should join.
func set_status(content: String) -> void:
	_help_status.text = content
	_help_status.visible = content != ""
	_help.reset_size()


func refresh() -> void:
	_update_clock()
	_update_energy()
	_update_tool()
	_update_banner()
	set_status(_help_status.text)


func _update_clock() -> void:
	_clock.text = "%s %d, Year %d\n%s  %s" % [
		TimeManager.season_name(), TimeManager.day_of_season(), TimeManager.year(),
		TimeManager.time_string(), "Rainy" if TimeManager.raining else "Clear",
	]
	# The help card starts open on the very first day; H toggles it any time.
	if not _help_chosen:
		_help.visible = TimeManager.day_index == 0


func _update_energy() -> void:
	if player == null:
		return
	var e: int = GameState.get_energy(player.get("player_id"))
	_energy_fill.size.x = 50.0 * e / GameState.MAX_ENERGY
	_energy_fill.color = Color(0.5, 0.9, 0.45) if e > 25 else Color(0.95, 0.5, 0.3)


func _update_tool() -> void:
	if player == null:
		return
	var index: int = player.get("tool_index")
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _style(i == index))
	var line: String = ""
	if index == 2:
		var id: String = player.get("seed_id")
		line = "%s seeds x%d   (Q to change)" % [GameState.species[id].display_name, GameState.seed_count(id)]
	_set_line(_seed_line, line)


func _update_banner() -> void:
	var line: String = ""
	if player != null and Net.online:
		var me: int = player.get("player_id")
		var others_asleep: bool = false
		for slot: int in GameState.sleeping.keys():
			if slot != me:
				others_asleep = true
		if GameState.sleeping.has(me):
			line = "In bed, waiting for your partner  (Space: get up)"
		elif others_asleep:
			line = "Your partner is in bed, waiting for you"
	_set_line(_banner, line)


func _on_day_advanced(summary: Dictionary) -> void:
	var content: String = "%s %d" % [TimeManager.season_name(), TimeManager.day_of_season()]
	var dozers: Array = summary.get("passed_out", [])
	if player != null and dozers.has(player.get("player_id")):
		content = "You dozed off among the plants...\n" + content
	elif bool(summary.get("raining", false)):
		content += "\nIt's raining today"
	_fade_label.text = content
	_fade.modulate.a = 1.0
	_fade_label.modulate.a = 1.0
	if player != null:
		player.set("frozen", true)
	var tween: Tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_fade, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(_fade_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		if player != null:
			player.set("frozen", false))
