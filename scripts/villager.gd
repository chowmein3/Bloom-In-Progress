extends CanvasLayer
## Talking to today's visitor: a line of chat (worth a little friendship once
## a day), their hearts, and a list of things from the backpack to give them.

const Assets := preload("res://scripts/assets.gd")
const Ui := preload("res://scripts/ui_style.gd")

var player: Node2D

var _root: Control
var _face: TextureRect
var _name: Label
var _hearts: Label
var _line: Label
var _list: VBoxContainer
var _who: String = ""


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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 5)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(32, 48)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	header.add_child(_face)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name = Ui.label("", Ui.ACCENT, 10)
	words.add_child(_name)
	_hearts = Ui.label("", Ui.ACCENT)
	words.add_child(_hearts)
	_line = Ui.label("")
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(150, 20)
	words.add_child(_line)
	header.add_child(words)
	box.add_child(header)
	box.add_child(Ui.label("Give a gift (one a day):", Ui.FAINT))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(200, 62)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	box.add_child(scroll)
	box.add_child(Ui.label("Esc to close", Ui.FAINT))
	GameState.inventory_changed.connect(_rebuild)
	GameState.economy_changed.connect(_rebuild)
	GameState.notice.connect(func(text: String) -> void:
		if visible:
			_line.text = text)


## Talk to `who` (a villager in town), or by default today's visitor.
func open(who_id: String = "") -> void:
	_who = who_id if who_id != "" else GameState.visitor_today()
	if visible or _who == "" or player == null or bool(player.get("reading")):
		return
	visible = true
	player.set("reading", true)
	Sound.play("page")
	var who: Dictionary = GameState.person(_who)
	var lines: Array = who["lines"]
	_line.text = lines[(TimeManager.day_index + GameState.hearts(_who)) % lines.size()]
	_face.texture = Assets.texture("res://assets/sprites/villager_%s.png" % _who)
	GameState.request_talk(player.get("player_id"), _who)  # the day's chat
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
	if not visible or not GameState.VILLAGERS.has(_who):
		return
	var who: Dictionary = GameState.person(_who)
	var friend: Dictionary = GameState.friends.get(_who, {})
	_name.text = "%s, %s" % [who["name"], who["what"]]
	var full: int = GameState.hearts(_who)
	_hearts.text = "Hearts: %d of %d   (%d points to the next)" % [full, GameState.MAX_HEARTS, 100 - int(friend.get("points", 0)) % 100] if full < GameState.MAX_HEARTS else "Hearts: %d of %d. Best of friends!" % [full, full]
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var me: int = player.get("player_id")
	var given: bool = bool(friend.get("gifted", false))
	var any: bool = false
	var gifts: Array = GameState.sellable_ids()
	for id: String in _meals():
		if not gifts.has(id):
			gifts.append(id)
	for id: String in gifts:
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = Assets.texture("res://assets/sprites/items/%s.png" % GameState.base_of(id))
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var words: Label = Ui.label("%s x%d" % [GameState.name_of(id), GameState.stock_of(id)])
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var give := Button.new()
		give.text = "Give"
		give.disabled = given
		give.pressed.connect(func() -> void: GameState.request_gift(me, _who, id))
		row.add_child(give)
		_list.add_child(row)
	if not any:
		_list.add_child(Ui.label("Nothing to give yet. Harvest, fish and\nmeals all make gifts.", Ui.FAINT))


func _meals() -> Array:
	var out: Array = []
	for id: String in GameState.items.keys():
		if GameState.item_count(id) > 0 and str(GameState.ITEMS.get(id, {}).get("kind", "")) == "meal":
			out.append(id)
	return out
