extends Node
## The single source of truth for the shared garden.
##
## RULE: every change to the world goes through a request_*() function here.
## Nothing else may edit `soil`, `plants`, `seeds` or `produce` directly.
##
## In co-op the host owns the garden. A guest's request_*() call is sent to the
## host, the host checks it and applies it with the matching _do_*() function,
## and the host's change signals are mirrored back to guests by the _net_*()
## functions at the bottom of this file.

signal cell_changed(cell: Vector2i)
signal plant_added(cell: Vector2i)
signal plant_removed(cell: Vector2i)
signal plant_petted(cell: Vector2i)
signal inventory_changed
signal energy_changed(player_id: int)
signal notice(text: String)
signal day_advanced(summary: Dictionary)
signal state_reloaded
signal sleepers_changed
signal tree_changed
signal journal_changed
signal object_changed(cell: Vector2i)  # something was placed on or picked up from a garden tile
signal mail_changed  # letters arrived or were opened, or the quest board changed
signal animals_changed  # an animal was bought, fed, petted or woke up
signal time_warped  # the clock tower changed the date or time
signal economy_changed  # coins, upgrades, hats owned or hats worn changed
signal bedtime_started(kiss_by: int)  # everyone is in bed and the fade begins; kiss_by: who leans over for a kiss, or 0
signal scenery_hit(cell: Vector2i, felled: bool)  # an axe struck a tree, stump or log; `felled` when it came down

const SPECIES_PATHS: Array[String] = [
	"res://data/plants/sunpuff.tres",
	"res://data/plants/moonbell.tres",
	"res://data/plants/dewcup.tres",
	"res://data/plants/pricklepal.tres",
	"res://data/plants/gigglecap.tres",
	"res://data/plants/lanternsquash.tres",
	"res://data/plants/frostwhisker.tres",
	"res://data/plants/snowpip.tres",
	"res://data/plants/skybell.tres",
	"res://data/plants/snapvine.tres",
	"res://data/plants/blazestar.tres",
	"res://data/plants/melonbub.tres",
	"res://data/plants/amberleaf.tres",
	"res://data/plants/duskberry.tres",
	"res://data/plants/glimmercap.tres",
	"res://data/plants/icebloom.tres",
	"res://data/plants/wheat.tres",
]
## Seeds Bristle starts stocking once the garden reaches a gardening level.
const SEED_LEVELS: Dictionary = {
	"wheat": 1, "skybell": 2, "blazestar": 2, "amberleaf": 2, "glimmercap": 2,
	"snapvine": 4, "melonbub": 4, "duskberry": 4, "icebloom": 4,
}
const WORLD_SIZE := Vector2i(40, 26)  # in 16px tiles
## Trees, bushes, boulders, stumps and logs that are part of the land. The
## axe cuts down trees, stumps and logs (see CHOP); bushes and boulders stay.
## Each is drawn from assets/sprites/scenery/<kind>.png, which changes with the
## season, and blocks only the tile its trunk or base stands on (a log, two).
const SCENERY: Dictionary = {
	Vector2i(30, 2): "oak", Vector2i(34, 1): "cherry", Vector2i(37, 4): "maple", Vector2i(31, 7): "birch",
	Vector2i(36, 9): "oak", Vector2i(38, 13): "maple", Vector2i(33, 14): "apple", Vector2i(29, 19): "cherry",
	Vector2i(35, 20): "birch", Vector2i(38, 22): "oak", Vector2i(10, 18): "maple", Vector2i(8, 22): "cherry",
	Vector2i(14, 20): "oak", Vector2i(16, 24): "birch", Vector2i(25, 20): "apple", Vector2i(11, 24): "maple",
	Vector2i(32, 4): "pine", Vector2i(38, 7): "pine", Vector2i(29, 11): "pine", Vector2i(35, 16): "pine",
	Vector2i(31, 23): "pine", Vector2i(9, 24): "pine", Vector2i(17, 21): "pine", Vector2i(23, 24): "pine",
	Vector2i(33, 9): "bush", Vector2i(30, 15): "bush", Vector2i(37, 18): "bush", Vector2i(27, 22): "bush",
	Vector2i(1, 19): "bush", Vector2i(12, 19): "bush", Vector2i(19, 19): "bush",
	Vector2i(36, 6): "boulder", Vector2i(34, 23): "boulder", Vector2i(9, 20): "boulder", Vector2i(22, 21): "boulder",
	Vector2i(32, 12): "stump", Vector2i(26, 24): "stump", Vector2i(6, 19): "stump", Vector2i(39, 1): "stump",
	Vector2i(29, 16): "log", Vector2i(12, 22): "log",
	Vector2i(19, 9): "oak", Vector2i(24, 10): "maple", Vector2i(21, 8): "birch", Vector2i(26, 14): "pine",
	Vector2i(16, 17): "cherry", Vector2i(1, 13): "pine", Vector2i(12, 17): "apple", Vector2i(26, 6): "oak",
	Vector2i(27, 11): "birch", Vector2i(37, 11): "cherry", Vector2i(30, 10): "oak", Vector2i(34, 6): "birch",
	Vector2i(28, 24): "oak", Vector2i(15, 23): "maple", Vector2i(18, 23): "birch", Vector2i(10, 21): "oak",
	Vector2i(14, 25): "pine", Vector2i(24, 22): "maple",
}
const SCENERY_NAMES: Dictionary = {
	"oak": "Oak tree", "maple": "Maple tree", "birch": "Birch tree", "cherry": "Cherry tree", "apple": "Wild apple tree",
	"pine": "Pine tree", "bush": "Wild bush", "boulder": "Mossy boulder", "stump": "Old stump", "log": "Fallen log",
}
## Worn dirt trails, just for looks (they can still be dug). Cells outside the
## garden carry the trails off through the cliff and the fence.
const TRAILS: Array[Vector2i] = [
	Vector2i(22, -5), Vector2i(22, -4), Vector2i(22, -3), Vector2i(22, -2), Vector2i(22, -1),
	Vector2i(22, 0), Vector2i(22, 1), Vector2i(22, 2),
	Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 3),
	Vector2i(12, 3), Vector2i(13, 3), Vector2i(14, 3), Vector2i(15, 3), Vector2i(16, 3), Vector2i(17, 3), Vector2i(18, 3),
	Vector2i(19, 3), Vector2i(20, 3), Vector2i(21, 3), Vector2i(22, 3), Vector2i(23, 3), Vector2i(24, 3), Vector2i(25, 3), Vector2i(26, 3),
	Vector2i(20, 18), Vector2i(20, 19), Vector2i(20, 20), Vector2i(20, 21), Vector2i(20, 22), Vector2i(20, 23),
	Vector2i(20, 24), Vector2i(20, 25), Vector2i(20, 26), Vector2i(20, 27), Vector2i(20, 28), Vector2i(20, 29),
]

## Trees, stumps and logs in the garden can be cut down with the axe:
## [swings needed, least wood, most wood]. They grow back after REGROW_DAYS
## unless something is built or dug where they stood.
const CHOP: Dictionary = {
	"oak": [3, 6, 8], "maple": [3, 6, 8], "pine": [3, 6, 8], "birch": [3, 5, 7], "cherry": [3, 5, 7],
	"apple": [3, 5, 7], "stump": [2, 2, 3], "log": [2, 3, 5],
}
const COST_CHOP := 3
const REGROW_DAYS := 28

## The tile a scenery thing is listed under (a log's left tile), or `cell`.
func scenery_base(cell: Vector2i) -> Vector2i:
	if not SCENERY.has(cell) and SCENERY.get(cell - Vector2i(1, 0), "") == "log":
		return cell - Vector2i(1, 0)
	return cell


## The scenery thing standing on `cell` (counting the second tile of a log),
## or "" for none or one that has been cut down.
func scenery_at(cell: Vector2i) -> String:
	var base: Vector2i = scenery_base(cell)
	if not SCENERY.has(base) or felled.has(base):
		return ""
	return SCENERY[base]


## The tiles a scenery thing listed at `at` stands on (a log has two).
func scenery_tiles(at: Vector2i) -> Array:
	return [at, at + Vector2i(1, 0)] if SCENERY.get(at, "") == "log" else [at]


## Whether the axe can cut what stands on `cell`.
func can_chop(cell: Vector2i) -> bool:
	return CHOP.has(scenery_at(cell))


const TENT_RECT := Rect2i(12, 1, 3, 2)  # sleep here to end the day
## The Heart Tree: one shared plant that grows on the love the whole garden
## gets. Water it and hug it (pet) like any plant.
const TREE_RECT := Rect2i(9, 4, 2, 2)
const TREE_STAGE_NAMES: Array[String] = ["Heart Seed", "Heart Sprout", "Heart Sapling", "Young Heart Tree", "Heart Tree in bloom"]
const TREE_STAGE_LOVE: Array[int] = [0, 40, 120, 260, 450]  # love needed to reach each stage
const TREE_GIFTS: Dictionary = {  # seeds dropped on reaching a stage
	1: {"pricklepal": 3},
	2: {"gigglecap": 3, "lanternsquash": 3},
	3: {"frostwhisker": 3, "snowpip": 3},
	4: {"sunpuff": 2, "dewcup": 2},
}
const TREE_LOVE_PER_PLANT := 1  # per plant cared for that day...
const TREE_LOVE_PLANT_CAP := 12  # ...up to this many
const TREE_LOVE_WATERED := 3
const TREE_LOVE_HUG := 2  # per player who hugged it
const JOURNAL_PLANTED := 1
const JOURNAL_BLOOMED := 2
const JOURNAL_RADIANT := 3
const MAX_ENERGY := 100
const START_SEEDS := {"sunpuff": 6, "moonbell": 4, "dewcup": 3}
const START_COINS := 100
const ENERGY_PER_HOME_LEVEL := 15  # a better bed means more energy each morning
const STARTER_SEEDS: Array[String] = ["sunpuff", "moonbell", "dewcup"]

## The clock tower, left of the home: lets players set any date and time.
const TOWER_RECT := Rect2i(7, 1, 2, 2)
const LAST_YEAR := 99

## The shopkeeper's stall in the garden.
const STALL_RECT := Rect2i(17, 1, 3, 2)

## Things the shop sells once each; buying raises upgrades[kind] by one level.
const UPGRADES: Dictionary = {
	"hoe": [
		{"name": "Sturdy Hoe", "cost": 250, "blurb": "Tills 3 tiles in a row"},
		{"name": "Master Hoe", "cost": 800, "blurb": "Tills 5 tiles in a row"},
	],
	"can": [
		{"name": "Big Watering Can", "cost": 300, "blurb": "Waters 3 tiles in a row"},
		{"name": "Grand Watering Can", "cost": 900, "blurb": "Waters 5 tiles in a row"},
	],
	"pickaxe": [{"name": "Pickaxe", "cost": 200, "blurb": "Breaks the rocks in the mine"}],
	"greenhouse": [{"name": "Greenhouse", "cost": 3000, "blurb": "A glass house where every plant grows all year"}],
	"coop": [{"name": "Chicken Coop", "cost": 800, "blurb": "A home for up to four hens"}],
	"barn": [{"name": "Barn", "cost": 2000, "blurb": "A home for up to two cows"}],
	"home": [
		{"name": "Cabin", "cost": 1500, "blurb": "A roomier home with a stove for cooking. +15 energy each morning"},
		{"name": "Cottage", "cost": 5000, "blurb": "Fireplace and all. +30 energy each morning"},
	],
}
const TOOL_REACH: Array[int] = [1, 3, 5]  # tiles in a row, by hoe / can level
const HOME_NAMES: Array[String] = ["Tent", "Cabin", "Cottage"]

## Hats: bought once for the garden, then either player can wear them.
## The order is the frame order in assets/sprites/hats.png.
const HAT_ORDER: Array[String] = ["straw", "flower", "sprout", "beanie", "sun", "laurel"]
const HATS: Dictionary = {
	"straw": {"name": "Straw Hat", "cost": 0},
	"flower": {"name": "Flower Crown", "cost": 150},
	"sprout": {"name": "Sprout", "cost": 200},
	"beanie": {"name": "Cosy Beanie", "cost": 250},
	"sun": {"name": "Sun Hat", "cost": 400},
	"laurel": {"name": "Golden Laurel", "cost": 0, "reward": true},  # for finishing every goal
}

## The fishing pond, and the shipping bin between the home and the stall.
## The pond, in the bottom-left corner, tucked in under the woods' leaves.
const POND_CELLS: Array[Vector2i] = [
	Vector2i(2, 20), Vector2i(3, 20), Vector2i(4, 20), Vector2i(5, 20),
	Vector2i(1, 21), Vector2i(2, 21), Vector2i(3, 21), Vector2i(4, 21), Vector2i(5, 21), Vector2i(6, 21),
	Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22), Vector2i(4, 22), Vector2i(5, 22), Vector2i(6, 22), Vector2i(7, 22),
	Vector2i(1, 23), Vector2i(2, 23), Vector2i(3, 23), Vector2i(4, 23), Vector2i(5, 23), Vector2i(6, 23), Vector2i(7, 23),
	Vector2i(2, 24), Vector2i(3, 24), Vector2i(4, 24), Vector2i(5, 24), Vector2i(6, 24),
	Vector2i(2, 25), Vector2i(3, 25), Vector2i(4, 25), Vector2i(5, 25),
]
const POND_RECT := Rect2i(1, 20, 7, 6)  # the pond's bounds
const BIN_CELL := Vector2i(16, 2)
const COST_FISH := 2
const XP_FISH := 3
## Fish, most common first; _roll_fish() decides which can bite when.
const FISH: Array[String] = ["minnow", "sunfish", "raincarp", "moonfin", "frostfin", "goldie"]

## Animals. The coop and barn are bought once; each animal has a fixed spot
## in front of its building, in buying order.
const COOP_RECT := Rect2i(1, 1, 3, 2)
const BARN_RECT := Rect2i(1, 6, 3, 2)
const ANIMAL_YARD := Rect2i(0, 0, 5, 10)  # kept clear of debris
const ANIMALS: Dictionary = {
	"chicken": {"name": "Chicken", "cost": 150, "home": "coop", "gives": "egg", "max": 4,
		"spots": [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]},
	"cow": {"name": "Cow", "cost": 500, "home": "barn", "gives": "milk", "max": 2,
		"spots": [Vector2i(1, 8), Vector2i(3, 8)]},
}

## Villagers who visit. `days` are days of the week (day number modulo 7).
## Each stands at VISITOR_CELL for the day. Friendship is 100 points a heart.
const VISITOR_CELL := Vector2i(17, 4)  # below the stall, clear of where players appear
const MAX_HEARTS := 5
const VILLAGERS: Dictionary = {
	"maple": {"name": "Maple", "what": "the beekeeper", "days": [0, 3],
		"loves": ["moonbell", "tea", "honey", "cinnamonbuns"], "likes": ["sunpuff", "dewcup", "plumble", "jam", "apple"], "dislikes": ["minnow", "sunfish", "raincarp", "moonfin", "frostfin", "goldie"],
		"lines": ["My bees adore your garden.", "Flowers first, everything else after.", "A good day starts with something sweet."],
		"rewards": [{"seeds": {"moonbell": 5}}, {"coins": 150}, {"items": {"tea": 3}}, {"coins": 300}, {"items": {"birdbath": 1}}]},
	"pebble": {"name": "Pebble", "what": "the young angler", "days": [1, 4],
		"loves": ["goldie", "moonfin", "skewer"], "likes": ["minnow", "sunfish", "raincarp", "frostfin"], "dislikes": ["weed", "fiber"],
		"lines": ["The big one's still in your pond. I can feel it.", "Rainy days are the best days.", "Have you tried fishing after dark?"],
		"rewards": [{"items": {"minnow": 3}}, {"coins": 150}, {"items": {"skewer": 3}}, {"coins": 300}, {"items": {"gnome": 1}}]},
	"thistle": {"name": "Old Thistle", "what": "the retired gardener", "days": [2, 5],
		"loves": ["pie", "lanternsquash", "applepie", "bananabread"], "likes": ["salad", "stew", "omelette", "egg", "milk"], "dislikes": ["stone", "wood"],
		"lines": ["In my day we watered by moonlight.", "Mulch. That's the secret. Mulch.", "You two have done wonders with this plot."],
		"rewards": [{"items": {"mulch": 4}}, {"items": {"cinnamon": 3, "sugar": 3, "butter": 2}}, {"items": {"sprinkler": 1}}, {"coins": 300}, {"items": {"sapling": 1}}]},
}

## The mine: a cave whose rocks are renewed every morning. It sits below the
## home's room in the far part of the grid. Rocks need the pickaxe.
const MINE_RECT := Rect2i(25, 1, 2, 2)  # the entrance, in the garden
const MINE_ORIGIN := Vector2i(100, 40)
const MINE_SIZE := Vector2i(12, 7)  # floor tiles, below two rows of wall
const COST_MINE := 2
const ORES: Dictionary = {  # rock kind -> [item it gives, most it gives, share of rocks]
	"ore_stone": ["stone", 2, 0.62],
	"ore_copper": ["copper", 2, 0.26],
	"ore_gold": ["goldore", 1, 0.08],
	"ore_gem": ["amethyst", 1, 0.04],
}

