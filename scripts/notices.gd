extends CanvasLayer
## Two small list screens that share a look: the mailbox (letters, some with
## gifts inside) and the notice board (requests to hand in for coins and
## friendship). Open with open_mail() or open_board().

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")

var player: Node2D
var mode: String = "mail"

var _root: Control
var _title: Label
var _list: VBoxContainer
var _note: Label


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
	_title = Ui.label("", Ui.ACCENT, 10)
	box.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(216, 100)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	_note = Ui.label("", Ui.FAINT)
	box.add_child(_note)
	GameState.mail_changed.connect(_rebuild)
	GameState.inventory_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)
	GameState.notice.connect(func(text: String) -> void:
		if visible:
			_note.text = text)


func open_mail() -> void:
	_open("mail")


func open_board() -> void:
	_open("quests")


func _open(new_mode: String) -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	mode = new_mode
	visible = true
	player.set("reading", true)
	Sound.play("page")
	_note.text = "Esc to close"
	_rebuild()


func close() -> void:
	visible = false
	player.set("reading", false)
	Sound.play("page")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("close") or event.is_action_pressed("toggle_inventory")):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if not visible:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var me: int = player.get("player_id")
	if mode == "mail":
		_title.text = "Mailbox"
		if GameState.mail.is_empty():
			_list.add_child(Ui.label("No letters today.", Ui.FAINT))
		for i in GameState.mail.size():
			var letter: Dictionary = GameState.mail[i]
			var has_gift: bool = not letter.get("gift", {}).is_empty()
			_row(null, "From %s" % letter["from"], str(letter["text"]), "Take gift" if has_gift else "Done", true,
				func() -> void: GameState.request_open_mail(me, i))
	else:
		_title.text = "Notice Board"
		if GameState.quests.is_empty():
			_list.add_child(Ui.label("Nothing pinned up today.", Ui.FAINT))
		for i in GameState.quests.size():
			var quest: Dictionary = GameState.quests[i]
			var who: String = "Bristle" if not GameState.VILLAGERS.has(str(quest["who"])) else str(GameState.VILLAGERS[quest["who"]]["name"])
			var have: int = GameState.total_of(quest["id"])  # any quality will do
			var count: int = quest["count"]
			var icon := TextureRect.new()
			icon.texture = Assets.texture("res://assets/sprites/items/%s.png" % quest["id"])
			icon.custom_minimum_size = Vector2(16, 16)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			_row(icon, "%s wants %d %s" % [who, count, GameState.name_of(quest["id"])],
				"Pays %d coins. You have %d. %d days left." % [int(quest["coins"]), have, int(quest["days"])], "Hand in", have >= count,
				func() -> void: GameState.request_quest(me, i))


func _row(icon: Control, title: String, text: String, button_text: String, enabled: bool, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	if icon != null:
		row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -1)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Ui.label(title, Ui.ACCENT))
	var body: Label = Ui.label(text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 130
	words.add_child(body)
	row.add_child(words)
	var button := Button.new()
	button.text = button_text
	button.disabled = not enabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	row.add_child(button)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.box(Color(1.0, 0.96, 0.85), Color(0.8, 0.68, 0.5), 2))
	panel.add_child(row)
	_list.add_child(panel)
