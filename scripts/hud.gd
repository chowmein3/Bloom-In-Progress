extends CanvasLayer
## The in-game HUD: minimap (top left, M), info box with date, time, weather
## and Heart Tree love (top right), energy bar (bottom right), icon tool bar
## (bottom), help card (H) and messages. Sizes are in game units (320x180);
## the window scales them up, so text stays sharp.

const Minimap := preload("res://scripts/minimap.gd")
const HELP_ROWS: Array = [
	["WASD", "Move"],
	["Space", "Use tool"],
	["1-5", "Choose tool"],
	["Q", "Change seed"],
	["Tent", "Sleep"],
	["J", "Journal"],
	["M", "Map"],
	["N", "Music"],
	["H", "Help"],
	["Esc", "Menu"],
]
const ICON := 12  # size of one frame in assets/sprites/ui_icons.png
const ICON_SUN := 5
const ICON_RAIN := 6
const ICON_SNOW := 7
const ICON_MOON := 8
const ICON_LOVE := 9
const PAPER := Color(0.98, 0.91, 0.74)
const SLOT := Color(0.93, 0.8, 0.58)
const WOOD := Color(0.42, 0.26, 0.15)
const INK := Color(0.3, 0.18, 0.12)
const ACCENT := Color(0.75, 0.28, 0.2)

var player: Node2D
var remote_players: Dictionary = {}  # shared with main.gd, for the minimap

var _root: Control
var _icons: Texture2D = load("res://assets/sprites/ui_icons.png")
var _map: PanelContainer
var _date: Label
var _time: Label
var _weather: TextureRect
var _love: Label
var _energy_fill: ColorRect
var _banner: Label
var _message: Label
var _inspect: Label
var _seed_line: Label
var _seed_count: Label
var _slots: Array[Panel] = []
var _help: PanelContainer
var _help_status: Label
var _help_chosen: bool = false
var _fade: ColorRect
var _fade_label: Label
var _message_time: float = 0.0


func _ready() -> void:
	layer = 10
	var theme := Theme.new()
	theme.default_font_size = 6
	_root = Control.new()
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Top left: minimap.
	var minimap := Minimap.new()
	minimap.player = player
	minimap.remote_players = remote_players
	_map = _panel(minimap, 1)
	_map.position = Vector2(3, 3)

	# Top right: date, time and weather, Heart Tree love.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", -1)
	_date = _text("")
	info.add_child(_date)
	_weather = _icon(ICON_SUN)
	_time = _text("")
	info.add_child(_row([_weather, _time]))
	_love = _text("")
	info.add_child(_row([_icon(ICON_LOVE), _love]))
	var info_panel: PanelContainer = _panel(info)
	_pin(info_panel, Control.PRESET_TOP_RIGHT, Vector2(-3, 3))

	# Bottom right: energy.
	var energy_box := VBoxContainer.new()
	energy_box.add_theme_constant_override("separation", 0)
	var e: Label = _text("E")
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_box.add_child(e)
	var bar := ColorRect.new()
	bar.color = Color(0.3, 0.2, 0.16)
	bar.custom_minimum_size = Vector2(5, 34)
	_energy_fill = ColorRect.new()
	bar.add_child(_energy_fill)
	energy_box.add_child(bar)
	var energy_panel: PanelContainer = _panel(energy_box, 1)
	_pin(energy_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-3, -3))

	# Top centre: co-op status banner and short messages.
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 1)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)
	_pin(top, Control.PRESET_CENTER_TOP, Vector2(0, 4))
	_banner = _text("")
	_banner.add_theme_color_override("font_color", ACCENT)
	_centered(top, _banner)
	_message = _text("")
	_centered(top, _message)

	# Bottom centre: what you're facing, seed choice, tool bar.
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 1)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom)
	_pin(bottom, Control.PRESET_CENTER_BOTTOM, Vector2(0, -3))
	_inspect = _text("")
	_centered(bottom, _inspect)
	_seed_line = _text("")
	_centered(bottom, _seed_line)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 1)
	for i in 5:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(16, 16)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture: TextureRect = _icon(i)
		picture.position = Vector2(2, 3)
		slot.add_child(picture)
		var number: Label = _text(str(i + 1))
		number.add_theme_font_size_override("font_size", 5)
		number.add_theme_color_override("font_color", ACCENT)
		number.position = Vector2(2, -1)
		slot.add_child(number)
		if i == 2:
			_seed_count = _text("")
			_seed_count.add_theme_font_size_override("font_size", 5)
			_seed_count.add_theme_color_override("font_color", Color.WHITE)
			_seed_count.add_theme_color_override("font_outline_color", INK)
			_seed_count.add_theme_constant_override("outline_size", 3)
			_seed_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_seed_count.position = Vector2(0, 8)
			_seed_count.size = Vector2(15, 8)
			slot.add_child(_seed_count)
		bar_row.add_child(slot)
		_slots.append(slot)
	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", _style(PAPER, 2))
	bar_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_panel.add_child(bar_row)
	bottom.add_child(bar_panel)

	# Left, under the map: how to play.
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", -2)
	for entry: Array in HELP_ROWS:
		var key: Label = _text(entry[0])
		key.custom_minimum_size.x = 20
		key.add_theme_color_override("font_color", ACCENT)
		help_box.add_child(_row([key, _text(entry[1])]))
	_help_status = _text("")
	_help_status.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	help_box.add_child(_help_status)
	_help = _panel(help_box)
	_help.position = Vector2(3, 46)

	# Night fade.
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.06, 0.14)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)
	_fade_label = Label.new()
	_fade_label.add_theme_color_override("font_color", PAPER)
	_fade_label.add_theme_font_size_override("font_size", 9)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_label.modulate.a = 0.0
	_root.add_child(_fade_label)

	TimeManager.time_changed.connect(_update_clock)
	GameState.energy_changed.connect(func(_id: int) -> void: _update_energy())
	GameState.inventory_changed.connect(_update_tool)
	GameState.tree_changed.connect(_update_love)
	GameState.state_reloaded.connect(refresh)
	GameState.sleepers_changed.connect(_update_banner)
	GameState.notice.connect(show_message)
	GameState.day_advanced.connect(_on_day_advanced)
	Net.player_joined.connect(func(_s: int) -> void: _update_banner())
	Net.player_left.connect(func(_s: int) -> void: _update_banner())
	if player != null:
		player.connect("loadout_changed", _update_tool)
	refresh()


