extends RefCounted
## The town's quest tables, read by GameState (rules) and the quest screens.
##
## STORIES: one story per person, offered once you have `hearts` hearts with
## them. Each step is one of:
##   talk:    talk to `to`
##   bring:   hand `count` of `id` to `to` (silver and gold count)
##   deliver: carry `id` (a quest item, given when the step starts) to `to`
##   find:    `id` (a quest item) is dropped somewhere in town when the step
##            starts; pick it up and take it to `to`
## `say` is what you're asked (and what the journal shows); `thanks` is said
## by `to` when the step is done.
##
## SCENES: a moment with someone on reaching 2 and 4 hearts, with three
## replies, each worth some friendship and an answer.
##
## LOST: what each person loses for a "find" errand. PROJECTS: the town hall's
## projects board; `props` appear in town (town tiles) once one is built.

const STORIES: Dictionary = {
	"bristle": {"title": "Heirloom Seeds", "hearts": 1,
		"intro": ["My mother grew a sunpuff you won't find in any catalogue.", "Thistle might remember where her seeds went. Would you ask him?"],
		"steps": [
			{"do": "talk", "to": "thistle", "say": "Ask Old Thistle about Bristle's mother's seeds", "thanks": "Her seeds? I gave the last of them to Professor Quill, for safekeeping."},
			{"do": "talk", "to": "quill", "say": "Ask Professor Quill about the heirloom seeds", "thanks": "Hoo! Yes, here: a letter, with the seeds pressed inside. Take it to Bristle."},
			{"do": "deliver", "id": "letter", "to": "bristle", "say": "Take Quill's letter to Bristle", "thanks": "Her handwriting... Thank you, friend. These are going in the window box."},
			{"do": "bring", "id": "sunpuff", "count": 3, "to": "bristle", "say": "Bring Bristle 3 sunpuffs to compare", "thanks": "Ha! Yours are nearly as fine as hers. Nearly."},
		],
		"reward": {"coins": 300, "seeds": {"sunpuff": 10}}},
	"juniper": {"title": "The Lost Recipe", "hearts": 1,
		"intro": ["I've lost my grandmother's honey cake recipe! It blew away when I opened the door.", "It must be somewhere in town. Could you look?"],
		"steps": [
			{"do": "find", "id": "recipecard", "to": "juniper", "say": "Find Juniper's recipe card somewhere in town", "thanks": "You found it! A little flour-stained, but that's how I like it."},
			{"do": "bring", "id": "honey", "count": 2, "to": "juniper", "say": "Bring Juniper 2 honey for the cake", "thanks": "Lovely. Now, into the oven..."},
			{"do": "deliver", "id": "parcel", "to": "clementine", "say": "Take Juniper's honey cake to Mayor Clementine", "thanks": "A honey cake! Juniper spoils this town. Tell her thank you."},
		],
		"reward": {"coins": 250, "items": {"cinnamonbuns": 3}}},
	"flint": {"title": "A Song in the Steel", "hearts": 1,
		"intro": ["My father used to hum while he worked. I've forgotten the tune.", "I'd like to forge him a bell that rings it. I'll need copper first."],
		"steps": [
			{"do": "bring", "id": "copper", "count": 5, "to": "flint", "say": "Bring Flint 5 copper", "thanks": "Good copper. Now if only I remembered that tune."},
			{"do": "talk", "to": "rosie", "say": "Ask Rosie if she remembers Flint's father's tune", "thanks": "Old Ember's song? He sang it every night at the bar. It goes like this... Tell Flint."},
			{"do": "bring", "id": "amethyst", "count": 1, "to": "flint", "say": "Bring Flint an amethyst for the bell's clapper", "thanks": "...There. Hear that? That's him. That's exactly him."},
		],
		"reward": {"coins": 400, "items": {"copper": 3}}},
	"marlow": {"title": "The One That Got Away", "hearts": 1,
		"intro": ["Twenty years I've chased a salmon the size of a rowing boat.", "Young Pebble says they've seen it. Ask them where?"],
		"steps": [
			{"do": "talk", "to": "pebble", "say": "Ask Pebble where they saw Marlow's big salmon", "thanks": "Below the falls, at dawn! But it only bites after it's eaten a trout or two."},
			{"do": "bring", "id": "trout", "count": 1, "to": "marlow", "say": "Bring Marlow a trout for bait", "thanks": "Perfect bait. Now we need the big one itself."},
			{"do": "bring", "id": "salmon", "count": 1, "to": "marlow", "say": "Catch a salmon in the river and bring it to Marlow", "thanks": "Not the giant... but a beauty. Maybe the chase is the best part."},
		],
		"reward": {"coins": 350, "items": {"skewer": 2}}},
	"birch": {"title": "A Bench for Everyone", "hearts": 1,
		"intro": ["The Mayor says the town needs more places to sit. I'll carve a bench.", "Wood first, lots of it."],
		"steps": [
			{"do": "bring", "id": "wood", "count": 10, "to": "birch", "say": "Bring Birch 10 wood", "thanks": "Lovely grain. Now some stone for the feet."},
			{"do": "bring", "id": "stone", "count": 5, "to": "birch", "say": "Bring Birch 5 stone", "thanks": "There. Take this carved sign to the Mayor, would you?"},
			{"do": "deliver", "id": "parcel", "to": "clementine", "say": "Take Birch's carved sign to Mayor Clementine", "thanks": "\"Sit a while.\" Oh, Birch. It's perfect."},
		],
		"reward": {"coins": 200, "items": {"armchair": 1}}},
	"sage": {"title": "Thank the Weeds", "hearts": 1,
		"intro": ["I'm writing a book of valley remedies. Every weed in it is a friend.", "Will you help me gather what it needs?"],
		"steps": [
			{"do": "bring", "id": "wildgreens", "count": 3, "to": "sage", "say": "Bring Sage 3 wild greens", "thanks": "Ah, these will do nicely. Maple knows which flowers her bees love: ask her."},
			{"do": "talk", "to": "maple", "say": "Ask Maple which flowers her bees love", "thanks": "Moonbells, always moonbells. Tell Sage they hum for them."},
			{"do": "bring", "id": "moonbell", "count": 2, "to": "sage", "say": "Bring Sage 2 moonbells", "thanks": "The last page. Thank you. I'll put your name in the front."},
		],
		"reward": {"coins": 250, "items": {"tonic": 3}}},
	"quill": {"title": "The Valley Map", "hearts": 1,
		"intro": ["Hoo! The museum's oldest map has gone missing.", "The wind took it from my desk. It could be anywhere in town!"],
		"steps": [
			{"do": "find", "id": "oldmap", "to": "quill", "say": "Find Professor Quill's old map somewhere in town", "thanks": "My map! Look, the valley before the town was built. And there, an X..."},
			{"do": "talk", "to": "clementine", "say": "Ask Mayor Clementine about the X on the old map", "thanks": "That's where the first mine shaft was. They say they found gold there."},
			{"do": "bring", "id": "goldore", "count": 1, "to": "quill", "say": "Bring Professor Quill a piece of gold ore from the mine", "thanks": "Hoo hoo! The map was right. This goes in a case of its own."},
		],
		"reward": {"coins": 400, "items": {"bookcase": 1}}},
	"clementine": {"title": "The Town Bell", "hearts": 1,
		"intro": ["The town hall bell cracked in the frost years ago. I'd love it to ring again.", "Would you ask Flint if he can mend it?"],
		"steps": [
			{"do": "talk", "to": "flint", "say": "Ask Flint about mending the town bell", "thanks": "Mend it? I'll recast it. I'll need gold to make it sing, though."},
			{"do": "bring", "id": "goldore", "count": 2, "to": "flint", "say": "Bring Flint 2 gold ore for the bell", "thanks": "Done. Listen to her ring! Tell the Mayor."},
			{"do": "deliver", "id": "letter", "to": "rosie", "say": "Take the Mayor's invitation to the bell-ringing to Rosie", "thanks": "A bell-ringing party? I'll bring the stew!"},
		],
		"reward": {"coins": 300, "items": {"lantern": 2}}},
	"rosie": {"title": "Grandmother's Stew", "hearts": 1,
		"intro": ["Everyone loves my stew, but it's not quite Gran's.", "Old Thistle ate at her table. Ask him what I'm missing?"],
		"steps": [
			{"do": "talk", "to": "thistle", "say": "Ask Old Thistle about Rosie's gran's stew", "thanks": "Eggs! She stirred an egg through at the end. And fresh milk."},
			{"do": "bring", "id": "egg", "count": 2, "to": "rosie", "say": "Bring Rosie 2 eggs", "thanks": "An egg stirred through... of course!"},
			{"do": "bring", "id": "milk", "count": 1, "to": "rosie", "say": "Bring Rosie some milk", "thanks": "Taste that. That's Gran's stew. Oh, I could cry."},
		],
		"reward": {"coins": 300, "items": {"stew": 3}}},
	"thistle": {"title": "The First Garden", "hearts": 1,
		"intro": ["Did you know your garden was mine once, long ago?", "I'd love to see it written down. Ask Bristle; he kept the old ledgers."],
		"steps": [
			{"do": "talk", "to": "bristle", "say": "Ask Bristle about the old garden ledgers", "thanks": "Thistle's garden? The ledger's here. Tell him I found it... and his spectacles, he left them in town somewhere."},
			{"do": "find", "id": "spectacles", "to": "thistle", "say": "Find Old Thistle's spectacles in town", "thanks": "My spectacles! Now I can read about my own garden."},
			{"do": "bring", "id": "pie", "count": 1, "to": "thistle", "say": "Bring Old Thistle a pie to read by", "thanks": "Pie and memories. You've given an old gardener a good day."},
		],
		"reward": {"coins": 300, "items": {"gnome": 1}}},
	"pebble": {"title": "Biggest Catch", "hearts": 1,
		"intro": ["I want to be the best angler in the valley!", "Help me prove it? Start with a goldie: they're so rare."],
		"steps": [
			{"do": "bring", "id": "goldie", "count": 1, "to": "pebble", "say": "Bring Pebble a goldie", "thanks": "A real goldie! Marlow's never going to believe this. Go tell him!"},
			{"do": "talk", "to": "marlow", "say": "Tell Marlow about Pebble's goldie", "thanks": "A goldie? Tell that rascal the eels are the real test. After dark."},
			{"do": "bring", "id": "eel", "count": 1, "to": "pebble", "say": "Catch an eel in the river (after dark) and bring it to Pebble", "thanks": "We did it! Best anglers in the valley. Both of us!"},
		],
		"reward": {"coins": 300, "items": {"bottleship": 1}}},
	"maple": {"title": "Where the Bees Go", "hearts": 1,
		"intro": ["My bees fly off over the hill every morning. I think they visit your garden!", "Would you bring me some of what they find there?"],
		"steps": [
			{"do": "bring", "id": "sunpuff", "count": 3, "to": "maple", "say": "Bring Maple 3 sunpuffs", "thanks": "Smell that! Sage will know what it does to the honey."},
			{"do": "talk", "to": "sage", "say": "Ask Sage about sunpuff honey", "thanks": "Sunpuff honey is the sweetest there is. Tell Maple to share some with Juniper."},
			{"do": "deliver", "id": "parcel", "to": "juniper", "say": "Take Maple's jar of sunpuff honey to Juniper", "thanks": "Sunpuff honey! Tomorrow's buns will be famous."},
		],
		"reward": {"coins": 250, "items": {"beehive": 1}}},
}

