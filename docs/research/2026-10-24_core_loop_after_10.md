# Core loop after minute 10 (2026-10-24)

Owner: "a game where you just walk to 10 green buttons all the time won't be interesting after 10
minutes." Qi boost stays as it is.

## What the sim says
`lune run tools/qisim/options.luau <profile> 7 3 <base|auto|missions|both>` (overlays on the real qisim).
Every breakthrough wipes the island (`s.data.owned = {}`) and the realm rebuilds 16 / 31 / 43 / 63 pads
(D48). Between minute 10 and 60 the sim player buys ~350 to 420 pads (one every 7 to 8 s), about half
of the time walking (until Heavenly Hands turns it into tapping). Only ~25 of them are pads never built
before.

| 7 days, median of 3 seeds | base | auto build | missions | both |
|---|---|---|---|---|
| pads pressed, min 10-60 (engaged) | 386 | 25 | 415 | 25 |
| rebirth 10 (engaged 3 x 15) | 4.8 h | 3.4 h | 4.8 h | 3.4 h |
| idle (engaged / hooked) | 1% / 12% | 10% / 28% | 1% / 10% | 8% / 26% |
| mission qi (45 s income per 180 s) | - | - | 3% | 6% |

sim_check.py with walk 0 (auto build stand-in): deepest realm on day 7 16 -> 17 (regular).

## What top games layer on "buy the next pad"
- Auto Build / Auto Purchase passes: Mega Mansion Tycoon Auto Build, 999 Robux, "Automatically build
  your house as you can afford each purchase" (https://www.rolimons.com/gamepass/843923528); Farm
  Tycoon 2 Auto Purchase ("Hands-Free Tycoon Building", https://www.rolimons.com/gamepass/1168512977);
  Ice Factory Tycoon Auto Buy Button 199; Battle Gods Simulator Auto Buy 399.
- Quests with a rank path: Pet Simulator 99 ranks, one quest from each group at a time, stars fill
  a reward path (rank 1 = 13 stars, rank 5 = 63), rewards are boosts, currency bags, slots
  (https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)). Bee Swarm Simulator NPC quest
  lines with several objectives each and rising rewards. Anime Fighting Simulator: 20 NPC quests that
  unlock powers.
- AppQuantum 2025: "The core issue with traditional tycoons is monotony"; DevForum: players stay
  when they have something to do, quests and missions.

## Offered (mock https://claude.ai/artifact/SDkN2vLSirLyygxEwJ9LNd)
A Auto Build (free, pads built before in any life), B Sect Missions (PS99 ranks), C both
(recommended). Not offered: upgrades on built pads (more walks), active skills, merging.
Already have: timed events (Spirit Tide, altar), gifts, collection (disciples, index).