## Artisan machines: placed like any made thing. By hand: fill an empty one,
## wait `nights`, collect. A beehive needs no filling.
const MACHINES: Dictionary = {
	"jar": {"takes": "harvest", "count": 2, "makes": "jam", "nights": 2},
	"press": {"takes": "plumble", "count": 2, "makes": "juice", "nights": 2},
	"cheesepress": {"takes": "milk", "count": 1, "makes": "cheese", "nights": 1},
	"beehive": {"takes": "", "count": 0, "makes": "honey", "nights": 3},
}
## The greenhouse: plants inside ignore the seasons.
const GREENHOUSE_RECT := Rect2i(19, 13, 6, 4)
const MAILBOX_CELL := Vector2i(11, 2)
const BOARD_CELL := Vector2i(15, 2)
const MAX_QUESTS := 3
const QUEST_DAYS := 4
## Wild things to forage, one kind a season.
const FORAGE: Array[String] = ["wildgreens", "sunberry", "chestnut", "frostroot"]

## Fruit trees, by the sapling that grows into them, and the fruit each bears.
const TREES: Dictionary = {"sapling": "plumble", "applesapling": "apple", "bananasapling": "banana"}

## Fruit trees: a planted sapling takes this long to grow, then bears fruit
## every few days except in winter.
const TREE_GROW_DAYS := 10
const TREE_FRUIT_EVERY := 3
const SCARECROW_REACH := 6
const CROW_CHANCE := 0.2  # each night, when plants stand unguarded
const QUALITIES: Dictionary = {"silver": 1.25, "gold": 1.5}  # sell price multipliers

## One festival a season, on this day (1-28). Keyed by season.
const FESTIVAL_DAY := 14
const FESTIVALS: Dictionary = {
	0: {"name": "Bloom Show", "today": "Party in the yard from 5pm. Radiant plants are judged tonight: 50 coins each."},
	1: {"name": "Firefly Night", "today": "Party in the yard from 5pm. Plants petted today get twice the joy."},
	2: {"name": "Harvest Fair", "today": "Party in the yard from 5pm. Bristle and the shipping bin pay half as much again today."},
	3: {"name": "Lantern Night", "today": "Party in the yard from 5pm. Light three garden lanterns for a gift tonight."},
}

## Long-term goals, checked each night. Each pays its reward once.
const GOALS: Array[Dictionary] = [
	{"id": "blooms", "name": "First Blooms", "text": "Bring 3 kinds of plant to bloom", "coins": 150},
	{"id": "radiant", "name": "Glowing Reviews", "text": "Make 3 kinds of plant radiant", "coins": 300},
	{"id": "sprinkler", "name": "Hands Free", "text": "Set a sprinkler in the garden", "coins": 150},
	{"id": "angler", "name": "Angler", "text": "Catch 4 kinds of fish", "coins": 250},
	{"id": "chef", "name": "Home Cooking", "text": "Cook 3 different meals", "coins": 200},
	{"id": "helper", "name": "Good Neighbour", "text": "Fill 5 of Bristle's requests", "coins": 300},
	{"id": "cabin", "name": "Home Sweet Home", "text": "Move into the Cabin", "coins": 200},
	{"id": "sapling", "name": "Deep Roots", "text": "Grow the Heart Tree into a sapling", "coins": 250},
	{"id": "level5", "name": "Green Thumb", "text": "Reach gardening level 5", "coins": 400},
	{"id": "collector", "name": "Plant Collector", "text": "Plant 8 kinds of plant", "coins": 500},
	{"id": "master", "name": "Master Gardener", "text": "Finish every other goal", "hat": "laurel"},
]

## Things kept in the shared backpack besides seeds and harvest.
##   material: gathered from debris, used in recipes
##   place:    set down on an empty garden tile (solid ones block walking)
##   soil:     spread on a tilled tile
##   meal:     eaten for energy
##   fish:     caught in the pond; sold or cooked
##   decor:    bought from Bristle; set down indoors or in the garden
## `price` is what Bristle pays for one; `cost` is what he charges.
const ITEMS: Dictionary = {
	"wood": {"name": "Wood", "kind": "material", "blurb": "From fallen branches."},
	"stone": {"name": "Stone", "kind": "material", "blurb": "From rocks."},
	"fiber": {"name": "Fiber", "kind": "material", "blurb": "From weeds."},
	"mulch": {"name": "Rich Mulch", "kind": "soil", "blurb": "Spread on tilled soil. Plants in it often grow twice as fast, and the bed never grasses over."},
	"path": {"name": "Stepping Stone", "kind": "place", "solid": false, "blurb": "A tidy path. Nothing sprouts on it."},
	"fence": {"name": "Fence", "kind": "place", "solid": true, "blurb": "Marks out a bed."},
	"sprinkler": {"name": "Sprinkler", "kind": "place", "solid": true, "blurb": "Waters the four tiles beside it every morning."},
	"lantern": {"name": "Garden Lantern", "kind": "place", "solid": true, "blurb": "A warm glow after dark."},
	"tea": {"name": "Moonbell Tea", "kind": "meal", "energy": 30, "blurb": "Restores 30 energy."},
	"salad": {"name": "Garden Salad", "kind": "meal", "energy": 45, "blurb": "Restores 45 energy."},
	"stew": {"name": "Gigglecap Stew", "kind": "meal", "energy": 75, "blurb": "Restores 75 energy."},
	"pie": {"name": "Lantern Pie", "kind": "meal", "energy": 110, "blurb": "Restores 110 energy."},
	"skewer": {"name": "Fish Skewer", "kind": "meal", "energy": 50, "blurb": "Restores 50 energy."},
	"supper": {"name": "Moonfin Supper", "kind": "meal", "energy": 95, "blurb": "Restores 95 energy."},
	"minnow": {"name": "Pond Minnow", "kind": "fish", "price": 15, "blurb": "Bites any time."},
	"sunfish": {"name": "Sunny Bream", "kind": "fish", "price": 35, "blurb": "Spring and summer, by day."},
	"raincarp": {"name": "Rain Carp", "kind": "fish", "price": 50, "blurb": "Only when it rains."},
	"moonfin": {"name": "Moonfin", "kind": "fish", "price": 60, "blurb": "After six in the evening."},
	"frostfin": {"name": "Frostfin", "kind": "fish", "price": 55, "blurb": "Winter only."},
	"goldie": {"name": "Golden Koi", "kind": "fish", "price": 200, "blurb": "Very rare. Any time."},
	"fern": {"name": "Potted Fern", "kind": "decor", "solid": true, "cost": 80, "blurb": "A bit of the garden indoors."},
	"lamp": {"name": "Floor Lamp", "kind": "decor", "solid": true, "cost": 120, "blurb": "Cosy light."},
	"rug": {"name": "Round Rug", "kind": "decor", "solid": false, "flat": true, "cost": 150, "blurb": "Soft underfoot. Can be walked on."},
	"armchair": {"name": "Armchair", "kind": "decor", "solid": true, "cost": 200, "blurb": "For admiring the garden from."},
	"teatable": {"name": "Tea Table", "kind": "decor", "solid": true, "cost": 180, "blurb": "Set for two."},
	"bookcase": {"name": "Little Bookcase", "kind": "decor", "solid": true, "cost": 250, "blurb": "Mostly books about plants."},
	"jar": {"name": "Preserves Jar", "kind": "place", "solid": true, "blurb": "Fill with 2 of any harvest. Jam in two days."},
	"press": {"name": "Juice Press", "kind": "place", "solid": true, "blurb": "Fill with 2 plumbles. Juice in two days."},
	"cheesepress": {"name": "Cheese Press", "kind": "place", "solid": true, "blurb": "Fill with milk. Cheese tomorrow."},
	"beehive": {"name": "Beehive", "kind": "place", "solid": true, "blurb": "Honey every three days, except in winter."},
	"jam": {"name": "Jam", "kind": "fruit", "price": 110, "blurb": "From the preserves jar."},
	"juice": {"name": "Plumble Juice", "kind": "fruit", "price": 240, "blurb": "From the juice press."},
	"cheese": {"name": "Cheese", "kind": "fruit", "price": 190, "blurb": "From the cheese press."},
	"honey": {"name": "Honey", "kind": "fruit", "price": 80, "blurb": "From the beehive."},
	"wildgreens": {"name": "Wild Greens", "kind": "fruit", "price": 20, "blurb": "Foraged in spring."},
	"sunberry": {"name": "Sunberry", "kind": "fruit", "price": 25, "blurb": "Foraged in summer."},
	"chestnut": {"name": "Chestnut", "kind": "fruit", "price": 30, "blurb": "Foraged in fall."},
	"frostroot": {"name": "Frostroot", "kind": "fruit", "price": 35, "blurb": "Foraged in winter."},
	"scarecrow": {"name": "Scarecrow", "kind": "place", "solid": true, "blurb": "Keeps crows off plants within six tiles."},
	"bigsprinkler": {"name": "Great Sprinkler", "kind": "place", "solid": true, "blurb": "Waters all eight tiles around it every morning."},
	"applesapling": {"name": "Apple Sapling", "kind": "place", "solid": true, "cost": 350, "blurb": "Plant it on open ground. Grows in ten days, then bears apples."},
	"bananasapling": {"name": "Banana Sapling", "kind": "place", "solid": true, "cost": 400, "blurb": "Plant it on open ground. Grows in ten days, then bears bananas."},
	"apple": {"name": "Apple", "kind": "fruit", "price": 50, "blurb": "Crisp tree fruit. Good in a pie."},
	"banana": {"name": "Banana", "kind": "fruit", "price": 55, "blurb": "Tree fruit. Good in bread."},
	"flour": {"name": "Flour", "kind": "material", "pantry": true, "cost": 35, "blurb": "Milled from wheat, or bought."},
	"sugar": {"name": "Sugar", "kind": "material", "pantry": true, "cost": 15, "blurb": "From Bristle's pantry."},
	"butter": {"name": "Butter", "kind": "material", "pantry": true, "cost": 25, "blurb": "From Bristle's pantry."},
	"cinnamon": {"name": "Cinnamon", "kind": "material", "pantry": true, "cost": 30, "blurb": "From Bristle's pantry."},
	"oven": {"name": "Oven", "kind": "decor", "solid": true, "cost": 400, "blurb": "Set it down in your home, then press F on it to bake."},
	"bananabread": {"name": "Banana Bread", "kind": "meal", "energy": 120, "price": 260, "blurb": "Restores 120 energy."},
	"applepie": {"name": "Apple Pie", "kind": "meal", "energy": 140, "price": 320, "blurb": "Restores 140 energy."},
	"cinnamonbuns": {"name": "Cinnamon Buns", "kind": "meal", "energy": 90, "price": 130, "blurb": "Restores 90 energy."},
	"sapling": {"name": "Plumble Sapling", "kind": "place", "solid": true, "cost": 300, "blurb": "Plant it on open ground. Grows in ten days, then bears plumbles."},
	"feed": {"name": "Animal Feed", "kind": "material", "cost": 10, "blurb": "One helping for a chicken or cow."},
	"plumble": {"name": "Plumble", "kind": "fruit", "price": 60, "blurb": "Sweet tree fruit."},
	"egg": {"name": "Egg", "kind": "fruit", "pantry": true, "cost": 70, "price": 40, "blurb": "From a fed hen, or Bristle's pantry."},
	"milk": {"name": "Milk", "kind": "fruit", "price": 90, "blurb": "From a fed cow."},
	"copper": {"name": "Copper Ore", "kind": "material", "price": 25, "blurb": "From the mine."},
	"goldore": {"name": "Gold Nugget", "kind": "material", "price": 80, "blurb": "From the mine."},
	"amethyst": {"name": "Amethyst", "kind": "material", "price": 150, "blurb": "A rare find in the mine."},
	"omelette": {"name": "Omelette", "kind": "meal", "energy": 60, "blurb": "Restores 60 energy."},
	"cocoa": {"name": "Moonbell Cocoa", "kind": "meal", "energy": 85, "blurb": "Restores 85 energy."},
	"gnome": {"name": "Garden Gnome", "kind": "decor", "solid": true, "cost": 100, "blurb": "Keeps watch. Happy indoors or out."},
	"birdbath": {"name": "Bird Bath", "kind": "decor", "solid": true, "cost": 220, "blurb": "Visitors welcome."},
}
## Recipes, by the item they make. `needs` may name materials or harvested
## plants. `level` is the gardening level required; `kitchen` recipes need a
## stove (the Cabin or better).
const RECIPES: Dictionary = {
	"mulch": {"needs": {"fiber": 3}, "makes": 2, "level": 1},
	"path": {"needs": {"stone": 1}, "makes": 1, "level": 1},
	"fence": {"needs": {"wood": 2}, "makes": 1, "level": 1},
	"sprinkler": {"needs": {"stone": 3, "wood": 2}, "makes": 1, "level": 2},
	"lantern": {"needs": {"wood": 1, "stone": 1, "fiber": 1}, "makes": 1, "level": 3},
	"tea": {"needs": {"moonbell": 2}, "makes": 1, "level": 1, "kitchen": true},
	"salad": {"needs": {"sunpuff": 1, "dewcup": 1}, "makes": 1, "level": 2, "kitchen": true},
	"stew": {"needs": {"gigglecap": 2, "pricklepal": 1}, "makes": 1, "level": 3, "kitchen": true},
	"pie": {"needs": {"lanternsquash": 1, "snowpip": 1}, "makes": 1, "level": 4, "kitchen": true},
	"jar": {"needs": {"wood": 6, "stone": 2}, "makes": 1, "level": 2},
	"beehive": {"needs": {"wood": 5, "fiber": 3}, "makes": 1, "level": 2},
	"cheesepress": {"needs": {"wood": 4, "stone": 4}, "makes": 1, "level": 3},
	"press": {"needs": {"wood": 4, "copper": 2}, "makes": 1, "level": 3},
	"feed": {"needs": {"fiber": 2}, "makes": 2, "level": 1},
	"scarecrow": {"needs": {"wood": 3, "fiber": 2}, "makes": 1, "level": 1},
	"bigsprinkler": {"needs": {"copper": 4, "goldore": 1}, "makes": 1, "level": 4},
	"flour": {"needs": {"wheat": 2}, "makes": 1, "level": 1, "kitchen": true},
	"bananabread": {"needs": {"banana": 2, "flour": 1, "egg": 1, "sugar": 1}, "makes": 1, "level": 2, "oven": true},
	"applepie": {"needs": {"apple": 3, "flour": 1, "butter": 1, "sugar": 1}, "makes": 1, "level": 3, "oven": true},
	"cinnamonbuns": {"needs": {"flour": 2, "butter": 1, "cinnamon": 1, "sugar": 1}, "makes": 2, "level": 1, "oven": true},
	"omelette": {"needs": {"egg": 2}, "makes": 1, "level": 1, "kitchen": true},
	"cocoa": {"needs": {"milk": 1, "moonbell": 1}, "makes": 1, "level": 2, "kitchen": true},
	"skewer": {"needs": {"minnow": 2}, "makes": 1, "level": 1, "kitchen": true},
	"supper": {"needs": {"moonfin": 1, "gigglecap": 1}, "makes": 1, "level": 3, "kitchen": true},
}
## Wild debris that turns up in the garden, and the material each gives.
const DEBRIS: Dictionary = {"branch": "wood", "rock": "stone", "weed": "fiber"}
const DEBRIS_NAMES: Dictionary = {"branch": "Fallen branch", "rock": "Rock", "weed": "Weeds"}
const MAX_DEBRIS := 30
const YARD := Rect2i(5, 0, 17, 7)  # kept clear around the home, tower, stall and tree
const MULCH_BOOST := 0.35  # chance of an extra day's growth each night
## Gardening skill: total experience needed to reach each level (index 0 = level 1).
const LEVEL_XP: Array[int] = [0, 40, 100, 190, 320, 500, 740, 1050, 1450, 2000]
const ENERGY_PER_LEVEL := 2
const XP_HARVEST := 8
const XP_RADIANT := 4
const XP_REQUEST := 20

