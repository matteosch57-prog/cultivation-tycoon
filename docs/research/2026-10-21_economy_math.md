# Economy math: the whole climb, realms 1 to 12 (2026-10-21)

Evidence file (write once). Numbers below are outputs of `python tools/sim_economy.py` on branch
`economy`; the live values stay in `Config.luau`. Inputs include the Celestial and Dao Ancestor
rarities (branch cultivators) and the Shop passes (branch shop: 2x qi on live and offline income,
VIP +1 slot, auto orbs).

## 0. In plain words
- **The first hour is good and stays as it is.** First breakthrough at about 10 minutes, then a
  quick realm 2 that shows off what the disciples do.
- **The late game hit a wall.** Recruits stopped mattering after realm 1: each one cost 50% more than
  the last, forever, on top of the x8 per realm, so by realm 2 a roll cost as much as a building and
  players stopped. Disciples froze, and from then on every realm took about 2.4x longer than the one
  before: realm 9 took 6 to 10 hours of play, realm 10 a whole day of play, and online you spent 99%
  of the time with nothing to buy (longest wait up to 4 hours). The two new rare disciples were
  almost never seen (8 to 16% of players ever rolled either one in a month).
- **The fix on this branch (two numbers and one rule):**
  1. The +50% recruit price restarts at each breakthrough. Every realm opens with cheap rolls again,
     so recruiting stays a thing to do in every realm and the rare disciples stay a chase (59 to 83%
     roll one within a month).
  2. Costs grow x8 per realm up to realm 5 (the five named realms), then x4.5. A late realm now takes
     about 1.3x the one before instead of 2.4x.
- **Result:** realms grow steadily from about 10 minutes to 2 to 5 hours of play by realm 12; a
  regular player (two 30 minute sessions a day) ends the five named realms on day 2 and reaches
  realm 10 in about a week instead of a month. The longest wait inside a late realm is under 10
  minutes instead of hours: you come back for a long goal, not to stare at a counter.
- **Passes:** a player with all three passes goes about 1.5 to 2x faster. Nothing breaks, so 2x on
  offline qi is fine.

## 1. What healthy frustration means here (targets)
No first-party benchmark for rebirth length exists; these are the anchors used.
- Roblox Creator Docs: get to the fun in 5 minutes; D7 needs short and long goals.
  https://create.roblox.com/docs/production/analytics/retention
- 2025 Roblox Benchmark Report (third party): D1 roughly doubles once sessions pass ~25 minutes
  (already in `2026-10-21_first_session_onboarding.md`).
- Idle-game design (Anthony Pecorella, "The Math of Idle Games", parts I and III): costs grow
  exponentially and income polynomially, so progress slows by design; prestige exists to rein the
  slowdown back. https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii
- A developer postmortem: first prestige took 25 to 35 minutes and the author wanted it at 15 to 20.
  Tycoon guides put one rebirth cycle at 20 to 60 minutes (Military Tycoon ~20 to 30 min to its first
  rebirth); a DevForum thread calls more than 30 minutes of play for a single goal too much.
  https://devforum.roblox.com/t/balancing-game-difficulty/1565656 ·
  https://allthings.how/military-tycoon-how-to-rebirth-fast-and-progress-in-roblox/
- Gladiator RNG lesson: the first live batch, not a model, says where players leave; ship the
  measurement with the feature (its R23). The funnel and realm events already exist (TECH Telemetry).

Targets, per realm: realm 1 10 to 15 min (first session); realm 2 a short reward lap; realms 3 to 5 a
day 1 to 2 arc; realm 6+ each a little longer than the last (1.2 to 1.6x), a multi-session goal but
never a wall of days; the longest wait inside a realm stays a few minutes while online, and there is
always a qi sink (recruits) between buildings.

## 2. The model (`tools/sim_economy.py`)
Every qi source in the server: pads, disciples (best `maxDisciples` work), pill, orbs, Spirit Tide
(joins a server at a random point of its cycle), playtime gifts, offline qi capped at `OFFLINE_CAP`,
plus optional passes. Player kinds are a sweep (no real players yet): hooked 3 x 60 min a day,
regular 2 x 30, casual 1 x 20; hooked and regular play like sim_pacing's "active", casual like its
"casual". Median of 6 runs. Cells: play minutes inside that realm, the day it ends; `--waits` adds
w = share of the realm with nothing affordable, L = longest such wait, d = disciple multiplier.

## 3. Before (rules on integration)
| realm | hooked | regular | casual |
|---|---|---|---|
| 1 | 9.4 min, day 1 | 9.4 min, day 1 | 10 min, day 1 |
| 2 | 3.4 | 3.4 | 7.3 |
| 3 | 4.9 | 4.9 | 7.9, day 2 |
| 5 | 27, day 1 | 23, day 1 | 31, day 4 |
| 7 | 108, day 2 | 92, day 4 | 108, day 12 |
| 8 | 260, day 3 (L 49 min) | 165, day 6 | 190, day 22 |
| 9 | 597, day 6 (L 105 min) | 375, day 13 | 440, day 44 |
| 10 | 1426, day 14 (L 253 min) | 888, day 27 | not in 60 days |

Disciple multiplier froze at ~12.6 (hooked) after realm 1: ~120 recruits in the whole month.

