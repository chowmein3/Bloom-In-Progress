extends Node
## The single source of truth for the shared garden.
##
## RULE: every change to the world goes through a request_*() function here.
## Nothing else may edit `soil`, `plants`, `seeds` or `produce` directly.
##
## In co-op the host owns the garden. A guest's request_*() call is sent to the
## host, the host checks it and applies it with the matching _do_*() function,
## and the host's change signals are mirrored back to guests by the _net_*()
## functions at the bottom of this file.

signal cell_changed(cell: Vector2i)
signal plant_added(cell: Vector2i)
signal plant_removed(cell: Vector2i)
signal plant_petted(cell: Vector2i)
signal inventory_changed
signal energy_changed(player_id: int)
signal notice(text: String)
signal day_advanced(summary: Dictionary)
signal state_reloaded
signal sleepers_changed
signal tree_changed
signal journal_changed

const SPECIES_PATHS: Array[String] = [
	"res://data/plants/sunpuff.tres",
	"res://data/plants/moonbell.tres",
	"res://data/plants/dewcup.tres",
	"res://data/plants/pricklepal.tres",
	"res://data/plants/gigglecap.tres",
	"res://data/plants/lanternsquash.tres",
	"res://data/plants/frostwhisker.tres",
	"res://data/plants/snowpip.tres",
]
const WORLD_SIZE := Vector2i(28, 18)  # in 16px tiles
const TENT_RECT := Rect2i(12, 1, 3, 2)  # sleep here to end the day
## The Heart Tree: one shared plant that grows on the love the whole garden
## gets. Water it and hug it (pet) like any plant.
const TREE_RECT := Rect2i(9, 4, 2, 2)
const TREE_STAGE_NAMES: Array[String] = ["Heart Seed", "Heart Sprout", "Heart Sapling", "Young Heart Tree", "Heart Tree in bloom"]
const TREE_STAGE_LOVE: Array[int] = [0, 40, 120, 260, 450]  # love needed to reach each stage
const TREE_GIFTS: Dictionary = {  # seeds dropped on reaching a stage
	1: {"pricklepal": 3},
	2: {"gigglecap": 3, "lanternsquash": 3},
	3: {"frostwhisker": 3, "snowpip": 3},
	4: {"sunpuff": 2, "dewcup": 2},
}
const TREE_LOVE_PER_PLANT := 1  # per plant cared for that day...
const TREE_LOVE_PLANT_CAP := 12  # ...up to this many
const TREE_LOVE_WATERED := 3
const TREE_LOVE_HUG := 2  # per player who hugged it
const JOURNAL_PLANTED := 1
const JOURNAL_BLOOMED := 2
const JOURNAL_RADIANT := 3
const MAX_ENERGY := 100
const COST_TILL := 2
const COST_WATER := 1
const COST_PLANT := 1
const COST_HARVEST := 1
const START_HAPPINESS := 50
const RADIANT_AT := 80  # happiness needed for a radiant bloom
const HAPPY_WATERED := 4
const HAPPY_PETTED := 8
const HAPPY_NEGLECTED := -12
const HAPPY_DUET := 6  # extra when two different players pet a plant the same day
const SOIL_REVERT_CHANCE := 0.1

const LEGACY_SAVE := "user://garden_save.json"  # the single save older versions used

## Folder holding one JSON file per saved garden.
var saves_dir: String = "user://saves"
## File of the garden being played; "" while none is open (nothing is saved).
var save_path: String = ""
var garden_name: String = "My Garden"
var species: Dictionary = {}  # id -> PlantData
var soil: Dictionary = {}  # Vector2i -> {"watered": bool}
var plants: Dictionary = {}  # Vector2i -> plant Dictionary (see _new_plant)
var seeds: Dictionary = {}  # species id -> count (shared by all players)
var produce: Dictionary = {}  # species id -> count (shared by all players)
var energy: Dictionary = {}  # player id -> int
var tree: Dictionary = {"love": 0, "watered": false, "hugged_by": {}}
var journal: Dictionary = {}  # species id -> best milestone so far (JOURNAL_*)
var sleeping: Dictionary = {}  # player id -> true, players in bed waiting for the others
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for path: String in SPECIES_PATHS:
		var data: Resource = load(path)
		species[data.get("id")] = data
	TimeManager.curfew_reached.connect(_on_curfew)
	TimeManager.time_changed.connect(_mirror_time)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.session_ended.connect(_on_session_ended)
	tree_changed.connect(_mirror_tree)
	journal_changed.connect(_mirror_journal)
	cell_changed.connect(_mirror_cell)
	plant_added.connect(_mirror_cell)
	plant_removed.connect(_mirror_cell)
	plant_petted.connect(_mirror_pet)
	inventory_changed.connect(_mirror_inventory)
	energy_changed.connect(_mirror_energy)
	sleepers_changed.connect(_mirror_sleepers)
	new_game()  # an empty garden behind the title menu until one is chosen