# ----------------------------------------------------------------- pieces

func _text(content: String) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_color_override("font_color", INK)
	return label


## One frame of the icon sheet.
func _icon(index: int) -> TextureRect:
	var frame := AtlasTexture.new()
	frame.atlas = _icons
	frame.region = Rect2(index * ICON, 0, ICON, ICON)
	var picture := TextureRect.new()
	picture.texture = frame
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	picture.custom_minimum_size = Vector2(ICON, ICON - 2)
	picture.size = Vector2(ICON, ICON)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for child: Control in children:
		row.add_child(child)
	return row


## A parchment box with a wooden edge.
func _style(fill: Color, margin: int = 3, edge: Color = WOOD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(1)
	box.set_border_width_all(1)
	box.border_color = edge
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = mini(margin, 1)
	box.content_margin_bottom = mini(margin, 1)
	return box


func _panel(content: Control, margin: int = 3) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PAPER, margin))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	_root.add_child(panel)
	return panel


## Anchors `control` to a corner or edge of the screen, `nudge` units inwards,
## growing away from that edge as its content changes.
func _pin(control: Control, preset: Control.LayoutPreset, nudge: Vector2) -> void:
	control.set_anchors_and_offsets_preset(preset)
	var right: bool = preset == Control.PRESET_TOP_RIGHT or preset == Control.PRESET_BOTTOM_RIGHT
	var bottom: bool = preset == Control.PRESET_BOTTOM_RIGHT or preset == Control.PRESET_CENTER_BOTTOM
	var centre: bool = preset == Control.PRESET_CENTER_TOP or preset == Control.PRESET_CENTER_BOTTOM
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH if centre else (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	control.offset_left = nudge.x
	control.offset_right = nudge.x
	control.offset_top = nudge.y
	control.offset_bottom = nudge.y


## Puts `label` in its own box inside `box`; the box hides when empty.
func _centered(box: VBoxContainer, label: Label) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PAPER))
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


# ---------------------------------------------------------------- updates

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
	elif event.is_action_pressed("toggle_map"):
		_map.visible = not _map.visible
		_help.position.y = 46 if _map.visible else 3


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
	_update_love()
	_update_banner()
	set_status(_help_status.text)


func _update_clock() -> void:
	_date.text = "%s %d" % [TimeManager.season_name(), TimeManager.day_of_season()]
	_time.text = TimeManager.time_string()
	var picture: int = ICON_SUN
	if TimeManager.raining:
		picture = ICON_RAIN
	elif TimeManager.minutes >= 20 * 60:
		picture = ICON_MOON
	elif TimeManager.season() == 3:
		picture = ICON_SNOW
	(_weather.texture as AtlasTexture).region.position.x = picture * ICON
	# The help card starts open on the very first day; H toggles it any time.
	if not _help_chosen:
		_help.visible = TimeManager.day_index == 0


func _update_love() -> void:
	var goal: int = GameState.tree_next_goal()
	_love.text = "%d/%d" % [int(GameState.tree["love"]), goal] if goal > 0 else str(int(GameState.tree["love"]))


func _update_energy() -> void:
	if player == null:
		return
	var e: int = GameState.get_energy(player.get("player_id"))
	var height: float = 34.0 * e / GameState.MAX_ENERGY
	_energy_fill.position = Vector2(0, 34.0 - height)
	_energy_fill.size = Vector2(5, height)
	_energy_fill.color = Color(0.36, 0.8, 0.36) if e > 25 else Color(0.95, 0.5, 0.3)


func _update_tool() -> void:
	if player == null:
		return
	var index: int = player.get("tool_index")
	for i in _slots.size():
		var chosen: bool = i == index
		_slots[i].add_theme_stylebox_override("panel", _style(Color(1.0, 0.95, 0.8) if chosen else SLOT, 0, ACCENT if chosen else WOOD))
	var id: String = player.get("seed_id")
	_seed_count.text = str(GameState.seed_count(id))
	_set_line(_seed_line, "%s seeds  (Q: change)" % GameState.species[id].display_name if index == 2 else "")


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
	var extra: Array = []
	var tree_news: Dictionary = summary.get("tree", {})
	if not tree_news.is_empty():
		extra.append("The Heart Tree grew into a %s!" % GameState.TREE_STAGE_NAMES[int(tree_news["stage"])])
		if str(tree_news.get("gifts", "")) != "":
			extra.append("It dropped %s" % tree_news["gifts"])
	for line: String in summary.get("discoveries", []):
		extra.append(line)
	if not extra.is_empty():
		content += "\n\n" + "\n".join(extra)
	_fade_label.text = content
	_fade.modulate.a = 1.0
	_fade_label.modulate.a = 1.0
	if player != null:
		player.set("frozen", true)
	var tween: Tween = create_tween()
	tween.tween_interval(1.0 + 0.8 * extra.size())  # longer when there is news to read
	tween.tween_property(_fade, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(_fade_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		if player != null:
			player.set("frozen", false))