## Inside the home. It lives far to the right of the garden in the same grid,
## so a position alone says whether someone is indoors. A room has two rows
## of wall, then `size` tiles of floor; the exit mat is the middle two tiles
## of the bottom floor row. `bed` and `blocked` are relative to the room's
## top-left corner; the bed is 2x2.
const INTERIOR_ORIGIN := Vector2i(100, 0)
const ROOMS: Array[Dictionary] = [
	{"size": Vector2i(8, 5), "bed": Vector2i(1, 2), "blocked": [Vector2i(6, 2), Vector2i(7, 2)]},
	{"size": Vector2i(10, 6), "bed": Vector2i(1, 2), "blocked": [Vector2i(5, 2), Vector2i(7, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(9, 7)]},
	{"size": Vector2i(12, 7), "bed": Vector2i(1, 2), "blocked": [Vector2i(4, 2), Vector2i(6, 2), Vector2i(8, 2), Vector2i(9, 2), Vector2i(11, 2), Vector2i(11, 8), Vector2i(0, 8)]},
]
const COST_TILL := 2
const COST_WATER := 1
const COST_PLANT := 1
const COST_HARVEST := 1
const START_HAPPINESS := 50
const RADIANT_AT := 80  # happiness needed for a radiant bloom
const HAPPY_WATERED := 4
const HAPPY_PETTED := 8
const HAPPY_NEGLECTED := -12
const HAPPY_DUET := 6  # extra when two different players pet a plant the same day
const SOIL_REVERT_CHANCE := 0.1

const LEGACY_SAVE := "user://garden_save.json"  # the single save older versions used

## Folder holding one JSON file per saved garden.
var saves_dir: String = "user://saves"
## File of the garden being played; "" while none is open (nothing is saved).
var save_path: String = ""
var garden_name: String = "My Garden"
## Six-letter invite code a partner uses to join this garden through the relay.
var garden_code: String = ""
var species: Dictionary = {}  # id -> PlantData
var soil: Dictionary = {}  # Vector2i -> {"watered": bool}
var plants: Dictionary = {}  # Vector2i -> plant Dictionary (see _new_plant)
## Each player has their own bag: seeds, harvest, items, coins, what they put
## in the shipping bin and the order of their backpack slots. `seeds`,
## `produce`, `items`, `coins` and `bin` below are the bag of the player the
## rules are working for (`_owner`), or this player's own everywhere else.
var bags: Dictionary = {}  # str(player id) -> bag, see _new_bag()
var felled: Dictionary = {}  # SCENERY tile -> day it was cut down
var _chops: Dictionary = {}  # SCENERY tile -> axe swings so far (host only, not saved)
var _owner: int = 0  # whose bag the rules are using; 0 means this player's own
var _pending: Dictionary = {}  # signals held back while working on someone else's bag
var seeds: Dictionary:  # species id -> count
	get: return _bag()["seeds"]
	set(value): _bag()["seeds"] = value
var produce: Dictionary:  # species id -> count (plain quality)
	get: return _bag()["produce"]
	set(value): _bag()["produce"] = value
var energy: Dictionary = {}  # player id -> int
var tree: Dictionary = {"love": 0, "watered": false, "hugged_by": {}}
var items: Dictionary:  # item id -> count: materials, crafted things, meals, silver and gold harvest
	get: return _bag()["items"]
	set(value): _bag()["items"] = value
var objects: Dictionary = {}  # Vector2i -> {"kind": item or debris id}: things standing on garden tiles
var xp: int = 0  # gardening experience (shared)
var wanted: Dictionary = {}  # Bristle's request: {"species", "count", "reward"}, or {} for none
## Whether debris turns up in the garden by itself. Tests switch it off.
var wild_growth: bool = true
var mail: Array = []  # unopened letters: {"from", "text", "gift": {"coins", "items", "seeds"}}
var quests: Array = []  # notice board: {"who", "id", "count", "coins", "days"}
var animals: Array = []  # each {"kind", "mood", "fed", "petted_by"}; order gives its spot
var friends: Dictionary = {}  # villager id -> {"points", "talked", "gifted", "rewards"}
var bin: Dictionary:  # what this player put in the shipping bin: id -> count, sold overnight
	get: return _bag()["bin"]
	set(value): _bag()["bin"] = value
var stats: Dictionary = {"requests": 0, "cooked": {}, "fish": {}}  # tallies the goals look at
var goals_done: Array = []  # ids of GOALS already rewarded
var coins: int:  # each player has their own purse
	get: return int(_bag()["coins"])
	set(value): _bag()["coins"] = value
var upgrades: Dictionary = {"hoe": 0, "can": 0, "home": 0}
var hats_owned: Array = ["straw"]
var outfits: Dictionary = {}  # str(player id) -> hat id being worn
var journal: Dictionary = {}  # species id -> best milestone so far (JOURNAL_*)
var sleeping: Dictionary = {}  # player id -> true, players in bed waiting for the others
## Seconds from everyone being in bed to the next day, while the screen fades
## slowly to black (0 ends the day at once, for tests).
var bedtime_fade: float = 3.2
var _bedtime: int = 0  # bumped when bedtime starts or is called off, so a stale fade does nothing
## The chance that, with two in bed, one leans over to kiss the other as the
## night falls. Rolled on its own dice so it never changes the garden's luck.
var kiss_chance: float = 0.25
var _kiss_dice := RandomNumberGenerator.new()
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for path: String in SPECIES_PATHS:
		var data: Resource = load(path)
		species[data.get("id")] = data
	TimeManager.curfew_reached.connect(_on_curfew)
	TimeManager.time_changed.connect(_mirror_time)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.session_ended.connect(_on_session_ended)
	tree_changed.connect(_mirror_tree)
	journal_changed.connect(_mirror_journal)
	economy_changed.connect(_mirror_economy)
	object_changed.connect(_mirror_object)
	animals_changed.connect(_mirror_animals)
	mail_changed.connect(_mirror_mail)
	cell_changed.connect(_mirror_cell)
	plant_added.connect(_mirror_cell)
	plant_removed.connect(_mirror_cell)
	plant_petted.connect(_mirror_pet)
	_kiss_dice.randomize()
	inventory_changed.connect(_mirror_inventory)
	scenery_hit.connect(_mirror_scenery_hit)
	energy_changed.connect(_mirror_energy)
	sleepers_changed.connect(_mirror_sleepers)
	new_game()  # an empty garden behind the title menu until one is chosen


func new_game() -> void:
	bags = {}
	felled = {}
	_chops = {}
	soil.clear()
	plants.clear()
	produce.clear()
	sleeping.clear()
	journal.clear()
	tree = {"love": 0, "watered": false, "hugged_by": {}}
	objects = {}
	xp = 0
	wanted = {}
	animals = []
	friends = {}
	mail = []
	quests = []
	stats = {"requests": 0, "cooked": {}, "fish": {}}
	goals_done = []
	upgrades = {"hoe": 0, "can": 0, "home": 0}
	hats_owned = ["straw"]
	outfits = {}
	_fill_mine()
	for pid: int in energy.keys():
		energy[pid] = MAX_ENERGY
	TimeManager.reset()
	state_reloaded.emit()


func register_player(player_id: int) -> void:
	if Net.is_host() and not bags.has(str(player_id)):
		bags[str(player_id)] = _new_bag()  # a newcomer starts with their own seeds and purse
	if Net.is_host() and not energy.has(player_id):
		energy[player_id] = max_energy()
	energy_changed.emit(player_id)


# ------------------------------------------------------------------ bags

## A new player's bag: a few seeds and the starting purse.
func _new_bag() -> Dictionary:
	return {"seeds": START_SEEDS.duplicate(), "produce": {}, "items": {}, "coins": START_COINS, "bin": {}, "slots": []}


func _me() -> int:
	return maxi(Net.local_id(), 1)


func _bag() -> Dictionary:
	var key: String = str(_owner if _owner != 0 else _me())
	if not bags.has(key):
		bags[key] = _new_bag()
	return bags[key]


## A player's bag, for reading (never changes anything).
func bag_of(player_id: int) -> Dictionary:
	return bags.get(str(player_id), {})


## Emits inventory_changed or economy_changed, or holds it back while the host
## works on a partner's bag, so the host's own screens never redraw with it.
func _changed(what: String) -> void:
	if _owner != 0 and _owner != _me():
		_pending[what] = true
	elif what == "inventory":
		inventory_changed.emit()
	else:
		economy_changed.emit()


## Runs `job` with `player_id`'s bag as `seeds`, `items`, `coins` and so on.
func _as(player_id: int, job: Callable) -> Variant:
	var was: int = _owner
	_owner = player_id
	var result: Variant = job.call()
	_owner = was
	if _owner == 0 or _owner == _me():
		var held: Dictionary = _pending
		_pending = {}
		if held.has("inventory"):
			inventory_changed.emit()
		if held.has("economy"):
			economy_changed.emit()
	return result


## Coins and seeds for everyone in the garden (festival prizes, goals, the tree).
func _reward_everyone(amount: int, gift_seeds: Dictionary = {}) -> void:
	_bag()  # the host always has a bag
	for key: String in bags.keys():
		var bag: Dictionary = bags[key]
		bag["coins"] = int(bag["coins"]) + amount
		for id: String in gift_seeds.keys():
			bag["seeds"][id] = int(bag["seeds"].get(id, 0)) + int(gift_seeds[id])
	_changed("inventory")
	_changed("economy")


## Hot bar slots at the front of every bag's slot list (keys 7, 8, 9, 0).
const HOT_SLOTS := 4
const BAG_SLOTS := 30  # backpack slots shown at least, after the hot bar


## How many of a bag key ("seed:<id>", "harvest:<id>" or "item:<id>") the
## current bag has.
func bag_count(key: String) -> int:
	var id: String = key.get_slice(":", 1)
	match key.get_slice(":", 0):
		"seed": return seed_count(id)
		"harvest": return int(produce.get(id, 0))
		"item": return item_count(id)
	return 0


## Whether a thing can go in a hot bar slot: seeds, and things you hold.
func holdable(key: String) -> bool:
	var id: String = key.get_slice(":", 1)
	return key.begins_with("seed:") or (key.begins_with("item:") and ITEMS.has(id) and ["place", "soil", "meal", "decor"].has(str(ITEMS[id]["kind"])))


## The current bag's slots, tidied: things that ran out leave their slot and
## new things take the first free backpack slot. Each thing is in one slot.
## Slots 0-3 are the hot bar.
func bag_slots() -> Array:
	var bag: Dictionary = _bag()
	var present: Array = []
	for id: String in species.keys():
		if seed_count(id) > 0:
			present.append("seed:" + id)
	for id: String in species.keys():
		if int(produce.get(id, 0)) > 0:
			present.append("harvest:" + id)
	var item_ids: Array = items.keys()
	item_ids.sort()
	for id: String in item_ids:
		if item_count(id) > 0:
			present.append("item:" + id)
	var slots: Array = []
	for key: Variant in bag.get("slots", []):
		slots.append(str(key) if present.has(str(key)) and not slots.has(str(key)) else "")
	while slots.size() < HOT_SLOTS:
		slots.append("")
	for i in HOT_SLOTS:
		if slots[i] != "" and not holdable(slots[i]):
			slots[i] = ""
	for key: String in present:
		if not slots.has(key):
			var free: int = slots.find("", HOT_SLOTS)
			if free >= 0:
				slots[free] = key
			else:
				slots.append(key)
	while slots.size() < HOT_SLOTS + BAG_SLOTS:
		slots.append("")
	while slots.size() > HOT_SLOTS + BAG_SLOTS and slots[-1] == "":
		slots.pop_back()
	bag["slots"] = slots
	return slots


# ---------------------------------------------------------------- queries

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WORLD_SIZE.x and cell.y < WORLD_SIZE.y


func is_tent(cell: Vector2i) -> bool:
	return TENT_RECT.has_point(cell)


func is_tree(cell: Vector2i) -> bool:
	return TREE_RECT.has_point(cell)


func is_stall(cell: Vector2i) -> bool:
	return STALL_RECT.has_point(cell)


func is_pond(cell: Vector2i) -> bool:
	return POND_CELLS.has(cell)


func is_bin(cell: Vector2i) -> bool:
	return cell == BIN_CELL


func is_tower(cell: Vector2i) -> bool:
	return TOWER_RECT.has_point(cell)


## Garden tiles nobody can walk on or dig up.
func is_blocked(cell: Vector2i) -> bool:
	if scenery_at(cell) != "":
		return true
	if is_tent(cell) or is_tree(cell) or is_stall(cell) or is_tower(cell) or is_pond(cell) or is_bin(cell) or MINE_RECT.has_point(cell) or cell == MAILBOX_CELL or cell == BOARD_CELL:
		return true
	if (upgrade_level("coop") > 0 and COOP_RECT.has_point(cell)) or (upgrade_level("barn") > 0 and BARN_RECT.has_point(cell)):
		return true
	return animal_at(cell) >= 0 or (cell == VISITOR_CELL and visitor_today() != "")


## Index into `animals` of the one standing on `cell`, or -1.
func animal_at(cell: Vector2i) -> int:
	var seen: Dictionary = {}
	for i in animals.size():
		var kind: String = animals[i]["kind"]
		var nth: int = int(seen.get(kind, 0))
		seen[kind] = nth + 1
		if ANIMALS[kind]["spots"][nth] == cell:
			return i
	return -1


func animal_cell(index: int) -> Vector2i:
	var nth: int = 0
	for i in index:
		if animals[i]["kind"] == animals[index]["kind"]:
			nth += 1
	return ANIMALS[animals[index]["kind"]]["spots"][nth]


func animal_count(kind: String) -> int:
	var count: int = 0
	for animal: Dictionary in animals:
		if animal["kind"] == kind:
			count += 1
	return count


func in_greenhouse(cell: Vector2i) -> bool:
	return upgrade_level("greenhouse") > 0 and GREENHOUSE_RECT.has_point(cell)


## Whether a plant of this species is awake on `cell` this season.
func in_season(cell: Vector2i, species_id: String) -> bool:
	return in_greenhouse(cell) or species[species_id].seasons.has(TimeManager.season())


## Id of the villager visiting today, or "".
func visitor_today() -> String:
	for id: String in VILLAGERS.keys():
		if VILLAGERS[id]["days"].has(TimeManager.day_index % 7):
			return id
	return ""


func hearts(villager: String) -> int:
	@warning_ignore("integer_division")
	return mini(int(friends.get(villager, {}).get("points", 0)) / 100, MAX_HEARTS)


# ----- the mine

func is_mine_entrance(cell: Vector2i) -> bool:
	return MINE_RECT.has_point(cell)


func is_in_mine(cell: Vector2i) -> bool:
	return is_indoors(cell) and cell.y >= MINE_ORIGIN.y - 5


func mine_floor() -> Rect2i:
	return Rect2i(MINE_ORIGIN + Vector2i(0, 2), MINE_SIZE)


## Empties the mine and fills it with a fresh scatter of rocks.
func _fill_mine() -> void:
	for cell: Vector2i in objects.keys():
		if is_in_mine(cell):
			objects.erase(cell)
	var floor: Rect2i = mine_floor()
	for i in 20:
		var cell := Vector2i(rng.randi_range(floor.position.x, floor.end.x - 1), rng.randi_range(floor.position.y, floor.end.y - 2))
		if objects.has(cell):
			continue
		var roll: float = rng.randf()
		var kind: String = "ore_stone"
		for ore: String in ORES.keys():
			roll -= float(ORES[ore][2])
			if roll <= 0.0:
				kind = ore
				break
		objects[cell] = {"kind": kind}


# ----- the home and its inside

func home_level() -> int:
	return clampi(int(upgrades.get("home", 0)), 0, ROOMS.size() - 1)


func max_energy() -> int:
	return MAX_ENERGY + ENERGY_PER_HOME_LEVEL * home_level() + ENERGY_PER_LEVEL * (garden_level() - 1)


## The garden tile of the home's door (bottom middle of its footprint).
func home_door() -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(TENT_RECT.position.x + TENT_RECT.size.x / 2, TENT_RECT.end.y - 1)


func is_indoors(cell: Vector2i) -> bool:
	return cell.x >= INTERIOR_ORIGIN.x - 20


func room_size() -> Vector2i:
	return ROOMS[home_level()]["size"]


func room_floor() -> Rect2i:
	return Rect2i(INTERIOR_ORIGIN + Vector2i(0, 2), room_size())


func bed_rect() -> Rect2i:
	var bed: Vector2i = ROOMS[home_level()]["bed"]
	return Rect2i(INTERIOR_ORIGIN + bed, Vector2i(2, 2))


func is_bed(cell: Vector2i) -> bool:
	return bed_rect().has_point(cell)


## The exit mat: the middle two tiles of the bottom floor row.
func is_exit_mat(cell: Vector2i) -> bool:
	var floor: Rect2i = mine_floor() if is_in_mine(cell) else room_floor()
	@warning_ignore("integer_division")
	var middle: int = floor.position.x + floor.size.x / 2
	return cell.y == floor.end.y - 1 and (cell.x == middle or cell.x == middle - 1)


## Whether a player may stand on `cell`, in the garden or indoors.
func can_walk(cell: Vector2i) -> bool:
	if not is_indoors(cell):
		# The Heart Tree's leaves hang over the tiles above its trunk: you can
		# walk behind it there, but not dig or build.
		var behind_tree: bool = is_tree(cell) and cell.y < TREE_RECT.end.y - 1
		return in_bounds(cell) and (not is_blocked(cell) or behind_tree) and not is_solid(cell)
	if is_in_mine(cell):
		return mine_floor().has_point(cell) and not is_solid(cell)
	return _room_free(cell) and not is_solid(cell)


## Indoor floor with no bed or built-in furniture on it.
func _room_free(cell: Vector2i) -> bool:
	if not room_floor().has_point(cell) or is_bed(cell):
		return false
	return not ROOMS[home_level()]["blocked"].has(cell - INTERIOR_ORIGIN)


# ----- items, objects and crafting

func item_count(id: String) -> int:
	return int(items.get(id, 0))


## How many of an ingredient the garden has: harvested plants or items.
func stock_of(id: String) -> int:
	return int(produce.get(id, 0)) if species.has(id) else item_count(id)


## Harvest comes in three qualities. Normal harvest is kept in `produce` under
## the plant's id; silver and gold are kept in `items` as "<plant>.silver" and
## "<plant>.gold". These two split such an id.
func base_of(id: String) -> String:
	return id.get_slice(".", 0)


func quality_of(id: String) -> String:
	return id.get_slice(".", 1) if id.contains(".") else ""


func name_of(id: String) -> String:
	if quality_of(id) != "":
		return "%s (%s)" % [name_of(base_of(id)), quality_of(id)]
	if species.has(id):
		return species[id].display_name
	return str(ITEMS.get(id, {}).get("name", id))


## How many of a plant have been harvested, counting every quality.
func harvest_total(id: String) -> int:
	return int(produce.get(id, 0)) + item_count(id + ".silver") + item_count(id + ".gold")


## How many of an ingredient there are counting every quality of harvest.
## Recipes, requests and machines accept any quality.
func total_of(id: String) -> int:
	return harvest_total(id) if species.has(id) else item_count(id)


## Uses up `count` of an ingredient: plain harvest first, then silver, then gold.
func _take_any(id: String, count: int) -> void:
	if not species.has(id):
		items[id] = item_count(id) - count
		return
	var plain: int = mini(count, int(produce.get(id, 0)))
	produce[id] = int(produce.get(id, 0)) - plain
	count -= plain
	for quality: String in ["silver", "gold"]:
		var key: String = "%s.%s" % [id, quality]
		var used: int = mini(count, item_count(key))
		if used > 0:
			items[key] = item_count(key) - used
			count -= used


## Whether an oven stands somewhere (baking recipes need one).
func has_oven() -> bool:
	for cell: Vector2i in objects.keys():
		if object_kind(cell) == "oven":
			return true
	return false


## Everything in the backpack that can be sold, shipped or given.
func sellable_ids() -> Array:
	var ids: Array = []
	for id: String in species.keys():
		if int(produce.get(id, 0)) > 0:
			ids.append(id)
	for id: String in items.keys():
		if item_count(id) > 0 and sell_price_of(id) > 0:
			ids.append(id)
	return ids


func object_kind(cell: Vector2i) -> String:
	return str(objects[cell]["kind"]) if objects.has(cell) else ""


## Placed things that can't be walked through (debris and paths can).
func is_solid(cell: Vector2i) -> bool:
	return objects.has(cell) and (ORES.has(object_kind(cell)) or bool(ITEMS.get(object_kind(cell), {}).get("solid", false)))


func has_kitchen() -> bool:
	return home_level() >= 1


## 1 to 10, from gardening experience.
func garden_level() -> int:
	var level: int = 1
	for i in LEVEL_XP.size():
		if xp >= LEVEL_XP[i]:
			level = i + 1
	return level


## Experience needed for the next level, or -1 at the top.
func next_level_xp() -> int:
	var level: int = garden_level()
	return LEVEL_XP[level] if level < LEVEL_XP.size() else -1


## "" if the recipe can be made now, otherwise why not.
func craft_problem(recipe_id: String) -> String:
	if not RECIPES.has(recipe_id):
		return "No such recipe"
	var recipe: Dictionary = RECIPES[recipe_id]
	if garden_level() < int(recipe["level"]):
		return "Needs gardening level %d" % int(recipe["level"])
	if bool(recipe.get("kitchen", false)) and not has_kitchen():
		return "Needs a stove (the Cabin has one)"
	if bool(recipe.get("oven", false)) and not has_oven():
		return "Needs an oven (Bristle sells one)"
	for id: String in recipe["needs"].keys():
		if total_of(id) < int(recipe["needs"][id]):
			return "Not enough %s" % name_of(id)
	return ""


## What Bristle (or the shipping bin) pays for one of `id` today; 0 if it
## can't be sold.
func sell_price_of(id: String) -> int:
	var price: int = int(species[id].sell_price) if species.has(id) else int(ITEMS.get(id, {}).get("price", 0))
	if QUALITIES.has(quality_of(id)) and species.has(base_of(id)):
		price = int(int(species[base_of(id)].sell_price) * float(QUALITIES[quality_of(id)]))
	if festival_today() == 2:  # Harvest Fair
		price = int(price * 1.5)
	return price


## The season (0-3) whose festival is today, or -1.
func festival_today() -> int:
	return TimeManager.season() if TimeManager.day_of_season() == FESTIVAL_DAY else -1


## Whether a goal's condition holds right now.
func goal_met(id: String) -> bool:
	match id:
		"blooms": return _journal_count(JOURNAL_BLOOMED) >= 3
		"radiant": return _journal_count(JOURNAL_RADIANT) >= 3
		"collector": return _journal_count(JOURNAL_PLANTED) >= 8
		"sprinkler":
			for cell: Vector2i in objects.keys():
				if object_kind(cell) == "sprinkler":
					return true
			return false
		"angler": return stats["fish"].size() >= 4
		"chef": return stats["cooked"].size() >= 3
		"helper": return int(stats["requests"]) >= 5
		"cabin": return home_level() >= 1
		"sapling": return tree_stage() >= 2
		"level5": return garden_level() >= 5
		"master":
			for goal: Dictionary in GOALS:
				if goal["id"] != "master" and not goals_done.has(goal["id"]):
					return false
			return true
	return false


func _journal_count(at_least: int) -> int:
	var count: int = 0
	for id: String in journal.keys():
		if journal_level(id) >= at_least:
			count += 1
	return count


# ----- the shop

func upgrade_level(kind: String) -> int:
	return int(upgrades.get(kind, 0))


## The next thing to buy of this kind ({"name", "cost", "blurb"}), or {} when
## it is fully upgraded.
func next_upgrade(kind: String) -> Dictionary:
	var steps: Array = UPGRADES.get(kind, [])
	var level: int = upgrade_level(kind)
	return steps[level] if level < steps.size() else {}


func tool_reach(kind: String) -> int:
	return TOOL_REACH[clampi(upgrade_level(kind), 0, TOOL_REACH.size() - 1)]


## The shop stocks seeds for plants the garden already knows: the three it
## starts with, and those the Heart Tree has gifted so far.
func seed_in_stock(species_id: String) -> bool:
	if not species.has(species_id):
		return false
	if STARTER_SEEDS.has(species_id) or journal_level(species_id) > 0:
		return true
	if SEED_LEVELS.has(species_id):
		return garden_level() >= int(SEED_LEVELS[species_id])
	for stage: int in TREE_GIFTS.keys():
		if stage <= tree_stage() and TREE_GIFTS[stage].has(species_id):
			return true
	return false


func hat_of(player_id: int) -> String:
	return str(outfits.get(str(player_id), "straw"))


func tree_stage() -> int:
	var stage: int = 0
	for i in TREE_STAGE_LOVE.size():
		if int(tree["love"]) >= TREE_STAGE_LOVE[i]:
			stage = i
	return stage


## Love needed for the next stage, or -1 when fully grown.
func tree_next_goal() -> int:
	var stage: int = tree_stage()
	return TREE_STAGE_LOVE[stage + 1] if stage + 1 < TREE_STAGE_LOVE.size() else -1


func journal_level(species_id: String) -> int:
	return int(journal.get(species_id, 0))


func get_energy(player_id: int) -> int:
	return int(energy.get(player_id, max_energy()))


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
	if object_kind(cell) == "dropped":
		var key: String = objects[cell]["key"]
		return "%d %s%s: walk over it to pick it up" % [int(objects[cell]["count"]), name_of(key.get_slice(":", 1)), " seeds" if key.begins_with("seed:") else ""]
	if is_indoors(cell):
		if is_bed(cell):
			return "Bed: tuck in to end the day"
		if ORES.has(object_kind(cell)):
			return "%s (pickaxe, 6)" % {"ore_stone": "Rock", "ore_copper": "Copper vein", "ore_gold": "Gold vein", "ore_gem": "Amethyst cluster"}[object_kind(cell)]
		if objects.has(cell):
			return name_of(object_kind(cell))
		if is_exit_mat(cell):
			return "Ladder: walk down to climb out" if is_in_mine(cell) else "Door mat: walk down to go outside"
		return ""
	if is_tent(cell):
		return "%s: your home" % HOME_NAMES[home_level()]
	if is_stall(cell):
		return "Bristle's stall: sell plants, buy seeds and more"
	if is_tower(cell):
		return "Clock tower: set any date and time"
	if scenery_at(cell) != "":
		return "%s%s" % [SCENERY_NAMES[scenery_at(cell)], " (axe, 7)" if can_chop(cell) else ""]
	if is_mine_entrance(cell):
		return "Mine: rocks and ore inside"
	if cell == MAILBOX_CELL:
		return "Mailbox%s" % (": %d letters waiting" % mail.size() if not mail.is_empty() else "")
	if cell == BOARD_CELL:
		return "Notice board: %d requests" % quests.size()
	if upgrade_level("coop") > 0 and COOP_RECT.has_point(cell):
		return "Chicken coop"
	if upgrade_level("barn") > 0 and BARN_RECT.has_point(cell):
		return "Barn"
	if animal_at(cell) >= 0:
		var animal: Dictionary = animals[animal_at(cell)]
		return "%s, mood %d%s" % [ANIMALS[animal["kind"]]["name"], int(animal["mood"]), "" if bool(animal["fed"]) else ", hungry"]
	if cell == VISITOR_CELL and visitor_today() != "":
		var who: Dictionary = VILLAGERS[visitor_today()]
		return "%s, %s" % [who["name"], who["what"]]
	if is_pond(cell):
		return "Pond: cast here with the fishing rod (5)"
	if is_bin(cell):
		return "Shipping bin: what's inside is sold overnight"
	if objects.has(cell):
		var kind: String = object_kind(cell)
		if DEBRIS.has(kind):
			return "%s: clear it for %s" % [DEBRIS_NAMES[kind], name_of(DEBRIS[kind]).to_lower()]
		if MACHINES.has(kind):
			if bool(objects[cell].get("ready", false)):
				return "%s: %s ready" % [name_of(kind), name_of(MACHINES[kind]["makes"]).to_lower()]
			if int(objects[cell].get("busy", 0)) > 0:
				return "%s: %d days to go" % [name_of(kind), int(objects[cell]["busy"])]
			return "%s: empty" % name_of(kind)
		if TREES.has(kind):
			var age: int = int(objects[cell].get("age", 0))
			var fruit_name: String = name_of(TREES[kind])
			if age < TREE_GROW_DAYS:
				return "%s sapling, %d days to go" % [fruit_name, TREE_GROW_DAYS - age]
			return "%s tree%s" % [fruit_name, ", fruit ready" if bool(objects[cell].get("fruit", false)) else ""]
		return name_of(kind)
	if is_tree(cell):
		var goal: int = tree_next_goal()
		var progress: String = "love %d/%d" % [int(tree["love"]), goal] if goal > 0 else "fully grown"
		return "%s, %s%s" % [TREE_STAGE_NAMES[tree_stage()], progress, "" if bool(tree["watered"]) else ", thirsty"]
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
		return "Tilled soil (%s%s)" % ["watered" if bool(soil[cell]["watered"]) else "dry", ", mulched" if bool(soil[cell].get("mulch", false)) else ""]
	return ""


# --------------------------------------------------------------- requests
# Call these from gameplay code. On a guest they only send the request to the
# host and return true; the result arrives through the usual signals.

## `facing` is the way the player is looking; with a better hoe or watering
## can the tool reaches further tiles in that direction.
func request_till(player_id: int, cell: Vector2i, facing: Vector2i = Vector2i.ZERO) -> bool:
	return _request("till", player_id, [cell, facing])


func request_water(player_id: int, cell: Vector2i, facing: Vector2i = Vector2i.ZERO) -> bool:
	return _request("water", player_id, [cell, facing])


func request_sell(player_id: int, species_id: String, count: int) -> bool:
	return _request("sell", player_id, [species_id, count])


func request_buy_seeds(player_id: int, species_id: String, count: int) -> bool:
	return _request("buy_seeds", player_id, [species_id, count])


func request_buy_upgrade(player_id: int, kind: String) -> bool:
	return _request("buy_upgrade", player_id, [kind])


func request_buy_hat(player_id: int, hat_id: String) -> bool:
	return _request("buy_hat", player_id, [hat_id])


func request_wear(player_id: int, hat_id: String) -> bool:
	return _request("wear", player_id, [hat_id])


## Put an item from the backpack on a garden tile (or mulch on soil).
func request_place(player_id: int, cell: Vector2i, item_id: String) -> bool:
	return _request("place", player_id, [cell, item_id])


func request_craft(player_id: int, recipe_id: String) -> bool:
	return _request("craft", player_id, [recipe_id])


func request_eat(player_id: int, item_id: String) -> bool:
	return _request("eat", player_id, [item_id])


## Hand over what Bristle asked for (see `wanted`).
func request_deliver(player_id: int) -> bool:
	return _request("deliver", player_id, [])


## Break a rock in the mine with the pickaxe.
func request_mine(player_id: int, cell: Vector2i) -> bool:
	return _request("mine", player_id, [cell])


func request_buy_animal(player_id: int, kind: String) -> bool:
	return _request("buy_animal", player_id, [kind])


## Feed the animal on `cell` if it is hungry, otherwise pet it.
func request_tend(player_id: int, cell: Vector2i) -> bool:
	return _request("tend", player_id, [cell])


## Open the letter at `index` in the mailbox and take what it holds.
func request_open_mail(player_id: int, index: int) -> bool:
	return _request("open_mail", player_id, [index])


## Hand in the notice-board request at `index`.
func request_quest(player_id: int, index: int) -> bool:
	return _request("quest", player_id, [index])


func request_talk(player_id: int, villager: String) -> bool:
	return _request("talk", player_id, [villager])


func request_gift(player_id: int, villager: String, id: String) -> bool:
	return _request("gift", player_id, [villager, id])


## One cast of the fishing rod. `landed` is whether the player won the
## reeling game; the host decides which fish it was.
func request_fish(player_id: int, landed: bool) -> bool:
	return _request("fish", player_id, [landed])


## Buy `count` of a decor item from Bristle.
func request_buy_item(player_id: int, item_id: String, count: int) -> bool:
	return _request("buy_item", player_id, [item_id, count])


## Move `count` of a sellable thing into the shipping bin (negative: take back).
func request_ship(player_id: int, id: String, count: int) -> bool:
	return _request("ship", player_id, [id, count])


## The clock tower: jump to any day (counted from the garden's first day) and
## time of day, with or without rain.
func request_set_time(player_id: int, day_index: int, minutes: int, raining: bool) -> bool:
	return _request("set_time", player_id, [day_index, minutes, raining])


func request_plant(player_id: int, cell: Vector2i, species_id: String) -> bool:
	return _request("plant", player_id, [cell, species_id])


func request_pet(player_id: int, cell: Vector2i) -> bool:
	return _request("pet", player_id, [cell])


func request_harvest(player_id: int, cell: Vector2i) -> bool:
	return _request("harvest", player_id, [cell])


## Moves the whole stack in backpack slot `from` to slot `to` (swapping with
## what is there). Slots 0-3 are the hot bar and only take holdable things.
func request_move_slot(player_id: int, from: int, to: int) -> bool:
	return _request("move_slot", player_id, [from, to])


## Drops a whole stack ("seed:<id>", "harvest:<id>", "item:<id>") on `cell`.
## Anyone can pick it up again by walking over it or with F.
func request_drop(player_id: int, key: String, cell: Vector2i) -> bool:
	return _request("drop", player_id, [key, cell])


## One swing of the axe at a tree, stump or log.
func request_chop(player_id: int, cell: Vector2i) -> bool:
	return _request("chop", player_id, [cell])


func request_sleep(player_id: int) -> bool:
	return _request("sleep", player_id, [])


func _request(action: String, player_id: int, args: Array) -> bool:
	if Net.is_host():
		return _apply(action, player_id, args)
	_rpc_request.rpc_id(1, action, args)
	return true


func _apply(action: String, player_id: int, args: Array) -> bool:
	return bool(_as(player_id, _apply_now.bind(action, player_id, args)))


func _apply_now(action: String, player_id: int, args: Array) -> bool:
	match action:
		"till": return _do_reach(player_id, "hoe", args[0], args[1])
		"water": return _do_reach(player_id, "can", args[0], args[1])
		"sell": return _do_sell(player_id, args[0], args[1])
		"buy_seeds": return _do_buy_seeds(player_id, args[0], args[1])
		"buy_upgrade": return _do_buy_upgrade(player_id, args[0])
		"buy_hat": return _do_buy_hat(player_id, args[0])
		"wear": return _do_wear(player_id, args[0])
		"set_time": return _do_set_time(args[0], args[1], args[2])
		"place": return _do_place(player_id, args[0], args[1])
		"craft": return _do_craft(player_id, args[0])
		"eat": return _do_eat(player_id, args[0])
		"deliver": return _do_deliver(player_id)
		"fish": return _do_fish(player_id, args[0])
		"buy_item": return _do_buy_item(player_id, args[0], args[1])
		"ship": return _do_ship(args[0], args[1])
		"mine": return _do_mine(player_id, args[0])
		"buy_animal": return _do_buy_animal(player_id, args[0])
		"tend": return _do_tend(player_id, args[0])
		"open_mail": return _do_open_mail(player_id, args[0])
		"quest": return _do_quest(player_id, args[0])
		"talk": return _do_talk(player_id, args[0])
		"gift": return _do_gift(player_id, args[0], args[1])
		"plant": return _do_plant(player_id, args[0], args[1])
		"pet": return _do_pet(player_id, args[0])
		"harvest": return _do_harvest(player_id, args[0])
		"sleep": return _do_sleep(player_id)
		"move_slot": return _do_move_slot(args[0], args[1])
		"drop": return _do_drop(player_id, args[0], args[1])
		"chop": return _do_chop(player_id, args[0])
	return false


# ------------------------------------------------- rules (host side only)

## Tilling or watering `cell` and, with a better tool, the tiles beyond it in
## the direction faced. One use costs the same energy however far it reaches.
func _do_reach(player_id: int, tool: String, cell: Vector2i, facing: Vector2i) -> bool:
	var cost: int = COST_TILL if tool == "hoe" else COST_WATER
	if get_energy(player_id) < cost:
		_notify(player_id, "Too tired... time to rest")
		return false
	var reach: int = tool_reach(tool) if facing != Vector2i.ZERO else 1
	var did: bool = false
	for i in reach:
		var target: Vector2i = cell + facing * i
		if tool == "hoe":
			did = _do_till(target) or did
		else:
			did = _do_water(player_id, target) or did
	if did:
		_spend(player_id, cost)
	return did


func _do_till(cell: Vector2i) -> bool:
	if not in_bounds(cell) or is_blocked(cell) or soil.has(cell) or objects.has(cell):
		return false
	soil[cell] = {"watered": TimeManager.raining}
	cell_changed.emit(cell)
	return true


func _do_water(player_id: int, cell: Vector2i) -> bool:
	if is_tree(cell):
		if bool(tree["watered"]):
			return false
		tree["watered"] = true
		tree_changed.emit()
		return true
	if not soil.has(cell) or bool(soil[cell]["watered"]):
		return false
	soil[cell]["watered"] = true
	if plants.has(cell):
		_credit(plants[cell], player_id)
	cell_changed.emit(cell)
	return true


func _do_plant(player_id: int, cell: Vector2i, species_id: String) -> bool:
	if not soil.has(cell) or plants.has(cell) or not species.has(species_id):
		return false
	var d: Resource = species[species_id]
	if seed_count(species_id) <= 0:
		_notify(player_id, "No %s seeds left" % d.display_name)
		return false
	if not in_season(cell, species_id):
		_notify(player_id, "%s won't wake up in %s" % [d.display_name, TimeManager.season_name()])
		return false
	if not _spend(player_id, COST_PLANT):
		return false
	seeds[species_id] = seed_count(species_id) - 1
	plants[cell] = _new_plant(species_id)
	_credit(plants[cell], player_id)
	_note(species_id, JOURNAL_PLANTED)
	_changed("inventory")
	plant_added.emit(cell)
	return true


## Affection: each player can pet each plant once per day.
func _do_pet(player_id: int, cell: Vector2i) -> bool:
	if is_tree(cell):
		if tree["hugged_by"].has(str(player_id)):
			_notify(player_id, "The tree is still glowing from your hug")
			return false
		tree["hugged_by"][str(player_id)] = true
		tree_changed.emit()
		return true
	if not plants.has(cell):
		return false
	var p: Dictionary = plants[cell]
	var key: String = str(player_id)
	if p["petted_by"].has(key):
		_notify(player_id, "It already feels loved today")
		return false
	p["petted_by"][key] = true
	_credit(p, player_id)
	plant_petted.emit(cell)
	return true


## The basket: picks a ripe plant, clears debris, or lifts a placed thing.
func _do_harvest(player_id: int, cell: Vector2i) -> bool:
	if objects.has(cell):
		return _do_gather(player_id, cell)
	if not plants.has(cell):
		return false
	if not plant_is_ripe(cell):
		_notify(player_id, "Not ready to pick yet")
		return false
	if not _spend(player_id, COST_HARVEST):
		return false
	var p: Dictionary = plants[cell]
	var id: String = p["species"]
	var d: Resource = species[id]
	var radiant: bool = plant_is_radiant(cell)
	# Quality: radiant plants give gold; happy ones (and a seasoned gardener's) silver.
	var quality: String = ""
	if radiant:
		quality = "gold"
	elif int(p["happiness"]) >= 65 or rng.randf() < 0.05 * (garden_level() - 1):
		quality = "silver"
	if quality == "":
		produce[id] = int(produce.get(id, 0)) + 1
	else:
		items["%s.%s" % [id, quality]] = item_count("%s.%s" % [id, quality]) + 1
	_gain_xp(XP_HARVEST + (XP_RADIANT if radiant else 0))
	if d.regrows:
		if radiant:
			seeds[id] = seed_count(id) + 1
		p["regrow_wait"] = d.regrow_days
		cell_changed.emit(cell)
	else:
		seeds[id] = seed_count(id) + (3 if radiant else 2)
		plants.erase(cell)
		plant_removed.emit(cell)
	_changed("inventory")
	_notify(player_id, "Picked %s%s" % [d.display_name, " (%s quality!)" % quality if quality != "" else ""])
	return true


func _do_sell(_player_id: int, id: String, count: int) -> bool:
	var price: int = sell_price_of(id)
	if price <= 0 or count < 1 or stock_of(id) < count:
		return false
	_take(id, count)
	coins += price * count
	_changed("inventory")
	_changed("economy")
	return true


func _do_mine(player_id: int, cell: Vector2i) -> bool:
	if not ORES.has(object_kind(cell)):
		return false
	if upgrade_level("pickaxe") < 1:
		_notify(player_id, "That needs a pickaxe. Bristle sells one")
		return false
	if not _spend(player_id, COST_MINE):
		return false
	var ore: Array = ORES[object_kind(cell)]
	var amount: int = rng.randi_range(1, int(ore[1]))
	items[ore[0]] = item_count(ore[0]) + amount
	objects.erase(cell)
	object_changed.emit(cell)
	_changed("inventory")
	_notify(player_id, "+%d %s" % [amount, name_of(ore[0])])
	_gain_xp(1)
	return true


func _do_buy_animal(player_id: int, kind: String) -> bool:
	if not ANIMALS.has(kind):
		return false
	var info: Dictionary = ANIMALS[kind]
	if upgrade_level(info["home"]) < 1:
		_notify(player_id, "A %s needs a %s first" % [str(info["name"]).to_lower(), UPGRADES[info["home"]][0]["name"]])
		return false
	if animal_count(kind) >= int(info["max"]):
		_notify(player_id, "There's no room for another")
		return false
	if not _pay(player_id, int(info["cost"])):
		return false
	animals.append({"kind": kind, "mood": 50, "fed": false, "petted_by": {}})
	_clear_ground(animal_cell(animals.size() - 1))
	animals_changed.emit()
	return true


func _do_tend(player_id: int, cell: Vector2i) -> bool:
	var index: int = animal_at(cell)
	if index < 0:
		return false
	var animal: Dictionary = animals[index]
	if not bool(animal["fed"]):
		if item_count("feed") < 1:
			_notify(player_id, "No feed. Make some from fiber, or buy it from Bristle")
			return false
		items["feed"] = item_count("feed") - 1
		animal["fed"] = true
		_changed("inventory")
	elif not animal["petted_by"].has(str(player_id)):
		animal["petted_by"][str(player_id)] = true
	else:
		return false
	animals_changed.emit()
	return true


func _do_open_mail(player_id: int, index: int) -> bool:
	if index < 0 or index >= mail.size():
		return false
	var gift: Dictionary = mail[index].get("gift", {})
	mail.remove_at(index)
	var parts: Array = _give(gift)
	if not parts.is_empty():
		_notify(player_id, "Inside: %s" % ", ".join(parts))
	_changed("inventory")
	_changed("economy")
	mail_changed.emit()
	return true


func _do_quest(player_id: int, index: int) -> bool:
	if index < 0 or index >= quests.size():
		return false
	var quest: Dictionary = quests[index]
	if total_of(quest["id"]) < int(quest["count"]):
		_notify(player_id, "That needs %d %s" % [int(quest["count"]), name_of(quest["id"])])
		return false
	_take_any(quest["id"], int(quest["count"]))
	coins += int(quest["coins"])
	quests.remove_at(index)
	stats["requests"] = int(stats["requests"]) + 1
	_changed("inventory")
	_gain_xp(15)
	if VILLAGERS.has(str(quest["who"])):
		_befriend(player_id, quest["who"], 30)
	_changed("economy")
	mail_changed.emit()
	return true


## Hands over coins, items and seeds; returns words for each ("3 Tea").
func _give(gift: Dictionary) -> Array:
	var parts: Array = []
	if int(gift.get("coins", 0)) > 0:
		coins += int(gift["coins"])
		parts.append("%d coins" % int(gift["coins"]))
	for id: String in gift.get("seeds", {}).keys():
		seeds[id] = seed_count(id) + int(gift["seeds"][id])
		parts.append("%d %s seeds" % [int(gift["seeds"][id]), name_of(id)])
	for id: String in gift.get("items", {}).keys():
		items[id] = item_count(id) + int(gift["items"][id])
		parts.append("%d %s" % [int(gift["items"][id]), name_of(id)])
	return parts


## The morning post: a welcome, festival notices, notes from friends.
func _deliver_mail() -> void:
	var day: int = TimeManager.day_index
	if day == 1:
		mail.append({"from": "Bristle", "text": "Welcome to the neighbourhood! A little something to get you started. Come by the stall any time.", "gift": {"coins": 50}})
	if TimeManager.day_of_season() == FESTIVAL_DAY - 2:
		var fest: Dictionary = FESTIVALS[TimeManager.season()]
		mail.append({"from": "The Garden Club", "text": "The %s is in two days, on the 14th. %s" % [fest["name"], fest["today"]], "gift": {}})
	for id: String in friends.keys():
		var friend: Dictionary = friends[id]
		if hearts(id) >= 2 and not bool(friend.get("wrote", false)):
			friend["wrote"] = true
			var who: Dictionary = VILLAGERS[id]
			var liked: String = who["likes"][0]
			var present: Dictionary = {"coins": 100}
			if ITEMS.has(liked):
				present["items"] = {liked: 2}
			mail.append({"from": who["name"], "text": "It's a joy visiting your garden. Between us, I'm very fond of %s. Here's something for you both." % name_of(who["loves"][0]).to_lower(), "gift": present})
	mail_changed.emit()


## Keeps the notice board stocked with requests from Bristle and the villagers.
func _refresh_quests() -> void:
	for i in range(quests.size() - 1, -1, -1):
		quests[i]["days"] = int(quests[i]["days"]) - 1
		if int(quests[i]["days"]) <= 0:
			quests.remove_at(i)
	var wants: Array = ["wood", "stone", "fiber", "minnow", FORAGE[TimeManager.season()]]
	for id: String in species.keys():
		if seed_in_stock(id) and species[id].seasons.has(TimeManager.season()):
			wants.append(id)
	if upgrade_level("coop") > 0:
		wants.append("egg")
	var askers: Array = ["bristle"] + VILLAGERS.keys()
	var tries: int = 0
	while quests.size() < MAX_QUESTS and tries < 12:
		tries += 1
		var id: String = wants[rng.randi_range(0, wants.size() - 1)]
		var taken: bool = false
		for quest: Dictionary in quests:
			if quest["id"] == id:
				taken = true
		if taken:
			continue
		var count: int = rng.randi_range(2, 5)
		var each: int = maxi(sell_price_of(id), 12)
		quests.append({"who": askers[rng.randi_range(0, askers.size() - 1)], "id": id, "count": count, "coins": int(each * count * 1.8), "days": QUEST_DAYS})
	mail_changed.emit()


## Artisan machines count down, and beehives fill.
func _run_machines() -> Array:
	var ready: int = 0
	for cell: Vector2i in objects.keys():
		var kind: String = object_kind(cell)
		if not MACHINES.has(kind) or is_indoors(cell):
			continue
		var machine: Dictionary = objects[cell]
		if kind == "beehive" and int(machine.get("busy", 0)) <= 0 and not bool(machine.get("ready", false)) and TimeManager.season() != 3:
			machine["busy"] = int(MACHINES[kind]["nights"])
		if int(machine.get("busy", 0)) > 0:
			machine["busy"] = int(machine["busy"]) - 1
			if int(machine["busy"]) == 0:
				machine["ready"] = true
				ready += 1
			object_changed.emit(cell)
	return ["%d of your machines have something ready" % ready] if ready > 0 else []


## What a machine would be filled with from the backpack right now ("" if
## nothing suitable): its set input, or for the jar the harvest you have most of.
func machine_input(kind: String) -> String:
	var machine: Dictionary = MACHINES.get(kind, {})
	var need: int = int(machine.get("count", 0))
	if str(machine.get("takes", "")) == "harvest":
		var best: String = ""
		for id: String in species.keys():
			if harvest_total(id) >= need and (best == "" or harvest_total(id) > harvest_total(best)):
				best = id
		return best
	var takes: String = machine.get("takes", "")
	return takes if takes != "" and total_of(takes) >= need else ""


func _do_talk(player_id: int, villager: String) -> bool:
	if villager != visitor_today():
		return false
	var friend: Dictionary = _friend(villager)
	if bool(friend["talked"]):
		return false
	friend["talked"] = true
	_befriend(player_id, villager, 10)
	return true


## A gift a day: loved +80, liked +40, disliked -20, anything else +15.
func _do_gift(player_id: int, villager: String, id: String) -> bool:
	if villager != visitor_today() or stock_of(id) < 1:
		return false
	var friend: Dictionary = _friend(villager)
	if bool(friend["gifted"]):
		_notify(player_id, "One gift a day is plenty")
		return false
	var who: Dictionary = VILLAGERS[villager]
	var what: String = base_of(id)
	var points: int = 15
	var reaction: String = "Oh, thank you."
	if who["loves"].has(what):
		points = 80
		reaction = "%s loves it!" % who["name"]
	elif who["likes"].has(what):
		points = 40
		reaction = "%s likes that." % who["name"]
	elif who["dislikes"].has(what):
		points = -20
		reaction = "%s isn't keen on that..." % who["name"]
	if quality_of(id) == "gold" and points > 0:
		points += 20
	_take(id, 1)
	friend["gifted"] = true
	_changed("inventory")
	_notify(player_id, reaction)
	_befriend(player_id, villager, points)
	return true


func _friend(villager: String) -> Dictionary:
	if not friends.has(villager):
		friends[villager] = {"points": 0, "talked": false, "gifted": false, "rewards": 0}
	return friends[villager]


## Changes friendship and hands over the reward for each new heart.
func _befriend(player_id: int, villager: String, points: int) -> void:
	var friend: Dictionary = _friend(villager)
	friend["points"] = clampi(int(friend["points"]) + points, 0, MAX_HEARTS * 100)
	while int(friend["rewards"]) < hearts(villager):
		var reward: Dictionary = VILLAGERS[villager]["rewards"][int(friend["rewards"])]
		friend["rewards"] = int(friend["rewards"]) + 1
		var parts: Array = []
		if reward.has("coins"):
			coins += int(reward["coins"])
			parts.append("%d coins" % int(reward["coins"]))
		for id: String in reward.get("seeds", {}).keys():
			seeds[id] = seed_count(id) + int(reward["seeds"][id])
			parts.append("%d %s seeds" % [int(reward["seeds"][id]), name_of(id)])
		for id: String in reward.get("items", {}).keys():
			items[id] = item_count(id) + int(reward["items"][id])
			parts.append("%d %s" % [int(reward["items"][id]), name_of(id)])
		_notify(player_id, "A new heart with %s! A gift: %s" % [VILLAGERS[villager]["name"], ", ".join(parts)])
		_changed("inventory")
	_changed("economy")


## Removes soil, plants and things from a tile something is about to stand on.
func _clear_ground(cell: Vector2i) -> void:
	if plants.has(cell):
		plants.erase(cell)
		plant_removed.emit(cell)
	if soil.has(cell):
		soil.erase(cell)
		cell_changed.emit(cell)
	if objects.has(cell):
		objects.erase(cell)
		object_changed.emit(cell)


## Removes `count` of a harvested plant or an item from the backpack.
func _take(id: String, count: int) -> void:
	if species.has(id):
		produce[id] = int(produce.get(id, 0)) - count
	else:
		items[id] = item_count(id) - count


func _do_ship(id: String, count: int) -> bool:
	if sell_price_of(id) <= 0 or count == 0:
		return false
	if count > 0:
		if stock_of(id) < count:
			return false
		_take(id, count)
		bin[id] = int(bin.get(id, 0)) + count
	else:
		if int(bin.get(id, 0)) < -count:
			return false
		_take(id, count)  # a negative count puts them back
		bin[id] = int(bin[id]) + count
		if int(bin[id]) <= 0:
			bin.erase(id)
	_changed("inventory")
	return true


func _do_buy_item(player_id: int, item_id: String, count: int) -> bool:
	var cost: int = int(ITEMS.get(item_id, {}).get("cost", 0))
	if cost <= 0 or count < 1 or not _pay(player_id, cost * count):
		return false
	items[item_id] = item_count(item_id) + count
	_changed("inventory")
	return true


func _do_fish(player_id: int, landed: bool) -> bool:
	if not _spend(player_id, COST_FISH):
		return false
	if not landed:
		return true
	var id: String = _roll_fish()
	items[id] = item_count(id) + 1
	stats["fish"][id] = int(stats["fish"].get(id, 0)) + 1
	_changed("inventory")
	_notify(player_id, "Caught a %s!" % name_of(id))
	_gain_xp(XP_FISH)
	return true


## Which fish takes the bait, given the season, hour and weather.
func _roll_fish() -> String:
	if rng.randf() < 0.05:
		return "goldie"
	var pool: Array = ["minnow", "minnow", "minnow"]
	var evening: bool = TimeManager.minutes >= 18 * 60
	if TimeManager.season() <= 1 and not evening:
		pool.append_array(["sunfish", "sunfish", "sunfish"])
	if evening:
		pool.append_array(["moonfin", "moonfin", "moonfin"])
	if TimeManager.raining:
		pool.append_array(["raincarp", "raincarp", "raincarp", "raincarp"])
	if TimeManager.season() == 3:
		pool.append_array(["frostfin", "frostfin", "frostfin"])
	return pool[rng.randi_range(0, pool.size() - 1)]


func _do_buy_seeds(player_id: int, species_id: String, count: int) -> bool:
	if not seed_in_stock(species_id) or count < 1:
		return false
	if not _pay(player_id, int(species[species_id].seed_price) * count):
		return false
	seeds[species_id] = seed_count(species_id) + count
	_changed("inventory")
	return true


func _do_buy_upgrade(player_id: int, kind: String) -> bool:
	var next: Dictionary = next_upgrade(kind)
	if next.is_empty() or not _pay(player_id, int(next["cost"])):
		return false
	upgrades[kind] = upgrade_level(kind) + 1
	if kind == "greenhouse":
		for cell: Vector2i in plants.keys():
			plants[cell]["dormant"] = not in_season(cell, plants[cell]["species"])
		state_reloaded.emit()
	if kind == "coop" or kind == "barn":
		var site: Rect2i = COOP_RECT if kind == "coop" else BARN_RECT
		for x in site.size.x:
			for y in site.size.y:
				_clear_ground(site.position + Vector2i(x, y))
		state_reloaded.emit()
	if kind == "home":
		# The new room has its own built-in furniture: anything of ours now
		# standing where that is goes back in the backpack.
		for cell: Vector2i in objects.keys():
			if is_indoors(cell) and not is_in_mine(cell) and not _room_free(cell):
				items[object_kind(cell)] = item_count(object_kind(cell)) + 1
				objects.erase(cell)
				object_changed.emit(cell)
		_changed("inventory")
	_changed("economy")
	return true


func _do_buy_hat(player_id: int, hat_id: String) -> bool:
	if not HATS.has(hat_id) or hats_owned.has(hat_id):
		return false
	if not _pay(player_id, int(HATS[hat_id]["cost"])):
		return false
	hats_owned.append(hat_id)
	outfits[str(player_id)] = hat_id  # put it straight on
	_changed("economy")
	return true


func _do_wear(player_id: int, hat_id: String) -> bool:
	if not hats_owned.has(hat_id) or hat_of(player_id) == hat_id:
		return false
	outfits[str(player_id)] = hat_id
	_changed("economy")
	return true


func _do_gather(player_id: int, cell: Vector2i) -> bool:
	var kind: String = object_kind(cell)
	if kind == "dropped":
		return _pick_up(player_id, cell)
	if ORES.has(kind):
		_notify(player_id, "Solid rock. That needs the pickaxe (6)")
		return false
	if MACHINES.has(kind):
		var machine: Dictionary = objects[cell]
		if bool(machine.get("ready", false)):
			var made: String = MACHINES[kind]["makes"]
			items[made] = item_count(made) + 1
			machine["ready"] = false
			object_changed.emit(cell)
			_changed("inventory")
			_notify(player_id, "Collected %s" % name_of(made))
			_gain_xp(3)
			return true
		if int(machine.get("busy", 0)) > 0:
			_notify(player_id, "Still working: %d days to go" % int(machine["busy"]))
			return false
		var input: String = machine_input(kind)
		if input != "":
			_take_any(input, int(MACHINES[kind]["count"]))
			machine["busy"] = int(MACHINES[kind]["nights"])
			object_changed.emit(cell)
			_changed("inventory")
			return true
		# Empty, and nothing to fill it with: fall through and pick it up.
	if TREES.has(kind):
		if bool(objects[cell].get("fruit", false)):
			var fruit: String = TREES[kind]
			objects[cell]["fruit"] = false
			objects[cell]["since"] = 0
			items[fruit] = item_count(fruit) + 1
			object_changed.emit(cell)
			_changed("inventory")
			_notify(player_id, "Picked: %s" % name_of(fruit))
			return true
		if int(objects[cell].get("age", 0)) > 0:
			_notify(player_id, "It has taken root")
			return false
	if DEBRIS.has(kind):
		if not _spend(player_id, COST_HARVEST):
			return false
		var material: String = DEBRIS[kind]
		var amount: int = rng.randi_range(1, 2)
		items[material] = item_count(material) + amount
		_notify(player_id, "+%d %s" % [amount, name_of(material)])
		_gain_xp(1)
	else:
		items[kind] = item_count(kind) + 1
	objects.erase(cell)
	object_changed.emit(cell)
	_changed("inventory")
	return true


## Each swing counts; on the last one the tree comes down and leaves a stack
## of wood on its tile for anyone to pick up.
func _do_chop(player_id: int, cell: Vector2i) -> bool:
	var kind: String = scenery_at(cell)
	if not CHOP.has(kind):
		return false
	if not _spend(player_id, COST_CHOP):
		return false
	var base: Vector2i = scenery_base(cell)
	var info: Array = CHOP[kind]
	_chops[base] = int(_chops.get(base, 0)) + 1
	if int(_chops[base]) < int(info[0]):
		scenery_hit.emit(base, false)
		return true
	_chops.erase(base)
	felled[base] = TimeManager.day_index
	scenery_hit.emit(base, true)
	var wood: int = rng.randi_range(int(info[1]), int(info[2]))
	objects[base] = {"kind": "dropped", "key": "item:wood", "count": wood}
	object_changed.emit(base)
	_gain_xp(2)
	_notify(player_id, "Timber! %d wood" % wood if kind != "stump" and kind != "log" else "%d wood" % wood)
	return true


## Cut-down trees grow back after a season, if their tiles are still clear.
func _regrow_trees() -> void:
	for at: Vector2i in felled.keys():
		if TimeManager.day_index - int(felled[at]) < REGROW_DAYS:
			continue
		var tiles: Array = scenery_tiles(at)
		if tiles.all(func(tile: Vector2i) -> bool: return not soil.has(tile) and not objects.has(tile)):
			felled.erase(at)


func _do_move_slot(from: int, to: int) -> bool:
	var slots: Array = bag_slots()
	if from < 0 or to < 0 or from >= slots.size() or to >= slots.size() or from == to or slots[from] == "":
		return false
	if (to < HOT_SLOTS and not holdable(slots[from])) or (from < HOT_SLOTS and slots[to] != "" and not holdable(slots[to])):
		return false
	var moved: String = slots[from]
	slots[from] = slots[to]
	slots[to] = moved
	_changed("inventory")
	return true


## Whether something dropped could lie on `cell`.
func can_drop_on(cell: Vector2i) -> bool:
	if objects.has(cell) or soil.has(cell):
		return false
	if is_indoors(cell):
		return (mine_floor() if is_in_mine(cell) else room_floor()).has_point(cell) and can_walk(cell)
	return in_bounds(cell) and not is_blocked(cell)


func _do_drop(player_id: int, key: String, cell: Vector2i) -> bool:
	var count: int = bag_count(key)
	if count < 1:
		return false
	if not can_drop_on(cell):
		_notify(player_id, "No room to drop that there")
		return false
	var id: String = key.get_slice(":", 1)
	match key.get_slice(":", 0):
		"seed": seeds.erase(id)
		"harvest": produce.erase(id)
		"item": items.erase(id)
	objects[cell] = {"kind": "dropped", "key": key, "count": count}
	object_changed.emit(cell)
	_changed("inventory")
	return true


## Picks up a dropped stack into this player's bag.
func _pick_up(player_id: int, cell: Vector2i) -> bool:
	var thing: Dictionary = objects[cell]
	var key: String = thing["key"]
	var id: String = key.get_slice(":", 1)
	var count: int = int(thing["count"])
	match key.get_slice(":", 0):
		"seed": seeds[id] = seed_count(id) + count
		"harvest": produce[id] = int(produce.get(id, 0)) + count
		_: items[id] = item_count(id) + count
	objects.erase(cell)
	object_changed.emit(cell)
	_changed("inventory")
	_notify(player_id, "Picked up %d %s%s" % [count, name_of(id), " seeds" if key.begins_with("seed:") else ""])
	return true


func _do_place(player_id: int, cell: Vector2i, item_id: String) -> bool:
	var info: Dictionary = ITEMS.get(item_id, {})
	if info.is_empty() or item_count(item_id) < 1:
		return false
	match str(info["kind"]):
		"soil":
			if not soil.has(cell) or bool(soil[cell].get("mulch", false)):
				_notify(player_id, "%s goes on tilled soil" % info["name"])
				return false
			soil[cell]["mulch"] = true
			cell_changed.emit(cell)
		"place", "decor":
			var fits: bool = in_bounds(cell) and not is_blocked(cell) and not soil.has(cell)
			if str(info["kind"]) == "decor" and is_indoors(cell):
				fits = _room_free(cell) and not is_exit_mat(cell)
			if not fits or objects.has(cell):
				_notify(player_id, "There's no room for it there")
				return false
			if is_in_mine(cell):
				_notify(player_id, "Not down here")
				return false
			objects[cell] = {"kind": item_id}
			object_changed.emit(cell)
		_:
			return false
	items[item_id] = item_count(item_id) - 1
	_changed("inventory")
	return true


func _do_craft(player_id: int, recipe_id: String) -> bool:
	var problem: String = craft_problem(recipe_id)
	if problem != "":
		_notify(player_id, problem)
		return false
	var recipe: Dictionary = RECIPES[recipe_id]
	for id: String in recipe["needs"].keys():
		_take_any(id, int(recipe["needs"][id]))
	items[recipe_id] = item_count(recipe_id) + int(recipe["makes"])
	if bool(recipe.get("kitchen", false)) or bool(recipe.get("oven", false)):
		stats["cooked"][recipe_id] = true
	_changed("inventory")
	_gain_xp(2)
	return true


func _do_eat(player_id: int, item_id: String) -> bool:
	var info: Dictionary = ITEMS.get(item_id, {})
	if str(info.get("kind", "")) != "meal" or item_count(item_id) < 1:
		return false
	if get_energy(player_id) >= max_energy():
		_notify(player_id, "You're full of energy already")
		return false
	items[item_id] = item_count(item_id) - 1
	energy[player_id] = mini(get_energy(player_id) + int(info["energy"]), max_energy())
	energy_changed.emit(player_id)
	_changed("inventory")
	_notify(player_id, "Delicious! +%d energy" % int(info["energy"]))
	return true


func _do_deliver(player_id: int) -> bool:
	if wanted.is_empty():
		return false
	var id: String = wanted["species"]
	var count: int = wanted["count"]
	if total_of(id) < count:
		_notify(player_id, "Bristle wants %d %s" % [count, name_of(id)])
		return false
	_take_any(id, count)
	coins += int(wanted["reward"])
	wanted = {}
	stats["requests"] = int(stats["requests"]) + 1
	_changed("inventory")
	_gain_xp(XP_REQUEST)
	_changed("economy")
	return true


## One wild thing to pick turns up most mornings; last season's wilts away.
func _grow_forage() -> void:
	var now: String = FORAGE[TimeManager.season()]
	var have: int = 0
	for cell: Vector2i in objects.keys():
		var kind: String = object_kind(cell)
		if FORAGE.has(kind) and not is_indoors(cell):
			if kind != now:
				objects.erase(cell)
				object_changed.emit(cell)
			else:
				have += 1
	if have >= 5 or rng.randf() > 0.7:
		return
	for attempt in 12:
		var cell := Vector2i(rng.randi_range(0, WORLD_SIZE.x - 1), rng.randi_range(0, WORLD_SIZE.y - 1))
		if is_blocked(cell) or YARD.has_point(cell) or ANIMAL_YARD.has_point(cell) or soil.has(cell) or objects.has(cell):
			continue
		objects[cell] = {"kind": now}
		object_changed.emit(cell)
		return


## Fed animals give an egg or milk; mood follows how they were treated.
func _tend_animals_overnight() -> Array:
	var given: Dictionary = {}
	for animal: Dictionary in animals:
		var mood: int = int(animal["mood"])
		if bool(animal["fed"]):
			mood += 5 + 6 * animal["petted_by"].size()
			var gives: String = ANIMALS[animal["kind"]]["gives"]
			items[gives] = item_count(gives) + (2 if mood >= 90 else 1)
			given[gives] = int(given.get(gives, 0)) + (2 if mood >= 90 else 1)
		else:
			mood -= 15
		animal["mood"] = clampi(mood, 0, 100)
		animal["fed"] = false
		animal["petted_by"] = {}
	if not animals.is_empty():
		animals_changed.emit()
	var lines: Array = []
	for id: String in given.keys():
		lines.append("The animals gave %d %s" % [int(given[id]), name_of(id).to_lower()])
	return lines


func _grow_fruit_trees() -> Array:
	var ripe: int = 0
	for cell: Vector2i in objects.keys():
		if not TREES.has(object_kind(cell)):
			continue
		var tree_here: Dictionary = objects[cell]
		tree_here["age"] = int(tree_here.get("age", 0)) + 1
		if int(tree_here["age"]) >= TREE_GROW_DAYS and TimeManager.season() != 3 and not bool(tree_here.get("fruit", false)):
			tree_here["since"] = int(tree_here.get("since", 0)) + 1
			if int(tree_here["since"]) >= TREE_FRUIT_EVERY:
				tree_here["fruit"] = true
				ripe += 1
		object_changed.emit(cell)
	return ["A fruit tree has fruit ready"] if ripe > 0 else []


## Now and then a crow pecks at a plant no scarecrow is watching.
func _crows() -> Array:
	if plants.size() < 6 or rng.randf() >= CROW_CHANCE:
		return []
	var guards: Array = []
	for cell: Vector2i in objects.keys():
		if object_kind(cell) == "scarecrow":
			guards.append(cell)
	var open: Array = []
	for cell: Vector2i in plants.keys():
		var watched: bool = false
		for guard: Vector2i in guards:
			if absi(guard.x - cell.x) <= SCARECROW_REACH and absi(guard.y - cell.y) <= SCARECROW_REACH:
				watched = true
		if not watched and not bool(plants[cell]["dormant"]) and not in_greenhouse(cell):
			open.append(cell)
	if open.is_empty():
		return []
	var victim: Vector2i = open[rng.randi_range(0, open.size() - 1)]
	plants[victim]["happiness"] = maxi(int(plants[victim]["happiness"]) - 25, 0)
	return ["A crow pecked at a %s. A scarecrow would keep crows away" % name_of(plants[victim]["species"])]


## Judges the festival of the day that is ending. Returns lines for the
## morning screen.
func _end_festival() -> Array:
	match festival_today():
		0:  # Bloom Show
			var radiant: int = 0
			for cell: Vector2i in plants.keys():
				if plant_is_radiant(cell) and not bool(plants[cell]["dormant"]):
					radiant += 1
			var prize: int = mini(radiant, 12) * 50
			_reward_everyone(prize)
			return ["Bloom Show: %d radiant plants won %d coins" % [radiant, prize]] if radiant > 0 else ["Bloom Show: no radiant plants this year"]
		3:  # Lantern Night
			var lanterns: int = 0
			for cell: Vector2i in objects.keys():
				if object_kind(cell) == "lantern":
					lanterns += 1
			if lanterns >= 3:
				_reward_everyone(100, {"frostwhisker": 3, "snowpip": 3})
				return ["Lantern Night: your lanterns earned 100 coins and winter seeds"]
			return ["Lantern Night: %d of 3 lanterns were lit" % lanterns]
	return []


## Pays out any goals newly met. Returns lines for the morning screen.
func _check_goals() -> Array:
	var lines: Array = []
	for goal: Dictionary in GOALS:
		var id: String = goal["id"]
		if goals_done.has(id) or not goal_met(id):
			continue
		goals_done.append(id)
		var prize: String = ""
		if goal.has("coins"):
			_reward_everyone(int(goal["coins"]))
			prize = "%d coins" % int(goal["coins"])
		if goal.has("hat") and not hats_owned.has(goal["hat"]):
			hats_owned.append(goal["hat"])
			prize = "the %s" % HATS[goal["hat"]]["name"]
		lines.append("Goal met: %s! You earned %s" % [goal["name"], prize])
	return lines


## Adds gardening experience and announces a new level to everyone.
func _gain_xp(amount: int) -> void:
	var before: int = garden_level()
	xp += amount
	_changed("economy")
	if garden_level() > before:
		var news: String = "Gardening level %d! Check the backpack for new recipes." % garden_level()
		notice.emit(news)
		if _mirroring():
			_net_notice.rpc(news)


## Scatters up to `count` pieces of debris on free ground away from the yard.
func scatter_debris(count: int) -> void:
	var have: int = 0
	for cell: Vector2i in objects.keys():
		if DEBRIS.has(object_kind(cell)):
			have += 1
	for i in count:
		if have >= MAX_DEBRIS:
			return
		for attempt in 12:
			var cell := Vector2i(rng.randi_range(0, WORLD_SIZE.x - 1), rng.randi_range(0, WORLD_SIZE.y - 1))
			if is_blocked(cell) or YARD.has_point(cell) or ANIMAL_YARD.has_point(cell) or soil.has(cell) or objects.has(cell):
				continue
			var roll: float = rng.randf()
			objects[cell] = {"kind": "weed" if roll < 0.5 else ("branch" if roll < 0.75 else "rock")}
			object_changed.emit(cell)
			have += 1
			break


## Bristle asks for a plant the garden can grow and pays double for it.
func _new_request() -> void:
	var choices: Array = []
	for id: String in species.keys():
		if seed_in_stock(id) and species[id].seasons.has(TimeManager.season()):
			choices.append(id)
	if choices.is_empty():
		return
	var id: String = choices[rng.randi_range(0, choices.size() - 1)]
	var count: int = rng.randi_range(2, 4)
	wanted = {"species": id, "count": count, "reward": int(species[id].sell_price) * count * 2}
	_changed("economy")


## Sets the calendar and clock without living through the days between:
## nothing grows and nothing is lost. Plants wake or go dormant for the new
## season, and rain (if asked for) waters the soil as on any rainy day.
func _do_set_time(day_index: int, minutes: int, raining: bool) -> bool:
	TimeManager.set_clock(mini(day_index, TimeManager.DAYS_PER_SEASON * 4 * LAST_YEAR - 1), minutes, raining)
	var season: int = TimeManager.season()
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		p["dormant"] = not in_season(cell, p["species"])
	if TimeManager.raining:
		for cell: Vector2i in soil.keys():
			soil[cell]["watered"] = true
		tree["watered"] = true
	state_reloaded.emit()  # every view redraws for the new season and light
	time_warped.emit()
	if _mirroring():
		_net_warp.rpc(to_snapshot())
	return true


## Takes `cost` coins from the player's purse, or tells the player they're short.
func _pay(player_id: int, cost: int) -> bool:
	if coins < cost:
		_notify(player_id, "Not enough coins (%d short)" % (cost - coins))
		return false
	coins -= cost
	_changed("economy")
	return true


## Getting into bed. The day ends once every player in the garden is in bed;
## asking again while waiting gets you back up.
func _do_sleep(player_id: int) -> bool:
	if sleeping.has(player_id):
		sleeping.erase(player_id)
		_bedtime += 1  # getting up calls off the fade to morning
		sleepers_changed.emit()
		return true
	sleeping[player_id] = true
	sleepers_changed.emit()  # everyone sees them tucked in
	if _everyone_asleep():
		_start_bedtime()
	return true


## Everyone is in bed: let the screens fade slowly to black with the
## sleepers together under the covers, then start the next day.
func _start_bedtime() -> void:
	_bedtime += 1
	var kiss_by: int = 0
	if sleeping.size() >= 2 and _kiss_dice.randf() < kiss_chance:
		var pair: Array = sleeping.keys()
		kiss_by = int(pair[_kiss_dice.randi_range(0, pair.size() - 1)])
	bedtime_started.emit(kiss_by)
	if _mirroring():
		_net_bedtime.rpc(kiss_by)
	if bedtime_fade <= 0.0:
		end_day(false)
		return
	var ticket: int = _bedtime
	get_tree().create_timer(bedtime_fade).timeout.connect(func() -> void:
		if ticket == _bedtime and everyone_in_bed():
			end_day(false))


## Whether everyone in the garden is in bed (the fade to morning is on).
func everyone_in_bed() -> bool:
	return not sleeping.is_empty() and _everyone_asleep()


# ------------------------------------------------------------ day rollover

## `passed_out` is true when the clock hit 2am: anyone not in bed by then
## wakes up with half energy.
func end_day(passed_out: bool) -> void:
	if not Net.is_host():
		return
	_bedtime += 1  # any fade still waiting is done with
	var night_news: Array = _end_festival()
	night_news.append_array(_tend_animals_overnight())
	night_news.append_array(_grow_fruit_trees())
	_regrow_trees()
	night_news.append_array(_run_machines())
	if wild_growth:
		night_news.append_array(_crows())
	for key: String in bags.keys():
		var bag: Dictionary = bags[key]
		var shipped: int = 0
		for id: String in bag["bin"].keys():
			shipped += sell_price_of(id) * int(bag["bin"][id])
		if shipped > 0:
			bag["coins"] = int(bag["coins"]) + shipped
			var who: String = "" if bags.size() < 2 else (" for you" if int(key) == _me() else " for %s" % Net.name_of_slot(int(key)))
			night_news.append("The shipping bin earned %d coins%s" % [shipped, who])
		bag["bin"] = {}
	_changed("economy")
	var tree_news: Dictionary = _grow_tree()
	var discoveries: Array = []
	for cell: Vector2i in plants.keys():
		_grow_plant(cell)
		var id: String = plants[cell]["species"]
		var level: int = JOURNAL_RADIANT if plant_is_radiant(cell) else (JOURNAL_BLOOMED if plant_is_mature(cell) else 0)
		if level > journal_level(id):
			discoveries.append("%s %s for the first time" % [species[id].display_name, "turned radiant" if level == JOURNAL_RADIANT else "bloomed"])
			_note(id, level)
	for cell: Vector2i in soil.keys():
		soil[cell]["watered"] = false
		if not plants.has(cell) and not bool(soil[cell].get("mulch", false)) and rng.randf() < SOIL_REVERT_CHANCE:
			soil.erase(cell)
	TimeManager.start_next_day()
	var season: int = TimeManager.season()
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		p["dormant"] = not in_season(cell, p["species"])
	if TimeManager.raining:
		for cell: Vector2i in soil.keys():
			soil[cell]["watered"] = true
	for cell: Vector2i in objects.keys():  # sprinklers do the morning watering
		var reach: Array = []
		if object_kind(cell) == "sprinkler":
			reach = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
		elif object_kind(cell) == "bigsprinkler":
			reach = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
		for side: Vector2i in reach:
			if soil.has(cell + side):
				soil[cell + side]["watered"] = true
	_fill_mine()
	_deliver_mail()
	_refresh_quests()
	if wild_growth:
		_grow_forage()
	for id: String in friends.keys():
		friends[id]["talked"] = false
		friends[id]["gifted"] = false
	if wild_growth:
		scatter_debris(rng.randi_range(1, 3) + (3 if TimeManager.stormy else 0))
	if wanted.is_empty():
		_new_request()
	tree["watered"] = TimeManager.raining
	tree["hugged_by"] = {}
	tree_changed.emit()
	var dozers: Array = []
	for pid: int in energy.keys():
		var slept: bool = not passed_out or sleeping.has(pid)
		@warning_ignore("integer_division")
		energy[pid] = max_energy() if slept else max_energy() / 2
		if not slept:
			dozers.append(pid)
		energy_changed.emit(pid)
	sleeping.clear()
	sleepers_changed.emit()
	save_game()
	night_news.append_array(_check_goals())
	var festival: int = festival_today()
	if festival != -1:
		night_news.append("Today is the %s! %s" % [FESTIVALS[festival]["name"], FESTIVALS[festival]["today"]])
	if TimeManager.stormy:
		night_news.append("A storm is blowing through today")
	if festival == -1 and TimeManager.day_of_season() == FESTIVAL_DAY - 1:
		night_news.append("Tomorrow is the %s" % FESTIVALS[TimeManager.season()]["name"])
	_changed("inventory")
	_changed("economy")
	var summary: Dictionary = {
		"news": night_news,
		"passed_out": dozers,
		"raining": TimeManager.raining,
		"tree": tree_news,
		"discoveries": discoveries,
	}
	day_advanced.emit(summary)
	if _mirroring():
		_net_day.rpc(to_snapshot(), summary)


## Adds today's love to the Heart Tree. Returns {} or, when it reached a new
## stage, {"stage": int, "gifts": "3 Pricklepal seeds, ..."}.
func _grow_tree() -> Dictionary:
	var cared: int = 0
	for cell: Vector2i in plants.keys():
		var p: Dictionary = plants[cell]
		if not bool(p["dormant"]) and (bool(soil[cell]["watered"]) or not p["petted_by"].is_empty()):
			cared += 1
	if cared > 0:
		_gain_xp(mini(cared, TREE_LOVE_PLANT_CAP))  # a point for every plant looked after today
	var gained: int = mini(cared, TREE_LOVE_PLANT_CAP) * TREE_LOVE_PER_PLANT
	if bool(tree["watered"]):
		gained += TREE_LOVE_WATERED
	gained += tree["hugged_by"].size() * TREE_LOVE_HUG
	var before: int = tree_stage()
	tree["love"] = int(tree["love"]) + gained
	var after: int = tree_stage()
	if after == before:
		return {}
	var parts: Array = []
	for stage in range(before + 1, after + 1):
		var gifts: Dictionary = TREE_GIFTS.get(stage, {})
		_reward_everyone(0, gifts)
		for id: String in gifts.keys():
			parts.append("%d %s seeds" % [int(gifts[id]), species[id].display_name])
	_changed("inventory")
	return {"stage": after, "gifts": ", ".join(parts)}


func _grow_plant(cell: Vector2i) -> void:
	var p: Dictionary = plants[cell]
	var d: Resource = species[p["species"]]
	var happiness: int = int(p["happiness"])
	# Out of season plants sleep: no growth, and no hurt feelings either.
	if in_season(cell, p["species"]):
		if bool(soil[cell]["watered"]):
			if not plant_is_mature(cell):
				p["days_grown"] = int(p["days_grown"]) + 1
				# Well-loved plants sometimes put on a growth spurt.
				if happiness >= RADIANT_AT and rng.randf() < 0.25:
					p["days_grown"] = int(p["days_grown"]) + 1
				if bool(soil[cell].get("mulch", false)) and rng.randf() < MULCH_BOOST:
					p["days_grown"] = int(p["days_grown"]) + 1
			elif int(p["regrow_wait"]) > 0:
				p["regrow_wait"] = int(p["regrow_wait"]) - 1
			happiness += HAPPY_WATERED
		else:
			happiness += HAPPY_NEGLECTED
		if not p["petted_by"].is_empty():
			happiness += HAPPY_PETTED * (2 if festival_today() == 1 else 1)  # Firefly Night
		if p["petted_by"].size() >= 2:
			happiness += HAPPY_DUET
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


## Records a first for the garden journal.
func _note(species_id: String, level: int) -> void:
	if level > journal_level(species_id):
		journal[species_id] = level
		journal_changed.emit()


func _everyone_asleep() -> bool:
	for slot: int in Net.slots():
		if not sleeping.has(slot):
			return false
	return true


## Show a short message to one player, wherever they are playing.
func _notify(player_id: int, text: String) -> void:
	if player_id == Net.local_id():
		notice.emit(text)
	elif _mirroring():
		var peer_id: int = Net.peer_of(player_id)
		if peer_id != 0:
			_net_notice.rpc_id(peer_id, text)


func _spend(player_id: int, cost: int) -> bool:
	var left: int = get_energy(player_id)
	if left < cost:
		_notify(player_id, "Too tired... time to rest")
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
		"name": garden_name,
		"code": garden_code,
		"saved_at": int(Time.get_unix_time_from_system()),
		"day_index": TimeManager.day_index,
		"minutes": TimeManager.minutes,
		"raining": TimeManager.raining,
		"stormy": TimeManager.stormy,
		"soil": soil_out,
		"plants": plants_out,
		"bags": bags,
		"tree": tree,
		"journal": journal,
		"coins": int(bag_of(1).get("coins", START_COINS)),  # the host's purse, for the garden list
		"upgrades": upgrades,
		"hats_owned": hats_owned,
		"outfits": outfits,
		"objects": _keyed(objects),
		"felled": _keyed(felled),
		"xp": xp,
		"wanted": wanted,
		"animals": animals,
		"mail": mail,
		"quests": quests,
		"friends": friends,
		"stats": stats,
		"goals_done": goals_done,
		"energy": energy_out,
	}


