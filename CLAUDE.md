# Bloom In Progress

Godot 4.4 project, GDScript. Cozy co-op gardening game. Read `docs/DESIGN.md` first.

## Layout
- `scripts/game_state.gd` (autoload `GameState`): all garden data and rules.
- `scripts/time_manager.gd` (autoload `TimeManager`): clock, seasons, rain.
- `scripts/net.gd` (autoload `Net`): networking entry point (solo stub for now).
- `scripts/main.gd`: builds the scene in code. `ground.gd`, `plant_view.gd`,
  `player.gd`, `hud.gd`, `rain.gd` are the visuals; all art is drawn with
  `_draw()` placeholders until real sprites go in `assets/`.
- `data/plants/*.tres`: one `plant_data.gd` resource per species. A new species
  must also be added to `GameState.SPECIES_PATHS`.

## Rules
- Every change to the world goes through `GameState.request_*()`. Never edit
  `soil`, `plants`, `seeds` or `produce` from other scripts. Co-op depends on it.
- Garden state is plain dictionaries (not nodes) so it can be saved and sent
  over the network. Views read it and redraw on GameState signals.
- Use static types. Don't use `:=` on Dictionary values (they are Variant).
- Reference scripts with `preload`, not `class_name`.

## Checks
- Rules: `godot --headless --path . res://tests/test_runner.tscn` (must print ALL TESTS PASSED).
- Add a test there for every new rule.
- Visual smoke test: `godot --path . res://tests/screenshot.tscn -- <output folder>`.
