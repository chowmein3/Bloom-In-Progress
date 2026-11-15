# Bloom In Progress — design notes

A whimsical pixel-art co-op game for couples about raising a shared garden over a long
time. The genre and general farming mechanics are borrowed from cozy farm
sims; the name, plants, characters and art are our own.

## Pillars
1. **Nurture, not farm.** Plants are companions. Harvesting is optional.
2. **Together.** One shared garden; anyone can care for any plant.
3. **Slow and gentle.** Neglect sets you back, it never wipes you out.

## Core loop (built in Milestone 1)
- A day runs 6am to 2am. Growth happens overnight, when you sleep in the tent.
- Soil: grass -> tilled (hoe) -> planted (seed) -> watered. Soil dries every
  morning. Empty tilled soil sometimes turns back to grass. Rain waters everything.
- A plant grows one day for each day it was watered. Unwatered = paused.
- **Mood** (0-100, starts at 50): +4 watered, +8 petted, -12 left thirsty.
  Mood 80+ on a mature plant makes it **radiant**: special colour, sparkles,
  extra seeds, and an occasional growth spurt while growing.
- Each player can pet each plant once a day. Plants remember who cared for
  them (`caretakers`), ready for co-op bonuses.
- Seasons are 28 days. Out of season, a plant goes **dormant** (asleep, no
  growth, no mood loss). It does not die.
- Energy (100/day) limits how much one player can do. Staying up to 2am means
  waking with half energy.
- Seeds and produce are shared by everyone in the garden. There is no money.

## Plants so far
| Plant | Seasons | Days to mature | Notes |
|---|---|---|---|
| Sunpuff | spring, summer | 5 | single harvest |
| Moonbell | spring, fall | 7 | regrows every 3 days |
| Gigglecap | fall | 6 | mushroom |
| Frostwhisker | winter | 8 | |

## Co-op (built in Milestone 2)
- Two players. One hosts and owns the garden and its save; the other joins by
  address. Players have stable slots (host 1, guest 2) so plants remember them.
- The host is in charge: a guest's actions are requests the host checks and
  applies, then every change is mirrored back. The host also runs the clock.
- A late joiner receives the whole garden.
- The day ends when both players are in the tent. At the 2am curfew, anyone
  not in bed wakes with half energy.
- **Duet:** if two different players pet the same plant on one day it gets +6
  mood on top of the normal +8.
- Seeds, produce and the garden are shared; energy is per player.

## Next
- **Easier connecting:** a relay or Steam networking so joining over the
  internet needs no router setup.
- **More co-op play:** plants that only reach a rare form with two carers,
  seeing which tool your partner is using, emotes.
- **Milestone 3, whimsy:** real pixel art, more species, the Heart Tree
  (one shared long-term plant), garden journal, music, light/shade needs.