func apply_snapshot(data: Dictionary) -> void:
	soil.clear()
	plants.clear()
	for key: String in data.get("soil", {}).keys():
		soil[_cell(key)] = {"watered": bool(data["soil"][key]["watered"])}
		if bool(data["soil"][key].get("mulch", false)):
			soil[_cell(key)]["mulch"] = true
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
	felled = {}
	for key: String in data.get("felled", {}).keys():
		if SCENERY.has(_cell(key)):
			felled[_cell(key)] = int(data["felled"][key])
	# Trees added since a garden was saved don't push out what grows or stands
	# there: they start out cut down instead.
	var saved_things: Dictionary = data.get("objects", {})
	for at: Vector2i in SCENERY.keys():
		var tiles: Array = scenery_tiles(at)
		for tile: Vector2i in tiles:
			if soil.has(tile) or saved_things.has(_key(tile)):
				felled[at] = int(data.get("day_index", 0))
	# Gardens saved before the tent or tree stood somewhere may have soil there.
	for cell: Vector2i in soil.keys():
		if is_blocked(cell):
			soil.erase(cell)
			plants.erase(cell)
	journal = _int_values(data.get("journal", {}))
	bags = {}
	if data.has("bags"):
		for key: String in data["bags"].keys():
			if int(key) >= 1:
				bags[str(int(key))] = _clean_bag(data["bags"][key])
	else:  # gardens from before everyone had their own bag: it was the host's
		bags["1"] = _clean_bag(data)
	upgrades = {"hoe": 0, "can": 0, "home": 0}
	animals = []  # so blocked-tile checks below don't see last garden's animals
	for kind: String in data.get("upgrades", {}).keys():
		if UPGRADES.has(kind):
			upgrades[kind] = clampi(int(data["upgrades"][kind]), 0, UPGRADES[kind].size())
	hats_owned = ["straw"]
	for hat: Variant in data.get("hats_owned", []):
		if HATS.has(str(hat)) and not hats_owned.has(str(hat)):
			hats_owned.append(str(hat))
	outfits = {}
	for key: String in data.get("outfits", {}).keys():
		if hats_owned.has(str(data["outfits"][key])):
			outfits[key] = str(data["outfits"][key])
	objects = {}
	for key: String in data.get("objects", {}).keys():
		var kind: String = str(data["objects"][key].get("kind", ""))
		var at: Vector2i = _cell(key)
		var fits: bool = in_bounds(at) and not is_blocked(at) and not soil.has(at)
		if is_indoors(at):
			fits = mine_floor().has_point(at) if is_in_mine(at) else room_floor().has_point(at)
		if kind == "dropped" and fits and _known(str(data["objects"][key].get("key", ""))) and int(data["objects"][key].get("count", 0)) > 0:
			objects[at] = {"kind": kind, "key": str(data["objects"][key]["key"]), "count": int(data["objects"][key]["count"])}
		elif (ITEMS.has(kind) or DEBRIS.has(kind) or ORES.has(kind)) and fits:
			objects[at] = {"kind": kind}
			for extra: String in ["age", "since", "busy"]:
				if data["objects"][key].has(extra):
					objects[at][extra] = int(data["objects"][key][extra])
			for flag: String in ["fruit", "ready"]:
				if bool(data["objects"][key].get(flag, false)):
					objects[at][flag] = true
	xp = int(data.get("xp", 0))
	animals = []
	for saved: Variant in data.get("animals", []):
		if typeof(saved) == TYPE_DICTIONARY and ANIMALS.has(str(saved.get("kind", ""))):
			var pets: Dictionary = {}
			for k: String in saved.get("petted_by", {}).keys():
				pets[k] = true
			animals.append({"kind": str(saved["kind"]), "mood": int(saved.get("mood", 50)), "fed": bool(saved.get("fed", false)), "petted_by": pets})
	friends = {}
	for id: String in data.get("friends", {}).keys():
		if VILLAGERS.has(id):
			var f: Dictionary = data["friends"][id]
			friends[id] = {"points": int(f.get("points", 0)), "talked": bool(f.get("talked", false)), "gifted": bool(f.get("gifted", false)), "rewards": int(f.get("rewards", 0))}
			if bool(f.get("wrote", false)):
				friends[id]["wrote"] = true
	mail = []
	for letter: Variant in data.get("mail", []):
		if typeof(letter) == TYPE_DICTIONARY:
			var gift: Dictionary = letter.get("gift", {})
			var clean: Dictionary = {}
			if int(gift.get("coins", 0)) > 0:
				clean["coins"] = int(gift["coins"])
			for part: String in ["items", "seeds"]:
				if not gift.get(part, {}).is_empty():
					clean[part] = _int_values(gift[part])
			mail.append({"from": str(letter.get("from", "")), "text": str(letter.get("text", "")), "gift": clean})
	quests = []
	for quest: Variant in data.get("quests", []):
		if typeof(quest) == TYPE_DICTIONARY and (species.has(str(quest.get("id", ""))) or ITEMS.has(str(quest.get("id", "")))):
			quests.append({"who": str(quest.get("who", "bristle")), "id": str(quest["id"]), "count": int(quest.get("count", 1)), "coins": int(quest.get("coins", 0)), "days": int(quest.get("days", 1))})
	var has_rocks: bool = false
	for at: Vector2i in objects.keys():
		if is_in_mine(at):
			has_rocks = true
	if not has_rocks and Net.is_host():
		_fill_mine()  # gardens saved before the mine existed
	var saved_stats: Dictionary = data.get("stats", {})
	stats = {"requests": int(saved_stats.get("requests", 0)), "cooked": {}, "fish": {}}
	for id: String in saved_stats.get("cooked", {}).keys():
		stats["cooked"][id] = true
	for id: String in saved_stats.get("fish", {}).keys():
		stats["fish"][id] = int(saved_stats["fish"][id])
	goals_done = []
	for id: Variant in data.get("goals_done", []):
		goals_done.append(str(id))
	wanted = {}
	var asked: Dictionary = data.get("wanted", {})
	if species.has(str(asked.get("species", ""))):
		wanted = {"species": str(asked["species"]), "count": int(asked.get("count", 1)), "reward": int(asked.get("reward", 0))}
	var saved_tree: Dictionary = data.get("tree", {})
	tree = {"love": int(saved_tree.get("love", 0)), "watered": bool(saved_tree.get("watered", false)), "hugged_by": {}}
	for k: String in saved_tree.get("hugged_by", {}).keys():
		tree["hugged_by"][k] = true
	# Older gardens: anything already growing counts as planted in the journal.
	for cell: Vector2i in plants.keys():
		if journal_level(plants[cell]["species"]) < JOURNAL_PLANTED:
			journal[plants[cell]["species"]] = JOURNAL_PLANTED
	energy.clear()
	for key: String in data.get("energy", {}).keys():
		energy[int(key)] = int(data["energy"][key])
	garden_name = str(data.get("name", "My Garden"))
	garden_code = str(data.get("code", ""))
	TimeManager.day_index = int(data.get("day_index", 0))
	TimeManager.minutes = int(data.get("minutes", TimeManager.DAY_START))
	TimeManager.raining = bool(data.get("raining", false))
	TimeManager.stormy = bool(data.get("stormy", false))
	TimeManager.time_changed.emit()
	state_reloaded.emit()


