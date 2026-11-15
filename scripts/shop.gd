extends CanvasLayer
## Bristle's stall: sell the harvest for coins, and spend them on seeds,
## better tools, a bigger home and hats. Every purchase goes through
## GameState.request_*(), so it works the same for a guest.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")
const TABS: Array[String] = ["Sell", "Seeds", "Tools", "Home", "Hats"]
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

var player: Node2D
var tab: String = "Sell"

var _root: Control
var _speech: Label
var _coins: Label
var _tab_row: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _icons: Texture2D
var _hats: Texture2D


func _ready() -> void:
	layer = 15
	visible = false
	_icons = Assets.texture("res://assets/sprites/ui_icons.png")
	_hats = Assets.texture("res://assets/sprites/hats.png")
	_root = Control.new()
	_root.theme = Ui.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	Ui.popup(_root).add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var keeper := TextureRect.new()
	keeper.texture = Assets.texture("res://assets/sprites/keeper.png")
	keeper.custom_minimum_size = Vector2(32, 32)
	header.add_child(keeper)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Ui.label("Bristle's Stall", Ui.ACCENT, 10))
	_speech = Ui.label("")
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.custom_minimum_size = Vector2(120, 18)
	words.add_child(_speech)
	header.add_child(words)
	header.add_child(Ui.picture(_icons, Rect2(10 * 12, 0, 12, 12)))
	_coins = Ui.label("", Ui.INK, 8)
	header.add_child(_coins)
	box.add_child(header)

	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 1)
	box.add_child(_tab_row)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(214, 78)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	box.add_child(_scroll)
	box.add_child(Ui.label("Esc to close", Ui.FAINT))

	GameState.inventory_changed.connect(_rebuild)
	GameState.economy_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)
	GameState.notice.connect(func(text: String) -> void:
		if visible:
			_speech.text = text)


func open() -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	visible = true
	player.set("reading", true)
	_speech.text = "Welcome! Fresh seeds, fair prices."
	Sound.play("page")
	_rebuild()


func close() -> void:
	visible = false
	player.set("reading", false)
	Sound.play("page")


func show_tab(new_tab: String) -> void:
	tab = new_tab
	_scroll.scroll_vertical = 0
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("close") or event.is_action_pressed("toggle_inventory")):
		close()
		get_viewport().set_input_as_handled()


func _rebuild() -> void:
	if not visible:
		return
	_coins.text = str(GameState.coins)
	for child: Node in _tab_row.get_children():
		_tab_row.remove_child(child)
		child.queue_free()
	for name_of: String in TABS:
		var button := Button.new()
		button.text = name_of
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if name_of == tab:
			button.add_theme_stylebox_override("normal", Ui.box(Color(1.0, 0.95, 0.8), Ui.ACCENT))
		button.pressed.connect(show_tab.bind(name_of))
		_tab_row.add_child(button)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match tab:
		"Sell": _fill_sell()
		"Seeds": _fill_seeds()
		"Tools": _fill_upgrades(["hoe", "can"])
		"Home": _fill_upgrades(["home"])
		"Hats": _fill_hats()


## One line of the list: picture, name with a smaller note, price, buttons.
func _row(icon: Control, title: String, note: String, price: String, buttons: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	if icon != null:
		row.add_child(icon)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Ui.label(title))
	if note != "":
		words.add_child(Ui.label(note, Ui.FAINT, 5))
	row.add_child(words)
	if price != "":
		row.add_child(Ui.label(price, Ui.ACCENT))
	for button: Button in buttons:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Ui.box(Color(1.0, 0.96, 0.85), Color(0.8, 0.68, 0.5), 2))
	panel.add_child(row)
	_list.add_child(panel)


func _button(text: String, enabled: bool, action: Callable, thanks: String) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.pressed.connect(func() -> void:
		_speech.text = thanks
		action.call())
	return button


func _item_icon(id: String, seeds: bool) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = Assets.texture("res://assets/sprites/items/%s%s.png" % [id, "_seeds" if seeds else ""])
	picture.custom_minimum_size = Vector2(16, 16)
	picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return picture


