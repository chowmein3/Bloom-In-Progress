# Bloom In Progress

Godot 4.4 project, GDScript. Cozy co-op gardening game. Read `docs/DESIGN.md` first.

## Layout
- `scripts/game_state.gd` (autoload `GameState`): all garden data and rules.
- `scripts/time_manager.gd` (autoload `TimeManager`): clock, seasons, rain.
- `scripts/net.gd` (autoload `Net`): host/join over ENet, player slots
  (host 1, guest 2), remote player positions, finding hosts on the local
  network (UDP beacon) and opening the router port (UPnP) while hosting.
- `scripts/relay_peer.gd` + `relay/server.js` (Node, deployed via
  `render.yaml`): co-op through a relay by invite code, used when
  `bloom/relay_url` in `project.godot` is set. Host is always peer 1, guest
  peer 2. Without it, co-op uses ENet on the local network or a typed address.
- `scripts/assets.gd`: load all art and audio through `Assets.texture()` /
  `Assets.sound()`; they fall back to the raw files when the project was never
  imported. `scripts/settings.gd`: per-player preferences.
- `export_presets.cfg`, `tools/build.sh`, `packaging/`: the downloadable
  Windows/Mac/Linux builds. `tools/publish_downloads.sh` force-pushes the zips
  to the `downloads` branch, which the README links to;
  `.github/workflows/release.yml` tests, builds and publishes on every push
  to `main` (when Actions can run for the account).
- `scripts/main.gd`: builds the scene in code and starts solo/host/join games.
  `menu.gd`, `ground.gd`, `plant_view.gd`, `tree_view.gd`, `player.gd`,
  `hud.gd`, `minimap.gd`, `journal.gd`, `rain.gd` (weather) and `effects.gd`
  (mood icons) are the visuals. `interior.gd` and `bed_view.gd` draw the
  inside of the home; `inventory.gd` (backpack), `shop.gd` and `clock.gd`
  (clock tower) are pop-up screens styled by `ui_style.gd`. `tower_view.gd`
  draws the tower; `time_warp.gd` is the animation played on
  `GameState.time_warped`. HUD panels share one parchment-and-wood style
  (`_style()` in `hud.gd`); icons come from `assets/sprites/ui_icons.png`.
- `scripts/object_view.gd`: one debris or placed thing on a garden tile
  (stepping stones and mulch are drawn by `ground.gd`). Item, recipe and
  debris tables are `ITEMS`, `RECIPES`, `DEBRIS` in `GameState`; every id
  needs a 16x16 picture at `assets/sprites/items/<id>.png`.
- `scripts/pond_view.gd` + `scripts/fishing.gd`: the pond and the fishing
  game. `scripts/bin.gd`: the shipping bin screen. Goals, festivals, fish and
  decor are tables in `GameState` (`GOALS`, `FESTIVALS`, `FISH`, `ITEMS`).
- `scripts/animal_view.gd`, `scripts/villager.gd` (chat and gifts),
  `scripts/mine_view.gd`: animals, visitors and the mine. Their tables are
  `ANIMALS`, `VILLAGERS`, `ORES` in `GameState`. The mine is a second indoor
  area at `GameState.MINE_ORIGIN`; use `is_in_mine(cell)` to tell it from the
  home.
- `scripts/notices.gd` (mailbox and notice board), `scripts/greenhouse_view.gd`,
  `scripts/social.gd` (emotes and chat). Tables: `MACHINES`, `SEED_LEVELS`,
  `FORAGE` in `GameState`. A machine's state lives on its object
  (`busy`, `ready`).