## One player's bag from a save or the network, keeping only things that exist.
func _clean_bag(src: Dictionary) -> Dictionary:
	var bag: Dictionary = {"seeds": {}, "produce": {}, "items": {}, "coins": maxi(int(src.get("coins", START_COINS)), 0), "bin": {}, "slots": []}
	for id: String in src.get("seeds", {}).keys():
		if species.has(id):
			bag["seeds"][id] = int(src["seeds"][id])
	for id: String in src.get("produce", {}).keys():
		if species.has(id):
			bag["produce"][id] = int(src["produce"][id])
	for id: String in src.get("items", {}).keys():
		if (ITEMS.has(id) or (species.has(base_of(id)) and QUALITIES.has(quality_of(id)))):
			bag["items"][id] = int(src["items"][id])
	for id: String in src.get("bin", {}).keys():
		if species.has(base_of(id)) or ITEMS.has(id):
			bag["bin"][id] = int(src["bin"][id])
	for key: Variant in src.get("slots", []):
		bag["slots"].append(str(key) if _known(str(key)) else "")
	return bag


## Whether a bag key ("seed:sunpuff", "item:tea", ...) names a real thing.
func _known(key: String) -> bool:
	var id: String = key.get_slice(":", 1)
	match key.get_slice(":", 0):
		"seed", "harvest": return species.has(id)
		"item": return ITEMS.has(id) or (species.has(base_of(id)) and QUALITIES.has(quality_of(id)))
	return false


