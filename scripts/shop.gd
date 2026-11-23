extends CanvasLayer
## A shop screen: Bristle's stall by the garden (selling only), or one of the
## townsfolk in town (GameState.TOWNSFOLK): their pages (`tabs`) are chosen
## from Sell, Wares, Request, Gift, Seeds, Animals, Pantry, Decor, Hats, Tools,
## Home, Build, Donate and Board. Every purchase goes through
## GameState.request_*(), so it works the same for a guest.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")
const Stories := preload("res://scripts/stories.gd")
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]
const FESTIVAL_HINTS: Array[String] = [
	"Enter your finest harvest in the show!",
	"Catch the fireflies over the plaza. Five gets you a jar!",
	"Help fill the town's display with harvests!",
	"Bring a garden lantern and send it up with ours!",
]

var player: Node2D
var tab: String = "Sell"
var keeper: String = "stall"  # whose shop this is: "stall", or a TOWNSFOLK id

var _root: Control
var _speech: Label
var _face: TextureRect
var _title: Label
var _hearts: Label
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
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(32, 32)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(_face)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Ui.label("Bristle's Stall", Ui.ACCENT, 10)
	words.add_child(_title)
	_hearts = Ui.label("", Ui.FAINT, 5)
	words.add_child(_hearts)
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


## Open `who`'s shop: "stall" (Bristle's stall by the garden) or one of the townsfolk.
func open(who: String = "stall") -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	keeper = who if GameState.TOWNSFOLK.has(who) else "stall"
	visible = true
	player.set("reading", true)
	tab = tabs()[0]
	_scroll.scroll_vertical = 0
	if keeper == "stall":
		_title.text = "Bristle's Stall"
		_face.texture = Assets.texture("res://assets/sprites/keeper.png")
		_speech.text = "Selling? I'll take it all. Seeds and the rest are at my store in town, up the north trail."
	else:
		var info: Dictionary = GameState.TOWNSFOLK[keeper]
		_title.text = "%s, %s" % [info["name"], info["what"]]
		_face.texture = Assets.texture("res://assets/sprites/keeper.png" if keeper == "bristle" else "res://assets/sprites/villager_%s.png" % keeper)
		var lines: Array = info["lines"]
		_speech.text = lines[(TimeManager.day_index + GameState.hearts(keeper)) % lines.size()]
		if keeper == "clementine" and GameState.party_on():
			_speech.text = "Welcome to the %s! %s" % [GameState.FESTIVALS[GameState.festival_today()]["name"], FESTIVAL_HINTS[GameState.festival_today()]]
		elif GameState.party_on():
			_speech.text = "Isn't this wonderful? Mayor Clementine's by the fountain if you want to join in."
		elif not GameState.is_open(keeper):
			_speech.text = "%s The shop's shut %s, but it's nice to chat." % [_speech.text, "today" if GameState.is_rest_day(keeper) else "just now"]
		GameState.request_talk(player.get("player_id"), keeper)  # the day's chat
	Sound.play("page")
	_rebuild()


