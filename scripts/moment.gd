extends CanvasLayer
## A moment with someone in town (or the garden's visitor), shown instead
## of their usual screen when GameState.moment(who) has something: a heart
## scene with three replies, a story step or errand to finish, or their
## story starting. The answer comes back as a notice from the host.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")

var player: Node2D

var _root: Control
var _face: TextureRect
var _name: Label
var _line: Label
var _buttons: VBoxContainer
var _who: String = ""
var _kind: String = ""


func _ready() -> void:
	layer = 15
	visible = false
	_root = Control.new()
	_root.theme = Ui.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	Ui.popup(_root).add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(32, 48)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	header.add_child(_face)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = Ui.label("", Ui.ACCENT, 10)
	words.add_child(_name)
	_line = Ui.label("")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(190, 30)
	words.add_child(_line)
	header.add_child(words)
	box.add_child(header)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 2)
	box.add_child(_buttons)
	GameState.notice.connect(func(text: String) -> void:
		if visible:
			_line.text = text)


## Whether `who` has a moment waiting (the player talks to them through this).
static func has_moment(who: String) -> bool:
	return not GameState.moment(who).is_empty()


func open(who: String) -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	var now: Dictionary = GameState.moment(who)
	if now.is_empty():
		return
	_who = who
	visible = true
	player.set("reading", true)
	Sound.play("page")
	var info: Dictionary = GameState.person(who)
	_name.text = "%s, %s" % [info["name"], info["what"]]
	_face.texture = Assets.texture("res://assets/sprites/keeper.png" if who == "bristle" else "res://assets/sprites/villager_%s.png" % who)
	_show(now)


## Lays out a moment: its words and a button per reply.
func _show(now: Dictionary) -> void:
	_kind = now["kind"]
	_line.text = "\n".join(now["lines"])
	if _kind == "scene":
		_name.text = "%s   (%d hearts)" % [_name.text.get_slice("   ", 0), int(now["level"])]
	_clear()
	var choices: Array = now["choices"]
	for i in choices.size():
		_add(choices[i], func() -> void:
			var me: int = player.get("player_id")
			_clear()
			GameState.request_moment(me, _who, _kind, i)
			_after())
	if _kind != "scene":
		_add("Not now", close)


## After a reply: carry on if there's more, or say goodbye.
func _after() -> void:
	var next: Dictionary = GameState.moment(_who)
	if not next.is_empty() and Net.is_host():
		_add("Go on", func() -> void: _show(next))
	_add("Bye", close)


func _add(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	_buttons.add_child(button)


func _clear() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func close() -> void:
	visible = false
	player.set("reading", false)
	Sound.play("page")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("close") or event.is_action_pressed("toggle_inventory")):
		close()
		get_viewport().set_input_as_handled()
