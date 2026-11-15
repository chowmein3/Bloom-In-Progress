# Bloom In Progress

Godot 4.4 project, GDScript. Cozy co-op gardening game. Read `docs/DESIGN.md` first.

## Layout
- `scripts/game_state.gd` (autoload `GameState`): all garden data and rules.
- `scripts/time_manager.gd` (autoload `TimeManager`): clock, seasons, rain.
- `scripts/net.gd` (autoload `Net`): host/join over ENet, player slots
  (host 1, guest 2), remote player positions.
- `scripts/main.gd`: builds the scene in code and starts solo/host/join games.
  `menu.gd`, `ground.gd`, `plant_view.gd`, `player.gd`, `hud.gd`, `rain.gd`
  are the visuals; all art is drawn with
  `_draw()` placeholders until real sprites go in `assets/`.
- `data/plants/*.tres`: one `plant_data.gd` resource per species. A new species
  must also be added to `GameState.SPECIES_PATHS`.

## Rules
- Every change to the world goes through `GameState.request_*()`. Never edit
  `soil`, `plants`, `seeds` or `produce` from other scripts. Co-op depends on it.
- Co-op is host-authoritative. A rule lives in a `_do_*()` function that only
  runs on the host; `request_*()` forwards a guest's call to the host. If a
  rule changes state, emit one of the existing change signals (they are
  mirrored to guests by the `_net_*()` functions) or add a mirrored one.
  Player ids are slots from `Net.local_id()`, never network peer ids.
- Only the host saves, ends the day and runs the clock.
- Garden state is plain dictionaries (not nodes) so it can be saved and sent
  over the network. Views read it and redraw on GameState signals.
- The window uses `canvas_items` stretch: positions and font sizes are in
  320x180 game units and text is drawn sharp at full window resolution.
- Use static types. Don't use `:=` on Dictionary values (they are Variant).
- Reference scripts with `preload`, not `class_name`.

## Checks
- Rules: `godot --headless --path . res://tests/test_runner.tscn` (must print ALL TESTS PASSED).
- Add a test there for every new rule.
- Co-op: `tests/run_coop_test.sh <godot binary>` (must print CO-OP TEST PASSED).
  Run it after touching `net.gd`, `game_state.gd` or the player/main scripts.
- Visual smoke test: `godot --path . res://tests/screenshot.tscn -- <output folder>`.
