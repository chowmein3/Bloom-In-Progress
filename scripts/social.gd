extends CanvasLayer
## Co-op chatter: T opens a strip of emotes (pick with 1-6), Enter opens a
## line to type a message to your partner.

const Ui := preload("res://scripts/ui_style.gd")
const EMOTES: Array[String] = ["Love", "Sing", "Sleepy", "Hey!", "Huh?", "Phew"]

var player: Node2D

var _root: Control
var _strip: PanelContainer
var _line: LineEdit


func _ready() -> void:
	layer = 13
	_root = Control.new()
	_root.theme = Ui.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var holder := VBoxContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_top = -44
	holder.offset_bottom = -44
	var words: Array = []
	for i in EMOTES.size():
		words.append("%d %s" % [i + 1, EMOTES[i]])
	_strip = PanelContainer.new()
	_strip.add_theme_stylebox_override("panel", Ui.box(Ui.PAPER))
	_strip.add_child(Ui.label("   ".join(words)))
	_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_strip.visible = false
	holder.add_child(_strip)
	_line = LineEdit.new()
	_line.placeholder_text = "Say something, then Enter"
	_line.max_length = 60
	_line.custom_minimum_size.x = 180
	_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_line.visible = false
	_line.text_submitted.connect(_say)
	holder.add_child(_line)


func _can_open() -> bool:
	return player != null and not bool(player.get("in_menu")) and not bool(player.get("reading")) and not bool(player.get("frozen"))


func _unhandled_input(event: InputEvent) -> void:
	if _strip.visible:
		for i in EMOTES.size():
			if event.is_action_pressed("tool_%d" % (i + 1)):
				Net.send_emote(i)
				_strip.visible = false
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("emote") or event.is_action_pressed("close"):
			_strip.visible = false
			get_viewport().set_input_as_handled()
	elif _line.visible:
		if event.is_action_pressed("close"):
			_close_line()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("emote") and _can_open():
		_strip.visible = true
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("chat") and _can_open() and Net.online:
		_line.visible = true
		_line.text = ""
		_line.grab_focus()
		player.set("reading", true)
		get_viewport().set_input_as_handled()


func _say(text: String) -> void:
	if text.strip_edges() != "":
		Net.send_chat(text.strip_edges())
	_close_line()


func _close_line() -> void:
	_line.release_focus()
	_line.visible = false
	player.set("reading", false)