## The pages of this shop (away from the counter, only a chat, their
## request and a gift).
func tabs() -> Array:
	if keeper == "stall":
		return ["Sell"]
	var pages: Array = GameState.TOWNSFOLK[keeper]["tabs"]
	if not GameState.is_open(keeper):
		pages = pages.filter(func(page: String) -> bool: return page == "Request" or page == "Gift")
	if keeper == "clementine" and GameState.party_on():
		pages = ["Festival"] + pages
	return pages


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
	_hearts.text = ""
	if keeper != "stall":
		var full: int = GameState.hearts(keeper)
		_hearts.text = "%s   %s" % [GameState.TOWNSFOLK[keeper]["title"], "Hearts %d of %d" % [full, GameState.MAX_HEARTS]]
	for child: Node in _tab_row.get_children():
		_tab_row.remove_child(child)
		child.queue_free()
	for name_of: String in tabs():
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
		"Sell":
			if keeper == "stall" or keeper == "bristle":
				_fill_sell()  # Bristle buys anything at the usual price
			else:
				_fill_sell_to()
		"Seeds": _fill_seeds()
		"Tools": _fill_upgrades(["hoe", "can", "pickaxe"])
		"Animals": _fill_animals()
		"Home": _fill_upgrades(["home", "greenhouse"])
		"Build": _fill_buildings()
		"Pantry": _fill_stock(true)
		"Decor": _fill_stock(false)
		"Hats": _fill_hats()
		"Wares": _fill_buy()
		"Request": _fill_request()
		"Gift": _fill_gift()
		"Donate": _fill_donate()
		"Board": _fill_board()
		"Festival": _fill_festival()
		"Errands": _fill_errands()
		"Projects": _fill_projects()


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
	picture.texture = Assets.texture("res://assets/sprites/items/%s%s.png" % [GameState.base_of(id), "_seeds" if seeds else ""])
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
		have = GameState.total_of(asked)  # any quality will do
		_row(_item_icon(asked, false), "Wanted: %d %s" % [amount, GameState.name_of(asked)], "Bristle pays double. You have %d." % have, str(int(GameState.wanted["reward"])), [
			_button("Deliver", have >= amount, func() -> void: GameState.request_deliver(me), "Just what I was after. Thank you!"),
		])
	for id: String in GameState.sellable_ids():
		var each: int = GameState.sell_price_of(id)
		var count: int = GameState.stock_of(id)
		if each <= 0 or count <= 0:
			continue
		any = true
		var title: String = GameState.name_of(id)
		_row(_item_icon(id, false), "%s x%d" % [title, count], "", "%d each" % each, [
			_button("Sell 1", true, func() -> void: GameState.request_sell(me, id, 1), "A fine %s!" % title),
			_button("Sell all (%d)" % (each * count), true, func() -> void: GameState.request_sell(me, id, count), "Lovely, I'll take the lot."),
		])
	if GameState.festival_today() == 2:
		_list.add_child(Ui.label("Harvest Fair today: everything sells for half as much again!", Ui.ACCENT, 5))
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
		var have: String = GameState.HOME_NAMES[level] if kind == "home" else (GameState.UPGRADES[kind][level - 1]["name"] if level > 0 else {"hoe": "Hoe", "can": "Watering Can"}.get(kind, "nothing yet"))
		var icon: Control = null
		if kind == "home":
			var house := TextureRect.new()
			house.texture = Assets.texture("res://assets/sprites/home_%d.png" % mini(level + 1, 2))
			house.custom_minimum_size = Vector2(24, 24)
			house.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			house.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon = house
		else:
			# The tool as it will look once bought.
			var column: int = int({"hoe": 0, "can": 1, "pickaxe": 4}.get(kind, 0))
			var tier: int = mini(level + 1, 2) if kind != "pickaxe" else 0
			icon = Ui.picture(Assets.texture("res://assets/sprites/tools.png"), Rect2(column * 16, tier * 16, 16, 16)) if kind != "greenhouse" else null
		if next.is_empty():
			_row(icon, have, "The best there is. Nothing more to buy.", "", [])
			continue
		var cost: int = next["cost"]
		_row(icon, next["name"], "%s. You have: %s." % [next["blurb"], have], str(cost), [
			_button("Buy", GameState.coins >= cost, func() -> void: GameState.request_buy_upgrade(me, kind), "Built to last. Enjoy!"),
		])


func _fill_animals() -> void:
	var me: int = player.get("player_id")
	if GameState.upgrade_level("coop") == 0 or GameState.upgrade_level("barn") == 0:
		_list.add_child(Ui.label("Birch the carpenter builds coops and barns.", Ui.FAINT, 5))
	for kind: String in GameState.ANIMALS.keys():
		var info: Dictionary = GameState.ANIMALS[kind]
		var have: int = GameState.animal_count(kind)
		var can: bool = GameState.upgrade_level(info["home"]) > 0 and have < int(info["max"]) and GameState.coins >= int(info["cost"])
		_row(_item_icon(kind, false), info["name"], "Feed and stroke daily for %s. You have %d of %d." % [GameState.name_of(info["gives"]).to_lower(), have, int(info["max"])], str(int(info["cost"])), [
			_button("Buy", can, func() -> void: GameState.request_buy_animal(me, kind), "Look after her well!"),
		])
	_row(_item_icon("feed", false), "Animal Feed", "One helping. Or make it from fiber. You have %d." % GameState.item_count("feed"), "10", [
		_button("Buy 5", GameState.coins >= 50, func() -> void: GameState.request_buy_item(me, "feed", 5), "Hungry mouths, eh?"),
	])


