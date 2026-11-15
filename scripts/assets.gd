extends RefCounted
## Loads art and audio. Normally these come from Godot's import cache, but a
## fresh download of the project that was never opened in the editor has no
## cache yet, which used to leave the game grey and silent. In that case the
## raw PNG / WAV files are read directly.


static func texture(path: String) -> Texture2D:
	var loaded: Resource = ResourceLoader.load(path) if _imported(path) else null
	if loaded is Texture2D:
		return loaded
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(image) if image != null else null


static func sound(path: String) -> AudioStreamWAV:
	var loaded: Resource = ResourceLoader.load(path) if _imported(path) else null
	if loaded is AudioStreamWAV:
		return loaded
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))


## True when Godot has an imported copy of `path` ready (always so in the
## downloadable build).
static func _imported(path: String) -> bool:
	if not FileAccess.file_exists(path + ".import"):
		return ResourceLoader.exists(path)
	var info := ConfigFile.new()
	if info.load(path + ".import") != OK:
		return false
	var cached: String = str(info.get_value("remap", "path", ""))
	return cached != "" and FileAccess.file_exists(cached)
