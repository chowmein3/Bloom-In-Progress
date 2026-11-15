extends CanvasLayer
## Title menu and pause menu.
##
## Title:  New | Load | Co-op | Exit
##   New    -> name the garden -> play
##   Load   -> pick a saved garden (or delete one) -> play
##   Co-op  -> Host (a saved garden or a new one) | Join (by address)
## Pause (Esc in game):  Resume | Return to title | Exit

signal new_chosen(garden_name: String)
signal load_chosen(path: String)
signal host_new_chosen(garden_name: String)
signal host_load_chosen(path: String)
signal join_chosen(address: String)
signal resume_chosen
signal title_chosen
signal exit_chosen

const PAPER := Color(0.98, 0.91, 0.74)
const SLOT := Color(0.93, 0.8, 0.58)
const WOOD := Color(0.42, 0.26, 0.15)
const INK := Color(0.3, 0.18, 0.12)
const ACCENT := Color(0.75, 0.28, 0.2)
const Settings := preload("res://scripts/settings.gd")
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

var screen: String = ""  # which screen is showing: title, new, load, coop, join, pause

var _root: Control
var _dim: ColorRect
var _box: VBoxContainer
var _status: Label
var _hosting: bool = false  # whether New/Load were reached through Co-op > Host
var _busy: bool = false
var _name_field: LineEdit
var _address: String = ""
var _confirm_delete: String = ""
var _found_box: VBoxContainer
var _code: String = ""


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.theme = _make_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)

	var panel := PanelContainer.new()
	var style := _box_style(PAPER)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var centre := CenterContainer.new()  # keeps the panel centred as its content changes
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(centre)
	centre.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.custom_minimum_size.x = 130
	panel.add_child(column)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 2)
	column.add_child(_box)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", ACCENT)
	_status.visible = false
	column.add_child(_status)
	Net.gardens_changed.connect(_list_found)
	Net.open_gardens_changed.connect(_list_known)
	show_title()


# ---------------------------------------------------------------- screens

func show_title(status: String = "") -> void:
	_open("title", 0.72)
	_heading("Bloom In Progress", 14)
	_note("a garden for two")
	_button("New", func() -> void:
		_hosting = false
		_show_new()).grab_focus()
	_button("Load", func() -> void:
		_hosting = false
		_show_load())
	_button("Co-op", _show_coop)
	_button("Exit", func() -> void: exit_chosen.emit())
	set_status(status)


func show_pause() -> void:
	_open("pause", 0.45)
	_heading("Paused", 10)
	_button("Resume", func() -> void: resume_chosen.emit()).grab_focus()
	_button("Return to title", func() -> void: title_chosen.emit())
	_button("Exit game", func() -> void: exit_chosen.emit())
	_note("The garden is saved each night when you\nsleep. Leaving now loses today's progress.")


func _show_new() -> void:
	_open("new", 0.72)
	_heading("Host a new garden" if _hosting else "New garden", 10)
	_note("Give your garden a name:")
	_name_field = LineEdit.new()
	_name_field.text = "Our Garden"
	_name_field.max_length = 24
	_name_field.select_all_on_focus = true
	_name_field.text_submitted.connect(func(_t: String) -> void: _confirm_new())
	_box.add_child(_name_field)
	_button("Start", _confirm_new)
	_button("Back", _show_coop_host if _hosting else show_title)
	_name_field.grab_focus()


func _confirm_new() -> void:
	if _hosting:
		host_new_chosen.emit(_name_field.text)
	else:
		new_chosen.emit(_name_field.text)