- The town (`GameState.TOWN_*`): its own area at `TOWN_ORIGIN`, drawn from
  `TOWN_MAP` (a letter per tile; `tools/town_art.py` reads it from
  `game_state.gd` to paint `town_<season>.png`, the buildings, props and
  townsfolk). `scripts/town_view.gd` draws the ground and water and adds the
  buildings, props, trees, woods and people to the y-sorted layer. Use
  `is_in_town(cell)`, `town_tile`, `town_building_at`, `town_prop_at`,
  `person_at`. Walking up off `GARDEN_TRAIL_TOP` goes to town
  (`Player.go_to_town`), down off `TOWN_GATE` back (`go_to_garden`).
  `TOWNSFOLK` are the shopkeepers (hours, `sells`, `buys`, `wants`, `tabs`);
  `shop.gd` is every shop screen (`open("stall")` or `open(keeper)`); rules
  are `request_sell_to`, `request_buy_from`, `request_town_request`,
  `request_donate`, `request_wish`, `request_lookout`; their state is
  `GameState.town` (saved, mirrored with the economy). Villagers stand at
  `TOWN_SPOTS` in town when not visiting; `person(id)` reads either table.
  Every building has a room (`TOWN_ROOMS`: a floor map per building, a
  letter per tile, also read by `tools/town_art.py` to paint
  `town_room_<id>.png`), laid out from `TOWN_ROOMS_X` far to the side of the
  grid (`is_indoors` is true there; use `town_room_of(cell)`,
  `town_room_tile`, `town_room_spot(id, letter)`). F on a building's door
  (`building_door`, `door_at`) goes in while `is_room_open`; walking down
  off the mat ("D") comes back out. Keepers stand at "K" behind their
  counter while open and at "H" otherwise; `talk_target` reaches across a
  counter. Everyone keeps a daily routine (`ROUTINES`: keepers have a
  morning, shop hours, an evening, a bedtime and a weekday off; villagers a
  day of favourite `TOWN_PLACES`; rain sends them to the inn or home),
  worked out from the clock alone so every player sees the same:
  `routine(id)` is the day's plan, `pose_of(id)` where someone is now
  (walking along `town_path`, which never crosses the orchard), `is_open`
  is false on a rest day. Walkers don't block the way; standing people do.
  `people_in_town()` says where everyone is (town or room cells);
  `town_rooms_view.gd` draws the rooms and the museum's cases.
- Quests: `scripts/stories.gd` holds the tables (`STORIES` a story per person
  in steps talk/bring/deliver/find, `SCENES` heart scenes at 2 and 4 hearts,
  `LOST`, `PROJECTS`); `GameState.Stories` reaches them. `moment(who)` says
  what talking to someone does next (scene, story step, errand, story start)
  and `request_moment(who, kind, choice)` does it; `scripts/moment.gd` is the
  screen player.gd opens instead of a shop or chat when one is waiting.
  Errands are on the mayor's Errands page (`request_errand`, new ones each
  morning), lost things are "dropped" objects on town grass (`_drop_lost`).
  Projects (`request_contribute`, the "J" board opens the mayor's Projects
  page) add props in town once built (`town_prop_at` includes them; call
  `_town_reshaped()` when what's built changes so walks are worked out
  again). All of it lives in `GameState.town` (saved, mirrored); the journal's
  Quests page lists it.
- Festivals (`FESTIVALS`, day `FESTIVAL_DAY` of each season) are held in the
  town plaza: everyone's routine ends at the party (`PARTY_GATHER` to
  `PARTY_END`, `PARTY_SPOTS`, shops shut, the garden's visitor comes too) and
  Mayor Clementine's screen gets a Festival page while `party_on()`. Each
  has an activity, kept in `town["festival"]` (`festival_state()`, fresh each
  festival) and judged by `_end_festival`: `request_show_entry` (Bloom Show
  entry, Harvest Fair display), `request_catch_firefly` (`fireflies()` are
  worked out from the clock; F on one catches it), `request_sky_lantern`.
  `scripts/festival_view.gd` draws the plaza's bunting, petals, fireflies,
  leaves and sky lanterns.
  Fixed trees, bushes, boulders, stumps and logs are `GameState.SCENERY`
  (each blocks its base tile, a log two; use `scenery_at(cell)`, which is ""
  once cut down). Trees, stumps and logs are cut with `request_chop`
  (`CHOP` table, `felled` saved, regrow after `REGROW_DAYS`); each swing
  emits `scenery_hit(cell, felled)`, mirrored to guests, which main.gd turns
  into the shake and fall animations (`scenery_view.gd`), drawn by
  `scenery_view.gd` from `assets/sprites/scenery/<kind>.png` (one frame per
  season). `border_view.gd` draws the land past the edge (the same grass,
  the cliff along the top, trails from `GameState.TRAILS`) and `decorate()`
  adds the woods to the y-sorted layer, all on the garden's level: along each
  side, the bottom (behind a fence) and the cliff top, a close edge row of
  trees with bushes and rocks between the trunks, then lighter woods behind
  (`WOODS_SPACING`).
  The pond is `GameState.POND_CELLS` (an organic blob in the bottom-left);
  `pond_view.gd` draws its smooth shape from those tiles. Scenery views are in the "scenery" group and change frame when
  border_view sees the season turn. The Heart Tree blocks walking only on its trunk row
  but can't be dug or built on anywhere in `TREE_RECT`. Fruit trees are `GameState.TREES` (sapling id -> fruit).