func new_game() -> void:
	soil.clear()
	plants.clear()
	produce.clear()
	sleeping.clear()
	journal.clear()
	tree = {"love": 0, "watered": false, "hugged_by": {}}
	seeds = {"sunpuff": 6, "moonbell": 4, "dewcup": 3}
	for pid: int in energy.keys():
		energy[pid] = MAX_ENERGY
	TimeManager.reset()
	state_reloaded.emit()


func register_player(player_id: int) -> void:
	if Net.is_host() and not energy.has(player_id):
		energy[player_id] = MAX_ENERGY
	energy_changed.emit(player_id)


# ---------------------------------------------------------------- queries

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_SIZE.x and cell.y < WORLD_SIZE.y


func is_tent(cell: Vector2i) -> bool:
	return TENT_RECT.has_point(cell)


func is_tree(cell: Vector2i) -> bool:
	return TREE_RECT.has_point(cell)


## Tiles nobody can walk on or dig up.
func is_blocked(cell: Vector2i) -> bool:
	return is_tent(cell) or is_tree(cell)


func tree_stage() -> int:
	var stage: int = 0
	for i in TREE_STAGE_LOVE.size():
		if int(tree["love"]) >= TREE_STAGE_LOVE[i]:
			stage = i
	return stage


## Love needed for the next stage, or -1 when fully grown.
func tree_next_goal() -> int:
	var stage: int = tree_stage()
	return TREE_STAGE_LOVE[stage + 1] if stage + 1 < TREE_STAGE_LOVE.size() else -1


func journal_level(species_id: String) -> int:
	return int(journal.get(species_id, 0))


func get_energy(player_id: int) -> int:
	return int(energy.get(player_id, MAX_ENERGY))


func seed_count(species_id: String) -> int:
	return int(seeds.get(species_id, 0))


func plant_stage(cell: Vector2i) -> int:
	var p: Dictionary = plants[cell]
	return species[p["species"]].stage_for(int(p["days_grown"]))


func plant_is_mature(cell: Vector2i) -> bool:
	var p: Dictionary = plants[cell]
	return plant_stage(cell) >= species[p["species"]].days_per_stage.size()


## Mature and ready to be picked.
func plant_is_ripe(cell: Vector2i) -> bool:
	return plant_is_mature(cell) and int(plants[cell]["regrow_wait"]) <= 0


func plant_is_radiant(cell: Vector2i) -> bool:
	return plant_is_mature(cell) and int(plants[cell]["happiness"]) >= RADIANT_AT


func describe_cell(cell: Vector2i) -> String:
	if is_tent(cell):
		return "Tent: rest here to end the day"
	if is_tree(cell):
		var goal: int = tree_next_goal()
		var progress: String = "love %d/%d" % [int(tree["love"]), goal] if goal > 0 else "fully grown"
		return "%s, %s%s" % [TREE_STAGE_NAMES[tree_stage()], progress, "" if bool(tree["watered"]) else ", thirsty"]
	if plants.has(cell):
		var p: Dictionary = plants[cell]
		var d: Resource = species[p["species"]]
		var stage: int = plant_stage(cell)
		var stage_name: String = "growing"
		if stage == 0:
			stage_name = "seed"
		elif plant_is_radiant(cell):
			stage_name = "radiant"
		elif plant_is_mature(cell):
			stage_name = "in bloom"
		var text: String = "%s, %s, mood %d" % [d.display_name, stage_name, int(p["happiness"])]
		if bool(p["dormant"]):
			text += ", dormant"
		elif not bool(soil[cell]["watered"]):
			text += ", thirsty"
		return text
	if soil.has(cell):
		return "Tilled soil (%s)" % ("watered" if bool(soil[cell]["watered"]) else "dry")
	return ""


