extends CanvasLayer
## Clock, energy, current tool, the "what am I looking at" line and messages.

var player: Node2D

var _root: Control
var _clock: Label
var _tool: Label
var _inspect: Label
var _hint: Label
var _message: Label
var _energy_fill: ColorRect
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

	_clock = _label(Vector2(4, 2))
	_tool = _label(Vector2(4, 166))
	_inspect = _label(Vector2(4, 154))
	_hint = _label(Vector2(4, 14))
	_hint.modulate = Color(1, 1, 1, 0.75)
	_hint.text = "Move WASD   Use Space   Tools 1-5   Seed Q"
	_message = _label(Vector2(0, 80))
	_message.size = Vector2(320, 12)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.1, 0.08, 0.14, 0.8)
	bar_bg.position = Vector2(262, 4)
	bar_bg.size = Vector2(54, 7)
	_root.add_child(bar_bg)
	_energy_fill = ColorRect.new()
	_energy_fill.color = Color(0.5, 0.9, 0.45)
	_energy_fill.position = Vector2(263, 5)
	_energy_fill.size = Vector2(52, 5)
	_root.add_child(_energy_fill)

	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.06, 0.14)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_root.add_child(_fade)
	_fade_label = _label(Vector2(0, 80))
	_fade_label.size = Vector2(320, 24)
	_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fade_label.modulate.a = 0.0

	TimeManager.time_changed.connect(_update_clock)
	GameState.energy_changed.connect(func(_id: int) -> void: _update_energy())
	GameState.inventory_changed.connect(_update_tool)
	GameState.state_reloaded.connect(_update_all)
	GameState.notice.connect(show_message)
	GameState.day_advanced.connect(_on_day_advanced)
	if player != null:
		player.connect("loadout_changed", _update_tool)
	_update_all()


func _label(pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.14))
	label.add_theme_constant_override("outline_size", 3)
	_root.add_child(label)
	return label


func _process(delta: float) -> void:
	if player != null:
		_inspect.text = GameState.describe_cell(player.call("target_cell"))
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)


func show_message(text: String) -> void:
	_message.text = text
	_message_time = 2.5


func _update_all() -> void:
	_update_clock()
	_update_energy()
	_update_tool()


func _update_clock() -> void:
	_clock.text = "%s %d, Year %d   %s%s" % [
		TimeManager.season_name(), TimeManager.day_of_season(), TimeManager.year(),
		TimeManager.time_string(), "   Rain" if TimeManager.raining else "",
	]
	# The controls hint is only needed on the very first morning.
	_hint.visible = TimeManager.day_index == 0


func _update_energy() -> void:
	if player == null:
		return
	var e: int = GameState.get_energy(player.get("player_id"))
	_energy_fill.size.x = 52.0 * e / GameState.MAX_ENERGY
	_energy_fill.color = Color(0.5, 0.9, 0.45) if e > 25 else Color(0.95, 0.5, 0.3)


func _update_tool() -> void:
	if player == null:
		return
	var index: int = player.get("tool_index")
	var text: String = "[%d] %s" % [index + 1, player.get("TOOLS")[index]]
	if index == 2:
		var id: String = player.get("seed_id")
		text += ": %s x%d" % [GameState.species[id].display_name, GameState.seed_count(id)]
	_tool.text = text


func _on_day_advanced(summary: Dictionary) -> void:
	var text: String = "%s %d" % [TimeManager.season_name(), TimeManager.day_of_season()]
	if bool(summary.get("passed_out", false)):
		text = "You dozed off among the plants...\n" + text
	elif bool(summary.get("raining", false)):
		text += "\nIt's raining today"
	_fade_label.text = text
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