## Only the garden's owner saves; a guest never writes the host's garden to disk.
func save_game() -> void:
	if not Net.is_host() or save_path == "":
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % save_path)
		return
	file.store_string(JSON.stringify(to_snapshot(), "\t"))


func load_game() -> bool:
	if save_path == "" or not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is damaged, starting a new garden")
		return false
	apply_snapshot(parsed)
	return true


# ------------------------------------------------------------ save files

## Every saved garden, newest first:
## {"path", "name", "day_index", "love", "saved_at"}.
func list_gardens() -> Array[Dictionary]:
	_adopt_legacy_save()
	var found: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(saves_dir):
		return found  # first run: nothing saved yet
	for file_name: String in DirAccess.get_files_at(saves_dir):
		if not file_name.ends_with(".json"):
			continue
		var path: String = saves_dir.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var data: Dictionary = parsed
		found.append({
			"path": path,
			"name": str(data.get("name", "My Garden")),
			"day_index": int(data.get("day_index", 0)),
			"love": int(data.get("tree", {}).get("love", 0)),
			"saved_at": int(data.get("saved_at", 0)),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["saved_at"]) > int(b["saved_at"]))
	return found


## Starts a brand new garden with its own save file and opens it.
func create_garden(new_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(saves_dir)
	new_game()
	garden_name = new_name.strip_edges().left(24)
	if garden_name == "":
		garden_name = "My Garden"
	garden_code = new_code()
	if wild_growth:
		scatter_debris(18)  # a new plot starts a little wild
	var number: int = 1
	while FileAccess.file_exists(saves_dir.path_join("garden_%d.json" % number)):
		number += 1
	save_path = saves_dir.path_join("garden_%d.json" % number)
	save_game()


func open_garden(path: String) -> bool:
	save_path = path
	if load_game():
		if garden_code == "":  # gardens from before invite codes
			garden_code = new_code()
			save_game()
		return true
	close_garden()
	return false


## Back to an empty, unsaved garden (the title menu's backdrop).
func close_garden() -> void:
	save_path = ""
	garden_name = "My Garden"
	garden_code = ""
	new_game()


## A fresh invite code: six characters, leaving out look-alikes (0/O, 1/I/L).
func new_code() -> String:
	const LETTERS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(6)
	var code: String = ""
	for b: int in bytes:
		code += LETTERS[b % LETTERS.length()]
	return code


func delete_garden(path: String) -> void:
	if path.begins_with(saves_dir) and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _adopt_legacy_save() -> void:
	if saves_dir != "user://saves" or not FileAccess.file_exists(LEGACY_SAVE):
		return
	DirAccess.make_dir_recursive_absolute(saves_dir)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(LEGACY_SAVE), ProjectSettings.globalize_path(saves_dir.path_join("garden_0.json")))


