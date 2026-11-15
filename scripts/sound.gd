extends Node
## Music and sound effects (autoload `Sound`). It only listens to GameState's
## signals, so in co-op you hear your partner's gardening too. N toggles music.

const Assets := preload("res://scripts/assets.gd")

const EFFECTS: Array[String] = ["soil", "water", "plant", "pet", "pick", "morning", "grow", "page"]
const MUSIC_DB := -16.0
const EFFECT_DB := -8.0

var music_on: bool = true

var _music: AudioStreamPlayer
var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _watered: Dictionary = {}  # cell -> was it watered, to tell watering from tilling
var _tree_watered: bool = false
var _tree_hugs: int = 0


func _ready() -> void:
	for effect: String in EFFECTS:
		_streams[effect] = Assets.sound("res://assets/audio/%s.wav" % effect)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = EFFECT_DB
		add_child(voice)
		_voices.append(voice)
	var theme: AudioStreamWAV = Assets.sound("res://assets/audio/garden_theme.wav")
	theme.loop_mode = AudioStreamWAV.LOOP_FORWARD
	theme.loop_begin = 0
	theme.loop_end = int(theme.get_length() * theme.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = theme
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_music.play()

	GameState.state_reloaded.connect(_remember)
	GameState.cell_changed.connect(_on_cell_changed)
	GameState.plant_added.connect(func(_c: Vector2i) -> void: play("plant"))
	GameState.plant_removed.connect(func(_c: Vector2i) -> void: play("pick"))
	GameState.plant_petted.connect(func(_c: Vector2i) -> void: play("pet"))
	GameState.tree_changed.connect(_on_tree_changed)
	GameState.day_advanced.connect(_on_day_advanced)
	_remember()


func play(effect: String) -> void:
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _streams[effect]
	voice.play()


func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("toggle_music") and event.is_action_pressed("toggle_music"):
		music_on = not music_on
		_music.stream_paused = not music_on


func _remember() -> void:
	_watered.clear()
	for cell: Vector2i in GameState.soil.keys():
		_watered[cell] = bool(GameState.soil[cell]["watered"])
	_tree_watered = bool(GameState.tree["watered"])
	_tree_hugs = GameState.tree["hugged_by"].size()


func _on_cell_changed(cell: Vector2i) -> void:
	if not GameState.soil.has(cell):
		_watered.erase(cell)
		return
	var watered: bool = bool(GameState.soil[cell]["watered"])
	if not _watered.has(cell):
		play("soil")  # freshly tilled
	elif watered and not bool(_watered[cell]):
		play("water")
	elif GameState.plants.has(cell) and int(GameState.plants[cell]["regrow_wait"]) > 0:
		play("pick")  # a regrowing plant was picked
	_watered[cell] = watered


func _on_tree_changed() -> void:
	var watered: bool = bool(GameState.tree["watered"])
	var hugs: int = GameState.tree["hugged_by"].size()
	if watered and not _tree_watered:
		play("water")
	if hugs > _tree_hugs:
		play("pet")
	_tree_watered = watered
	_tree_hugs = hugs


func _on_day_advanced(summary: Dictionary) -> void:
	_remember()
	play("grow" if not summary.get("tree", {}).is_empty() else "morning")


func _exit_tree() -> void:
	_music.stop()
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