## Birch builds the coop and the barn.
func _fill_buildings() -> void:
	var me: int = player.get("player_id")
	for kind: String in ["coop", "barn"]:
		var step: Dictionary = GameState.UPGRADES[kind][0]
		var built: bool = GameState.upgrade_level(kind) > 0
		var house := TextureRect.new()
		house.texture = Assets.texture("res://assets/sprites/%s.png" % kind)
		house.custom_minimum_size = Vector2(24, 20)
		house.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		house.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if built:
			_row(house, step["name"], "Built.", "", [])
		else:
			_row(house, step["name"], "%s." % step["blurb"], str(int(step["cost"])), [
				_button("Build", GameState.coins >= int(step["cost"]), func() -> void: GameState.request_buy_upgrade(me, kind), "I'll have it up in no time."),
			])


## Things sold one at a time: baking supplies (pantry) or furniture, the oven
## and saplings (decor).
func _fill_stock(pantry: bool) -> void:
	var me: int = player.get("player_id")
	if pantry:
		_list.add_child(Ui.label("For baking. Wheat, apples and bananas you grow yourself.", Ui.FAINT, 5))
	for id: String in GameState.ITEMS.keys():
		var info: Dictionary = GameState.ITEMS[id]
		var cost: int = int(info.get("cost", 0))
		if cost <= 0 or id == "feed" or bool(info.get("pantry", false)) != pantry:
			continue
		if not pantry and _sold_elsewhere(id):
			continue  # furniture is Birch's, the oven Juniper's
		var note: String = "%s You have %d." % [info["blurb"], GameState.item_count(id)]
		_row(_item_icon(id, false), info["name"], note, str(cost), [
			_button("Buy", GameState.coins >= cost, func() -> void: GameState.request_buy_item(me, id, 1), "Fresh in this morning." if pantry else "Hold it (4) and press Space to set it down."),
		])


func _fill_hats() -> void:
	var me: int = player.get("player_id")
	for hat: String in GameState.HAT_ORDER:
		var info: Dictionary = GameState.HATS[hat]
		if bool(info.get("reward", false)) and not GameState.hats_owned.has(hat):
			continue  # earned, not sold
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


func _sold_elsewhere(id: String) -> bool:
	for who: String in GameState.TOWNSFOLK.keys():
		if who != "bristle" and GameState.TOWNSFOLK[who]["sells"].has(id):
			return true
	return false


## What this keeper pays extra for.
func _fill_sell_to() -> void:
	var me: int = player.get("player_id")
	var any: bool = false
	for id: String in GameState.sellable_ids():
		var each: int = GameState.price_at(keeper, id)
		var count: int = GameState.stock_of(id)
		if each <= 0 or count <= 0:
			continue
		any = true
		var title: String = GameState.name_of(id)
		_row(_item_icon(id, false), "%s x%d" % [title, count], "Bristle would pay %d." % GameState.sell_price_of(id), "%d each" % each, [
			_button("Sell 1", true, func() -> void: GameState.request_sell_to(me, keeper, id, 1), "Just the thing."),
			_button("Sell all", true, func() -> void: GameState.request_sell_to(me, keeper, id, count), "I'll take every one!"),
		])
	if not any:
		var wanted: Array = []
		for id: String in GameState.TOWNSFOLK[keeper]["buys"]:
			wanted.append(GameState.name_of(id))
		_list.add_child(Ui.label("I pay extra for: %s." % ", ".join(wanted), Ui.FAINT, 5))


## What this keeper sells.
func _fill_buy() -> void:
	var me: int = player.get("player_id")
	var stock: Dictionary = GameState.TOWNSFOLK[keeper]["sells"]
	for id: String in stock.keys():
		var cost: int = int(stock[id])
		var info: Dictionary = GameState.ITEMS.get(id, {})
		var note: String = "%s You have %d." % [info.get("blurb", ""), GameState.item_count(id)]
		var buttons: Array = [_button("Buy", GameState.coins >= cost, func() -> void: GameState.request_buy_from(me, keeper, id, 1), "Thank you kindly!")]
		if str(info.get("kind", "")) == "material" or str(info.get("kind", "")) == "fish":
			buttons.append(_button("Buy 5", GameState.coins >= cost * 5, func() -> void: GameState.request_buy_from(me, keeper, id, 5), "A good stock of it."))
		_row(_item_icon(id, false), str(info.get("name", id)), note, str(cost), buttons)