const SCENES: Dictionary = {
	"bristle": {
		2: {"lines": ["You know, I almost sold this shop once.", "Then a young pair took on the old garden up the hill, and I thought: they'll need seeds."],
			"choices": [["We're glad you stayed.", "Hmph. Me too. Don't tell anyone.", 40], ["What made you want to sell?", "Being the only one awake at dawn, I suppose. Not so lonely now.", 25], ["You'd have got a good price.", "Ha! Spoken like a customer.", 5]]},
		4: {"lines": ["I've written you into my will. The stall by your garden, that is.", "Someone ought to keep it going when I can't."],
			"choices": [["We'll look after it always.", "I know you will. That's why I chose you.", 40], ["Don't talk like that, Bristle.", "Ha! I'm not going anywhere yet. Just planning.", 25], ["Can we paint it purple?", "Over my dead... ah. Fair point.", 10]]},
	},
	"juniper": {
		2: {"lines": ["I get up at four every morning to bake.", "Sometimes I wonder if anyone notices the bread's still warm."],
			"choices": [["It's the best part of my day.", "Oh! Really? That makes it all worth it.", 40], ["Four? Why so early?", "Bread waits for nobody. But I like the quiet.", 25], ["Could you bake later?", "And let the town wait for its breakfast? Never!", 5]]},
		4: {"lines": ["I've been working on a new loaf. It's shaped like your Heart Tree.", "Would you try the first slice?"],
			"choices": [["I'd be honoured.", "Here, still warm. Tell me honestly!", 40], ["Only if you share it with me.", "Ha! Half each, then.", 30], ["Does it have raisins?", "...It does now.", 10]]},
	},
	"flint": {
		2: {"lines": ["People think a forge is all fire and noise.", "Mostly it's waiting. Watching the colour of the steel."],
			"choices": [["That sounds peaceful.", "It is. Not many understand that.", 40], ["What colour is right?", "Straw yellow for a blade. Cherry red to bend. You've a good eye.", 30], ["Sounds hot.", "...It is that.", 5]]},
		4: {"lines": ["I made something. Not for selling.", "A little iron flower, for your home. It'll never wilt."],
			"choices": [["It's beautiful, Flint.", "Hm. Took me eleven tries. Don't tell anyone.", 40], ["You made this for us?", "Who else would I make flowers for?", 30], ["Can it be watered?", "...Please don't water it.", 10]]},
	},
	"marlow": {
		2: {"lines": ["I talk to the fish, you know.", "Not out loud. Mostly."],
			"choices": [["What do they say?", "Mostly 'no thank you'. The trout are rude.", 40], ["I talk to my plants too.", "Ha! Then we're both mad. Good.", 35], ["That's a bit odd.", "Odd keeps you fed in this trade.", 5]]},
		4: {"lines": ["My old boat. I'm too creaky to row her now.", "Would you two take her out sometimes? She hates sitting still."],
			"choices": [["We'd love to.", "Then she's yours whenever you like. Mind the falls.", 40], ["Only if you come too.", "...Aye, alright. One last voyage.", 35], ["Does she leak?", "Only a little. Bring a cup.", 10]]},
	},
	"birch": {
		2: {"lines": ["Every house in town has a little mark of mine on it.", "A leaf, carved somewhere nobody looks."],
			"choices": [["Is there one on our home?", "Under the step. Go and look sometime.", 40], ["That's lovely.", "A builder ought to sign their work. Quietly.", 30], ["Isn't that vandalism?", "It's art! Gnawed art.", 5]]},
		4: {"lines": ["I'm building myself a little lodge, down by the river.", "Would you help me choose where the window goes?"],
			"choices": [["Facing the sunrise.", "Facing the sunrise. Yes. That's the one.", 40], ["Facing the town.", "So I can see my friends. Good thinking.", 30], ["No windows. Cosier.", "...You're thinking of a burrow.", 10]]},
	},
	"sage": {
		2: {"lines": ["Do you ever just lie in the grass and listen?", "The valley is always talking, if you're quiet."],
			"choices": [["Every evening.", "Then you already know. I knew I liked you.", 40], ["What does it say?", "That it's glad you're here. Truly.", 30], ["I'm usually too busy.", "Then make time. Doctor's orders.", 10]]},
		4: {"lines": ["I've grown a herb nobody's named yet.", "I'd like to name it after you two."],
			"choices": [["We'd be so honoured.", "Then it's settled. It'll grow by the lookout.", 40], ["Name it after the valley.", "Hm, humble too. Fine: 'Valley Friend'.", 35], ["Does it taste nice?", "Terrible! But it smells wonderful.", 15]]},
	},
	"quill": {
		2: {"lines": ["Hoo. Do you know why I keep the museum open so late?", "In case someone brings something nobody has ever seen."],
			"choices": [["We'll find you something.", "Hoo! I believe you will.", 40], ["What's the rarest thing here?", "The first donation. A pebble, from a child. Priceless.", 35], ["Owls like the night anyway.", "...That may also be a factor.", 15]]},
		4: {"lines": ["I'd like to add a case to the museum.", "'The Gardeners', with your names on it. If you'll allow it."],
			"choices": [["Yes, of course!", "Splendid! I'll find a good spot by the window.", 40], ["Put our Heart Tree in it.", "Hoo, a branch of it, then. Perfect.", 35], ["Will there be a photo?", "A portrait. In oils. Hold very still.", 15]]},
	},
	"clementine": {
		2: {"lines": ["Being mayor is mostly listening.", "Sometimes I wish someone would ask me how I am."],
			"choices": [["How are you, Clementine?", "...Oh! Happier now, actually. Thank you.", 40], ["You do a wonderful job.", "Kind of you. I try.", 25], ["Can I complain about the paths?", "...Of course you can. Go on.", 5]]},
		4: {"lines": ["The town voted. We'd like to give you both the key to the valley.", "It doesn't open anything. It's just a lovely key."],
			"choices": [["We'll treasure it.", "Hang it by your door. Everyone will know you belong here.", 40], ["The town did all this?", "You made a whole town happier. Of course we did.", 35], ["It doesn't open anything?", "It opens hearts! ...And possibly the town hall's back door.", 15]]},
	},
	"rosie": {
		2: {"lines": ["The inn was my gran's. I nearly closed it when she passed.", "Then I thought: where would everyone go when it rains?"],
			"choices": [["Here, always.", "Then the door stays open. Always.", 40], ["She'd be proud of you.", "...You think so? Thank you, love.", 35], ["Somewhere drier?", "Cheeky! Pull up a stool.", 10]]},
		4: {"lines": ["I've named a dish after you two. 'The Gardeners' Plate'.", "Most popular thing on the menu!"],
			"choices": [["What's in it?", "Everything you've ever brought me. It's enormous.", 40], ["We're famous!", "Round here, you are!", 30], ["Do we get it free?", "...Once a week. Don't tell Bristle.", 20]]},
	},
	"thistle": {
		2: {"lines": ["When I was young, I planted a seed in your garden and forgot where.", "Every spring I wonder if it ever came up."],
			"choices": [["We'll look for it.", "Would you? An old man's silly hope.", 40], ["Maybe it's the Heart Tree.", "...My word. Wouldn't that be something.", 40], ["Probably a weed by now.", "Ha! Probably. Weeds are plants too.", 10]]},
		4: {"lines": ["I'm too old to dig, but I'd like to leave something to your garden.", "My trowel. Seventy years old, and still sharp."],
			"choices": [["We'll use it every day.", "Good. A tool wants to be used.", 40], ["Will you come and visit it?", "Every week, if my knees let me.", 35], ["Can we hang it on the wall?", "Don't you dare! Dig with it.", 10]]},
	},
	"pebble": {
		2: {"lines": ["Everybody thinks I'm too little to fish the river.", "But I'm not! Am I?"],
			"choices": [["You're the best angler I know.", "Really?! I'm telling everyone you said that!", 40], ["Show me how you do it.", "Okay! First you have to be really, really patient...", 35], ["Maybe start with the pond.", "Hmph. The pond is boring.", 5]]},
		4: {"lines": ["I made you a lure. It's my best one.", "It's got a feather from the lookout and a bead from Rosie."],
			"choices": [["We'll catch something huge with it.", "The biggest! Promise you'll show me!", 40], ["You made this for us?", "You're my best friends. Obviously!", 35], ["It's very... sparkly.", "Fish LOVE sparkly.", 15]]},
	},
	"maple": {
		2: {"lines": ["Bees know when someone's kind, you know.", "They never sting you. I noticed."],
			"choices": [["We love your bees.", "They love you back. They've told me.", 40], ["How do they know?", "They listen to hearts. Very softly.", 35], ["Lucky me.", "Not luck. Kindness.", 15]]},
		4: {"lines": ["I'm starting a new hive, and I want to name the queen.", "Would you choose her name?"],
			"choices": [["Queen Bloom.", "Queen Bloom! She already looks happier.", 40], ["Name her after you.", "Oh, how sweet. Queen Maple the Second, then.", 35], ["Buzz Aldrin.", "...She's a queen. But fine. Buzz.", 20]]},
	},
}