# --------------------------------------------------------------- requests
# Call these from gameplay code. On a guest they only send the request to the
# host and return true; the result arrives through the usual signals.

func request_till(player_id: int, cell: Vector2i) -> bool:
	return _request("till", player_id, [cell])


func request_water(player_id: int, cell: Vector2i) -> bool:
	return _request("water", player_id, [cell])


func request_plant(player_id: int, cell: Vector2i, species_id: String) -> bool:
	return _request("plant", player_id, [cell, species_id])


func request_pet(player_id: int, cell: Vector2i) -> bool:
	return _request("pet", player_id, [cell])


func request_harvest(player_id: int, cell: Vector2i) -> bool:
	return _request("harvest", player_id, [cell])


func request_sleep(player_id: int) -> bool:
	return _request("sleep", player_id, [])


func _request(action: String, player_id: int, args: Array) -> bool:
	if Net.is_host():
		return _apply(action, player_id, args)
	_rpc_request.rpc_id(1, action, args)
	return true


func _apply(action: String, player_id: int, args: Array) -> bool:
	match action:
		"till": return _do_till(player_id, args[0])
		"water": return _do_water(player_id, args[0])
		"plant": return _do_plant(player_id, args[0], args[1])
		"pet": return _do_pet(player_id, args[0])
		"harvest": return _do_harvest(player_id, args[0])
		"sleep": return _do_sleep(player_id)
	return false


# ------------------------------------------------- rules (host side only)

