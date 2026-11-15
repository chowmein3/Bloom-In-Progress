Plan: Co-op Pixel-Art Garden Game — Starter Design + Build Plan (Godot 4)
Context
The user wants a whimsical pixel-art co-op game with the feel and art style of Stardew Valley, focused on growing and nurturing plants together over a long time. Decisions so far: Godot 4 (GDScript), online co-op, user has some coding experience and will vibe code with Claude Code. The project folder is empty.

This plan (1) breaks down how Stardew Valley's farming works, (2) says which parts to keep, simplify or change for a nurturing-focused co-op game, and (3) lays out a starter build order. The game uses its own name, plants, characters and art. It borrows the genre and general mechanics, not Stardew's content.

Part 1 — How Stardew Valley's farming works
1. Daily loop
The day runs from 6am to 2am. Each action uses energy, so how much you can do in a day is limited.
All growth happens overnight when the player sleeps. During the day, crops don't change.
Sleeping saves the game and starts a new day. In multiplayer, the day ends only when everyone is in bed.
2. Soil states (per tile)
untilled → tilled (hoe) → planted (seed) → watered (dark soil)

Each morning, watered soil goes back to dry, so crops need water every day.
Tilled soil with nothing planted can revert to grass overnight.
Rain waters every outdoor tile automatically.
3. Crop growth
A crop has a list of stages, each lasting N days (e.g. 1-2-2-2 = 7 days to mature).
A crop only moves forward on days it was watered. If it wasn't watered, it pauses but doesn't die.
Each crop belongs to one or more seasons (28 days each: spring, summer, fall, winter). When the season changes, crops that are out of season die.
Single-harvest crops are removed when picked. Regrowing crops (berries, beans) produce again every N days after they mature.
Special cases:
Trellis crops block walking.
Giant crops: a 3×3 patch of certain fully grown crops can merge into one huge plant.
Fruit trees need empty space around them, take about 28 days to grow, and then fruit every day in their season.
4. Things that change growth
Fertilizers:
Quality fertilizer raises the odds of better produce.
Speed fertilizer cuts growth time by a percentage.
Water-retaining soil gives a chance of staying watered overnight.
Sprinklers water tiles automatically in larger patterns as you upgrade them. This is the main way players scale up later in the game.
Scarecrows stop crows from eating crops within their radius.
The Greenhouse is a covered area that ignores seasons.
5. Quality and progression
Harvested produce comes in 4 quality tiers (normal, silver, gold, iridium). The odds depend on farming skill level and fertilizer.
Farming XP comes from harvesting. Each new skill level unlocks crafting recipes (sprinklers, fertilizer, and so on) and perks.
Money comes from shipping produce. Players spend it on seeds, tool upgrades (bigger watering area) and buildings.
6. Co-op specifics
2–4 players (up to 8 on PC) farm the same land and each has a cabin.
Money can be shared or kept separate.
Any player can tend any crop.
The host's machine is in charge of the game and keeps the save file.
Why it feels good
Watering every day is a small, satisfying chore.
Visible changes each morning give you a reason to log in tomorrow.
Seasons force you to plan ahead.
Automation (sprinklers) makes you feel your farm has grown up.
In co-op, players naturally split up jobs ("you water, I'll harvest").
Part 2 — Adapting it to our game ("nurture, not farm")
Stardew system	Our version
Crops as cash	Plants as companions. Harvesting is optional; the main reward is plants that grow, bloom and change.
Water only	Care needs: water, light (sun/shade placement), and affection (talk, sing, pet), plus occasional pest/weed events.
Quality stars	Mood/bond level per plant. Well-loved plants get special blooms and colors and drop rare seeds.
Seasons kill crops	Seasons change plant behavior (dormant in winter, blooming in spring). Fewer punishing losses, which suits a cozy game.
Energy bar	Keep a gentle energy bar. It caps the day and pushes players to share work.
Sprinklers	Keep a light version ("rain barrels") later, but affection is never automated. That keeps the human contact at the center.
Giant crops	Co-op wonders: some plants need 2+ players caring for them on the same day, or a mix of neighboring species, to grow into something rare.
Fruit trees	The Heart Tree: one shared long-term plant that grows over weeks of in-game time. It's the main thing everyone works toward together.
Shop & money	Swap money for seeds and garden journal unlocks. Seed trading between players is a social action.
Unique co-op hooks (pick 1–2 for v1):

Each plant notes which players cared for it. Plants grow fondest of the people who visit them most.
Duet care: two players singing to the same plant gives a bonus.
A shared garden journal fills in species entries as the group discovers them.
Part 3 — Starter build plan
Step 0 — Setup (on the user's PC)
Install Godot 4.x (standard version).
Install Git and create a GitHub repo.
In VS Code, add the godot-tools extension.
Run claude in the project folder.
Once there's code, run /init to create CLAUDE.md.
Step 1 — docs/DESIGN.md
Put a condensed Part 2 here so every Claude session has the rules.

Step 2 — Project skeleton
scenes/  main.tscn, world/garden.tscn, player/player.tscn, plants/plant.tscn, ui/hud.tscn
scripts/ game_state.gd, time_manager.gd, net.gd   (autoloads)
         plant.gd, soil_grid.gd, player.gd
data/plants/*.tres   (PlantData resources)
assets/  sprites/, tiles/, audio/
Rendering: 320×180 base resolution, 16×16 tiles, Nearest texture filtering, integer scaling.
Step 3 — Milestone 1: solo nurture loop (placeholder art)
Player: 4-direction movement. Acts on the tile in front. Tools: hoe, watering can, seed bag, hands (talk/pet/harvest). Energy bar.
SoilGrid (TileMapLayer plus a dictionary of cell → state): untilled, tilled or watered. Watered resets to dry each morning.
PlantData resource:
stages[], days_per_stage[]
seasons[]
regrows, regrow_days
needs (water, light)
bloom_variants
Plant node:
days_grown, watered_today
happiness (0–100), caretakers{player_id: count}
advance_day() runs overnight. It applies growth if watered, changes happiness based on care, and switches the sprite.
TimeManager: in-game clock, sleep to end the day, 28-day seasons. Starts with 1–2 seasons.
Weather: a random rain day waters every tile.
Save/load: a JSON file in user://, written on sleep.
Rule: every change to the world goes through GameState.request_*(). This is what lets Milestone 2 plug in networking.
Step 4 — Milestone 2: online co-op
ENetMultiplayerPeer with a host/join-by-IP menu. The host is in charge of the game state.
MultiplayerSpawner creates player characters; MultiplayerSynchronizer keeps their movement in sync.
GameState.request_* become RPCs to the host, which checks each request and sends the result to everyone. The day ends when all players are asleep.
Anyone who joins late receives a snapshot of the whole garden.
Add caretaker tracking and one duet or co-op wonder mechanic.
Step 5 — Milestone 3: content and whimsy
Real pixel art: Aseprite, or a CC0 itch.io pack to start.
6–10 plant species, the Heart Tree, the garden journal, seasonal blooms, ambient music, plant reaction animations (wiggles, sparkles, little faces).
Verification
Step 2: godot --path . opens a scaled pixel window with no errors. godot --headless --quit reports no script errors.
Milestone 1:
Till, plant, water and sleep through several days, and the plant moves through its stages.
Skip watering and growth pauses.
Rain waters everything.
Out-of-season plants go dormant.
Quit and reload restores the garden.
Milestone 2:
Run two local instances (Debug → Customize Run Instances).
Each player sees the other's actions live.
The day advances only when both players sleep.
A late joiner sees the existing garden.