## A copy of a Vector2i-keyed dictionary with "x,y" keys, for saving and sending.
func _keyed(by_cell: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in by_cell.keys():
		out[_key(cell)] = by_cell[cell]
	return out


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


# ------------------------------------------------------------------ co-op

func is_sleeping(player_id: int) -> bool:
	return sleeping.has(player_id)


## True on a host with guests to keep up to date.
func _mirroring() -> bool:
	return Net.online and Net.is_host()


func _on_player_joined(slot: int) -> void:
	if not _mirroring():
		return
	register_player(slot)
	_net_snapshot.rpc_id(Net.peer_of(slot), to_snapshot(), sleeping.keys())


func _on_player_left(slot: int) -> void:
	if not _mirroring():
		return
	sleeping.erase(slot)
	sleepers_changed.emit()
	if everyone_in_bed():
		_start_bedtime()


## After leaving someone else's garden, go back to our own.
func _on_session_ended(was_host: bool) -> void:
	sleeping.clear()
	sleepers_changed.emit()
	if not was_host:
		close_garden()


## A guest asking the host to do something. Everything from the network is
## checked before use.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(action: String, args: Array) -> void:
	if not _mirroring():
		return
	var slot: int = Net.slot_of(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	var valid: bool = false
	const WAYS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	match action:
		"till", "water":
			valid = args.size() == 2 and args[0] is Vector2i and args[1] is Vector2i and WAYS.has(args[1])
		"sell", "buy_seeds":
			valid = args.size() == 2 and args[0] is String and args[1] is int and args[1] >= 1 and args[1] <= 999
		"place":
			valid = args.size() == 2 and args[0] is Vector2i and args[1] is String
		"open_mail", "quest":
			valid = args.size() == 1 and args[0] is int
		"mine", "tend":
			valid = args.size() == 1 and args[0] is Vector2i
		"buy_animal", "talk":
			valid = args.size() == 1 and args[0] is String
		"gift":
			valid = args.size() == 2 and args[0] is String and args[1] is String
		"fish":
			valid = args.size() == 1 and args[0] is bool
		"buy_item":
			valid = args.size() == 2 and args[0] is String and args[1] is int and args[1] >= 1 and args[1] <= 99
		"ship":
			valid = args.size() == 2 and args[0] is String and args[1] is int and absi(args[1]) <= 999
		"craft", "eat":
			valid = args.size() == 1 and args[0] is String
		"deliver":
			valid = args.is_empty()
		"set_time":
			valid = args.size() == 3 and args[0] is int and args[1] is int and args[2] is bool and args[0] >= 0
		"buy_upgrade", "buy_hat", "wear":
			valid = args.size() == 1 and args[0] is String
		"pet", "harvest":
			valid = args.size() == 1 and args[0] is Vector2i
		"plant":
			valid = args.size() == 2 and args[0] is Vector2i and args[1] is String
		"sleep":
			valid = args.is_empty()
		"move_slot":
			valid = args.size() == 2 and args[0] is int and args[1] is int
		"drop":
			valid = args.size() == 2 and args[0] is String and _known(args[0]) and args[1] is Vector2i
		"chop":
			valid = args.size() == 1 and args[0] is Vector2i
	if valid:
		_apply(action, slot, args)


@rpc("authority", "call_remote", "reliable")
func _net_warp(data: Dictionary) -> void:
	apply_snapshot(data)
	time_warped.emit()


func _mirror_mail() -> void:
	if _mirroring():
		_net_mail.rpc(mail, quests)


@rpc("authority", "call_remote", "reliable")
func _net_mail(new_mail: Array, new_quests: Array) -> void:
	mail = new_mail
	quests = new_quests
	mail_changed.emit()


func _mirror_animals() -> void:
	if _mirroring():
		_net_animals.rpc(animals)


@rpc("authority", "call_remote", "reliable")
func _net_animals(new_animals: Array) -> void:
	animals = new_animals
	animals_changed.emit()


func _mirror_object(cell: Vector2i) -> void:
	if _mirroring():
		_net_object.rpc(cell, objects.get(cell))


@rpc("authority", "call_remote", "reliable")
func _net_object(cell: Vector2i, thing: Variant) -> void:
	if thing == null:
		objects.erase(cell)
	else:
		objects[cell] = thing
	object_changed.emit(cell)


func _mirror_economy() -> void:
	if _mirroring():
		_net_economy.rpc(bags, upgrades, hats_owned, outfits, xp, wanted, stats, goals_done, friends)


@rpc("authority", "call_remote", "reliable")
func _net_economy(new_bags: Dictionary, new_upgrades: Dictionary, new_hats: Array, new_outfits: Dictionary, new_xp: int, new_wanted: Dictionary, new_stats: Dictionary, new_goals: Array, new_friends: Dictionary) -> void:
	friends = new_friends
	stats = new_stats
	goals_done = new_goals
	xp = new_xp
	wanted = new_wanted
	bags = new_bags
	upgrades = new_upgrades
	hats_owned = new_hats
	outfits = new_outfits
	economy_changed.emit()


func _mirror_tree() -> void:
	if _mirroring():
		_net_tree.rpc(tree)


func _mirror_journal() -> void:
	if _mirroring():
		_net_journal.rpc(journal)


@rpc("authority", "call_remote", "reliable")
func _net_tree(new_tree: Dictionary) -> void:
	tree = new_tree
	tree_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_journal(new_journal: Dictionary) -> void:
	journal = new_journal
	journal_changed.emit()


func _mirror_cell(cell: Vector2i) -> void:
	if _mirroring():
		_net_cell.rpc(cell, soil.get(cell), plants.get(cell))


func _mirror_pet(cell: Vector2i) -> void:
	if _mirroring():
		_net_cell.rpc(cell, soil.get(cell), plants.get(cell))
		_net_pet.rpc(cell)


func _mirror_inventory() -> void:
	if _mirroring():
		_net_inventory.rpc(bags)


func _mirror_scenery_hit(cell: Vector2i, did_fell: bool) -> void:
	if _mirroring():
		_net_scenery_hit.rpc(cell, did_fell, int(felled.get(cell, 0)))


@rpc("authority", "call_remote", "reliable")
func _net_scenery_hit(cell: Vector2i, did_fell: bool, day: int) -> void:
	if did_fell:
		felled[cell] = day
	scenery_hit.emit(cell, did_fell)


func _mirror_energy(player_id: int) -> void:
	if _mirroring():
		_net_energy.rpc(player_id, get_energy(player_id))


@rpc("authority", "call_remote", "reliable")
func _net_bedtime(kiss_by: int) -> void:
	bedtime_started.emit(kiss_by)


func _mirror_sleepers() -> void:
	if _mirroring():
		_net_sleepers.rpc(sleeping.keys())


func _mirror_time() -> void:
	if _mirroring():
		_net_time.rpc(TimeManager.day_index, TimeManager.minutes, TimeManager.raining)


@rpc("authority", "call_remote", "reliable")
func _net_snapshot(data: Dictionary, sleepers: Array) -> void:
	apply_snapshot(data)
	_net_sleepers(sleepers)


@rpc("authority", "call_remote", "reliable")
func _net_day(data: Dictionary, summary: Dictionary) -> void:
	apply_snapshot(data)
	_net_sleepers([])
	day_advanced.emit(summary)


@rpc("authority", "call_remote", "reliable")
func _net_cell(cell: Vector2i, soil_state: Variant, plant: Variant) -> void:
	var had_plant: bool = plants.has(cell)
	if soil_state == null:
		soil.erase(cell)
	else:
		soil[cell] = soil_state
	if plant == null:
		plants.erase(cell)
	else:
		plants[cell] = plant
	if plant != null and not had_plant:
		plant_added.emit(cell)
	elif plant == null and had_plant:
		plant_removed.emit(cell)
	else:
		cell_changed.emit(cell)


@rpc("authority", "call_remote", "reliable")
func _net_pet(cell: Vector2i) -> void:
	if plants.has(cell):
		plant_petted.emit(cell)


@rpc("authority", "call_remote", "reliable")
func _net_inventory(new_bags: Dictionary) -> void:
	bags = new_bags
	inventory_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_energy(player_id: int, value: int) -> void:
	energy[player_id] = value
	energy_changed.emit(player_id)


@rpc("authority", "call_remote", "reliable")
func _net_sleepers(sleepers: Array) -> void:
	sleeping.clear()
	for slot: int in sleepers:
		sleeping[slot] = true
	sleepers_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_time(day_index: int, minutes: int, raining: bool) -> void:
	TimeManager.day_index = day_index
	TimeManager.minutes = minutes
	TimeManager.raining = raining
	TimeManager.time_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_notice(text: String) -> void:
	notice.emit(text)
