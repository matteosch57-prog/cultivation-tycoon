# The island opens with the realms (owner 2026-10-22)

Owner: "Way too fast still. Tycoons are interesting because you get a bigger, more beautiful island
slowly; if you get it all in 5 min no one will want to pay. Maybe unlock more with the realms? Not
satisfying after 10 min."

## Research (web, 2026-10-22)
- A first full base should take about 30-60 min, with a fast hook first: one successful tycoon
  unlocks ~50 of ~200 buttons in the first 10-20 min, then slows (DevForum "Is this a good tycoon
  progress rate?" https://devforum.roblox.com/t/is-this-a-good-tycoon-progress-rate/2225354;
  creation.dev https://www.creation.dev/learn/how-to-make-tycoon-roblox). Tycoons finished in 5-15 min
  were told to add depth (https://devforum.roblox.com/t/tycoon-game-feedback/2838875,
  https://devforum.roblox.com/t/feedback-on-tycoon-game/2947343).
- A prestige should open new content, not only a multiplier: Build Your Backrooms keeps the build and
  each rebirth opens room types and biomes (https://allthings.how/build-your-backrooms-how-to-rebirth-and-every-rebirth-unlock/);
  Pet Simulator 99 gates worlds by rebirth count (https://progameguides.com/roblox/all-areas-in-pet-simulator-99-roblox/).
  Egg, Inc. players call "rebuild the same farm" a chore.
- Slow growth is what speed-ups sell: Grow a Garden's plot expansions are a money plus timer gate with a
  Robux timer skip (https://beebom.com/how-to-expand-plot-in-grow-a-garden-roblox/amp/).

## Today (sim, regular player)
The whole island (55 pads) stands at 9.6 min, all of it in realm 1; every later realm rebuilds the same.

## Options (tools/sim_game.py levers REALM_OF, BT_S, KEEP_ON_BT; script _local/cmp_land2.py, 2 runs, 3 weeks)
| | built in 10 min | realm 2 | whole island first | life 10 | life 20 |
|---|---|---|---|---|---|
| today (regular) | 55 | 9 min | 9 min | day 7 | day 20 |
| **A** opens over 4 realms, rebuilt each realm, breakthrough = 90 s of income | 16 | 5 min | 75 min | day 6 | day 21 |
| **B** opens over 4 realms, buildings kept through a breakthrough | 16 | 5 min | 38 min | day 2 | day 3 |
| **C** today's island, the 20 s price floor in life 1 too | 31 | 15 min | 14 min | day 7 | day 20 |
| A, casual player | 16 | 5 min | 86 min | day 17 | - |

- A: realm 1 = 16 pads (home island, first bridges, Main Hall 1-2, pill furnace, Disciple Hall, qi
  orbs, so the first-pill and first-orb tutorials still come in minute 1-5), realm 2 +14 (Expand the
  Peak I, training), realm 3 +11 (Expand II, koi, tea, springs), realm 4 the Summit +14. The
  breakthrough costs 90 s of the income the realm ends on (with fewer pads the old fixed price left
  minutes of waiting with nothing to buy). Mock: `docs/art/mocks/realm_land.png`.
- B is the Build Your Backrooms pattern but our income compounds (x3 per realm on every building
  kept), so lives fall to 5-10 min and the long game ends by day 3: it needs a full rebalance.
- C keeps the 5-minute island, only slower.

## Built (D48), simmed on the branch (`_local/cmp_island.py`, 2 runs, 3 weeks)
| | 10 min: built | realm 2 | whole island first | life 10 | life 20 | buy wait (median) |
|---|---|---|---|---|---|---|
| casual | 16 | 5.2 min | 86 min | day 17 | - | 10 s |
| regular | 16 | 4.8 min | 75 min | day 6 | day 21 | 10 s |
| hooked | 16 | 4.8 min | 77 min | day 3 | day 8 | 10 s |
| regular + 2x / VIP / orbs passes | 18 | 3.0 min | 47 min | day 4 | day 13 | 5 s |

Prices are measured against the income without the paid passes (Main `priceRate`), so a 2x pass now
halves every wait (before, the D44 floor rose with it and ate the pass). A first try that also left
the disciples out made lives 4x faster (life 20 on day 5): the disciples stay in.