## 4. After (this branch: `RECRUIT_GROWTH` per realm, `REALM_COST_LATE` 4.5 from realm 5)
| realm | hooked | regular | casual |
|---|---|---|---|
| 1 | 9.4 min, day 1 | 9.4 min, day 1 | 10 min, day 1 |
| 2 | 6.7 | 6.7 | 8.8 |
| 3 | 12 | 12 | 8.5, day 2 |
| 5 | 41, day 1 | 35, day 2 | 22, day 4 |
| 7 | 79, day 2 | 56, day 4 | 33, day 7 |
| 8 | 98, day 2 (L 4.6 min) | 65, day 5 | 41, day 9 |
| 9 | 129, day 3 (L 5.6 min) | 89, day 6 | 58, day 12 |
| 10 | 173, day 4 (L 8.5 min) | 121, day 8 | 80, day 16 |
| 12 | 322, day 7 | 215, day 14 | 110, day 26 |

Disciples keep growing (d 21 at realm 2 to ~40 at realm 12); ~1,200 recruits a month for a regular.
The realm 1 to 4 table of `sim_pacing.py` moves too: realm 3 at ~19 min and realm 4 at ~33 min for an
active player (was 15 and 22), because recruits now compete with buildings for qi in realms 2 to 4.

## 5. Sweep (why these two levers and not others)
| change (regular, minutes per realm 5 / 8 / 10, day realm 10 ends) | realm 5 | realm 8 | realm 10 | day |
|---|---|---|---|---|
| today | 23 | 165 | 888 | 27 |
| cost x5 every realm | 6 | 16 | 37 | 3 |
| cost x6 every realm | 8 | 42 | 92 | 5 |
| cost x4.5 from realm 5 only | 18 | 45 | 90 | 6 |
| recruit price restarts each realm only | 36 | 270 | 1455 | 45 |
| recruit price x3 per realm instead of x8, restarting each realm | 239 | - | - | - |
| **both levers (this branch)** | 35 | 65 | 121 | 8 |

- Cheaper realms alone rush the named realms (x5 everywhere: the whole climb in one evening).
- The recruit reset alone gives every realm a sink but the 2.4x wall stays.
- Cheap recruits (x3 per realm) are a trap: a roll always cheaper than a building eats the qi meant
  for buildings and realms slow to a crawl. Recruit price must keep the realm cost step.

## 6. Shop (branch shop) against this economy
- With 2x + VIP + auto orbs, regular: realm 5 day 2, realm 10 day 5 (no pass: day 8). A 1.5 to 2x
  speed-up, no wall skipped, so 2x on offline qi is fine.
- Qi packs are "N of current base income". A late realm is 1.5 to 5 hours of play, so the 6 h pack is
  about one to two late realms, the 1 h pack about half of one, and the 10 min pack a building or two.
  In realm 1 the 10 min pack is a whole realm (realm 1 is ~10 min). Fine for a paid skip; the owner
  prices them.

## 7. What to measure on the first live batch
Already logged: funnel steps with minutes played, realm reached, recruits, sources and sinks. Read
them against section 4: minutes per realm by realm (median), the share of players whose last session
ends inside a realm vs right after a breakthrough, and recruits per realm. If players leave in realm
6 to 8 rather than at 3 to 5, the late step (4.5) is still too steep.

## 8. Owner direction and the shipped curve (D25)
The owner's call on section 4: "first realms should be fast, then it should get hard. After realm 10
we will offer reincarnation." So realm 10 is the long goal of one life, and the x4.5 taper above was
replaced by costs x5 per realm through realm 5, then x10 (recruit reset kept).

| realm | hooked | regular | casual |
|---|---|---|---|
| 1 | 9.4 min, day 1 | 9.4 min, day 1 | 10 min, day 1 |
| 2 | 5.7 | 5.7 | 8.2 |
| 3 | 6.0 | 6.0 | 8.4, day 2 |
| 4 | 8.2 | 7.6 | 8.5 |
| 5 | 11, day 1 | 9.0, day 1 | 9.0, day 3 |
| 6 | 24 | 25, day 2 | 17, day 4 |
| 7 | 60 | 54 | 31, day 5 |
| 8 | 149, day 2 (L 9 min) | 104, day 4 | 54, day 8 |
| 9 | 395, day 4 (L 16 min) | 270, day 9 | 135, day 15 |
| 10 | 1218, day 11 (L 50 min) | 744, day 21 (L 30 min) | 380, day 34 |

- The five named realms all fall in the first ~45 minutes of play (day 1 for most).
- Realm 6 to 10 each take ~2 to 3x the last: the hard part. Realm 10 is a three week goal for a
  regular player, which is where the D7 to D30 "long goal" sits (Roblox retention doc).
- Online waits grow late (longest 30 to 50 min in realm 10): the climb leans on offline qi and
  return visits there. If live data shows players leaving in realm 8 to 9, lower `REALM_COST_LATE`
  (x8 gave realm 10 at day 10 for a regular player in the sweep).
- With 2x + VIP + auto orbs: realms 2 to 5 at 5 to 7 min, realm 10 at day 11 (regular). The passes
  halve the hard part; they skip nothing.
- Recruits stay alive: ~1,200 rolls a month (regular), 83% roll a Celestial or Dao Ancestor.
- sim_pacing (active): realm 2 at 11 min, realm 3 at 17, realm 4 at 24 of total play.