## This keeper's request, if they have one.
func _fill_request() -> void:
	var me: int = player.get("player_id")
	var wish: Dictionary = GameState.town_request(keeper)
	if wish.is_empty():
		_list.add_child(Ui.label("Nothing I need just now. Come back another day!", Ui.FAINT, 5))
		return
	var id: String = wish["id"]
	var have: int = GameState.total_of(id)
	_row(_item_icon(id, false), "Wanted: %d %s" % [int(wish["count"]), GameState.name_of(id)], "You have %d. Pays well, and makes a friend." % have, str(int(wish["coins"])), [
		_button("Hand over", have >= int(wish["count"]), func() -> void: GameState.request_town_request(me, keeper), "Oh, wonderful. Thank you!"),
	])


## A gift a day for this keeper.
func _fill_gift() -> void:
	var me: int = player.get("player_id")
	var given: bool = bool(GameState.friends.get(keeper, {}).get("gifted", false))
	var info: Dictionary = GameState.TOWNSFOLK[keeper]
	var any: bool = false
	for id: String in GameState.sellable_ids():
		any = true
		var base: String = GameState.base_of(id)
		var hint: String = "A favourite!" if info["loves"].has(base) and GameState.hearts(keeper) >= 1 else ""
		_row(_item_icon(id, false), "%s x%d" % [GameState.name_of(id), GameState.stock_of(id)], hint, "", [
			_button("Give", not given, func() -> void: GameState.request_gift(me, keeper, id), "For me? How kind."),
		])
	if given:
		_list.add_child(Ui.label("One gift a day. Come back tomorrow!", Ui.FAINT, 5))
	elif not any:
		_list.add_child(Ui.label("Nothing to give yet. Harvest, fish and meals make good gifts.", Ui.FAINT, 5))


## The museum's collection: donate one of each.
func _fill_donate() -> void:
	var me: int = player.get("player_id")
	_list.add_child(Ui.label("The collection: %d of %d. Thank-you gifts at 3, 6, 9, 13 and 17." % [GameState.town["museum"].size(), GameState.MUSEUM.size()], Ui.FAINT, 5))
	for id: String in GameState.MUSEUM:
		var title: String = GameState.name_of(id)
		if GameState.donated(id):
			_row(_item_icon(id, false), title, "On display. Thank you!", "", [])
		elif GameState.total_of(id) > 0:
			_row(_item_icon(id, false), title, "You have one to give.", "", [
				_button("Donate", true, func() -> void: GameState.request_donate(me, id), "Hoo! Splendid!"),
			])
		else:
			_row(null, "???", str(GameState.ITEMS.get(id, {}).get("blurb", "")), "", [])


## The festival, run by the mayor in the plaza: the show, the fireflies,
## the fair's display or the sky lanterns.
func _fill_festival() -> void:
	var me: int = player.get("player_id")
	var state: Dictionary = GameState.festival_state()
	match GameState.festival_today():
		0:
			var entered: String = str(state["entries"].get(str(me), ""))
			if entered != "":
				_list.add_child(Ui.label("Your %s is in the show. Judging is tonight: %d coins for the best, %d for every other entry." % [GameState.name_of(entered), GameState.SHOW_FIRST, GameState.SHOW_PLACED], Ui.FAINT, 5))
				return
			_list.add_child(Ui.label("Enter one harvest. The finest (silver and gold count!) wins %d coins." % GameState.SHOW_FIRST, Ui.FAINT, 5))
			_fill_entries("Enter", "Lovely! Good luck tonight.")
		1:
			var caught: int = GameState.fireflies_caught(me)
			_list.add_child(Ui.label("Fireflies hover over the plaza. Face one and press F to catch it. Catch %d for a Firefly Jar." % GameState.FIREFLY_JAR, Ui.FAINT, 5))
			_row(_item_icon("firefly_jar", false), "Caught tonight: %d" % caught, "A jar is yours!" if caught >= GameState.FIREFLY_JAR else "%d more for a jar" % (GameState.FIREFLY_JAR - caught), "", [])
		2:
			var display: Dictionary = state["display"]
			_list.add_child(Ui.label("The town's display: %d of %d kinds. Tonight each pays %d coins to everyone, more for silver and gold." % [display.size(), GameState.FAIR_KINDS, GameState.FAIR_PER_KIND], Ui.FAINT, 5))
			for base: String in display.keys():
				_row(_item_icon(display[base], false), GameState.name_of(display[base]), "On display", "", [])
			if display.size() < GameState.FAIR_KINDS:
				_fill_entries("Display", "That's a fine one for the display!", display.keys())
		3:
			var lanterns: int = int(state["lanterns"])
			_list.add_child(Ui.label("Send up %d sky lanterns tonight for a gift from the town. %d so far." % [GameState.SKY_LANTERNS, lanterns], Ui.FAINT, 5))
			_row(_item_icon("lantern", false), "Garden Lantern x%d" % GameState.item_count("lantern"), "Light it and let it go", "", [
				_button("Send up", GameState.item_count("lantern") > 0, func() -> void: GameState.request_sky_lantern(me), "Oh, look at it go!"),
			])