func _show_load() -> void:
	_open("load", 0.72)
	_heading("Host a garden" if _hosting else "Load garden", 10)
	if _hosting:
		_button("Host a new garden", _show_new)
	var gardens: Array[Dictionary] = GameState.list_gardens()
	if gardens.is_empty():
		_note("No saved gardens yet.")
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for garden: Dictionary in gardens:
		var path: String = garden["path"]
		var day: int = garden["day_index"]
		@warning_ignore("integer_division")
		var when: String = "%s %d, Year %d" % [SEASONS[(day / 28) % 4], day % 28 + 1, day / 112 + 1]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var pick := Button.new()
		pick.text = "%s\n%s" % [garden["name"], when]
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void:
			if _hosting:
				host_load_chosen.emit(path)
			else:
				load_chosen.emit(path))
		row.add_child(pick)
		var remove := Button.new()
		remove.text = "Sure?" if _confirm_delete == path else "Delete"
		remove.pressed.connect(func() -> void:
			if _confirm_delete == path:
				GameState.delete_garden(path)
				_confirm_delete = ""
			else:
				_confirm_delete = path
			_show_load())
		row.add_child(remove)
		list.add_child(row)
	if not gardens.is_empty():
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(150, minf(gardens.size() * 26.0, 80.0))
		scroll.add_child(list)
		_box.add_child(scroll)
	_button("Back", _show_coop if _hosting else show_title).grab_focus()


func _show_coop() -> void:
	_confirm_delete = ""
	_open("coop", 0.72)
	_heading("Co-op", 10)
	_button("Host", _show_coop_host).grab_focus()
	_button("Join", _show_join)
	_button("Back", show_title)
	if Net.relay_enabled():
		_note("The host owns the garden and its save.\nThe partner joins with its invite code once;\nafter that it is one click.")
	else:
		_note("The host owns the garden and its save.\nOn the same Wi-Fi, Join finds it by itself.")


func _show_coop_host() -> void:
	_hosting = true
	_show_load()


func _show_join() -> void:
	_open("join", 0.72)
	_heading("Join a garden", 10)
	if Net.relay_enabled():
		# Through the relay: gardens joined before are one click; a new one
		# needs its invite code once.
		_note("Your partner's gardens:")
		_found_box = VBoxContainer.new()
		_found_box.add_theme_constant_override("separation", 2)
		_box.add_child(_found_box)
		_note("New invite code:")
		var code_field := LineEdit.new()
		code_field.text = _code
		code_field.placeholder_text = "ABC-DEF"
		code_field.max_length = 9
		code_field.text_changed.connect(func(text: String) -> void: _code = text)
		code_field.text_submitted.connect(func(_t: String) -> void: _confirm_code())
		_box.add_child(code_field)
		_button("Join", _confirm_code)
		_button("Back", _show_coop)
		Net.start_lookup(Settings.known_gardens().keys())
		_list_known()
		return
	_note("Gardens on your network:")
	_found_box = VBoxContainer.new()
	_found_box.add_theme_constant_override("separation", 2)
	_box.add_child(_found_box)
	_note("Or type your partner's address:")
	if _address == "":
		_address = str(Settings.read().get("last_address", ""))
	var field := LineEdit.new()
	field.text = _address
	field.placeholder_text = "e.g. 192.168.1.20"
	field.text_changed.connect(func(text: String) -> void: _address = text)
	field.text_submitted.connect(func(_t: String) -> void: _confirm_join())
	_box.add_child(field)
	_button("Join", _confirm_join)
	_button("Back", _show_coop)
	Net.start_discovery()
	_list_found()


## Gardens this player has visited before, lit up when their host has them open.
func _list_known() -> void:
	if screen != "join" or _found_box == null or not Net.relay_enabled():
		return
	for child: Node in _found_box.get_children():
		_found_box.remove_child(child)
		child.queue_free()
	var known: Dictionary = Settings.known_gardens()
	for code: String in known.keys():
		var open: bool = Net.open_gardens.has(code)
		var full: bool = open and bool(Net.open_gardens[code]["full"])
		var button := Button.new()
		button.text = "%s%s" % [Net.open_gardens[code]["name"] if open else known[code], "" if open and not full else ("  (full)" if full else "  (not open)")]
		button.disabled = _busy or not open or full
		button.pressed.connect(func() -> void: join_chosen.emit("code:" + code))
		_found_box.add_child(button)
	if known.is_empty():
		var none := Label.new()
		none.text = "None yet. Ask your partner for\ntheir garden's invite code."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", Color(0.6, 0.5, 0.42))
		_found_box.add_child(none)


