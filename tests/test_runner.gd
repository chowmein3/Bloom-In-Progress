extends Node
## Headless checks for the garden rules. Run with:
##   godot --headless --path . res://tests/test_runner.tscn

const P := 1
var failures: int = 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok    ", label)
	else:
		failures += 1
		print("  FAIL  ", label)


func _ready() -> void:
	TimeManager.paused = true
	Net.stop_lookup()
	Net.relay_url = ""  # never touch the real relay from a test
	GameState.wild_growth = false  # no surprise debris where a test wants to dig
	TimeManager.rain_chance = 0.0
	GameState.save_path = "user://test_save.json"
	GameState.register_player(P)
	GameState.new_game()
	var a := Vector2i(3, 5)
	var b := Vector2i(4, 5)

	print("soil and planting")
	check(not GameState.request_plant(P, a, "sunpuff"), "can't plant on untilled ground")
	check(GameState.request_till(P, a), "till")
	check(not GameState.request_till(P, a), "can't till twice")
	check(not GameState.request_till(P, Vector2i(13, 1)), "can't till under the tent")
	check(not GameState.request_till(P, Vector2i(-1, 0)), "can't till out of bounds")
	GameState.seeds["frostwhisker"] = 1
	check(not GameState.request_plant(P, a, "frostwhisker"), "winter plant refused in spring")
	check(GameState.request_plant(P, a, "sunpuff"), "plant sunpuff")
	check(GameState.seed_count("sunpuff") == 5, "seed used up")
	check(GameState.get_energy(P) == 97, "energy spent (2 till + 1 plant)")

	print("growth needs water")
	GameState.end_day(false)
	check(int(GameState.plants[a]["days_grown"]) == 0, "unwatered plant pauses")
	check(int(GameState.plants[a]["happiness"]) == 38, "neglect lowers mood")
	check(GameState.get_energy(P) == 100, "sleep restores energy")
	check(GameState.request_water(P, a), "water")
	check(not GameState.request_water(P, a), "can't water twice")
	GameState.end_day(false)
	check(int(GameState.plants[a]["days_grown"]) == 1, "watered plant grows")
	check(GameState.plant_stage(a) == 1, "stage advances after 1 day")
	check(not bool(GameState.soil[a]["watered"]), "soil dries overnight")

	print("affection")
	check(GameState.request_pet(P, a), "pet")
	check(not GameState.request_pet(P, a), "only one pet per player per day")
	GameState.request_water(P, a)
	GameState.end_day(false)
	check(int(GameState.plants[a]["happiness"]) == 38 + 4 + 4 + 8, "water + pet raise mood")
	check(GameState.request_pet(P, a), "can pet again next day")
	check(int(GameState.plants[a]["caretakers"]["1"]) >= 4, "caretaker actions are recorded")

	print("maturity and harvest")
	check(not GameState.request_harvest(P, a), "can't pick an unripe plant")
	for i in 3:
		GameState.request_water(P, a)
		GameState.end_day(false)
	check(GameState.plant_is_mature(a), "sunpuff matures after 5 watered days")
	check(GameState.request_harvest(P, a), "harvest")
	check(not GameState.plants.has(a), "single-harvest plant is removed")
	check(GameState.harvest_total("sunpuff") == 1, "produce gained")
	check(GameState.seed_count("sunpuff") >= 7, "seeds returned")

	print("regrowing plant")
	GameState.request_till(P, b)
	GameState.request_plant(P, b, "moonbell")
	for i in 7:
		GameState.plants[b]["happiness"] = 50  # keep growth spurts out of the test
		GameState.request_water(P, b)
		GameState.end_day(false)
	check(GameState.plant_is_ripe(b), "moonbell ripe after 7 watered days")
	check(GameState.request_harvest(P, b), "harvest moonbell")
	check(GameState.plants.has(b), "regrowing plant stays")
	check(not GameState.plant_is_ripe(b), "not ripe right after picking")
	for i in 3:
		GameState.request_water(P, b)
		GameState.end_day(false)
	check(GameState.plant_is_ripe(b), "ripe again after regrow_days")

	print("rain")
	TimeManager.rain_chance = 1.0
	GameState.end_day(false)
	check(TimeManager.raining, "rain day")
	check(bool(GameState.soil[b]["watered"]), "rain waters the soil")
	TimeManager.rain_chance = 0.0

	print("save and load")
	var before: String = JSON.stringify(GameState.to_snapshot())
	var day: int = TimeManager.day_index
	GameState.new_game()
	check(GameState.plants.is_empty() and TimeManager.day_index == 0, "new game clears the garden")
	check(GameState.load_game(), "load")
	check(TimeManager.day_index == day, "day restored")
	check(JSON.stringify(GameState.to_snapshot()) == before, "garden restored exactly")

	print("seasons")
	var mood: int = int(GameState.plants[b]["happiness"])
	while TimeManager.season() != 1:
		GameState.plants[b]["happiness"] = mood
		GameState.request_water(P, b)
		GameState.end_day(false)
	check(bool(GameState.plants[b]["dormant"]), "moonbell goes dormant in summer")
	GameState.end_day(false)
	check(GameState.plants.has(b), "dormant plant survives")
	check(int(GameState.plants[b]["happiness"]) == mood + 4, "dormant plant isn't hurt by neglect")

	print("duet and sleeping together")
	var c := Vector2i(6, 6)
	GameState.request_till(P, c)
	GameState.request_plant(P, c, "sunpuff")
	GameState.request_water(P, c)
	GameState.request_pet(P, c)
	check(GameState.request_pet(2, c), "a second player can pet the same plant")
	GameState.end_day(false)
	check(int(GameState.plants[c]["happiness"]) == 50 + 4 + 8 + 6, "two carers in one day give a duet bonus")
	check(GameState.plants[c]["caretakers"].has("2"), "the second carer is remembered")
	var today: int = TimeManager.day_index
	GameState.request_sleep(P)
	check(TimeManager.day_index == today + 1 and GameState.sleeping.is_empty(), "alone, sleeping ends the day at once")

	print("heart tree and journal")
	GameState.new_game()
	var t := Vector2i(9, 4)
	var bed := Vector2i(3, 9)
	check(GameState.is_blocked(t) and not GameState.request_till(P, t), "the tree's ground can't be tilled")
	check(GameState.journal_level("sunpuff") == 0, "journal starts empty")
	GameState.request_till(P, bed)
	GameState.request_plant(P, bed, "sunpuff")
	check(GameState.journal_level("sunpuff") == GameState.JOURNAL_PLANTED, "planting is noted in the journal")
	GameState.request_water(P, bed)
	check(GameState.request_water(P, t) and not GameState.request_water(P, t), "tree can be watered once a day")
	check(GameState.request_pet(P, t) and not GameState.request_pet(P, t), "tree can be hugged once a day per player")
	check(GameState.request_pet(2, t), "a second player can hug it too")
	GameState.end_day(false)
	check(int(GameState.tree["love"]) == 1 + 3 + 2 + 2, "love = 1 cared plant + 3 watered + 2 per hug")
	check(not bool(GameState.tree["watered"]) and GameState.tree["hugged_by"].is_empty(), "tree care resets each morning")
	check(GameState.tree_stage() == 0 and GameState.seed_count("pricklepal") == 0, "still a seed, no gift yet")
	GameState.tree["love"] = 39
	GameState.request_water(P, t)
	var news: Array = [{}]
	GameState.day_advanced.connect(func(summary: Dictionary) -> void: news[0] = summary, CONNECT_ONE_SHOT)
	GameState.end_day(false)
	check(GameState.tree_stage() == 1, "tree reaches the sprout stage at 40 love")
	check(GameState.seed_count("pricklepal") == 3, "growing drops gift seeds")
	check(int(news[0]["tree"].get("stage", 0)) == 1 and str(news[0]["tree"]["gifts"]) == "3 Pricklepal seeds", "morning summary announces it")
	for i in 6:
		GameState.plants[bed]["happiness"] = 50
		GameState.request_water(P, bed)
		GameState.day_advanced.connect(func(summary: Dictionary) -> void: news[0] = summary, CONNECT_ONE_SHOT)
		GameState.end_day(false)
		if GameState.plant_is_mature(bed):
			break
	check(GameState.journal_level("sunpuff") == GameState.JOURNAL_BLOOMED, "first bloom is noted")
	check(news[0]["discoveries"] == ["Sunpuff bloomed for the first time"], "and announced once")
	GameState.plants[bed]["happiness"] = 100
	GameState.end_day(false)
	check(GameState.journal_level("sunpuff") == GameState.JOURNAL_RADIANT, "first radiant bloom is noted")
	var kept: String = JSON.stringify(GameState.to_snapshot())
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(JSON.stringify(GameState.to_snapshot()) == kept, "tree and journal survive save and load")
	GameState.tree["love"] = 1000
	check(GameState.tree_stage() == 4 and GameState.tree_next_goal() == -1, "tree tops out at full bloom")

	print("save files")
	GameState.saves_dir = "user://test_saves"
	for old: Dictionary in GameState.list_gardens():
		GameState.delete_garden(old["path"])
	check(GameState.list_gardens().is_empty(), "no gardens to begin with")
	GameState.create_garden("  Rose Corner  ")
	var first: String = GameState.save_path
	check(GameState.garden_name == "Rose Corner" and FileAccess.file_exists(first), "a new garden is named and saved straight away")
	GameState.request_till(P, Vector2i(2, 2))
	GameState.request_plant(P, Vector2i(2, 2), "sunpuff")  # planted soil never reverts to grass
	GameState.end_day(false)
	GameState.create_garden("")
	var second: String = GameState.save_path
	check(second != first and GameState.garden_name == "My Garden", "a second garden gets its own file and a default name")
	check(GameState.soil.is_empty() and TimeManager.day_index == 0, "and starts empty")
	var listed: Array[Dictionary] = GameState.list_gardens()
	check(listed.size() == 2, "both gardens are listed")
	var rose: Dictionary = listed[0] if listed[0]["name"] == "Rose Corner" else listed[1]
	check(int(rose["day_index"]) == 1, "the list shows each garden's day")
	check(GameState.open_garden(first) and GameState.soil.has(Vector2i(2, 2)) and GameState.garden_name == "Rose Corner", "loading brings a garden back")
	GameState.close_garden()
	check(GameState.save_path == "" and GameState.soil.is_empty(), "closing leaves an empty unsaved garden")
	GameState.request_till(P, Vector2i(5, 5))
	GameState.end_day(false)
	check(GameState.list_gardens().size() == 2, "nothing is saved while no garden is open")
	check(not GameState.open_garden("user://test_saves/missing.json") and GameState.save_path == "", "a missing file is refused")
	GameState.delete_garden(first)
	GameState.delete_garden(second)
	check(GameState.list_gardens().is_empty(), "gardens can be deleted")
	GameState.save_path = "user://test_save.json"
	GameState.new_game()

	print("shop: selling and buying seeds")
	GameState.new_game()
	check(GameState.coins == 100, "a new garden starts with 100 coins")
	GameState.produce["sunpuff"] = 3
	check(not GameState.request_sell(P, "sunpuff", 4), "can't sell more than you have")
	check(GameState.request_sell(P, "sunpuff", 2), "sell two sunpuffs")
	check(GameState.coins == 160 and int(GameState.produce["sunpuff"]) == 1, "30 coins each go into the shared purse")
	check(GameState.seed_in_stock("dewcup") and not GameState.seed_in_stock("snowpip"), "the shop stocks only seeds the garden knows")
	check(not GameState.request_buy_seeds(P, "snowpip", 1), "unknown seeds can't be bought")
	check(GameState.request_buy_seeds(P, "dewcup", 5), "buy five dewcup seeds")
	check(GameState.coins == 100 and GameState.seed_count("dewcup") == 8, "12 coins each, added to the seed bag")
	check(not GameState.request_buy_seeds(P, "moonbell", 4) and GameState.coins == 100, "can't spend coins you don't have")
	GameState.tree["love"] = 300
	check(GameState.seed_in_stock("snowpip"), "the Heart Tree's gifts join the shop's stock")

	print("shop: tools")
	GameState.coins = 1200
	check(GameState.tool_reach("hoe") == 1, "the first hoe tills one tile")
	check(GameState.request_buy_upgrade(P, "hoe") and GameState.coins == 950, "buy the Sturdy Hoe for 250")
	var before_energy: int = GameState.get_energy(P)
	check(GameState.request_till(P, Vector2i(2, 12), Vector2i.RIGHT), "till with the better hoe")
	check(GameState.soil.has(Vector2i(2, 12)) and GameState.soil.has(Vector2i(3, 12)) and GameState.soil.has(Vector2i(4, 12)) and not GameState.soil.has(Vector2i(5, 12)), "it tills three tiles in the direction faced")
	check(GameState.get_energy(P) == before_energy - 2, "for the energy of one")
	check(GameState.request_water(P, Vector2i(2, 12), Vector2i.RIGHT) and not bool(GameState.soil[Vector2i(3, 12)]["watered"]), "the first watering can still waters one tile")
	check(GameState.request_buy_upgrade(P, "can"), "buy the Big Watering Can")
	check(GameState.request_water(P, Vector2i(2, 12), Vector2i.RIGHT) and bool(GameState.soil[Vector2i(4, 12)]["watered"]), "now it waters the rest of the row")
	check(not GameState.request_water(P, Vector2i(2, 12), Vector2i.RIGHT), "nothing left to water costs nothing")
	check(not GameState.request_buy_upgrade(P, "hoe") and GameState.tool_reach("hoe") == 3, "the Master Hoe costs more than is in the purse")
	GameState.coins = 99999
	check(GameState.request_buy_upgrade(P, "hoe") and GameState.tool_reach("hoe") == 5, "with enough coins, the Master Hoe reaches five")
	check(not GameState.request_buy_upgrade(P, "hoe"), "a fully upgraded tool can't be bought again")

	print("shop: home and hats")
	check(GameState.max_energy() == 100 and GameState.room_size() == Vector2i(8, 5), "the tent is small")
	check(GameState.request_buy_upgrade(P, "home"), "buy the Cabin")
	check(GameState.home_level() == 1 and GameState.room_size() == Vector2i(10, 6), "the home grows")
	GameState.end_day(false)
	check(GameState.get_energy(P) == 115, "and mornings start with 15 more energy")
	check(GameState.hat_of(P) == "straw" and not GameState.request_wear(P, "flower"), "hats must be bought before wearing")
	check(GameState.request_buy_hat(P, "flower") and GameState.hat_of(P) == "flower", "a bought hat goes straight on")
	check(not GameState.request_buy_hat(P, "flower"), "a hat is bought once")
	check(GameState.request_wear(2, "flower") and GameState.request_wear(P, "straw"), "either player can wear any hat the garden owns")
	var shop_state: String = JSON.stringify(GameState.to_snapshot())
	GameState.save_game()
	GameState.new_game()
	check(GameState.coins == 100 and GameState.home_level() == 0, "a new garden starts over")
	GameState.load_game()
	check(JSON.stringify(GameState.to_snapshot()) == shop_state, "coins, tools, home and hats survive save and load")

	print("home: inside")
	var inside: Rect2i = GameState.room_floor()
	check(GameState.is_indoors(inside.position) and not GameState.is_indoors(Vector2i(13, 5)), "the room is its own place, apart from the garden")
	check(GameState.can_walk(inside.position + Vector2i(4, 3)) and not GameState.can_walk(inside.position + Vector2i(-1, 0)), "you can walk on its floor but not through its walls")
	check(not GameState.can_walk(GameState.bed_rect().position) and GameState.is_bed(GameState.bed_rect().position), "the bed is furniture")
	check(not GameState.request_till(P, inside.position + Vector2i(4, 3)), "the floor can't be tilled")
	check(GameState.is_exit_mat(Vector2i(inside.position.x + 5, inside.end.y - 1)) and not GameState.is_exit_mat(inside.position), "the exit mat is at the bottom middle")
	check(not GameState.can_walk(Vector2i(18, 1)) and not GameState.request_till(P, Vector2i(18, 1)), "the shop stall stands on garden ground")
	GameState.new_game()

	print("clock tower")
	GameState.new_game()
	var spot := Vector2i(4, 14)
	GameState.request_till(P, spot)
	GameState.request_plant(P, spot, "sunpuff")
	check(not GameState.can_walk(Vector2i(7, 1)) and GameState.is_tower(Vector2i(8, 2)), "the clock tower stands left of the home")
	var warps: Array = [0]
	GameState.time_warped.connect(func() -> void: warps[0] += 1)
	check(GameState.request_set_time(P, 2 * 28 + 11, 19 * 60, false), "set the time to Fall 12, 7pm")
	check(TimeManager.season() == 2 and TimeManager.day_of_season() == 12 and TimeManager.minutes == 19 * 60, "the calendar and clock jump there")
	check(warps[0] == 1, "and the change is announced")
	check(int(GameState.plants[spot]["days_grown"]) == 0 and int(GameState.plants[spot]["happiness"]) == 50, "nothing grows or suffers for the skipped days")
	check(bool(GameState.plants[spot]["dormant"]), "a spring plant is dormant in fall")
	check(not bool(GameState.soil[spot]["watered"]), "the soil is left as it was")
	GameState.request_set_time(P, 5, 12 * 60 + 7, true)
	check(TimeManager.season() == 0 and TimeManager.minutes == 12 * 60 and not bool(GameState.plants[spot]["dormant"]), "back in spring it wakes; minutes snap to the clock's ten-minute steps")
	check(TimeManager.raining and bool(GameState.soil[spot]["watered"]), "asking for rain waters the soil")
	GameState.request_set_time(P, 3 * 28, 3 * 60, true)
	check(TimeManager.minutes == 6 * 60 and not TimeManager.raining, "times before 6am become 6am, and it never rains in winter")
	GameState.request_set_time(P, 0, 30 * 60, false)
	check(TimeManager.minutes == 25 * 60 + 50, "times after 2am become 1:50am")
	GameState.request_set_time(P, 999999, 6 * 60, false)
	check(TimeManager.year() == 99, "the calendar stops at year 99")
	GameState.new_game()

	print("gathering")
	GameState.new_game()
	var in_garden: Callable = func() -> int:
		var count: int = 0
		for at: Vector2i in GameState.objects.keys():
			if not GameState.is_indoors(at):
				count += 1
		return count
	check(in_garden.call() == 0, "with wild growth off, the ground starts clear")
	GameState.wild_growth = true
	GameState.scatter_debris(40)
	var debris: int = in_garden.call()
	check(debris > 20 and debris <= GameState.MAX_DEBRIS, "debris scatters over the garden, up to a limit")
	var clear_yard: bool = true
	for at: Vector2i in GameState.objects.keys():
		if not GameState.is_indoors(at) and (GameState.YARD.has_point(at) or GameState.ANIMAL_YARD.has_point(at) or GameState.is_blocked(at)):
			clear_yard = false
	check(clear_yard, "but never in the yard around the home")
	GameState.end_day(false)
	GameState.wild_growth = false
	var rock := Vector2i(1, 15)
	GameState.objects.clear()
	GameState.objects[rock] = {"kind": "rock"}
	check(GameState.can_walk(rock) and not GameState.request_till(P, rock), "debris can be walked over but not tilled")
	check(GameState.request_harvest(P, rock), "the basket clears a rock")
	check(not GameState.objects.has(rock) and GameState.item_count("stone") >= 1, "leaving stone in the backpack")

	print("crafting and placing")
	GameState.items = {"stone": 5, "wood": 4, "fiber": 6}
	check(GameState.craft_problem("sprinkler") == "Needs gardening level 2", "the sprinkler recipe is locked at level 1")
	check(GameState.request_craft(P, "path") and GameState.item_count("path") == 1 and GameState.item_count("stone") == 4, "a stepping stone costs one stone")
	check(GameState.request_craft(P, "mulch") and GameState.item_count("mulch") == 2 and GameState.item_count("fiber") == 3, "three fiber make two mulch")
	check(GameState.request_craft(P, "fence") and not GameState.request_craft(P, "nonsense"), "fences can be made; unknown recipes can't")
	GameState.xp = 40
	check(GameState.garden_level() == 2 and GameState.max_energy() == 102, "40 experience is gardening level 2, with a little more energy")
	check(GameState.request_craft(P, "sprinkler") and GameState.item_count("stone") == 1 and GameState.item_count("wood") == 0, "now the sprinkler can be made")
	check(not GameState.request_craft(P, "sprinkler"), "but not without the materials")
	var bed_a := Vector2i(2, 15)
	var bed_b := Vector2i(4, 15)
	var post := Vector2i(3, 15)
	GameState.request_till(P, bed_a)
	GameState.request_till(P, bed_b)
	check(not GameState.request_place(P, bed_a, "sprinkler"), "things can't be placed on tilled soil")
	check(GameState.request_place(P, post, "sprinkler") and GameState.object_kind(post) == "sprinkler", "a sprinkler goes on open ground")
	check(not GameState.can_walk(post) and GameState.item_count("sprinkler") == 0, "it is solid, and leaves the backpack")
	check(GameState.request_place(P, Vector2i(3, 16), "path") and GameState.can_walk(Vector2i(3, 16)), "a stepping stone can be walked on")
	check(not GameState.request_place(P, Vector2i(3, 16), "fence") and not GameState.request_place(P, Vector2i(13, 1), "fence"), "one thing per tile, and not on the home")
	check(not GameState.request_place(P, post, "mulch") and GameState.request_place(P, bed_a, "mulch"), "mulch only goes on tilled soil")
	check(not GameState.request_place(P, bed_a, "mulch") and GameState.item_count("mulch") == 1, "a bed is mulched once")
	GameState.request_plant(P, bed_b, "sunpuff")
	GameState.end_day(false)
	check(bool(GameState.soil[bed_a]["watered"]) and bool(GameState.soil[bed_b]["watered"]), "next morning the sprinkler has watered both sides")
	for night in 40:
		GameState.end_day(false)
	check(GameState.soil.has(bed_a), "a mulched bed never grasses over")
	check(GameState.request_harvest(P, post) and GameState.item_count("sprinkler") == 1 and not GameState.objects.has(post), "the basket picks a sprinkler back up")
	var crafted: String = JSON.stringify(GameState.to_snapshot())
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(JSON.stringify(GameState.to_snapshot()) == crafted, "items, placed things, mulch and experience survive save and load")

	print("cooking")
	GameState.new_game()
	GameState.produce = {"moonbell": 4, "sunpuff": 1, "dewcup": 1}
	check(GameState.craft_problem("tea") == "Needs a stove (the Cabin has one)", "cooking needs a stove")
	GameState.upgrades["home"] = 1
	check(GameState.request_craft(P, "tea") and int(GameState.produce["moonbell"]) == 2 and GameState.item_count("tea") == 1, "two moonbells brew a tea")
	GameState.energy[P] = GameState.max_energy()
	check(not GameState.request_eat(P, "tea"), "a meal is saved while energy is full")
	GameState.energy[P] = 50
	check(GameState.request_eat(P, "tea") and GameState.get_energy(P) == 80 and GameState.item_count("tea") == 0, "drinking it restores 30 energy")
	check(not GameState.request_eat(P, "wood") and not GameState.request_eat(P, "tea"), "only meals you have can be eaten")

	print("gardening skill and requests")
	GameState.new_game()
	check(GameState.garden_level() == 1 and GameState.next_level_xp() == 40, "a new garden is level 1")
	var told: Array = []
	GameState.notice.connect(func(text: String) -> void: told.append(text))
	var patch := Vector2i(6, 15)
	GameState.request_till(P, patch)
	GameState.request_plant(P, patch, "sunpuff")
	for night in 5:
		GameState.plants[patch]["happiness"] = 50
		GameState.request_water(P, patch)
		GameState.end_day(false)
	check(GameState.xp == 5, "each plant cared for earns a point a day")
	GameState.xp = 35
	GameState.request_harvest(P, patch)
	check(GameState.xp == 43 and GameState.garden_level() == 2, "harvesting earns 8 and can raise the level")
	check(told.any(func(text: String) -> bool: return text.begins_with("Gardening level 2")), "which is announced")
	check(not GameState.wanted.is_empty() and GameState.species.has(GameState.wanted["species"]), "Bristle posts a request in the morning")
	GameState.wanted = {"species": "sunpuff", "count": 3, "reward": 180}
	GameState.produce["sunpuff"] = 2
	check(not GameState.request_deliver(P), "a request needs the full amount")
	GameState.produce["sunpuff"] = 4
	var purse: int = GameState.coins
	check(GameState.request_deliver(P) and GameState.coins == purse + 180 and int(GameState.produce["sunpuff"]) == 1, "delivering pays the doubled reward")
	check(GameState.wanted.is_empty() and GameState.xp == 63, "and earns 20 experience")
	GameState.new_game()

	print("fishing")
	GameState.new_game()
	check(GameState.is_pond(Vector2i(4, 22)) and not GameState.can_walk(Vector2i(4, 22)) and not GameState.request_till(P, Vector2i(4, 22)), "the pond is water: no walking, no digging")
	check(not GameState.is_pond(Vector2i(1, 20)) and GameState.can_walk(Vector2i(1, 20)), "its rounded corners are dry land")
	check(not GameState.SCENERY.keys().any(func(at: Vector2i) -> bool: return GameState.is_pond(at)), "no scenery stands in the pond")
	check(GameState.request_fish(P, false) and GameState.get_energy(P) == 98 and GameState.items.is_empty(), "a cast that gets away costs energy and catches nothing")
	check(GameState.request_fish(P, true) and GameState.items.size() == 1 and GameState.FISH.has(GameState.items.keys()[0]), "a landed cast puts a fish in the backpack")
	check(GameState.stats["fish"].size() == 1 and GameState.xp == 3, "and is tallied, with a little experience")
	var seen: Dictionary = {}
	for cast in 80:
		seen[GameState._roll_fish()] = true
	check(seen.has("minnow") and seen.has("sunfish") and not seen.has("moonfin") and not seen.has("frostfin") and not seen.has("raincarp"), "on a clear spring morning only day fish bite")
	GameState.request_set_time(P, 3 * 28 + 2, 20 * 60, false)
	seen = {}
	for cast in 80:
		seen[GameState._roll_fish()] = true
	check(seen.has("moonfin") and seen.has("frostfin") and not seen.has("sunfish"), "a winter evening brings moonfin and frostfin")
	GameState.request_set_time(P, 0, 6 * 60, false)
	GameState.items = {"moonfin": 2}
	var before_sale: int = GameState.coins
	check(GameState.request_sell(P, "moonfin", 1) and GameState.coins == before_sale + 60, "fish sell to Bristle")
	check(not GameState.request_sell(P, "wood", 1), "things without a price can't be sold")

	print("shipping bin")
	GameState.produce["sunpuff"] = 3
	check(GameState.is_bin(GameState.BIN_CELL) and not GameState.can_walk(GameState.BIN_CELL), "the bin stands between the home and the stall")
	check(GameState.request_ship(P, "sunpuff", 2) and GameState.request_ship(P, "moonfin", 1), "harvest and fish go in the bin")
	check(int(GameState.bin["sunpuff"]) == 2 and int(GameState.produce["sunpuff"]) == 1 and not GameState.request_ship(P, "sunpuff", 5), "they leave the backpack; you can't ship more than you have")
	check(GameState.request_ship(P, "sunpuff", -1) and int(GameState.bin["sunpuff"]) == 1 and int(GameState.produce["sunpuff"]) == 2, "things can be taken back out before night")
	var before_night: int = GameState.coins
	var night: Array = [{}]
	GameState.day_advanced.connect(func(summary: Dictionary) -> void: night[0] = summary, CONNECT_ONE_SHOT)
	GameState.end_day(false)
	check(GameState.coins == before_night + 30 + 60 and GameState.bin.is_empty(), "overnight the bin is sold at the usual prices")
	check(night[0]["news"].has("The shipping bin earned 90 coins"), "and the morning screen says so")

	print("decor")
	GameState.new_game()
	GameState.coins = 1000
	check(GameState.request_buy_item(P, "fern", 1) and GameState.request_buy_item(P, "rug", 1) and GameState.request_buy_item(P, "gnome", 1) and GameState.coins == 1000 - 80 - 150 - 100, "decor is bought from Bristle")
	check(not GameState.request_buy_item(P, "wood", 1), "only things with a price tag are for sale")
	var room: Rect2i = GameState.room_floor()
	var corner: Vector2i = room.position + Vector2i(4, 2)
	check(GameState.request_place(P, corner, "fern") and not GameState.can_walk(corner), "a potted fern stands on the floor indoors")
	check(not GameState.request_place(P, GameState.bed_rect().position, "rug") and not GameState.request_place(P, room.position + Vector2i(-1, 0), "rug"), "not on the bed or in the wall")
	check(GameState.request_place(P, corner + Vector2i(1, 0), "rug") and GameState.can_walk(corner + Vector2i(1, 0)), "a rug can be walked on")
	check(GameState.request_place(P, Vector2i(3, 12), "gnome"), "a gnome is happy in the garden")
	GameState.items["fence"] = 1
	check(not GameState.request_place(P, corner + Vector2i(2, 0), "fence"), "garden things stay outdoors")
	check(GameState.request_harvest(P, corner) and GameState.item_count("fern") == 1, "furniture can be picked up again")
	GameState.request_place(P, room.position + Vector2i(7, 0), "fern")  # where the Cabin's stove will stand
	GameState.coins = 5000
	GameState.request_buy_upgrade(P, "home")
	check(not GameState.objects.has(room.position + Vector2i(7, 0)) and GameState.item_count("fern") == 1, "moving house returns furniture that no longer fits")

	print("goals and festivals")
	var morning: Array = [{}]
	var purse_before: int = GameState.coins
	GameState.day_advanced.connect(func(summary: Dictionary) -> void: morning[0] = summary, CONNECT_ONE_SHOT)
	GameState.end_day(false)
	check(GameState.goals_done.has("cabin") and GameState.coins == purse_before + 200, "moving into the Cabin meets a goal and pays 200 coins")
	check(morning[0]["news"].has("Goal met: Home Sweet Home! You earned 200 coins"), "the morning screen announces it")
	GameState.end_day(false)
	check(GameState.coins == purse_before + 200, "a goal pays only once")
	for goal: Dictionary in GameState.GOALS:
		if goal["id"] != "master" and not GameState.goals_done.has(goal["id"]):
			GameState.goals_done.append(goal["id"])
	GameState.end_day(false)
	check(GameState.hats_owned.has("laurel"), "finishing every goal earns the Golden Laurel")
	GameState.new_game()
	check(GameState.festival_today() == -1, "most days are ordinary")
	var show := Vector2i(5, 15)
	GameState.request_till(P, show)
	GameState.request_plant(P, show, "sunpuff")
	GameState.plants[show]["days_grown"] = 9
	GameState.plants[show]["happiness"] = 100
	GameState.request_set_time(P, 12, 12 * 60, false)
	GameState.day_advanced.connect(func(summary: Dictionary) -> void: morning[0] = summary, CONNECT_ONE_SHOT)
	GameState.end_day(false)
	check(GameState.festival_today() == 0 and str(morning[0]["news"][-1]).begins_with("Today is the Bloom Show!"), "spring 14 is the Bloom Show, announced that morning")
	var before_show: int = GameState.coins
	GameState.day_advanced.connect(func(summary: Dictionary) -> void: morning[0] = summary, CONNECT_ONE_SHOT)
	GameState.end_day(false)
	check(GameState.coins == before_show + 50 and morning[0]["news"].has("Bloom Show: 1 radiant plants won 50 coins"), "that night each radiant plant wins 50 coins")
	GameState.request_set_time(P, 2 * 28 + 13, 12 * 60, false)
	check(GameState.festival_today() == 2 and GameState.sell_price_of("sunpuff") == 45, "at the Harvest Fair a 30-coin sunpuff sells for 45")
	GameState.request_set_time(P, 28 + 13, 12 * 60, false)
	GameState.plants[show]["happiness"] = 40
	GameState.plants[show]["dormant"] = false
	GameState.request_water(P, show)
	GameState.request_pet(P, show)
	GameState.end_day(false)
	check(int(GameState.plants[show]["happiness"]) == 40 + 4 + 16, "on Firefly Night a pet counts double")
	GameState.request_set_time(P, 3 * 28 + 13, 12 * 60, false)
	for i in 3:
		GameState.objects[Vector2i(1 + i, 16)] = {"kind": "lantern"}
	var winter_seeds: int = GameState.seed_count("snowpip")
	GameState.end_day(false)
	check(GameState.seed_count("snowpip") == winter_seeds + 3, "three lanterns on Lantern Night bring winter seeds")
	GameState.new_game()

	print("quality, crows and fruit trees")
	GameState.new_game()
	var q := Vector2i(5, 14)
	for mood_and_want: Array in [[40, "sunpuff"], [70, "sunpuff.silver"], [100, "sunpuff.gold"]]:
		GameState.request_till(P, q)
		GameState.request_plant(P, q, "sunpuff")
		GameState.plants[q]["days_grown"] = 9
		GameState.plants[q]["happiness"] = mood_and_want[0]
		GameState.request_harvest(P, q)
		check(GameState.stock_of(mood_and_want[1]) == 1, "mood %d harvests as %s" % [mood_and_want[0], mood_and_want[1]])
	check(GameState.sell_price_of("sunpuff.silver") == 37 and GameState.sell_price_of("sunpuff.gold") == 45, "silver sells for a quarter more, gold for half as much again")
	check(GameState.name_of("sunpuff.gold") == "Sunpuff (gold)" and GameState.sellable_ids().has("sunpuff.gold"), "starred harvest is named and can be sold")
	var coins_q: int = GameState.coins
	check(GameState.request_sell(P, "sunpuff.gold", 1) and GameState.coins == coins_q + 45, "selling a gold sunpuff pays 45")
	for i in 6:
		GameState.request_till(P, Vector2i(2 + i, 16))
		GameState.request_plant(P, Vector2i(2 + i, 16), "sunpuff")
		GameState.seeds["sunpuff"] = 9
	var pecked: bool = false
	for turn in 200:
		var lines: Array = GameState._crows()
		if not lines.is_empty():
			pecked = str(lines[0]).begins_with("A crow pecked")
			break
	check(pecked, "with six unguarded plants, a crow turns up sooner or later")
	GameState.items["scarecrow"] = 1
	check(GameState.request_place(P, Vector2i(4, 15), "scarecrow"), "a scarecrow can be set up")
	var quiet: bool = true
	for turn in 200:
		if not GameState._crows().is_empty():
			quiet = false
	check(quiet, "and then crows leave the plants near it alone")
	GameState.coins = 1000
	check(GameState.request_buy_item(P, "sapling", 1) and GameState.request_place(P, Vector2i(10, 14), "sapling"), "a plumble sapling is bought and planted")
	GameState.end_day(false)
	check(not GameState.request_harvest(P, Vector2i(10, 14)) and GameState.objects.has(Vector2i(10, 14)), "once rooted it can't be picked up")
	for turn in 12:
		GameState.end_day(false)
	check(bool(GameState.objects[Vector2i(10, 14)].get("fruit", false)), "after ten days of growing and three more, it bears fruit")
	check(GameState.request_harvest(P, Vector2i(10, 14)) and GameState.item_count("plumble") == 1 and not bool(GameState.objects[Vector2i(10, 14)]["fruit"]), "the fruit is picked by hand and the tree stays")

	print("animals")
	GameState.new_game()
	GameState.coins = 5000
	check(not GameState.request_buy_animal(P, "chicken"), "a chicken needs a coop")
	check(GameState.request_buy_upgrade(P, "coop") and not GameState.can_walk(Vector2i(2, 1)), "the coop is built at the top left")
	check(GameState.request_buy_animal(P, "chicken") and GameState.request_buy_animal(P, "chicken") and GameState.animals.size() == 2, "two hens move in")
	var hen: Vector2i = GameState.animal_cell(0)
	check(GameState.animal_at(hen) == 0 and not GameState.can_walk(hen), "each has her own spot in front of it")
	check(not GameState.request_tend(P, hen), "feeding needs feed")
	GameState.items["fiber"] = 2
	check(GameState.request_craft(P, "feed") and GameState.item_count("feed") == 2, "two fiber make two helpings of feed")
	check(GameState.request_tend(P, hen) and bool(GameState.animals[0]["fed"]) and GameState.item_count("feed") == 1, "the first visit feeds her")
	check(GameState.request_tend(P, hen) and GameState.animals[0]["petted_by"].has("1") and not GameState.request_tend(P, hen), "the second pets her, once a day each")
	GameState.end_day(false)
	check(GameState.item_count("egg") == 1, "a fed hen lays an egg; a hungry one doesn't")
	check(int(GameState.animals[0]["mood"]) == 61 and int(GameState.animals[1]["mood"]) == 35, "mood follows how each was treated")
	check(not bool(GameState.animals[0]["fed"]), "they are hungry again each morning")
	check(GameState.request_buy_upgrade(P, "barn") and GameState.request_buy_animal(P, "cow") and GameState.animal_at(Vector2i(1, 8)) == 2, "a barn and a cow can be added")
	GameState.upgrades["home"] = 1
	GameState.items["egg"] = 2
	check(GameState.request_craft(P, "omelette") and GameState.item_count("omelette") == 1, "two eggs cook into an omelette")
	var farm: String = JSON.stringify(GameState.to_snapshot())
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(JSON.stringify(GameState.to_snapshot()) == farm, "buildings, animals and the mine survive save and load")

	print("villagers")
	GameState.new_game()
	check(GameState.visitor_today() == "maple" and not GameState.can_walk(GameState.VISITOR_CELL), "Maple visits on the first day and stands by the stall")
	check(GameState.request_talk(P, "maple") and not GameState.request_talk(P, "maple") and int(GameState.friends["maple"]["points"]) == 10, "a chat a day is worth 10 points")
	check(not GameState.request_talk(P, "pebble"), "you can't talk to someone who isn't here")
	GameState.produce["moonbell"] = 2
	GameState.items["minnow"] = 1
	check(GameState.request_gift(P, "maple", "moonbell") and int(GameState.friends["maple"]["points"]) == 90 and int(GameState.produce["moonbell"]) == 1, "a loved gift is worth 80")
	check(not GameState.request_gift(P, "maple", "moonbell"), "one gift a day")
	GameState.end_day(false)
	check(GameState.visitor_today() == "pebble" and GameState.hearts("maple") == 0, "next day it's Pebble's turn; Maple is nearly at one heart")
	GameState.request_set_time(P, 3, 12 * 60, false)
	var seeds_before: int = GameState.seed_count("moonbell")
	GameState.request_talk(P, "maple")
	check(GameState.hearts("maple") == 1 and GameState.seed_count("moonbell") == seeds_before + 5, "the first heart brings a gift of seeds")
	check(GameState.request_gift(P, "maple", "minnow") and int(GameState.friends["maple"]["points"]) == 80, "a disliked gift costs 20, but hearts already rewarded stay rewarded")
	GameState.request_set_time(P, 6, 12 * 60, false)
	check(GameState.visitor_today() == "" and GameState.can_walk(GameState.VISITOR_CELL), "nobody visits on the seventh day")

	print("the mine")
	GameState.new_game()
	var cave: Rect2i = GameState.mine_floor()
	var rocks: Array = []
	for at: Vector2i in GameState.objects.keys():
		if GameState.is_in_mine(at):
			rocks.append(at)
	check(rocks.size() >= 10 and GameState.is_mine_entrance(Vector2i(25, 2)) and not GameState.can_walk(Vector2i(25, 2)), "the mine has an entrance in the garden and rocks inside")
	check(not GameState.can_walk(rocks[0]) and GameState.can_walk(Vector2i(cave.position.x + 6, cave.end.y - 1)), "rocks block the way; the ladder tile is always clear")
	check(not GameState.request_harvest(P, rocks[0]), "a bare hand can't lift a rock")
	GameState.coins = 500
	check(not GameState.request_mine(P, rocks[0]), "rocks need a pickaxe")
	GameState.coins = 500
	check(GameState.request_buy_upgrade(P, "pickaxe") and GameState.coins == 300 and GameState.request_mine(P, rocks[0]), "Bristle sells one for 200, and then a rock breaks")
	var got: int = GameState.item_count("stone") + GameState.item_count("copper") + GameState.item_count("goldore") + GameState.item_count("amethyst")
	check(got >= 1 and not GameState.objects.has(rocks[0]) and GameState.get_energy(P) == 98, "giving stone or ore for 2 energy")
	check(not GameState.request_place(P, rocks[0], "path"), "nothing can be built down there")
	GameState.end_day(false)
	var again: int = 0
	for at: Vector2i in GameState.objects.keys():
		if GameState.is_in_mine(at):
			again += 1
	check(again >= 10, "the rocks are back the next morning")
	GameState.items = {"copper": 4, "goldore": 1}
	GameState.xp = 320
	check(GameState.request_craft(P, "bigsprinkler"), "copper and gold make a Great Sprinkler at level 4")
	var ring: Array = [Vector2i(9, 13), Vector2i(11, 15)]
	for at: Vector2i in ring:
		GameState.request_till(P, at)
		GameState.request_plant(P, at, "sunpuff")  # planted soil never reverts to grass
	GameState.request_place(P, Vector2i(10, 14), "bigsprinkler")
	GameState.end_day(false)
	check(bool(GameState.soil[ring[0]]["watered"]) and bool(GameState.soil[ring[1]]["watered"]), "which waters the diagonals too")
	GameState.new_game()

	print("artisan machines")
	GameState.new_game()
	GameState.xp = 190  # level 4
	GameState.items = {"wood": 20, "stone": 6, "fiber": 3, "copper": 2}
	check(GameState.request_craft(P, "jar") and GameState.request_craft(P, "beehive") and GameState.request_craft(P, "cheesepress") and GameState.request_craft(P, "press"), "the four machines can be crafted")
	var jar_at := Vector2i(3, 12)
	var hive_at := Vector2i(5, 12)
	GameState.request_place(P, jar_at, "jar")
	GameState.request_place(P, hive_at, "beehive")
	GameState.produce = {"sunpuff": 3, "moonbell": 1}
	check(GameState.machine_input("jar") == "sunpuff" and GameState.machine_input("cheesepress") == "", "a jar takes the harvest you have most of; a cheese press wants milk")
	check(GameState.request_harvest(P, jar_at) and int(GameState.produce["sunpuff"]) == 1 and int(GameState.objects[jar_at]["busy"]) == 2, "by hand, an empty jar is filled with two sunpuffs")
	check(not GameState.request_harvest(P, jar_at) and GameState.objects.has(jar_at), "while it works it can't be emptied or picked up")
	GameState.end_day(false)
	check(not bool(GameState.objects[jar_at].get("ready", false)), "one night isn't enough")
	GameState.end_day(false)
	check(bool(GameState.objects[jar_at]["ready"]), "after two nights the jam is ready")
	check(GameState.request_harvest(P, jar_at) and GameState.item_count("jam") == 1 and GameState.sell_price_of("jam") == 110, "collected by hand: jam worth 110 from 60 coins of sunpuff")
	GameState.end_day(false)
	check(bool(GameState.objects[hive_at].get("ready", false)), "the beehive fills by itself in three days")
	GameState.request_harvest(P, hive_at)
	check(GameState.item_count("honey") == 1, "giving honey")
	GameState.produce = {}
	check(GameState.request_harvest(P, jar_at) and GameState.item_count("jar") == 1 and not GameState.objects.has(jar_at), "an empty jar with nothing to fill it is picked up instead")

	print("mail and the notice board")
	GameState.new_game()
	check(GameState.mail.is_empty() and not GameState.can_walk(GameState.MAILBOX_CELL) and not GameState.can_walk(GameState.BOARD_CELL), "a mailbox and a notice board stand by the home")
	GameState.end_day(false)
	check(GameState.mail.size() == 1 and GameState.mail[0]["from"] == "Bristle", "a welcome letter arrives on the second morning")
	var purse_mail: int = GameState.coins
	check(GameState.request_open_mail(P, 0) and GameState.coins == purse_mail + 50 and GameState.mail.is_empty(), "opening it gives its 50 coins and clears it")
	check(not GameState.request_open_mail(P, 0), "there is nothing more to open")
	check(GameState.quests.size() == 3, "the board holds three requests")
	GameState.quests = [{"who": "pebble", "id": "wood", "count": 3, "coins": 65, "days": 2}]
	GameState.items["wood"] = 2
	check(not GameState.request_quest(P, 0), "a request needs the full amount")
	GameState.items["wood"] = 5
	var purse_quest: int = GameState.coins
	check(GameState.request_quest(P, 0) and GameState.coins == purse_quest + 65 and GameState.item_count("wood") == 2, "handing it in pays the reward")
	check(int(GameState.friends["pebble"]["points"]) == 30 and int(GameState.stats["requests"]) == 1, "and pleases whoever asked")
	GameState.quests = [{"who": "bristle", "id": "stone", "count": 2, "coins": 40, "days": 1}]
	GameState.end_day(false)
	var stale: bool = false
	for quest: Dictionary in GameState.quests:
		if quest["id"] == "stone" and int(quest["days"]) <= 0:
			stale = true
	check(not stale and GameState.quests.size() == 3, "old requests expire and the board refills")
	GameState.friends["maple"] = {"points": 200, "talked": false, "gifted": false, "rewards": 2}
	GameState.mail = []
	GameState.end_day(false)
	GameState.end_day(false)
	var from_maple: int = 0
	for letter: Dictionary in GameState.mail:
		if letter["from"] == "Maple":
			from_maple += 1
	check(from_maple == 1, "a friend at two hearts writes once, not every day")
	var letters_state: String = JSON.stringify(GameState.to_snapshot())
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(JSON.stringify(GameState.to_snapshot()) == letters_state, "letters, requests and machines survive save and load")

	print("greenhouse, new plants and forage")
	GameState.new_game()
	check(GameState.species.size() == 17, "there are seventeen kinds of plant")
	check(not GameState.seed_in_stock("skybell") and not GameState.seed_in_stock("snapvine"), "the new seeds aren't stocked at first")
	GameState.xp = 40
	check(GameState.seed_in_stock("skybell") and not GameState.seed_in_stock("snapvine"), "level 2 brings the first of them")
	GameState.xp = 190
	check(GameState.seed_in_stock("snapvine") and GameState.seed_in_stock("icebloom"), "level 4 the rest")
	var glass := Vector2i(20, 14)
	var open_air := Vector2i(3, 14)
	GameState.request_till(P, glass)
	GameState.request_till(P, open_air)
	GameState.seeds["frostwhisker"] = 2
	check(not GameState.request_plant(P, glass, "frostwhisker"), "without a greenhouse a winter plant can't go in during spring")
	GameState.coins = 4000
	check(GameState.request_buy_upgrade(P, "greenhouse") and GameState.in_greenhouse(glass) and not GameState.in_greenhouse(open_air), "the greenhouse covers a patch in the lower right")
	check(GameState.request_plant(P, glass, "frostwhisker") and not GameState.request_plant(P, open_air, "frostwhisker"), "inside it any plant can be planted")
	GameState.request_plant(P, open_air, "sunpuff")
	GameState.request_water(P, glass)
	GameState.end_day(false)
	check(int(GameState.plants[glass]["days_grown"]) == 1 and not bool(GameState.plants[glass]["dormant"]), "and grows out of season")
	GameState.request_set_time(P, 3 * 28 + 2, 9 * 60, false)
	check(bool(GameState.plants[open_air]["dormant"]) and not bool(GameState.plants[glass]["dormant"]), "in winter only the plant outside goes dormant")
	GameState.wild_growth = true
	GameState.request_set_time(P, 2, 9 * 60, false)
	for dawn in 12:
		GameState.end_day(false)
	var greens: int = 0
	for at: Vector2i in GameState.objects.keys():
		if GameState.object_kind(at) == "wildgreens":
			greens += 1
	check(greens >= 1 and greens <= 5, "wild greens turn up in spring, a few at most")
	GameState.request_set_time(P, 28 + 2, 9 * 60, false)
	GameState.end_day(false)
	var wrong: int = 0
	var spot_found := Vector2i(-1, -1)
	for at: Vector2i in GameState.objects.keys():
		if GameState.object_kind(at) == "wildgreens":
			wrong += 1
		if GameState.object_kind(at) == "sunberry":
			spot_found = at
	check(wrong == 0, "and are gone once summer comes")
	GameState.wild_growth = false
	GameState.objects[Vector2i(2, 16)] = {"kind": "sunberry"}
	check(GameState.request_harvest(P, Vector2i(2, 16)) and GameState.item_count("sunberry") >= 1, "forage is picked by hand and can be sold")
	GameState.new_game()

	print("requests take any quality")
	GameState.new_game()
	GameState.wanted = {"species": "moonbell", "count": 2, "reward": 88}
	GameState.produce = {}
	GameState.items = {"moonbell.silver": 1, "moonbell.gold": 1}
	check(GameState.total_of("moonbell") == 2 and GameState.stock_of("moonbell") == 0, "two starred moonbells count as two moonbells")
	var before_wanted: int = GameState.coins
	check(GameState.request_deliver(P) and GameState.coins == before_wanted + 88, "Bristle accepts them for his request")
	check(GameState.item_count("moonbell.silver") == 0 and GameState.item_count("moonbell.gold") == 0, "and they are used up")
	GameState.produce = {"sunpuff": 1}
	GameState.items = {"sunpuff.silver": 2, "sunpuff.gold": 1}
	GameState.quests = [{"who": "bristle", "id": "sunpuff", "count": 2, "coins": 50, "days": 2}]
	check(GameState.request_quest(P, 0) and int(GameState.produce["sunpuff"]) == 0 and GameState.item_count("sunpuff.silver") == 1 and GameState.item_count("sunpuff.gold") == 1, "plain harvest is used first, then silver, keeping gold for last")
	GameState.upgrades["home"] = 1
	GameState.produce = {}
	GameState.items = {"moonbell.gold": 2}
	check(GameState.request_craft(P, "tea") and GameState.item_count("moonbell.gold") == 0, "recipes take starred harvest too")

	print("baking")
	GameState.new_game()
	GameState.coins = 3000
	check(GameState.seed_in_stock("wheat"), "wheat seeds are stocked from the start")
	check(GameState.craft_problem("cinnamonbuns") == "Needs an oven (Bristle sells one)", "baking needs an oven")
	check(GameState.request_buy_item(P, "oven", 1) and GameState.coins == 2600, "Bristle sells an oven for 400")
	var kitchen_spot: Vector2i = GameState.room_floor().position + Vector2i(4, 2)
	check(GameState.request_place(P, kitchen_spot, "oven") and GameState.has_oven(), "it stands in the home")
	for buy: Array in [["sugar", 3], ["butter", 2], ["cinnamon", 1], ["flour", 2], ["egg", 1]]:
		GameState.request_buy_item(P, buy[0], buy[1])
	check(GameState.item_count("sugar") == 3 and GameState.item_count("egg") == 1, "sugar, butter, cinnamon, flour and eggs come from the pantry")
	check(GameState.request_craft(P, "cinnamonbuns") and GameState.item_count("cinnamonbuns") == 2 and GameState.item_count("flour") == 0, "flour, butter, cinnamon and sugar bake into two cinnamon buns")
	GameState.upgrades["home"] = 1
	GameState.produce["wheat"] = 4
	check(GameState.request_craft(P, "flour") and GameState.request_craft(P, "flour") and GameState.item_count("flour") == 2, "two wheat mill into flour at the stove")
	GameState.xp = 190
	check(GameState.request_buy_item(P, "applesapling", 1) and GameState.request_buy_item(P, "bananasapling", 1), "apple and banana saplings are for sale")
	var apple_at := Vector2i(6, 14)
	var banana_at := Vector2i(9, 14)
	GameState.request_place(P, apple_at, "applesapling")
	GameState.request_place(P, banana_at, "bananasapling")
	for dawn in 13:
		GameState.end_day(false)
	check(GameState.request_harvest(P, apple_at) and GameState.request_harvest(P, banana_at) and GameState.item_count("apple") == 1 and GameState.item_count("banana") == 1, "each tree bears its own fruit")
	GameState.items["apple"] = 3
	GameState.items["banana"] = 2
	check(GameState.request_craft(P, "applepie") and GameState.request_craft(P, "bananabread"), "apples bake into a pie and bananas into bread")
	check(GameState.sell_price_of("applepie") == 320 and GameState.sellable_ids().has("bananabread"), "baked goods can be sold")
	GameState.energy[P] = 10
	check(GameState.request_eat(P, "applepie") and GameState.get_energy(P) == GameState.max_energy(), "or eaten: a pie restores 140 energy, up to full")

	print("the bigger garden")
	check(GameState.WORLD_SIZE == Vector2i(40, 26) and GameState.in_bounds(Vector2i(39, 25)), "the garden is 40 by 26 tiles")
	check(not GameState.can_walk(Vector2i(30, 2)) and not GameState.request_till(P, Vector2i(30, 2)), "trees stand in the new land and can't be dug up")
	var clear: bool = true
	for at: Vector2i in GameState.SCENERY.keys():
		for tile: Vector2i in GameState.scenery_tiles(at):
			if GameState.TRAILS.has(tile) or GameState.is_pond(tile) or GameState.YARD.has_point(tile) or GameState.ANIMAL_YARD.has_point(tile) \
					or GameState.GREENHOUSE_RECT.has_point(tile) or GameState.is_tree(tile) or tile == GameState.VISITOR_CELL or not GameState.in_bounds(tile):
				clear = false
	check(clear, "trees and rocks stay clear of the trails, the pond, the yards and the greenhouse")

	print("cutting trees down")
	var oak := Vector2i(19, 9)
	GameState.energy[P] = 100
	check(GameState.scenery_at(oak) == "oak" and GameState.can_chop(oak) and not GameState.can_walk(oak), "an oak stands in the garden")
	var hits: Array = []
	GameState.scenery_hit.connect(func(cell: Vector2i, down: bool) -> void: hits.append([cell, down]))
	check(GameState.request_chop(P, oak) and GameState.request_chop(P, oak) and GameState.scenery_at(oak) == "oak", "two swings aren't enough")
	check(GameState.get_energy(P) == 100 - 2 * GameState.COST_CHOP, "each swing costs energy")
	check(GameState.request_chop(P, oak) and GameState.scenery_at(oak) == "" and GameState.felled.has(oak), "the third brings it down")
	check(hits == [[oak, false], [oak, false], [oak, true]], "every swing is announced, the last as the fall")
	var stack: Dictionary = GameState.objects.get(oak, {})
	check(str(stack.get("kind", "")) == "dropped" and str(stack.get("key", "")) == "item:wood" and int(stack.get("count", 0)) >= 6, "it leaves a stack of wood where it stood")
	check(GameState.can_walk(oak), "and the tile can be walked on")
	var wood_before: int = GameState.item_count("wood")
	check(GameState.request_harvest(P, oak) and GameState.item_count("wood") > wood_before and not GameState.objects.has(oak), "the wood is picked up")
	check(not GameState.can_chop(Vector2i(36, 6)) and not GameState.request_chop(P, Vector2i(36, 6)), "boulders can't be chopped")
	check(not GameState.request_chop(P, Vector2i(5, 9)), "nor can open ground")
	var log_tail := Vector2i(30, 16)
	check(GameState.request_chop(P, log_tail) and GameState.request_chop(P, log_tail) and GameState.scenery_at(Vector2i(29, 16)) == "" and GameState.object_kind(Vector2i(29, 16)) == "dropped", "a log breaks up from either end, its wood on its first tile")
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(GameState.felled.has(oak) and GameState.scenery_at(oak) == "", "cut-down trees stay down after save and load")
	TimeManager.day_index += GameState.REGROW_DAYS
	GameState.request_till(P, Vector2i(29, 16))
	GameState.end_day(false)
	check(GameState.scenery_at(oak) == "oak", "a season later the oak has grown back")
	check(GameState.felled.has(Vector2i(29, 16)), "but not where the ground has been dug")
	var old_save: Dictionary = GameState.to_snapshot()
	old_save.erase("felled")
	old_save["soil"]["%d,%d" % [oak.x, oak.y]] = {"watered": false}
	GameState.apply_snapshot(old_save)
	check(GameState.soil.has(oak) and GameState.felled.has(oak), "in a garden saved before a tree was added, the soil there stays and the tree starts cut down")
	GameState.new_game()
	check(GameState.scenery_at(Vector2i(30, 16)) == "log" and not GameState.can_walk(Vector2i(30, 16)) and GameState.can_walk(Vector2i(31, 16)), "a fallen log blocks both its tiles and no more")
	var crown := Vector2i(GameState.TREE_RECT.position.x, GameState.TREE_RECT.position.y)
	var trunk := Vector2i(GameState.TREE_RECT.position.x, GameState.TREE_RECT.end.y - 1)
	check(GameState.can_walk(crown) and not GameState.can_walk(trunk), "you can walk behind the Heart Tree's leaves, not through its trunk")
	check(not GameState.request_till(P, crown) and not GameState.can_drop_on(crown), "but you can't dig or drop things under its leaves")
	check(GameState.can_walk(Vector2i(22, 3)) and GameState.request_till(P, Vector2i(22, 3)), "trails can be walked on and dug")
	var outside: Array = GameState.TRAILS.filter(func(cell: Vector2i) -> bool: return not GameState.in_bounds(cell))
	check(not outside.is_empty() and not outside.any(func(cell: Vector2i) -> bool: return GameState.can_walk(cell)), "trails lead off through the cliff and the fence, but only as scenery")
	GameState.new_game()

	print("each player has their own bag")
	GameState.new_game()
	GameState.register_player(2)
	check(GameState.bag_of(2)["coins"] == GameState.START_COINS and int(GameState.bag_of(2)["seeds"]["sunpuff"]) == 6, "a partner starts with their own seeds and purse")
	check(GameState.request_buy_seeds(2, "sunpuff", 2), "the partner buys seeds")
	check(GameState.coins == GameState.START_COINS and GameState.seed_count("sunpuff") == 6, "the host's purse and seeds are untouched")
	check(int(GameState.bag_of(2)["seeds"]["sunpuff"]) == 8 and int(GameState.bag_of(2)["coins"]) < GameState.START_COINS, "the partner paid from their own purse")
	GameState.bag_of(2)["produce"]["sunpuff"] = 2
	check(GameState.request_ship(2, "sunpuff", 2) and GameState.bin.is_empty(), "shipping goes in the partner's own part of the bin")
	var host_purse: int = GameState.coins
	var their_purse: int = int(GameState.bag_of(2)["coins"])
	GameState.end_day(false)
	check(GameState.coins == host_purse and int(GameState.bag_of(2)["coins"]) == their_purse + 60, "the night's sale pays whoever shipped it")
	GameState._reward_everyone(50)
	check(GameState.coins == host_purse + 50 and int(GameState.bag_of(2)["coins"]) == their_purse + 110, "festival and goal prizes go to everyone")

	print("moving stacks in the backpack")
	GameState.new_game()
	GameState.items["tea"] = 3
	GameState.items["stone"] = 5
	var slots: Array = GameState.bag_slots()
	check(slots.slice(0, GameState.HOT_SLOTS) == ["", "", "", ""] and slots.has("item:tea") and slots.has("seed:sunpuff"), "new things go in the backpack, not the hot bar")
	var tea_at: int = slots.find("item:tea")
	check(GameState.request_move_slot(P, tea_at, 0), "drag tea onto the hot bar")
	slots = GameState.bag_slots()
	check(slots[0] == "item:tea" and slots.count("item:tea") == 1 and slots[tea_at] == "", "the whole stack moved: it isn't in the backpack too")
	check(GameState.item_count("tea") == 3, "and none was copied or lost")
	check(not GameState.request_move_slot(P, slots.find("item:stone"), 1), "stone can't go on the hot bar")
	var stone_at: int = slots.find("item:stone")
	check(GameState.request_move_slot(P, stone_at, GameState.HOT_SLOTS + 20) and GameState.bag_slots()[GameState.HOT_SLOTS + 20] == "item:stone", "things can go in any backpack slot")
	check(not GameState.request_move_slot(P, 0, GameState.HOT_SLOTS + 20), "tea can't swap with stone, which can't go on the hot bar")
	for sip in 3:
		GameState.energy[P] = 10  # tired enough to drink it
		GameState.request_eat(P, "tea")
	check(GameState.item_count("tea") == 0 and GameState.bag_slots()[0] == "", "a stack used up leaves its slot empty")

	print("dropping things")
	GameState.new_game()
	GameState.register_player(2)
	var drop_at := Vector2i(9, 9)
	check(GameState.request_drop(P, "seed:moonbell", drop_at) and GameState.seed_count("moonbell") == 0, "the host drops all their moonbell seeds")
	check(GameState.object_kind(drop_at) == "dropped" and int(GameState.objects[drop_at]["count"]) == 4 and GameState.can_walk(drop_at), "they lie on the ground and can be walked over")
	check(not GameState.request_drop(P, "seed:sunpuff", drop_at), "nothing else can be dropped on the same tile")
	check(not GameState.request_till(P, drop_at), "the tile can't be dug while something lies there")
	check(GameState.request_harvest(2, drop_at) and int(GameState.bag_of(2)["seeds"]["moonbell"]) == 8, "the partner picks them up: a way to give things")
	check(not GameState.objects.has(drop_at) and GameState.seed_count("moonbell") == 0, "they're gone from the ground and the host has none")
	GameState.request_drop(P, "seed:dewcup", drop_at)
	GameState.save_game()
	GameState.new_game()
	GameState.load_game()
	check(GameState.object_kind(drop_at) == "dropped" and int(GameState.objects[drop_at]["count"]) == 3, "dropped things stay where they are after save and load")
	check(int(GameState.bag_of(2).get("seeds", {}).get("moonbell", 0)) == 8, "so does the partner's bag")
	GameState.soil[Vector2i(10, 10)] = {"watered": false}
	check(not GameState.request_drop(P, "seed:sunpuff", Vector2i(10, 10)) and not GameState.request_drop(P, "seed:sunpuff", GameState.MAILBOX_CELL), "not on soil or where something stands")

	print("gardens from before own bags")
	GameState.apply_snapshot({"seeds": {"sunpuff": 9}, "coins": 777, "items": {"tea": 2}, "bin": {"tea": 1}})
	check(GameState.coins == 777 and GameState.seed_count("sunpuff") == 9 and GameState.item_count("tea") == 2 and int(GameState.bin["tea"]) == 1, "the old shared bag becomes the host's")
	GameState.new_game()

	print("curfew and energy")
	GameState.energy[P] = 1
	check(not GameState.request_till(P, Vector2i(8, 8)), "too tired to till")
	GameState.end_day(true)
	check(GameState.get_energy(P) == 50, "passing out restores half energy")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