- Baking: recipes flagged `"oven": true` need an oven placed in the home
  (`has_oven()`); shop items flagged `"pantry": true` show on the Pantry tab.
- Each player has their own bag in `GameState.bags` (str(slot) -> seeds,
  produce, items, coins, bin, slots). `seeds`, `produce`, `items`, `coins`
  and `bin` are properties that read the bag of the player a rule is running
  for (inside `_apply`, via `_as()`), or this player's own anywhere else.
  Prizes for everyone use `_reward_everyone()`. In `game_state.gd` emit
  `inventory_changed` / `economy_changed` through `_changed()`. A bag's
  `slots` (from `bag_slots()`) order the backpack; slots 0-3 are the hot bar
  (keys 7-0). Moving and dropping go through `request_move_slot` /
  `request_drop`; a dropped stack is an object of kind "dropped".
- Tools are drawn from `assets/sprites/tools.png` (16x16, a row per upgrade
  tier); `tools_held.png` is the same set at 12x12 for the hands; `tool_art.gd` maps a tool to its picture (`frame`, `held_frame`). The HUD, shop and the
  player's swing (`Player._draw_tool`) all use it.
- `scripts/sound.gd` (autoload `Sound`): music and effects, driven by
  GameState signals.
- `assets/`: sprite sheets and audio, generated by `tools/make_art.py` and
  `tools/make_audio.py` (Python, Pillow and numpy). Frame layouts are described
  in those scripts. Commit the `.import` and `.uid` files Godot writes.
- `data/plants/*.tres`: one `plant_data.gd` resource per species. A new species
  must also be added to `GameState.SPECIES_PATHS`, to `PLANTS` in
  `tools/make_art.py` (then re-run it), and usually to `GameState.TREE_GIFTS`.

## Rules
- The inside of the home is at `GameState.INTERIOR_ORIGIN` in the same tile
  grid as the garden, so a position alone says whether someone is indoors.
  Use `GameState.can_walk(cell)` for movement. Room sizes and furniture in
  `GameState.ROOMS` must match the room pictures drawn by `tools/make_art.py`.
- Coins, upgrades and hats change only through `request_sell`, `request_buy_*`
  and `request_wear` (or other `request_*` rules); they emit `economy_changed`, which is mirrored to guests.
- Tests set `GameState.wild_growth = false` so debris never lands where a
  test digs. Keep that line in any new test.
- The date and time jump only through `request_set_time` (never by editing
  `TimeManager` from a screen), so guests stay in step.
- Tools are hoe, can, seeds, item, rod, pickaxe, axe (`Player.TOOLS`, keys
  1-7; the hot bar is 8, 9, 0, -). Anything that needs
  no tool goes through `Player.hand_action()` / `use_hand()`; `use_tool()`
  falls back to the hand when the tool has nothing to do. Don't add tools for
  hand jobs. Always act on `Player.target_cell()`: the tile in front for keys,
  or for mouse clicks the hovered tile if it is one of the 8 round the player
  (else the tile in front).
