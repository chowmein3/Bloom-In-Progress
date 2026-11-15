extends RefCounted
## Small per-player preferences kept in user://settings.json: the last address
## typed on the Join screen and the partner gardens joined by invite code.

const PATH := "user://settings.json"


static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


static func put(key: String, value: Variant) -> void:
	var data: Dictionary = read()
	data[key] = value
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


## Invite code -> garden name, for gardens this player has joined before.
static func known_gardens() -> Dictionary:
	var gardens: Variant = read().get("gardens", {})
	return gardens if typeof(gardens) == TYPE_DICTIONARY else {}


static func remember_garden(code: String, garden_name: String) -> void:
	var gardens: Dictionary = known_gardens()
	gardens[code] = garden_name
	put("gardens", gardens)


static func forget_garden(code: String) -> void:
	var gardens: Dictionary = known_gardens()
	gardens.erase(code)
	put("gardens", gardens)
