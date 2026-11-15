extends CanvasLayer
## The shipping bin: drop harvest and fish in during the day and they are
## sold overnight at Bristle's prices. Things can be taken back until then.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")

var player: Node2D

var _root: Control
var _list: VBoxContainer
var _total: Label


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
	box.add_child(Ui.label("Shipping Bin", Ui.ACCENT, 10))
	box.add_child(Ui.label("What's in the bin is sold while you sleep.", Ui.FAINT))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(200, 92)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	_total = Ui.label("", Ui.ACCENT)
	box.add_child(_total)
	box.add_child(Ui.label("Esc to close", Ui.FAINT))
	GameState.inventory_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)


func open() -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	visible = true
	player.set("reading", true)
	Sound.play("page")
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
	var total: int = 0
	var ids: Array = GameState.species.keys() + GameState.ITEMS.keys()
	var any: bool = false
	for id: String in ids:
		var price: int = GameState.sell_price_of(id)
		var have: int = GameState.stock_of(id)
		var inside: int = int(GameState.bin.get(id, 0))
		if price <= 0 or (have <= 0 and inside <= 0):
			continue
		any = true
		total += inside * price
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = Assets.texture("res://assets/sprites/items/%s.png" % id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var words: Label = Ui.label("%s  (%d each)\nIn bin: %d   In backpack: %d" % [GameState.name_of(id), price, inside, have])
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		row.add_child(_button("Add all", have > 0, func() -> void: GameState.request_ship(me, id, have)))
		row.add_child(_button("Take back", inside > 0, func() -> void: GameState.request_ship(me, id, -inside)))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Ui.box(Color(1.0, 0.96, 0.85), Color(0.8, 0.68, 0.5), 2))
		panel.add_child(row)
		_list.add_child(panel)
	if not any:
		_list.add_child(Ui.label("Nothing to ship yet.\nPicked plants and fish can go in here.", Ui.FAINT))
	_total.text = "Tonight's sale: %d coins" % total


func _button(text: String, enabled: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button
