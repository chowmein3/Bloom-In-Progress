extends Node
## In-game clock, calendar and weather.

signal time_changed
signal curfew_reached

const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
const DAYS_PER_SEASON := 28
const DAY_START := 6 * 60
const DAY_END := 26 * 60  # 2am the next morning
const STEP_MINUTES := 10
const REAL_SECONDS_PER_STEP := 7.0

var day_index: int = 0  # days elapsed since the garden began
var minutes: int = DAY_START
var raining: bool = false
var rain_chance: float = 0.2
var paused: bool = false
var rng := RandomNumberGenerator.new()

var _accum: float = 0.0


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta
	while _accum >= REAL_SECONDS_PER_STEP:
		_accum -= REAL_SECONDS_PER_STEP
		minutes += STEP_MINUTES
		time_changed.emit()
		if minutes >= DAY_END:
			_accum = 0.0
			curfew_reached.emit()
			return


## The time of day including the part of a ten-minute step already gone by,
## for anything that should change smoothly (the light).
func exact_minutes() -> float:
	return minutes + (0.0 if paused else _accum / REAL_SECONDS_PER_STEP * STEP_MINUTES)


func season() -> int:
	@warning_ignore("integer_division")
	return (day_index / DAYS_PER_SEASON) % 4


func season_name() -> String:
	return SEASON_NAMES[season()]


func day_of_season() -> int:
	return day_index % DAYS_PER_SEASON + 1


func year() -> int:
	@warning_ignore("integer_division")
	return day_index / (DAYS_PER_SEASON * 4) + 1


func start_next_day() -> void:
	day_index += 1
	minutes = DAY_START
	_accum = 0.0
	# No rain in winter (it would be snow, which doesn't water anything).
	raining = season() != 3 and rng.randf() < rain_chance
	time_changed.emit()


## Jump straight to a date and time (the clock tower does this).
func set_clock(new_day_index: int, new_minutes: int, rain: bool) -> void:
	day_index = maxi(new_day_index, 0)
	@warning_ignore("integer_division")
	minutes = clampi(new_minutes / STEP_MINUTES * STEP_MINUTES, DAY_START, DAY_END - STEP_MINUTES)
	_accum = 0.0
	raining = rain and season() != 3  # it never rains in winter
	time_changed.emit()


func reset() -> void:
	day_index = 0
	minutes = DAY_START
	_accum = 0.0
	raining = false
	time_changed.emit()


func time_string() -> String:
	@warning_ignore("integer_division")
	var h: int = (minutes / 60) % 24
	var m: int = minutes % 60
	var suffix: String = "am" if h < 12 else "pm"
	var h12: int = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d%s" % [h12, m, suffix]