## A row for each harvest in the backpack, with a button to put it in.
func _fill_entries(verb: String, thanks: String, skip: Array = []) -> void:
	var me: int = player.get("player_id")
	var any: bool = false
	for id: String in GameState.sellable_ids():
		if not GameState.species.has(GameState.base_of(id)) or skip.has(GameState.base_of(id)):
			continue
		any = true
		_row(_item_icon(id, false), "%s x%d" % [GameState.name_of(id), GameState.stock_of(id)], "", "", [
			_button(verb, true, func() -> void: GameState.request_show_entry(me, id), thanks),
		])
	if not any:
		_list.add_child(Ui.label("No harvest in your backpack to put in.", Ui.FAINT, 5))


## Errands on the town hall's board: take one on, then see it through.
func _fill_errands() -> void:
	var me: int = player.get("player_id")
	if GameState.town["errands"].is_empty():
		_list.add_child(Ui.label("No errands today. New ones go up most mornings.", Ui.FAINT, 5))
	for index in GameState.town["errands"].size():
		var errand: Dictionary = GameState.town["errands"][index]
		var taken: bool = bool(errand["taken"])
		var note: String = "Under way: talk to %s when you have it." % GameState.person(errand["to"])["name"] if taken else "Pays %d coins, and makes friends." % int(errand["coins"])
		_row(_item_icon(errand["id"], false), GameState.errand_text(errand), note, str(int(errand["coins"])), [
			_button("Take it on", not taken, func() -> void: GameState.request_errand(me, index), "Thank you! The town runs on helping hands."),
		])


## The town projects board: give what you have towards each project.
func _fill_projects() -> void:
	var me: int = player.get("player_id")
	for project: String in Stories.PROJECTS.keys():
		var info: Dictionary = Stories.PROJECTS[project]
		if GameState.project_built(project):
			_row(null, "%s: built!" % info["name"], info["text"], "", [])
			continue
		_row(null, info["name"], "%s Everyone gets %d coins when it's built." % [info["text"], int(info["coins"])], "", [])
		for id: String in info["needs"].keys():
			var left: int = GameState.project_needs(project, id)
			var have: int = GameState.total_of(id)
			_row(_item_icon(id, false), "  %s: %d of %d given" % [GameState.name_of(id), int(info["needs"][id]) - left, int(info["needs"][id])], "You have %d" % have if left > 0 else "Done", "", [
				_button("Give", left > 0 and have > 0, func() -> void: GameState.request_contribute(me, project, id), "Every bit helps!"),
			])


## The town's notice board, at the town hall.
func _fill_board() -> void:
	var me: int = player.get("player_id")
	if GameState.quests.is_empty():
		_list.add_child(Ui.label("No requests on the board today.", Ui.FAINT, 5))
	for index in GameState.quests.size():
		var quest: Dictionary = GameState.quests[index]
		var id: String = quest["id"]
		var who: String = str(GameState.person(str(quest["who"])).get("name", "Bristle"))
		var have: int = GameState.total_of(id)
		_row(_item_icon(id, false), "%s wants %d %s" % [who, int(quest["count"]), GameState.name_of(id)], "%d days left. You have %d." % [int(quest["days"]), have], str(int(quest["coins"])), [
			_button("Hand in", have >= int(quest["count"]), func() -> void: GameState.request_quest(me, index), "The town thanks you!"),
		])
