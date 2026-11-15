extends CanvasLayer
## The backpack (E): the garden's shared seeds and harvest in a grid, the
## purse, and the player's own corner: who they are, what the garden owns,
## and which hat they wear. Click a seed packet to hold those seeds.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")
const COLUMNS := 8
const SLOTS := 16
const SEASONS: Array[String] = ["Spring", "Summer", "Fall", "Winter"]

var player: Node2D

var _root: Control
var _grid: GridContainer
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
	box.add_theme_constant_override("separation", 3)
	Ui.popup(_root).add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 3)
	header.add_child(Ui.label("Backpack", Ui.ACCENT, 10))
	header.add_child(Ui.spacer())
	header.add_child(Ui.picture(_icons, Rect2(10 * 12, 0, 12, 12)))
	_coins = Ui.label("", Ui.INK, 8)
	header.add_child(_coins)
	box.add_child(header)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 1)
	_grid.add_theme_constant_override("v_separation", 1)
	box.add_child(_grid)
	_info = Ui.label("", Ui.FAINT)
	_info.custom_minimum_size.y = 9
	box.add_child(_info)

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
	about.add_theme_constant_override("separation", 0)
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
	box.add_child(lower)
	box.add_child(Ui.label("E or Esc to close", Ui.FAINT))

	GameState.inventory_changed.connect(_rebuild)
	GameState.economy_changed.connect(_rebuild)
	GameState.state_reloaded.connect(_rebuild)


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


func close() -> void:
	visible = false
	player.set("reading", false)
	Sound.play("page")


func _rebuild() -> void:
	if not visible:
		return
	_coins.text = str(GameState.coins)
	_info.text = "Seeds and harvest are shared by the whole garden."
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var shown: int = 0
	for id: String in GameState.species.keys():
		if GameState.seed_count(id) > 0:
			_add_slot(id, true)
			shown += 1
	for id: String in GameState.species.keys():
		if int(GameState.produce.get(id, 0)) > 0:
			_add_slot(id, false)
			shown += 1
	while shown < SLOTS or shown % COLUMNS != 0:
		var empty := Panel.new()
		empty.custom_minimum_size = Vector2(20, 20)
		empty.add_theme_stylebox_override("panel", Ui.box(Ui.SLOT))
		_grid.add_child(empty)
		shown += 1

	var me: int = player.get("player_id")
	_title.text = GameState.garden_name
	var tools: Array = []
	for kind: String in ["hoe", "can"]:
		var level: int = GameState.upgrade_level(kind)
		tools.append(GameState.UPGRADES[kind][level - 1]["name"] if level > 0 else ("Hoe" if kind == "hoe" else "Watering Can"))
	_facts.text = "%s %d, Year %d\nHome: %s\n%s" % [
		TimeManager.season_name(), TimeManager.day_of_season(), TimeManager.year(),
		GameState.HOME_NAMES[GameState.home_level()], ", ".join(tools),
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
		button.tooltip_text = GameState.HATS[hat]["name"]
		if wearing:
			button.add_theme_stylebox_override("normal", Ui.box(Color(1.0, 0.95, 0.8), Ui.ACCENT))
		button.pressed.connect(func() -> void: GameState.request_wear(me, hat))
		button.mouse_entered.connect(func() -> void: _info.text = "%s%s" % [GameState.HATS[hat]["name"], "  (wearing)" if wearing else ""])
		_hat_row.add_child(button)
	_portrait.queue_redraw()


func _add_slot(id: String, is_seed: bool) -> void:
	var d: Resource = GameState.species[id]
	var count: int = GameState.seed_count(id) if is_seed else int(GameState.produce.get(id, 0))
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(20, 20)
	slot.icon = Assets.texture("res://assets/sprites/items/%s%s.png" % [id, "_seeds" if is_seed else ""])
	slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var holding: bool = is_seed and str(player.get("seed_id")) == id
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
	if is_seed:
		var seasons: Array = []
		for s: int in d.seasons:
			seasons.append(SEASONS[s])
		words = "%s seeds x%d. Grows in %s. %s" % [d.display_name, count, " & ".join(seasons), "In your hand." if holding else "Click to hold."]
		slot.pressed.connect(func() -> void:
			player.call("hold_seed", id)
			_rebuild())
	else:
		words = "%s x%d. Bristle pays %d coins each." % [d.display_name, count, int(d.sell_price)]
	slot.mouse_entered.connect(func() -> void: _info.text = words)
	_grid.add_child(slot)


## The player as they look now, twice life size.
func _draw_portrait() -> void:
	var me: int = player.get("player_id")
	var body: Texture2D = Assets.texture("res://assets/sprites/player_%d.png" % clampi(me, 1, 2))
	_portrait.draw_texture_rect_region(body, Rect2(0, 0, 32, 48), Rect2(0, 0, 16, 24))
	var hat: int = GameState.HAT_ORDER.find(GameState.hat_of(me))
	if hat >= 0:
		_portrait.draw_texture_rect_region(_hats, Rect2(0, 0, 32, 24), Rect2(hat * 16, 0, 16, 12))
