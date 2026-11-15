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
	check(int(GameState.produce["sunpuff"]) >= 1, "produce gained")
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

	print("curfew and energy")
	GameState.energy[P] = 1
	check(not GameState.request_till(P, Vector2i(8, 8)), "too tired to till")
	GameState.end_day(true)
	check(GameState.get_energy(P) == 50, "passing out restores half energy")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
