extends Node2D
## Checks the hand-drawn characters through their real sheets and Player nodes.
##   godot --headless --path . res://tests/player_sprites_test.tscn
## Omit --headless and add -- <output folder> for direction/walk/hat galleries.

const Assets := preload("res://scripts/assets.gd")
const Player := preload("res://scripts/player.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]

var failures: int = 0
var out_dir: String = ""
var gallery: Array[Node2D] = []
var ground_line: float = INF


func _ready() -> void:
	Net.stop_lookup()
	Net.relay_url = ""
	TimeManager.paused = true
	GameState.save_path = ""
	GameState.wild_growth = false
	GameState.new_game()
	# Test fixture: begin bareheaded so the two galleries show the difference.
	# Normal gardens already own and wear straw; redundant purchases/wears fail.
	GameState.hats_owned = []
	GameState.outfits = {"1": "", "2": ""}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	RenderingServer.set_default_clear_color(Color("d6e6c3"))
	for action: String in ["move_left", "move_right", "move_up", "move_down", "sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for slot: int in [1, 2]:
		_check_sheet(slot)
	_check_motion()
	_build_gallery()
	await _frames(3)
	# The actual draw path must replace its cached sheet when a slot changes
	# (a local player becomes slot 2 when joining a host).
	var changing: Node2D = gallery[0]
	if int(changing.get("_texture_slot")) != -1:
		var first_texture: Texture2D = changing.get("_texture")
		changing.set("player_id", 2)
		changing.queue_redraw()
		await _frames(3)
		var second_texture: Texture2D = changing.get("_texture")
		_expect(int(changing.get("_texture_slot")) == 2 and first_texture != second_texture, "joining as slot 2 refreshes the rendered character")
		changing.set("player_id", 1)
		changing.queue_redraw()
		await _frames(2)
	else:
		print("  render cache check requires a display; sheet and movement checks ran")
	await _shot("players_walk_directions")
	_expect(GameState.request_buy_hat(1, "straw") and GameState.request_wear(2, "straw"), "one shared straw hat purchase equips both gardeners")
	await _shot("players_walk_directions_hats")
	print("PLAYER SPRITES TEST PASSED" if failures == 0 else "%d PLAYER SPRITE CHECKS FAILED" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _check_sheet(slot: int) -> void:
	var texture: Texture2D = Assets.player_texture(slot)
	_expect(texture != null, "slot %d loads its character sheet" % slot)
	if texture == null:
		return
	_expect(texture.get_size() == Vector2(1086, 1448), "slot %d uses the untouched source sheet" % slot)
	var image: Image = texture.get_image()
	_expect(image != null and not image.is_empty(), "slot %d has readable image content" % slot)
	if image == null or image.is_empty():
		return
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	var all_frames_valid: bool = true
	var frames_trimmed: bool = true
	var poses_fit: bool = true
	var scale_consistent: bool = true
	var feet_aligned: bool = true
	var hats_aligned: bool = true
	var source_regions: Array[Rect2] = []
	var visible_pixels_in_frames: int = 0
	var sheet_scale: float = -1.0
	var directions_differ: Dictionary = {}
	for direction: Vector2i in DIRECTIONS:
		var poses: Dictionary = {}
		for column in 4:
			var region: Rect2 = Assets.player_frame(slot, direction, column)
			if not region.has_area() or not bounds.encloses(region):
				all_frames_valid = false
				continue
			for previous: Rect2 in source_regions:
				if previous.intersects(region):
					all_frames_valid = false
			source_regions.append(region)
			var frame: Image = image.get_region(Rect2i(region))
			var visible_pixels: Rect2i = _silhouette_bounds(frame)
			if not visible_pixels.has_area():
				all_frames_valid = false
			else:
				if visible_pixels != Rect2i(Vector2i.ZERO, frame.get_size()):
					frames_trimmed = false
				visible_pixels_in_frames += _silhouette_pixel_count(frame)
				var destination: Rect2 = Assets.player_draw_rect(slot, direction, column)
				if destination.size.x > Assets.PLAYER_MAX_DRAW_SIZE.x + 0.01 or destination.size.y > Assets.PLAYER_MAX_DRAW_SIZE.y + 0.01:
					poses_fit = false
				var scale_x: float = destination.size.x / region.size.x
				var scale_y: float = destination.size.y / region.size.y
				if sheet_scale < 0.0:
					sheet_scale = scale_x
				if absf(scale_x - scale_y) > 0.0001 or absf(scale_x - sheet_scale) > 0.0001:
					scale_consistent = false
				if absf(destination.get_center().x) > 0.01:
					feet_aligned = false
				var feet_y: float = destination.position.y + float(visible_pixels.end.y) / frame.get_height() * destination.size.y
				if ground_line == INF:
					ground_line = feet_y
				if absf(feet_y - ground_line) > 0.01:
					feet_aligned = false
					print("    feet mismatch: slot %d direction %s column %d lands at %.2f, expected %.2f" % [slot, direction, column, feet_y, ground_line])
				var hat: Rect2 = Assets.player_hat_rect(slot, direction, column)
				if not hat.has_area() or absf(hat.get_center().x) > 0.01 or absf(hat.position.y - destination.position.y) > 0.01:
					hats_aligned = false
			poses[hash(frame.get_data())] = true
			if column == 0:
				directions_differ[hash(frame.get_data())] = true
		_expect(poses.size() > 1, "slot %d direction %s has distinct walking poses" % [slot, direction])
	_expect(all_frames_valid and source_regions.size() == 16, "slot %d all 16 source frames fit, contain art and do not overlap" % slot)
	_expect(frames_trimmed, "slot %d every frame fits its silhouette while ignoring faint alpha noise" % slot)
	_expect(visible_pixels_in_frames == _silhouette_pixel_count(image), "slot %d slicing retains every source pixel with alpha at least 128" % slot)
	_expect(poses_fit, "slot %d all poses fit the world character envelope" % slot)
	_expect(scale_consistent, "slot %d all poses preserve aspect ratio at one consistent scale" % slot)
	_expect(feet_aligned, "slot %d every facing and walking pose shares the same visible ground line" % slot)
	_expect(hats_aligned, "slot %d hats follow every pose's crown and stay centered" % slot)
	_expect(directions_differ.size() == 4, "slot %d each facing direction selects different art" % slot)
	_expect(image.get_pixel(0, 0).a == 0.0, "slot %d retains a transparent background" % slot)
	var front: Rect2 = Assets.player_frame(slot)
	var head: Rect2 = Assets.player_head_frame(slot)
	_expect(head.has_area() and front.encloses(head) and head.position == front.position, "slot %d the bed head crop stays inside the front-facing pose" % slot)
	_expect(is_equal_approx(head.size.x, front.size.x) and head.size.y > front.size.y * 0.45 and head.size.y < front.size.y * 0.65, "slot %d the bed crop includes the hair and face above the overalls" % slot)
	if slot == 2:
		var back: Rect2 = Assets.player_frame(slot, Vector2i.UP)
		_expect(back.position.y >= 1070.0 and back.position.y <= 1090.0 and back.end.y > 1340.0, "the girl's back pose retains the crown above the equal-height row boundary and both feet")
		var right: Rect2 = Assets.player_frame(slot, Vector2i.RIGHT)
		_expect(right.end.y < 1020.0 and right.size.y > 240.0, "the girl's right-facing pose excludes the following row's hair")


## Measure the visible silhouette independently of the runtime's row boundaries.
## The supplied PNGs have faint alpha noise in otherwise empty gutters.
func _silhouette_bounds(source: Image) -> Rect2i:
	var first := Vector2i(source.get_width(), source.get_height())
	var last := Vector2i(-1, -1)
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x, y).a >= 0.5:
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
	return Rect2i(first, last - first + Vector2i.ONE) if last.x >= 0 else Rect2i()


func _silhouette_pixel_count(source: Image) -> int:
	var rgba: Image = source.duplicate()
	if rgba.is_compressed():
		rgba.decompress()
	rgba.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = rgba.get_data()
	var count: int = 0
	for alpha in range(3, pixels.size(), 4):
		if pixels[alpha] >= 128:
			count += 1
	return count


func _check_motion() -> void:
	var local: Node2D = Player.new()
	local.position = Vector2(216, 152)
	local.set("in_menu", false)
	add_child(local)
	local.set_process(false)
	Input.action_press("move_right")
	local.call("_process", 0.15)
	_expect(float(local.get("_walk")) > 0.0 and local.get("facing") == Vector2i.RIGHT, "local movement advances the walk and faces right")
	Input.action_release("move_right")
	local.call("_process", 0.05)
	_expect(float(local.get("_walk")) == 0.0, "releasing movement restores the local idle pose")
	for busy_flag: String in ["in_menu", "reading", "frozen"]:
		Input.action_press("move_right")
		local.call("_process", 0.15)
		local.set(busy_flag, true)
		local.call("_process", 0.05)
		_expect(float(local.get("_walk")) == 0.0, "%s interrupts walking with an idle pose" % busy_flag)
		local.set(busy_flag, false)
		Input.action_release("move_right")
	local.emit_signal("acted")
	_expect(float(local.get("_lunge")) == 1.0 and int(local.get("_swings")) == 1, "a local action starts the sprite lean and reports its swing")
	local.call("_process", 0.1)
	_expect(float(local.get("_lunge")) > 0.0 and float(local.get("_lunge")) < 1.0, "the local action lean eases back toward the standing pose")
	local.call("_process", 0.2)
	_expect(float(local.get("_lunge")) == 0.0, "the local sprite settles after its action")
	local.queue_free()
	var remote: Node2D = Player.new()
	remote.set("player_id", 2)
	remote.set("is_remote", true)
	add_child(remote)
	remote.set_process(false)
	remote.call("remote_update", Vector2(3, 0), Vector2i.LEFT, true)
	remote.call("_process", 0.1)
	_expect(float(remote.get("_walk")) > 0.0 and remote.get("facing") == Vector2i.LEFT, "remote movement animates the girl's left-facing row")
	remote.call("remote_update", Vector2(3, 0), Vector2i.UP, false)
	remote.call("_process", 0.1)
	_expect(float(remote.get("_walk")) == 0.0 and remote.get("facing") == Vector2i.UP, "a stopped remote player changes direction and returns to idle")
	remote.call("remote_update", Vector2(3, 0), Vector2i.RIGHT, false, 1, 1)
	_expect(float(remote.get("_lunge")) == 1.0 and int(remote.get("tool_index")) == 1, "a partner's action starts the girl's lean with the held tool")
	remote.call("_process", 0.1)
	var settled_lean: float = remote.get("_lunge")
	remote.call("remote_update", Vector2(3, 0), Vector2i.RIGHT, false, 1, 1)
	_expect(float(remote.get("_lunge")) == settled_lean, "repeated partner state does not restart the action lean")
	remote.call("_process", 0.2)
	_expect(float(remote.get("_lunge")) == 0.0, "the partner sprite settles after its action")
	remote.queue_free()


func _build_gallery() -> void:
	_label("BOY  /  host", Vector2(24, 1))
	_label("GIRL  /  partner", Vector2(184, 1))
	_label("Columns: idle, stride A, idle, stride B", Vector2(50, 169))
	for row in DIRECTIONS.size():
		_label(["down", "left", "right", "up"][row], Vector2(1, 26 + row * 36))
		for slot: int in [1, 2]:
			for column in 4:
				var actor: Node2D = Player.new()
				actor.set("player_id", slot)
				actor.set("is_remote", true)
				actor.set("facing", DIRECTIONS[row])
				actor.set("_walk", (column + 0.1) / 9.0)
				actor.position = Vector2(34 + (slot - 1) * 160 + column * 32, 48 + row * 36)
				add_child(actor)
				actor.set_process(false)
				gallery.append(actor)


func _label(words: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = words
	label.position = at
	label.add_theme_font_size_override("font_size", 7)
	label.add_theme_color_override("font_color", Color("394d36"))
	add_child(label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(2)
	await RenderingServer.frame_post_draw
	var result: Error = get_viewport().get_texture().get_image().save_png(out_dir.path_join(shot_name + ".png"))
	_expect(result == OK, "saved %s" % shot_name)


func _expect(condition: bool, label: String) -> void:
	print("  %s  %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		failures += 1
