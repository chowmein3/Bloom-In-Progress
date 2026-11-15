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

	print("curfew and energy")
	GameState.energy[P] = 1
	check(not GameState.request_till(P, Vector2i(8, 8)), "too tired to till")
	GameState.end_day(true)
	check(GameState.get_energy(P) == 50, "passing out restores half energy")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	print("\n%s" % ("ALL TESTS PASSED" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
