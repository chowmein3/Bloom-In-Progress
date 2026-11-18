extends RefCounted
## Loads art and audio. Normally these come from Godot's import cache, but a
## fresh download of the project that was never opened in the editor has no
## cache yet, which used to leave the game grey and silent. In that case the
## raw PNG / WAV files are read directly.

const PLAYER_SPRITES: Array[String] = [
	"res://assets/sprites/boy_player.png",
	"res://assets/sprites/girl_player.png",
]
const PLAYER_FRAME_COUNT := 4
const PLAYER_MAX_DRAW_SIZE := Vector2(20, 26)
# The source poses have uneven vertical gutters, especially the girl's back row.
# Cuts lie in those gutters; equal-height cells would clip her hair.
const PLAYER_ATLAS_HEIGHT := 1448.0
const PLAYER_ROW_CUTS := [
	[0, 360, 715, 1078, 1448],
	[0, 375, 710, 1042, 1448],
]

static var _player_textures: Dictionary = {}
static var _player_regions: Dictionary = {}
static var _player_scales: Dictionary = {}


## Slot 1 is the boy; slot 2 is the girl, including remote players.
static func player_texture(slot: int) -> Texture2D:
	slot = clampi(slot, 1, 2)
	if not _player_textures.has(slot):
		_player_textures[slot] = texture(PLAYER_SPRITES[slot - 1])
	return _player_textures[slot]


## Read the source atlas once. Trim only transparent padding, keeping the PNG
## unchanged and using one scale for every pose so walking never changes size.
static func _prepare_player(slot: int) -> void:
	if _player_regions.has(slot):
		return
	var image: Image = player_texture(slot).get_image()
	var regions: Array[Rect2] = []
	var largest := Vector2.ZERO
	for row in 4:
		var top: int = roundi(float(PLAYER_ROW_CUTS[slot - 1][row]) * image.get_height() / PLAYER_ATLAS_HEIGHT)
		var bottom: int = roundi(float(PLAYER_ROW_CUTS[slot - 1][row + 1]) * image.get_height() / PLAYER_ATLAS_HEIGHT)
		for column in PLAYER_FRAME_COUNT:
			var left: int = roundi(float(column) * image.get_width() / PLAYER_FRAME_COUNT)
			var right: int = roundi(float(column + 1) * image.get_width() / PLAYER_FRAME_COUNT)
			var cell := Rect2i(left, top, right - left, bottom - top)
			var visible: Rect2i = _player_visible_rect(image.get_region(cell))
			var region := Rect2(Vector2(cell.position + visible.position), Vector2(visible.size))
			regions.append(region)
			largest = largest.max(region.size)
	_player_regions[slot] = regions
	_player_scales[slot] = minf(PLAYER_MAX_DRAW_SIZE.x / maxf(largest.x, 1.0), PLAYER_MAX_DRAW_SIZE.y / maxf(largest.y, 1.0))


## Faint alpha noise extends into the source gutters. Measure the silhouette
## using solid pixels; continue drawing the original texture and its colors.
static func _player_visible_rect(image: Image) -> Rect2i:
	image.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = image.get_data()
	var width: int = image.get_width()
	var left: int = width
	var top: int = image.get_height()
	var right: int = -1
	var bottom: int = -1
	for y in image.get_height():
		for x in width:
			if pixels[(y * width + x) * 4 + 3] < 128:
				continue
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1) if right >= 0 else Rect2i()


## Four columns (neutral, stride A, neutral, stride B); rows face down, left, right, up.
static func player_frame(slot: int = 1, facing: Vector2i = Vector2i.DOWN, column: int = 0) -> Rect2:
	slot = clampi(slot, 1, 2)
	_prepare_player(slot)
	var row: int = 0
	if facing == Vector2i.UP:
		row = 3
	elif facing.x < 0:
		row = 1
	elif facing.x > 0:
		row = 2
	return _player_regions[slot][row * PLAYER_FRAME_COUNT + clampi(column, 0, PLAYER_FRAME_COUNT - 1)]


## Centre every complete pose above the same ground line at the player's feet.
static func player_draw_rect(slot: int, facing: Vector2i = Vector2i.DOWN, column: int = 0) -> Rect2:
	slot = clampi(slot, 1, 2)
	var region: Rect2 = player_frame(slot, facing, column)
	var size: Vector2 = region.size * float(_player_scales[slot])
	return Rect2(Vector2(-size.x / 2.0, 1.0 - size.y), size)


static func player_hat_rect(slot: int, facing: Vector2i = Vector2i.DOWN, column: int = 0) -> Rect2:
	return Rect2(Vector2(-8, player_draw_rect(slot, facing, column).position.y), Vector2(16, 12))


## Front-facing hair and face, without the overalls below the covers.
static func player_head_frame(slot: int) -> Rect2:
	var region: Rect2 = player_frame(slot)
	region.size.y = floorf(region.size.y * 4.0 / 7.0)
	return region


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