func _do_till(player_id: int, cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_blocked(cell) or soil.has(cell):
		return false
	if not _spend(player_id, COST_TILL):
		return false
	soil[cell] = {"watered": TimeManager.raining}
	cell_changed.emit(cell)
	return true


func _do_water(player_id: int, cell: Vector2i) -> bool:
	if is_tree(cell):
		if bool(tree["watered"]) or not _spend(player_id, COST_WATER):
			return false
		tree["watered"] = true
		tree_changed.emit()
		return true
	if not soil.has(cell) or bool(soil[cell]["watered"]):
		return false
	if not _spend(player_id, COST_WATER):
		return false
	soil[cell]["watered"] = true
	if plants.has(cell):
		_credit(plants[cell], player_id)
	cell_changed.emit(cell)
	return true


func _do_plant(player_id: int, cell: Vector2i, species_id: String) -> bool:
	if not soil.has(cell) or plants.has(cell) or not species.has(species_id):
		return false
	var d: Resource = species[species_id]
	if seed_count(species_id) <= 0:
		_notify(player_id, "No %s seeds left" % d.display_name)
		return false
	if not d.seasons.has(TimeManager.season()):
		_notify(player_id, "%s won't wake up in %s" % [d.display_name, TimeManager.season_name()])
		return false
	if not _spend(player_id, COST_PLANT):
		return false
	seeds[species_id] = seed_count(species_id) - 1
	plants[cell] = _new_plant(species_id)
	_credit(plants[cell], player_id)
	_note(species_id, JOURNAL_PLANTED)
	inventory_changed.emit()
	plant_added.emit(cell)
	return true


## Affection: each player can pet each plant once per day.
func _do_pet(player_id: int, cell: Vector2i) -> bool:
	if is_tree(cell):
		if tree["hugged_by"].has(str(player_id)):
			_notify(player_id, "The tree is still glowing from your hug")
			return false
		tree["hugged_by"][str(player_id)] = true
		tree_changed.emit()
		return true
	if not plants.has(cell):
		return false
	var p: Dictionary = plants[cell]
	var key: String = str(player_id)
	if p["petted_by"].has(key):
		_notify(player_id, "It already feels loved today")
		return false
	p["petted_by"][key] = true
	_credit(p, player_id)
	plant_petted.emit(cell)
	return true


func _do_harvest(player_id: int, cell: Vector2i) -> bool:
	if not plants.has(cell):
		return false
	if not plant_is_ripe(cell):
		_notify(player_id, "Not ready to pick yet")
		return false
	if not _spend(player_id, COST_HARVEST):
		return false
	var p: Dictionary = plants[cell]
	var id: String = p["species"]
	var d: Resource = species[id]
	var radiant: bool = plant_is_radiant(cell)
	produce[id] = int(produce.get(id, 0)) + (2 if radiant else 1)
	if d.regrows:
		if radiant:
			seeds[id] = seed_count(id) + 1
		p["regrow_wait"] = d.regrow_days
		cell_changed.emit(cell)
	else:
		seeds[id] = seed_count(id) + (3 if radiant else 2)
		plants.erase(cell)
		plant_removed.emit(cell)
	inventory_changed.emit()
	_notify(player_id, "Picked %s%s" % [d.display_name, " (radiant!)" if radiant else ""])
	return true


## Getting into bed. The day ends once every player in the garden is in bed;
## asking again while waiting gets you back up.
func _do_sleep(player_id: int) -> bool:
	if sleeping.has(player_id):
		sleeping.erase(player_id)
		sleepers_changed.emit()
		return true
	sleeping[player_id] = true
	if _everyone_asleep():
		end_day(false)
	else:
		sleepers_changed.emit()
	return true


# ------------------------------------------------------------ day rollover

## `passed_out` is true when the clock hit 2am: anyone not in bed by then
## wakes up with half energy.
func end_day(passed_out: bool) -> void:
	if not Net.is_host():
		return
	var tree_news: Dictionary = _grow_tree()
	var discoveries: Array = []
	for cell: Vector2i in plants.keys():
		_grow_plant(cell)
		var id: String = plants[cell]["species"]
		var level: int = JOURNAL_RADIANT if plant_is_radiant(cell) else (JOURNAL_BLOOMED if plant_is_mature(cell) else 0)
		if level > journal_level(id):
			discoveries.append("%s %s for the first time" % [species[id].display_name, "turned radiant" if level == JOURNAL_RADIANT else "bloomed"])
			_note(id, level)
	for cell: Vector2i in soil.keys():
		soil[cell]["watered"] = false
		if not plants.has(cell) and rng.randf() < SOIL_REVERT_CHANCE:
			soil.erase(cell)
	TimeManager.start_next_day()
	var season: int = TimeManager.season()
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		p["dormant"] = not species[p["species"]].seasons.has(season)
	if TimeManager.raining:
		for cell: Vector2i in soil.keys():
			soil[cell]["watered"] = true
	tree["watered"] = TimeManager.raining
	tree["hugged_by"] = {}
	tree_changed.emit()
	var dozers: Array = []
	for pid: int in energy.keys():
		var slept: bool = not passed_out or sleeping.has(pid)
		@warning_ignore("integer_division")
		energy[pid] = MAX_ENERGY if slept else MAX_ENERGY / 2
		if not slept:
			dozers.append(pid)
		energy_changed.emit(pid)
	sleeping.clear()
	sleepers_changed.emit()
	save_game()
	var summary: Dictionary = {
		"passed_out": dozers,
		"raining": TimeManager.raining,
		"tree": tree_news,
		"discoveries": discoveries,
	}
	day_advanced.emit(summary)
	if _mirroring():
		_net_day.rpc(to_snapshot(), summary)


## Adds today's love to the Heart Tree. Returns {} or, when it reached a new
## stage, {"stage": int, "gifts": "3 Pricklepal seeds, ..."}.
func _grow_tree() -> Dictionary:
	var cared: int = 0
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		if not bool(p["dormant"]) and (bool(soil[cell]["watered"]) or not p["petted_by"].is_empty()):
			cared += 1
	var gained: int = mini(cared, TREE_LOVE_PLANT_CAP) * TREE_LOVE_PER_PLANT
	if bool(tree["watered"]):
		gained += TREE_LOVE_WATERED
	gained += tree["hugged_by"].size() * TREE_LOVE_HUG
	var before: int = tree_stage()
	tree["love"] = int(tree["love"]) + gained
	var after: int = tree_stage()
	if after == before:
		return {}
	var parts: Array = []
	for stage in range(before + 1, after + 1):
		var gifts: Dictionary = TREE_GIFTS.get(stage, {})
		for id: String in gifts.keys():
			seeds[id] = seed_count(id) + int(gifts[id])
			parts.append("%d %s seeds" % [int(gifts[id]), species[id].display_name])
	inventory_changed.emit()
	return {"stage": after, "gifts": ", ".join(parts)}


func _grow_plant(cell: Vector2i) -> void:
	var p: Dictionary = plants[cell]
	var d: Resource = species[p["species"]]
	var happiness: int = int(p["happiness"])
	# Out of season plants sleep: no growth, and no hurt feelings either.
	if d.seasons.has(TimeManager.season()):
		if bool(soil[cell]["watered"]):
			if not plant_is_mature(cell):
				p["days_grown"] = int(p["days_grown"]) + 1
				# Well-loved plants sometimes put on a growth spurt.
				if happiness >= RADIANT_AT and rng.randf() < 0.25:
					p["days_grown"] = int(p["days_grown"]) + 1
			elif int(p["regrow_wait"]) > 0:
				p["regrow_wait"] = int(p["regrow_wait"]) - 1
			happiness += HAPPY_WATERED
		else:
			happiness += HAPPY_NEGLECTED
		if not p["petted_by"].is_empty():
			happiness += HAPPY_PETTED
		if p["petted_by"].size() >= 2:
			happiness += HAPPY_DUET
	p["happiness"] = clampi(happiness, 0, 100)
	p["petted_by"] = {}


func _on_curfew() -> void:
	end_day(true)


# ----------------------------------------------------------------- helpers

func _new_plant(species_id: String) -> Dictionary:
	return {
		"species": species_id,
		"days_grown": 0,
		"happiness": START_HAPPINESS,
		"regrow_wait": 0,
		"dormant": false,
		"petted_by": {},  # str(player id) -> true, cleared every night
		"caretakers": {},  # str(player id) -> number of caring actions
	}


func _credit(plant: Dictionary, player_id: int) -> void:
	var key: String = str(player_id)
	plant["caretakers"][key] = int(plant["caretakers"].get(key, 0)) + 1


## Records a first for the garden journal.
func _note(species_id: String, level: int) -> void:
	if level > journal_level(species_id):
		journal[species_id] = level
		journal_changed.emit()


func _everyone_asleep() -> bool:
	for slot: int in Net.slots():
		if not sleeping.has(slot):
			return false
	return true


## Show a short message to one player, wherever they are playing.
func _notify(player_id: int, text: String) -> void:
	if player_id == Net.local_id():
		notice.emit(text)
	elif _mirroring():
		var peer_id: int = Net.peer_of(player_id)
		if peer_id != 0:
			_net_notice.rpc_id(peer_id, text)


func _spend(player_id: int, cost: int) -> bool:
	var left: int = get_energy(player_id)
	if left < cost:
		_notify(player_id, "Too tired... time to rest")
		return false
	energy[player_id] = left - cost
	energy_changed.emit(player_id)
	return true


# ------------------------------------------------------------- save / load

func to_snapshot() -> Dictionary:
	var soil_out: Dictionary = {}
	for cell: Vector2i in soil.keys():
		soil_out[_key(cell)] = soil[cell]
	var plants_out: Dictionary = {}
	for cell: Vector2i in plants.keys():
		plants_out[_key(cell)] = plants[cell]
	var energy_out: Dictionary = {}
	for pid: int in energy.keys():
		energy_out[str(pid)] = energy[pid]
	return {
		"version": 1,
		"name": garden_name,
		"saved_at": int(Time.get_unix_time_from_system()),
		"day_index": TimeManager.day_index,
		"minutes": TimeManager.minutes,
		"raining": TimeManager.raining,
		"soil": soil_out,
		"plants": plants_out,
		"seeds": seeds,
		"produce": produce,
		"tree": tree,
		"journal": journal,
		"energy": energy_out,
	}


func apply_snapshot(data: Dictionary) -> void:
	soil.clear()
	plants.clear()
	for key: String in data.get("soil", {}).keys():
		soil[_cell(key)] = {"watered": bool(data["soil"][key]["watered"])}
	for key: String in data.get("plants", {}).keys():
		var src: Dictionary = data["plants"][key]
		var p: Dictionary = _new_plant(str(src["species"]))
		p["days_grown"] = int(src["days_grown"])
		p["happiness"] = int(src["happiness"])
		p["regrow_wait"] = int(src["regrow_wait"])
		p["dormant"] = bool(src["dormant"])
		for k: String in src.get("petted_by", {}).keys():
			p["petted_by"][k] = true
		for k: String in src.get("caretakers", {}).keys():
			p["caretakers"][k] = int(src["caretakers"][k])
		plants[_cell(key)] = p
	# Gardens saved before the tent or tree stood somewhere may have soil there.
	for cell: Vector2i in soil.keys():
		if is_blocked(cell):
			soil.erase(cell)
			plants.erase(cell)
	seeds = _int_values(data.get("seeds", {}))
	produce = _int_values(data.get("produce", {}))
	journal = _int_values(data.get("journal", {}))
	var saved_tree: Dictionary = data.get("tree", {})
	tree = {"love": int(saved_tree.get("love", 0)), "watered": bool(saved_tree.get("watered", false)), "hugged_by": {}}
	for k: String in saved_tree.get("hugged_by", {}).keys():
		tree["hugged_by"][k] = true
	# Older gardens: anything already growing counts as planted in the journal.
	for cell: Vector2i in plants.keys():
		if journal_level(plants[cell]["species"]) < JOURNAL_PLANTED:
			journal[plants[cell]["species"]] = JOURNAL_PLANTED
	energy.clear()
	for key: String in data.get("energy", {}).keys():
		energy[int(key)] = int(data["energy"][key])
	garden_name = str(data.get("name", "My Garden"))
	TimeManager.day_index = int(data.get("day_index", 0))
	TimeManager.minutes = int(data.get("minutes", TimeManager.DAY_START))
	TimeManager.raining = bool(data.get("raining", false))
	TimeManager.time_changed.emit()
	state_reloaded.emit()


## Only the garden's owner saves; a guest never writes the host's garden to disk.
func save_game() -> void:
	if not Net.is_host() or save_path == "":
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % save_path)
		return
	file.store_string(JSON.stringify(to_snapshot(), "\t"))