## Who loses what, for "find" errands.
const LOST: Dictionary = {"bristle": "keyring", "rosie": "locket", "maple": "scarf", "pebble": "toyboat"}

## Errands posted on the town hall's board.
const ERRAND_DELIVER_COINS := 60
const ERRAND_FIND_COINS := 90
const ERRAND_FRIENDSHIP := 30
const ERRANDS_POSTED := 2  # open errands on the board at a time

## The town hall's projects board: things given towards each; once all are
## in, `props` appear in town (town tiles, prop kinds) and everyone gets
## `coins` and some friendship with the whole town.
const PROJECTS: Dictionary = {
	"lamplight": {"name": "Lamplight", "text": "More lamps along the paths, lit every evening.",
		"needs": {"copper": 6, "wood": 10, "honey": 2}, "coins": 300,
		"props": {Vector2i(12, 12): "lamp", Vector2i(32, 18): "lamp", Vector2i(26, 25): "lamp", Vector2i(29, 33): "lamp", Vector2i(44, 24): "lamp"}},
	"flowerbeds": {"name": "Flower Beds", "text": "Flower boxes by the doors and along the main path.",
		"needs": {"wood": 8, "fiber": 10, "sunpuff": 5, "moonbell": 3}, "coins": 250,
		"props": {Vector2i(4, 17): "planter", Vector2i(10, 22): "planter", Vector2i(30, 25): "planter", Vector2i(16, 25): "planter"}},
	"bandstand": {"name": "Bandstand", "text": "A bandstand in the park, for music on summer evenings.",
		"needs": {"wood": 20, "stone": 10, "copper": 4}, "coins": 400,
		"props": {Vector2i(12, 25): "bandstand"}},
	"benches": {"name": "Riverside Benches", "text": "Benches along the river, for watching the water.",
		"needs": {"wood": 12, "stone": 6}, "coins": 200,
		"props": {Vector2i(34, 25): "bench", Vector2i(43, 22): "bench"}},
}
const PROJECT_FRIENDSHIP := 20
