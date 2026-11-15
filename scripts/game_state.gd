extends Node
## The single source of truth for the shared garden.
##
## RULE: every change to the world goes through a request_*() function here.
## In co-op (Milestone 2) these become RPCs that the host validates, so
## nothing else may edit `soil`, `plants`, `seeds` or `produce` directly.

signal cell_changed(cell: Vector2i)
signal plant_added(cell: Vector2i)
signal plant_removed(cell: Vector2i)
signal plant_petted(cell: Vector2i)
signal inventory_changed
signal energy_changed(player_id: int)
signal notice(text: String)
signal day_advanced(summary: Dictionary)
signal state_reloaded

const SPECIES_PATHS: Array[String] = [
	"res://data/plants/sunpuff.tres",
	"res://data/plants/moonbell.tres",
	"res://data/plants/gigglecap.tres",
	"res://data/plants/frostwhisker.tres",
]
const WORLD_SIZE := Vector2i(28, 18)  # in 16px tiles
const TENT_RECT := Rect2i(20, 1, 3, 2)  # sleep here to end the day
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
const SOIL_REVERT_CHANCE := 0.1

var save_path: String = "user://garden_save.json"
var species: Dictionary = {}  # id -> PlantData
var soil: Dictionary = {}  # Vector2i -> {"watered": bool}
var plants: Dictionary = {}  # Vector2i -> plant Dictionary (see _new_plant)
var seeds: Dictionary = {}  # species id -> count (shared by all players)
var produce: Dictionary = {}  # species id -> count (shared by all players)
var energy: Dictionary = {}  # player id -> int
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for path: String in SPECIES_PATHS:
		var data: Resource = load(path)
		species[data.get("id")] = data
	TimeManager.curfew_reached.connect(_on_curfew)
	if not load_game():
		new_game()


func new_game() -> void:
	soil.clear()
	plants.clear()
	produce.clear()
	seeds = {"sunpuff": 6, "moonbell": 4, "gigglecap": 3, "frostwhisker": 2}
	for pid: int in energy.keys():
		energy[pid] = MAX_ENERGY
	TimeManager.reset()
	state_reloaded.emit()


func register_player(player_id: int) -> void:
	if not energy.has(player_id):
		energy[player_id] = MAX_ENERGY
	energy_changed.emit(player_id)


# ---------------------------------------------------------------- queries

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_SIZE.x and cell.y < WORLD_SIZE.y


func is_blocked(cell: Vector2i) -> bool:
	return TENT_RECT.has_point(cell)


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
	if is_blocked(cell):
		return "Tent: rest here to end the day"
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

func request_till(player_id: int, cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_blocked(cell) or soil.has(cell):
		return false
	if not _spend(player_id, COST_TILL):
		return false
	soil[cell] = {"watered": TimeManager.raining}
	cell_changed.emit(cell)
	return true


func request_water(player_id: int, cell: Vector2i) -> bool:
	if not soil.has(cell) or bool(soil[cell]["watered"]):
		return false
	if not _spend(player_id, COST_WATER):
		return false
	soil[cell]["watered"] = true
	if plants.has(cell):
		_credit(plants[cell], player_id)
	cell_changed.emit(cell)
	return true


func request_plant(player_id: int, cell: Vector2i, species_id: String) -> bool:
	if not soil.has(cell) or plants.has(cell) or not species.has(species_id):
		return false
	var d: Resource = species[species_id]
	if seed_count(species_id) <= 0:
		notice.emit("No %s seeds left" % d.display_name)
		return false
	if not d.seasons.has(TimeManager.season()):
		notice.emit("%s won't wake up in %s" % [d.display_name, TimeManager.season_name()])
		return false
	if not _spend(player_id, COST_PLANT):
		return false
	seeds[species_id] = seed_count(species_id) - 1
	plants[cell] = _new_plant(species_id)
	_credit(plants[cell], player_id)
	inventory_changed.emit()
	plant_added.emit(cell)
	return true


## Affection: each player can pet each plant once per day.
func request_pet(player_id: int, cell: Vector2i) -> bool:
	if not plants.has(cell):
		return false
	var p: Dictionary = plants[cell]
	var key: String = str(player_id)
	if p["petted_by"].has(key):
		notice.emit("It already feels loved today")
		return false
	p["petted_by"][key] = true
	_credit(p, player_id)
	plant_petted.emit(cell)
	return true


func request_harvest(player_id: int, cell: Vector2i) -> bool:
	if not plants.has(cell):
		return false
	if not plant_is_ripe(cell):
		notice.emit("Not ready to pick yet")
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
	notice.emit("Picked %s%s" % [d.display_name, " (radiant!)" if radiant else ""])
	return true


## Solo: sleeping ends the day at once. Co-op will wait for every player.
func request_sleep(_player_id: int) -> bool:
	end_day(false)
	return true


# ------------------------------------------------------------ day rollover

func end_day(passed_out: bool) -> void:
	for cell: Vector2i in plants.keys():
		_grow_plant(cell)
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
	for pid: int in energy.keys():
		@warning_ignore("integer_division")
		energy[pid] = MAX_ENERGY / 2 if passed_out else MAX_ENERGY
		energy_changed.emit(pid)
	save_game()
	day_advanced.emit({"passed_out": passed_out, "raining": TimeManager.raining})


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


func _spend(player_id: int, cost: int) -> bool:
	var left: int = get_energy(player_id)
	if left < cost:
		notice.emit("Too tired... time to rest")
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
		"day_index": TimeManager.day_index,
		"raining": TimeManager.raining,
		"soil": soil_out,
		"plants": plants_out,
		"seeds": seeds,
		"produce": produce,
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
	seeds = _int_values(data.get("seeds", {}))
	produce = _int_values(data.get("produce", {}))
	for key: String in data.get("energy", {}).keys():
		energy[int(key)] = int(data["energy"][key])
	TimeManager.day_index = int(data.get("day_index", 0))
	TimeManager.minutes = TimeManager.DAY_START
	TimeManager.raining = bool(data.get("raining", false))
	TimeManager.time_changed.emit()
	state_reloaded.emit()


func save_game() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % save_path)
		return
	file.store_string(JSON.stringify(to_snapshot(), "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is damaged, starting a new garden")
		return false
	apply_snapshot(parsed)
	return true


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
