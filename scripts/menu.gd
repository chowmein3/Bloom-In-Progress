extends CanvasLayer
## Start screen: tend the garden alone, host it for a partner, or join theirs.

signal solo_pressed
signal host_pressed
signal join_pressed(address: String)

var _status: Label
var _address: LineEdit
var _buttons: Array[Button] = []


func _ready() -> void:
	layer = 20
	var theme := Theme.new()
	theme.default_font_size = 8
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	root.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size.x = 170

	var title := Label.new()
	title.text = "Bloom In Progress"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "a garden for two"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_button(box, "Tend the garden alone").pressed.connect(func() -> void: solo_pressed.emit())
	_button(box, "Host my garden for a partner").pressed.connect(func() -> void: host_pressed.emit())

	var join_label := Label.new()
	join_label.text = "Or join your partner's garden:"
	box.add_child(join_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	_address = LineEdit.new()
	_address.placeholder_text = "e.g. 192.168.1.20"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.text_submitted.connect(func(_t: String) -> void: _join())
	row.add_child(_address)
	_button(row, "Join").pressed.connect(_join)
	box.add_child(row)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
	box.add_child(_status)


func _button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	parent.add_child(button)
	_buttons.append(button)
	return button


func _join() -> void:
	var address: String = _address.text.strip_edges()
	if address == "":
		set_status("Type your partner's address first")
		return
	join_pressed.emit(address)


func set_status(text: String) -> void:
	_status.text = text


## Greyed out while a connection attempt is in progress.
func set_busy(busy: bool) -> void:
	for button: Button in _buttons:
		button.disabled = busy
	_address.editable = not busy