func _fill_sell() -> void:
	var me: int = player.get("player_id")
	var any: bool = false
	if not GameState.wanted.is_empty():  # Bristle's request pays double
		var asked: String = GameState.wanted["species"]
		var amount: int = GameState.wanted["count"]
		var have: int = int(GameState.produce.get(asked, 0))
		_row(_item_icon(asked, false), "Wanted: %d %s" % [amount, GameState.name_of(asked)], "Bristle pays double. You have %d." % have, str(int(GameState.wanted["reward"])), [
			_button("Deliver", have >= amount, func() -> void: GameState.request_deliver(me), "Just what I was after. Thank you!"),
		])
	for id: String in GameState.species.keys():
		var count: int = int(GameState.produce.get(id, 0))
		if count <= 0:
			continue
		any = true
		var d: Resource = GameState.species[id]
		var each: int = d.sell_price
		_row(_item_icon(id, false), "%s x%d" % [d.display_name, count], "", "%d each" % each, [
			_button("Sell 1", true, func() -> void: GameState.request_sell(me, id, 1), "A fine %s!" % d.display_name),
			_button("Sell all (%d)" % (each * count), true, func() -> void: GameState.request_sell(me, id, count), "Lovely, I'll take the lot."),
		])
	if not any:
		_list.add_child(Ui.label("Nothing to sell yet.\nPick grown plants with the basket (5),\nthen bring them here.", Ui.FAINT))


func _fill_seeds() -> void:
	var me: int = player.get("player_id")
	for id: String in GameState.species.keys():
		if not GameState.seed_in_stock(id):
			continue
		var d: Resource = GameState.species[id]
		var price: int = d.seed_price
		var seasons: Array = []
		for s: int in d.seasons:
			seasons.append(SEASONS[s])
		var note: String = "%s, %d days. You have %d." % [" & ".join(seasons), d.total_days(), GameState.seed_count(id)]
		_row(_item_icon(id, true), "%s seeds" % d.display_name, note, str(price), [
			_button("Buy 1", GameState.coins >= price, func() -> void: GameState.request_buy_seeds(me, id, 1), "Plant it with love."),
			_button("Buy 5", GameState.coins >= price * 5, func() -> void: GameState.request_buy_seeds(me, id, 5), "A whole row's worth!"),
		])
	_list.add_child(Ui.label("New kinds arrive as the Heart Tree grows.", Ui.FAINT, 5))


func _fill_upgrades(kinds: Array) -> void:
	var me: int = player.get("player_id")
	for kind: String in kinds:
		var next: Dictionary = GameState.next_upgrade(kind)
		var level: int = GameState.upgrade_level(kind)
		var have: String = GameState.HOME_NAMES[level] if kind == "home" else (GameState.UPGRADES[kind][level - 1]["name"] if level > 0 else ("Hoe" if kind == "hoe" else "Watering Can"))
		var icon: Control = null
		if kind == "home":
			var house := TextureRect.new()
			house.texture = Assets.texture("res://assets/sprites/home_%d.png" % mini(level + 1, 2))
			house.custom_minimum_size = Vector2(24, 24)
			house.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			house.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon = house
		else:
			icon = Ui.picture(_icons, Rect2((0 if kind == "hoe" else 1) * 12, 0, 12, 12))
		if next.is_empty():
			_row(icon, have, "The best there is. Nothing more to buy.", "", [])
			continue
		var cost: int = next["cost"]
		_row(icon, next["name"], "%s. You have: %s." % [next["blurb"], have], str(cost), [
			_button("Buy", GameState.coins >= cost, func() -> void: GameState.request_buy_upgrade(me, kind), "Built to last. Enjoy!"),
		])


func _fill_hats() -> void:
	var me: int = player.get("player_id")
	for hat: String in GameState.HAT_ORDER:
		var info: Dictionary = GameState.HATS[hat]
		var icon: TextureRect = Ui.picture(_hats, Rect2(GameState.HAT_ORDER.find(hat) * 16, 0, 16, 12))
		var cost: int = info["cost"]
		if GameState.hats_owned.has(hat):
			var wearing: bool = GameState.hat_of(me) == hat
			_row(icon, info["name"], "Wearing it now." if wearing else "In the garden's wardrobe.", "", [
				_button("Wear", not wearing, func() -> void: GameState.request_wear(me, hat), "Suits you!"),
			])
		else:
			_row(icon, info["name"], "Either of you can wear it once bought.", str(cost), [
				_button("Buy", GameState.coins >= cost, func() -> void: GameState.request_buy_hat(me, hat), "Very dashing!"),
			])
