extends CanvasLayer
## The backpack (E). Three tabs:
##   Items    - this player's own seeds, harvest, materials and made things
##              in a grid, plus their corner (portrait, hats).
##              Click seeds, placeable things or meals to hold them.
##   Crafting - recipes made from gathered materials.
##   Kitchen  - meals cooked from the harvest (needs the Cabin's stove).
##   Oven     - baking (needs an oven set down in the home).
## On the Items tab, drag a stack to move it (onto the hot bar row puts it on
## the tool bar), or out of the backpack to drop it on the ground.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")
const TABS: Array[String] = ["Items", "Crafting", "Kitchen", "Oven"]
const COLUMNS := 10
const MIN_SLOTS := 30
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

var player: Node2D
var tab: String = "Items"

var _root: Control
var _tab_row: HBoxContainer
var _items_page: VBoxContainer
var _recipes_page: ScrollContainer
var _recipes: VBoxContainer
var _grid: GridContainer
var _bar: HBoxContainer
var _order: Array = []  # what each bag slot holds right now (0-3: hot bar)
var _info: Label
var _coins: Label
var _facts: Label
var _title: Label
var _portrait: Control
var _hat_row: HBoxContainer
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
	box.add_theme_constant_override("separation", 2)
	Ui.popup(_root).add_child(box)
	# Dragging something out of the panel onto the backdrop drops it.
	var shade: Control = _root.get_child(0)
	shade.set_drag_forwarding(Callable(), func(_at: Vector2, data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("key"), _drop_outside)
	(_root.get_child(1) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.add_child(Ui.label("Backpack", Ui.ACCENT, 10))
	header.add_child(Ui.label("  E or Esc to close", Ui.FAINT))
	header.add_child(Ui.spacer())
	header.add_child(Ui.picture(_icons, Rect2(10 * 12, 0, 12, 12)))
	_coins = Ui.label("", Ui.INK, 8)
	header.add_child(_coins)
	box.add_child(header)
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 1)
	box.add_child(_tab_row)
	_info = Ui.label("", Ui.FAINT)
	_info.custom_minimum_size = Vector2(212, 9)
	_info.clip_text = true

	# --- Items page
	_items_page = VBoxContainer.new()
	_items_page.add_theme_constant_override("separation", 2)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 1)
	_items_page.add_child(_bar)
	var grid_scroll := ScrollContainer.new()  # three rows show; more scroll
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.custom_minimum_size = Vector2(218, 43)
	grid_scroll.add_child(_grid)
	_items_page.add_child(grid_scroll)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 6)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(32, 48)
	_portrait.draw.connect(_draw_portrait)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", Ui.box(Color(0.72, 0.87, 0.95)))
	frame.add_child(_portrait)
	lower.add_child(frame)
	var about := VBoxContainer.new()
	about.add_theme_constant_override("separation", -1)
	about.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Ui.label("", Ui.ACCENT, 8)
	about.add_child(_title)
	_facts = Ui.label("")
	about.add_child(_facts)
	about.add_child(Ui.label("Hats (click to wear):", Ui.FAINT))
	_hat_row = HBoxContainer.new()
	_hat_row.add_theme_constant_override("separation", 1)
	about.add_child(_hat_row)
	lower.add_child(about)
	_items_page.add_child(lower)
	box.add_child(_items_page)

	# --- Crafting and Kitchen page
	_recipes_page = ScrollContainer.new()
	_recipes_page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipes_page.custom_minimum_size = Vector2(212, 104)
	_recipes = VBoxContainer.new()
	_recipes.add_theme_constant_override("separation", 1)
	_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipes_page.add_child(_recipes)
	box.add_child(_recipes_page)
	box.add_child(_info)

	GameState.inventory_changed.connect(_rebuild)
	GameState.economy_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)
	GameState.notice.connect(func(text: String) -> void:
		if visible:
			_info.text = text)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or bool(player.get("in_menu")):
		return
	if visible and (event.is_action_pressed("toggle_inventory") or event.is_action_pressed("close")):
		close()
		get_viewport().set_input_as_handled()
	elif not visible and event.is_action_pressed("toggle_inventory") and not bool(player.get("reading")):
		visible = true
		player.set("reading", true)
		Sound.play("page")
		_rebuild()
		get_viewport().set_input_as_handled()


