# Bloom-In-Progress
Grow a Garden Multiplayer Video Game for Couples

A cozy pixel-art co-op gardening game made with Godot 4. Milestone 1 (the solo
garden loop, with placeholder art) is playable. Online co-op is next.

![screenshot](docs/screenshot.png)

## Run it
1. Install [Godot 4.4 or newer](https://godotengine.org/download) (standard version).
2. Open Godot, choose **Import**, pick this folder's `project.godot`, then press **F5**.

Or from a terminal in this folder:

```bash
godot --path .
```

## Controls
| Key | Action |
|---|---|
| WASD / arrows | Move |
| Space / E | Use the current tool on the highlighted tile |
| 1-5 | Hoe, Watering Can, Seeds, Hands (pet), Basket (harvest) |
| Tab | Next tool |
| Q | Next seed type |

Face the tent and press Space to sleep. Plants grow overnight if they were
watered, and the game saves each night.

## Tests
```bash
godot --headless --path . res://tests/test_runner.tscn
```

See `docs/DESIGN.md` for the rules and roadmap.