- Harvest ids may carry a quality suffix (`sunpuff.gold`). Use
  `GameState.base_of(id)` for icons and tables, `name_of`, `stock_of`,
  `sell_price_of` and `sellable_ids()` for everything else. Anything that
  consumes produce (recipes, requests, machines) counts with `total_of(id)`
  and takes with `_take_any()`, so silver and gold harvest count too.
- A pop-up screen sets `player.reading` while open and must not open when it
  is already true.
- Every change to the world goes through `GameState.request_*()`. Never edit
  `soil`, `plants`, `seeds` or `produce` from other scripts. Co-op depends on it.
- Co-op is host-authoritative. A rule lives in a `_do_*()` function that only
  runs on the host; `request_*()` forwards a guest's call to the host. If a
  rule changes state, emit one of the existing change signals (they are
  mirrored to guests by the `_net_*()` functions) or add a mirrored one.
  Player ids are slots from `Net.local_id()`, never network peer ids.
- Only the host saves, ends the day and runs the clock. When everyone is in
  bed the host waits `GameState.bedtime_fade` seconds (the HUD fades to
  black meanwhile) before `end_day`; getting up calls it off. Rule tests set
  `bedtime_fade = 0.0` so the day ends at once. As the fade starts the host
  emits `bedtime_started(kiss_by)` (mirrored): with two in bed, a
  `kiss_chance` goodnight kiss, which `bed_view.gd` plays frame by frame
  (`KISS_STEPS`) from `assets/sprites/kiss_<slot>.png`, hand-placed pixels in
  `tools/kiss_pixels.py` (32x32 frames over the bed, matched to the player
  sheet's size in bed), turning the covers down with
  `blanket_<level>_turned.png`. Only slot 1's frames exist so far: when the
  roll picks a slot without frames, slot 1 leans over instead.
- Saves are one JSON file per garden in `GameState.saves_dir`. A garden must be
  opened (`create_garden` / `open_garden`) before play; while `save_path` is ""
  nothing is saved. `main.gd` does this from the menu's signals, then calls
  `start_solo()` or `start_host()`.
- Garden state is plain dictionaries (not nodes) so it can be saved and sent
  over the network. Views read it and redraw on GameState signals.
- The window uses `canvas_items` stretch with `expand`: positions and font
  sizes are in game units and text is drawn sharp at full resolution. The view
  is at least 320x180 units but can be wider or taller; never assume exactly
  320x180, use anchors or `get_viewport().get_visible_rect().size`.
- Use static types. Don't use `:=` on Dictionary values (they are Variant).
- Reference scripts with `preload`, not `class_name`. Load textures and audio
  with `Assets.texture()` / `Assets.sound()`, never `preload` or bare `load()`.

## Checks
- After a fresh clone, or after changing anything in `assets/`, run
  `godot --headless --path . --import` once before the checks below.
- Rules: `godot --headless --path . res://tests/test_runner.tscn` (must print ALL TESTS PASSED).
- Add a test there for every new rule.
- Co-op: `tests/run_coop_test.sh <godot binary>` (must print CO-OP TEST PASSED).
  It runs over the local network, then through a local relay when Node.js is
  installed.
  Run it after touching `net.gd`, `game_state.gd` or the player/main scripts.
- Home, bed, shop, backpack: `godot --headless --path . res://tests/home_test.tscn`
  (must print HOME TEST PASSED). Run it after touching the player, interior,
  shop or inventory scripts.
- Menus: `godot --headless --path . res://tests/menu_test.tscn` (must print
  MENU TEST PASSED). Run it after touching `menu.gd` or how games start.
- Download build: `tools/build.sh <godot binary>` (needs export templates).
  Tests, tools, docs and packaging are left out of the exported game.
- Visual smoke test: `godot --path . res://tests/screenshot.tscn -- <output folder>`.
- Whole map, one picture per season (add `blocked` to tint tiles that can't be
  walked on, `town` for the town): `godot --path . res://tests/map_shot.tscn -- <output folder>`.
- The goodnight kiss, every frame in each home (add `film` for 20 pictures a
  second of it playing, darkening as in the game):
  `godot --path . res://tests/bed_shot.tscn -- <output folder>`.