## Open the backpack straight onto one of its tabs (the oven does this).
func open_tab(which: String) -> void:
	if visible or player == null or bool(player.get("reading")):
		return
	tab = which
	visible = true
	player.set("reading", true)
	Sound.play("page")
	_rebuild()


func close() -> void:
	visible = false
	player.set("reading", false)
	Sound.play("page")


func show_tab(new_tab: String) -> void:
	tab = new_tab
	_rebuild()


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
	_items_page.visible = tab == "Items"
	_recipes_page.visible = tab != "Items"
	if tab == "Items":
		_info.text = "Your own things. Drag to move them, or out of the backpack to drop them."
		_fill_items()
	else:
		_info.text = "Level up by caring for plants and harvesting." if tab == "Crafting" else "Meals restore energy. Hold one (4) and press Space."
		if tab == "Oven":
			_info.text = "Baked goods restore lots of energy and sell well."
		_fill_recipes({"Crafting": "", "Kitchen": "kitchen", "Oven": "oven"}[tab])


# ------------------------------------------------------------ items page

func _fill_items() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_order = GameState.bag_slots()
	for i in range(GameState.HOT_SLOTS, _order.size()):
		_grid.add_child(_slot_at(i))
	_fill_hot_bar()

	var me: int = player.get("player_id")
	_title.text = GameState.garden_name
	var next: int = GameState.next_level_xp()
	var skill: String = "Gardening level %d" % GameState.garden_level()
	skill += "  (%d/%d)" % [GameState.xp, next] if next > 0 else "  (the best!)"
	_facts.text = "%s %d, Year %d.  Home: %s\n%s" % [
		TimeManager.season_name(), TimeManager.day_of_season(), TimeManager.year(),
		GameState.HOME_NAMES[GameState.home_level()], skill,
	]
	for child: Node in _hat_row.get_children():
		_hat_row.remove_child(child)
		child.queue_free()
	for hat: String in GameState.HAT_ORDER:
		if not GameState.hats_owned.has(hat):
			continue
		var wearing: bool = GameState.hat_of(me) == hat
		var button := Button.new()
		button.custom_minimum_size = Vector2(22, 16)
		var frame := AtlasTexture.new()
		frame.atlas = _hats
		frame.region = Rect2(GameState.HAT_ORDER.find(hat) * 16, 0, 16, 12)
		button.icon = frame
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if wearing:
			button.add_theme_stylebox_override("normal", Ui.box(Color(1.0, 0.95, 0.8), Ui.ACCENT))
		button.pressed.connect(func() -> void: GameState.request_wear(me, hat))
		button.mouse_entered.connect(func() -> void: _info.text = "%s%s" % [GameState.HATS[hat]["name"], "  (wearing)" if wearing else ""])
		_hat_row.add_child(button)
	_portrait.queue_redraw()


## The button for bag slot `index`: drag it anywhere in the backpack to move
## the whole stack (swapping with what is there), or out of the backpack to
## drop it on the ground in front of you.
func _slot_at(index: int) -> Control:
	var key: String = _order[index]
	var slot: Control
	if key == "":
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(20, 20)
		empty.add_theme_stylebox_override("panel", Ui.box(Ui.SLOT))
		slot = empty
	else:
		slot = _add_slot(key.get_slice(":", 1), key.get_slice(":", 0))
	slot.set_drag_forwarding(_drag_from_bag.bind(index), _can_drop.bind(index), _drop_on_bag.bind(index))
	return slot


## What is being dragged: {"key": "seed:sunpuff", "from": slot index}.
func _drag_from_bag(_at: Vector2, index: int) -> Variant:
	var key: String = _order[index]
	if key == "":
		return null
	var ghost := TextureRect.new()
	ghost.texture = Assets.texture("res://assets/sprites/items/%s%s.png" % [GameState.base_of(key.get_slice(":", 1)), "_seeds" if key.begins_with("seed:") else ""])
	ghost.custom_minimum_size = Vector2(16, 16)
	_root.set_drag_preview(ghost)
	return {"key": key, "from": index}


