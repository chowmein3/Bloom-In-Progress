extends CanvasLayer
## The clock tower's screen: pick a season, day, year, time of day and
## weather, then press the big button. Nothing grows for the skipped time;
## it is for seeing the garden at any moment.

const Ui := preload("res://scripts/ui_style.gd")
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
const PRESETS: Array = [["Dawn", 6 * 60], ["Noon", 12 * 60], ["Dusk", 19 * 60], ["Night", 23 * 60]]

var player: Node2D

var _root: Control
var _season: int = 0
var _day: int = 1
var _year: int = 1
var _minutes: int = 6 * 60
var _rain: bool = false
var _season_row: HBoxContainer
var _weather_row: HBoxContainer
var _day_label: Label
var _year_label: Label
var _time_label: Label


func _ready() -> void:
	layer = 15
	visible = false
	_root = Control.new()
	_root.theme = Ui.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	Ui.popup(_root).add_child(box)
	box.add_child(Ui.label("The Clock Tower", Ui.ACCENT, 10))
	box.add_child(Ui.label("Set any date and time to see the garden then.\nNothing grows or wilts for the time skipped.", Ui.FAINT))

	_season_row = HBoxContainer.new()
	_season_row.add_theme_constant_override("separation", 1)
	box.add_child(_season_row)

	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 2)
	date_row.add_child(Ui.label("Day"))
	date_row.add_child(_stepper("-", func() -> void: _day = wrapi(_day - 1, 1, 29)))
	_day_label = _value(14)
	date_row.add_child(_day_label)
	date_row.add_child(_stepper("+", func() -> void: _day = wrapi(_day + 1, 1, 29)))
	date_row.add_child(Ui.spacer())
	date_row.add_child(Ui.label("Year"))
	date_row.add_child(_stepper("-", func() -> void: _year = maxi(_year - 1, 1)))
	_year_label = _value(14)
	date_row.add_child(_year_label)
	date_row.add_child(_stepper("+", func() -> void: _year = mini(_year + 1, GameState.LAST_YEAR)))
	box.add_child(date_row)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 2)
	time_row.add_child(Ui.label("Time"))
	time_row.add_child(_stepper("-1h", func() -> void: _shift_time(-60)))
	time_row.add_child(_stepper("-10m", func() -> void: _shift_time(-10)))
	_time_label = _value(34)
	time_row.add_child(_time_label)
	time_row.add_child(_stepper("+10m", func() -> void: _shift_time(10)))
	time_row.add_child(_stepper("+1h", func() -> void: _shift_time(60)))
	box.add_child(time_row)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 1)
	for preset: Array in PRESETS:
		var minutes: int = preset[1]
		var button: Button = _stepper(preset[0], func() -> void: _minutes = minutes)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_row.add_child(button)
	box.add_child(preset_row)

	_weather_row = HBoxContainer.new()
	_weather_row.add_theme_constant_override("separation", 1)
	box.add_child(_weather_row)

	var go := Button.new()
	go.text = "CHANGE TIME!"
	go.add_theme_font_size_override("font_size", 9)
	go.add_theme_stylebox_override("normal", Ui.box(Color(0.95, 0.6, 0.4), Ui.ACCENT))
	go.add_theme_stylebox_override("hover", Ui.box(Color(1.0, 0.72, 0.5), Ui.ACCENT))
	go.pressed.connect(_confirm)
	box.add_child(go)
	box.add_child(Ui.label("Esc to close", Ui.FAINT))


func _stepper(text: String, change: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func() -> void:
		change.call()
		_refresh())
	return button


func _value(width: int) -> Label:
	var label: Label = Ui.label("")
	label.custom_minimum_size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _shift_time(by: int) -> void:
	_minutes = clampi(_minutes + by, TimeManager.DAY_START, TimeManager.DAY_END - TimeManager.STEP_MINUTES)


## The day number, counted from the garden's first day, that the screen shows.
func chosen_day_index() -> int:
	return ((_year - 1) * 4 + _season) * TimeManager.DAYS_PER_SEASON + _day - 1


func open() -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	# Start from the present moment.
	_season = TimeManager.season()
	_day = TimeManager.day_of_season()
	_year = TimeManager.year()
	_minutes = TimeManager.minutes
	_rain = TimeManager.raining
	visible = true
	player.set("reading", true)
	Sound.play("page")
	_refresh()


func close() -> void:
	visible = false
	player.set("reading", false)


func _confirm() -> void:
	var me: int = player.get("player_id")
	close()
	GameState.request_set_time(me, chosen_day_index(), _minutes, _rain)


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("close") or event.is_action_pressed("toggle_inventory")):
		close()
		Sound.play("page")
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _season == 3:
		_rain = false  # it never rains in winter
	_day_label.text = str(_day)
	_year_label.text = str(_year)
	@warning_ignore("integer_division")
	var hour: int = (_minutes / 60) % 24
	var shown: int = 12 if hour % 12 == 0 else hour % 12
	_time_label.text = "%d:%02d%s" % [shown, _minutes % 60, "am" if hour < 12 else "pm"]
	_choices(_season_row, SEASONS, _season, func(index: int) -> void: _season = index)
	var weathers: Array[String] = ["Clear"]
	if _season != 3:
		weathers.append("Rain")
	_choices(_weather_row, weathers, 1 if _rain else 0, func(index: int) -> void: _rain = index == 1)


## A row of buttons where one is the current choice.
func _choices(row: HBoxContainer, names: Array[String], current: int, pick: Callable) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	for i in names.size():
		var button := Button.new()
		button.text = names[i]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == current:
			button.add_theme_stylebox_override("normal", Ui.box(Color(1.0, 0.95, 0.8), Ui.ACCENT))
		button.pressed.connect(func() -> void:
			pick.call(i)
			_refresh())
		row.add_child(button)