func load_game() -> bool:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is damaged, starting a new garden")
		return false
	apply_snapshot(parsed)
	return true


# ------------------------------------------------------------ save files

## Every saved garden, newest first:
## {"path", "name", "day_index", "love", "saved_at"}.
func list_gardens() -> Array[Dictionary]:
	_adopt_legacy_save()
	var found: Array[Dictionary] = []
	for file_name: String in DirAccess.get_files_at(saves_dir):
		if not file_name.ends_with(".json"):
			continue
		var path: String = saves_dir.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		found.append({
			"path": path,
			"name": str(data.get("name", "My Garden")),
			"day_index": int(data.get("day_index", 0)),
			"love": int(data.get("tree", {}).get("love", 0)),
			"saved_at": int(data.get("saved_at", 0)),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["saved_at"]) > int(b["saved_at"]))
	return found


## Starts a brand new garden with its own save file and opens it.
func create_garden(new_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(saves_dir)
	new_game()
	garden_name = new_name.strip_edges().left(24)
	if garden_name == "":
		garden_name = "My Garden"
	var number: int = 1
	while FileAccess.file_exists(saves_dir.path_join("garden_%d.json" % number)):
		number += 1
	save_path = saves_dir.path_join("garden_%d.json" % number)
	save_game()


func open_garden(path: String) -> bool:
	save_path = path
	if load_game():
		return true
	close_garden()
	return false


## Back to an empty, unsaved garden (the title menu's backdrop).
func close_garden() -> void:
	save_path = ""
	garden_name = "My Garden"
	new_game()


func delete_garden(path: String) -> void:
	if path.begins_with(saves_dir) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _adopt_legacy_save() -> void:
	if saves_dir != "user://saves" or not FileAccess.file_exists(LEGACY_SAVE):
		return
	DirAccess.make_dir_recursive_absolute(saves_dir)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_SAVE), ProjectSettings.globalize_path(saves_dir.path_join("garden_0.json")))