## Slots 0-3 (the hot bar) only take seeds and things you can hold.
func _can_drop(_at: Vector2, data: Variant, index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("from"):
		return false
	var from: int = int(data["from"])
	if index < GameState.HOT_SLOTS and not GameState.holdable(str(data["key"])):
		return false
	return not (from < GameState.HOT_SLOTS and _order[index] != "" and not GameState.holdable(_order[index]))


## Move the dragged stack to slot `index`, swapping with what is there.
func _drop_on_bag(_at: Vector2, data: Variant, index: int) -> void:
	if _can_drop(_at, data, index):
		GameState.request_move_slot(int(player.get("player_id")), int(data["from"]), index)


## Whether a hot bar slot takes this thing (kept for the tests and the HUD).
func bar_accepts(slot: int, key: String) -> bool:
	return slot >= GameState.HOT_SLOTS or GameState.holdable(key)


## Dragged out of the backpack: drop the whole stack on the tile ahead.
func _drop_outside(_at: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.has("key"):
		if bool(player.call("drop", str(data["key"]))):
			Sound.play("plant")
			_info.text = "Dropped. Walk over it to pick it up again."


## The hot bar: bag slots 0-3, on keys 7, 8, 9 and 0 and shown on the tool bar.
func _fill_hot_bar() -> void:
	for child: Node in _bar.get_children():
		_bar.remove_child(child)
		child.queue_free()
	_bar.add_child(Ui.label("Hot bar:", Ui.FAINT))
	for i in GameState.HOT_SLOTS:
		var slot: Control = _slot_at(i)
		var number: Label = Ui.label(["7", "8", "9", "0"][i], Ui.ACCENT, 5)
		number.position = Vector2(2, -1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(number)
		if _order[i] == "":
			slot.mouse_entered.connect(func() -> void: _info.text = "Hot bar slot (%s). Drag seeds or something to hold here." % ["7", "8", "9", "0"][i])
		_bar.add_child(slot)


## Builds (but does not add) the button for one thing. `sort` is "seed",
## "harvest" or "item".
func _add_slot(id: String, sort: String) -> Button:
	var count: int = GameState.seed_count(id) if sort == "seed" else GameState.stock_of(id)
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(20, 20)
	slot.icon = Assets.texture("res://assets/sprites/items/%s%s.png" % [GameState.base_of(id), "_seeds" if sort == "seed" else ""])
	var quality: String = GameState.quality_of(id)
	if quality != "":  # a silver or gold star in the corner
		var star := ColorRect.new()
		star.color = Color(1.0, 0.82, 0.25) if quality == "gold" else Color(0.82, 0.86, 0.92)
		star.position = Vector2(2, 2)
		star.size = Vector2(4, 4)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(star)
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var holding: bool = (sort == "seed" and str(player.get("seed_id")) == id) or (sort == "item" and str(player.get("item_id")) == id)
	if holding:
		slot.add_theme_stylebox_override("normal", Ui.box(Color(1.0, 0.95, 0.8), Ui.ACCENT))
	var number: Label = Ui.label(str(count), Color.WHITE, 5)
	number.add_theme_color_override("font_outline_color", Ui.INK)
	number.add_theme_constant_override("outline_size", 3)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.position = Vector2(0, 11)
	number.size = Vector2(19, 8)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(number)
	var words: String
	if sort == "seed":
		var d: Resource = GameState.species[id]
		var seasons: Array = []
		for s: int in d.seasons:
			seasons.append(SEASONS[s])
		words = "%s seeds x%d. Grows in %s. %s" % [d.display_name, count, " & ".join(seasons), "In your hand." if holding else "Click to hold."]
		slot.pressed.connect(func() -> void:
			player.call("hold_seed", id)
			_rebuild())
	elif sort == "harvest":
		words = "%s x%d. Bristle pays %d coins each." % [GameState.name_of(id), count, int(GameState.species[id].sell_price)]
	elif quality != "":
		words = "%s x%d. Sells for %d each." % [GameState.name_of(id), count, GameState.sell_price_of(id)]
	else:
		var info: Dictionary = GameState.ITEMS[id]
		words = "%s x%d. %s" % [info["name"], count, info["blurb"]]
		if int(info.get("price", 0)) > 0:
			words += " Sells for %d." % int(info["price"])
		if ["place", "soil", "meal", "decor"].has(str(info["kind"])):
			words += " In your hand (4)." if holding else " Click to hold."
			slot.pressed.connect(func() -> void:
				player.call("hold_item", id)
				_rebuild())
	slot.mouse_entered.connect(func() -> void: _info.text = words)
	return slot


## The player as they look now, twice life size.
func _draw_portrait() -> void:
	var me: int = player.get("player_id")
	var body: Texture2D = Assets.texture("res://assets/sprites/player_%d.png" % clampi(me, 1, 2))
	_portrait.draw_texture_rect_region(body, Rect2(0, 0, 32, 48), Rect2(0, 0, 16, 24))
	var hat: int = GameState.HAT_ORDER.find(GameState.hat_of(me))
	if hat >= 0:
		_portrait.draw_texture_rect_region(_hats, Rect2(0, 0, 32, 24), Rect2(hat * 16, 0, 16, 12))


# ---------------------------------------------------------- recipe pages

## `station` is "" for crafting, "kitchen" for the stove or "oven".
func _fill_recipes(station: String) -> void:
	var kitchen: bool = station != ""
	for child: Node in _recipes.get_children():
		_recipes.remove_child(child)
		child.queue_free()
	if station == "oven" and not GameState.has_oven():
		_recipes.add_child(Ui.label("Baking needs an oven.\nBristle sells one (Decor tab). Set it down in your home.", Ui.FAINT))
		return
	if station == "kitchen" and not GameState.has_kitchen():
		_recipes.add_child(Ui.label("Cooking needs a stove.\nThe Cabin has one: see Bristle's stall, Home.", Ui.FAINT))
		return
	var me: int = player.get("player_id")
	for id: String in GameState.RECIPES.keys():
		var recipe: Dictionary = GameState.RECIPES[id]
		var needs_station: String = "oven" if bool(recipe.get("oven", false)) else ("kitchen" if bool(recipe.get("kitchen", false)) else "")
		if needs_station != station:
			continue
		var problem: String = GameState.craft_problem(id)
		var needs: Array = []
		for part: String in recipe["needs"].keys():
			needs.append("%d %s (have %d)" % [int(recipe["needs"][part]), GameState.name_of(part), GameState.total_of(part)])
		var made: int = recipe["makes"]
		var title: String = "%s%s" % [GameState.name_of(id), " x%d" % made if made > 1 else ""]
		if GameState.item_count(id) > 0:
			title += "   (you have %d)" % GameState.item_count(id)
		var note: String = ", ".join(needs)
		if problem.begins_with("Needs"):
			note = problem

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = Assets.texture("res://assets/sprites/items/%s.png" % id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		if problem.begins_with("Needs"):
			icon.modulate = Color(0.3, 0.18, 0.12, 0.5)
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", -2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Ui.label(title))
		words.add_child(Ui.label(note, Ui.FAINT, 5))
		row.add_child(words)
		var make := Button.new()
		make.text = "Bake" if station == "oven" else ("Cook" if kitchen else "Make")
		make.disabled = problem != ""
		make.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		make.pressed.connect(func() -> void: GameState.request_craft(me, id))
		make.mouse_entered.connect(func() -> void: _info.text = str(GameState.ITEMS[id]["blurb"]))
		row.add_child(make)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Ui.box(Color(1.0, 0.96, 0.85), Color(0.8, 0.68, 0.5), 2))
		panel.add_child(row)
		panel.mouse_entered.connect(func() -> void: _info.text = str(GameState.ITEMS[id]["blurb"]))
		_recipes.add_child(panel)