func _confirm_code() -> void:
	var code: String = ""
	for letter: String in _code.to_upper():
		if (letter >= "A" and letter <= "Z") or (letter >= "0" and letter <= "9"):
			code += letter
	if code.length() != 6:
		set_status("Invite codes are six letters, like ABC-DEF")
		return
	join_chosen.emit("code:" + code)


## Hosts announce themselves on the local network; each gets a one-click button.
func _list_found() -> void:
	if screen != "join" or _found_box == null or Net.relay_enabled():
		return
	for child: Node in _found_box.get_children():
		_found_box.remove_child(child)
		child.queue_free()
	for address: String in Net.found_gardens.keys():
		var found: Dictionary = Net.found_gardens[address]
		var button := Button.new()
		button.text = "%s%s" % [found["name"], "  (full)" if bool(found["full"]) else ""]
		button.disabled = _busy or bool(found["full"])
		var target: String = "%s:%d" % [address, int(found["port"])]
		button.pressed.connect(func() -> void: join_chosen.emit(target))
		_found_box.add_child(button)
	if Net.found_gardens.is_empty():
		var waiting := Label.new()
		waiting.text = "Looking..."
		waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		waiting.add_theme_color_override("font_color", Color(0.6, 0.5, 0.42))
		_found_box.add_child(waiting)


func _confirm_join() -> void:
	var address: String = _address.strip_edges()
	if address == "":
		set_status("Type your partner's address first")
		return
	Settings.put("last_address", address)
	join_chosen.emit(address)


# ----------------------------------------------------------------- pieces

func _open(new_screen: String, dim: float) -> void:
	if new_screen != "load":
		_confirm_delete = ""
	if new_screen != "join":
		Net.stop_discovery()
		Net.stop_lookup()
		_found_box = null
	screen = new_screen
	visible = true
	_dim.color = Color(0.08, 0.06, 0.14, dim)
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	set_status("")


func _heading(text: String, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ACCENT)
	_box.add_child(label)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(label)


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = _busy
	button.pressed.connect(action)
	_box.add_child(button)
	return button


func set_status(text: String) -> void:
	_status.text = text
	_status.visible = text != ""


## Greyed out while a connection attempt is in progress.
func set_busy(busy: bool) -> void:
	_busy = busy
	for node: Node in _box.find_children("*", "BaseButton", true, false):
		(node as BaseButton).disabled = busy


func _box_style(fill: Color, edge: Color = WOOD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(1)
	box.set_border_width_all(1)
	box.border_color = edge
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


## Parchment-and-wood look for buttons and text fields, matching the HUD.
func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 7
	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("normal", "Button", _box_style(SLOT))
	theme.set_stylebox("hover", "Button", _box_style(Color(1.0, 0.95, 0.8)))
	theme.set_stylebox("pressed", "Button", _box_style(Color(0.85, 0.7, 0.48)))
	theme.set_stylebox("focus", "Button", _box_style(Color(0, 0, 0, 0), ACCENT))
	theme.set_stylebox("disabled", "Button", _box_style(Color(0.88, 0.82, 0.7), Color(0.65, 0.55, 0.45)))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(0.6, 0.5, 0.42))
	theme.set_stylebox("normal", "LineEdit", _box_style(Color(1.0, 0.98, 0.9)))
	theme.set_stylebox("focus", "LineEdit", _box_style(Color(0, 0, 0, 0), ACCENT))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.6, 0.5, 0.42))
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("selection_color", "LineEdit", Color(0.75, 0.28, 0.2, 0.3))
	return theme