func _key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _cell(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


func _int_values(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in source.keys():
		out[k] = int(source[k])
	return out


# ------------------------------------------------------------------ co-op

func is_sleeping(player_id: int) -> bool:
	return sleeping.has(player_id)


## True on a host with guests to keep up to date.
func _mirroring() -> bool:
	return Net.online and Net.is_host()


func _on_player_joined(slot: int) -> void:
	if not _mirroring():
		return
	register_player(slot)
	_net_snapshot.rpc_id(Net.peer_of(slot), to_snapshot(), sleeping.keys())


func _on_player_left(slot: int) -> void:
	if not _mirroring():
		return
	sleeping.erase(slot)
	if not sleeping.is_empty() and _everyone_asleep():
		end_day(false)
	else:
		sleepers_changed.emit()


## After leaving someone else's garden, go back to our own.
func _on_session_ended(was_host: bool) -> void:
	sleeping.clear()
	sleepers_changed.emit()
	if not was_host:
		close_garden()


## A guest asking the host to do something. Everything from the network is
## checked before use.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(action: String, args: Array) -> void:
	if not _mirroring():
		return
	var slot: int = Net.slot_of(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	var valid: bool = false
	match action:
		"till", "water", "pet", "harvest":
			valid = args.size() == 1 and args[0] is Vector2i
		"plant":
			valid = args.size() == 2 and args[0] is Vector2i and args[1] is String
		"sleep":
			valid = args.is_empty()
	if valid:
		_apply(action, slot, args)


func _mirror_tree() -> void:
	if _mirroring():
		_net_tree.rpc(tree)


func _mirror_journal() -> void:
	if _mirroring():
		_net_journal.rpc(journal)


@rpc("authority", "call_remote", "reliable")
func _net_tree(new_tree: Dictionary) -> void:
	tree = new_tree
	tree_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_journal(new_journal: Dictionary) -> void:
	journal = new_journal
	journal_changed.emit()


func _mirror_cell(cell: Vector2i) -> void:
	if _mirroring():
		_net_cell.rpc(cell, soil.get(cell), plants.get(cell))


func _mirror_pet(cell: Vector2i) -> void:
	if _mirroring():
		_net_cell.rpc(cell, soil.get(cell), plants.get(cell))
		_net_pet.rpc(cell)


func _mirror_inventory() -> void:
	if _mirroring():
		_net_inventory.rpc(seeds, produce)


func _mirror_energy(player_id: int) -> void:
	if _mirroring():
		_net_energy.rpc(player_id, get_energy(player_id))


func _mirror_sleepers() -> void:
	if _mirroring():
		_net_sleepers.rpc(sleeping.keys())


func _mirror_time() -> void:
	if _mirroring():
		_net_time.rpc(TimeManager.day_index, TimeManager.minutes, TimeManager.raining)


@rpc("authority", "call_remote", "reliable")
func _net_snapshot(data: Dictionary, sleepers: Array) -> void:
	apply_snapshot(data)
	_net_sleepers(sleepers)


@rpc("authority", "call_remote", "reliable")
func _net_day(data: Dictionary, summary: Dictionary) -> void:
	apply_snapshot(data)
	_net_sleepers([])
	day_advanced.emit(summary)


@rpc("authority", "call_remote", "reliable")
func _net_cell(cell: Vector2i, soil_state: Variant, plant: Variant) -> void:
	var had_plant: bool = plants.has(cell)
	if soil_state == null:
		soil.erase(cell)
	else:
		soil[cell] = soil_state
	if plant == null:
		plants.erase(cell)
	else:
		plants[cell] = plant
	if plant != null and not had_plant:
		plant_added.emit(cell)
	elif plant == null and had_plant:
		plant_removed.emit(cell)
	else:
		cell_changed.emit(cell)


@rpc("authority", "call_remote", "reliable")
func _net_pet(cell: Vector2i) -> void:
	if plants.has(cell):
		plant_petted.emit(cell)


@rpc("authority", "call_remote", "reliable")
func _net_inventory(new_seeds: Dictionary, new_produce: Dictionary) -> void:
	seeds = new_seeds
	produce = new_produce
	inventory_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_energy(player_id: int, value: int) -> void:
	energy[player_id] = value
	energy_changed.emit(player_id)


@rpc("authority", "call_remote", "reliable")
func _net_sleepers(sleepers: Array) -> void:
	sleeping.clear()
	for slot: int in sleepers:
		sleeping[slot] = true
	sleepers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_time(day_index: int, minutes: int, raining: bool) -> void:
	TimeManager.day_index = day_index
	TimeManager.minutes = minutes
	TimeManager.raining = raining
	TimeManager.time_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_notice(text: String) -> void:
	notice.emit(text)
