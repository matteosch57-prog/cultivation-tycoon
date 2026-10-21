# Economy and progression

Every number lives in `src/shared/Config.luau`; this file names the keys and explains the shape.

## Qi
- Income per second = (`BASE_RATE` + sum of owned pads' `income`) x `incomeMult(realm)` x disciple bonus
  x 2 while a pill is active. Ticked on the server every second.
- Offline: income keeps flowing while away, capped at `OFFLINE_CAP` seconds.

## Pads (`Config.PADS`)
- A pad opens once `unlock` buildings are owned (any of them) and its `req` pads are owned. This keeps
  3 to 5 pads open at once so players choose (D11).
- Cost x `costMult(realm)`; income x `incomeMult(realm)`. `costMult` steps by `REALM_COST_MULT` per
  realm up to `REALM_COST_LATE_FROM`, then by `REALM_COST_LATE`: the first realms are quick laps, then
  each realm takes ~2 to 3x the last, and realm 10 is the long goal of one life (D25, research
  2026-10-21_economy_math).
- Buying is a server position check every 0.1 s (`checkPads`), not `.Touched` (D10).
- Feature pads carry a `feature` line shown on the price card.

## The Main Hall
`mainhall1..5`: one building at the back centre, each level replaces the last (hut, sect hall, great
hall, palace with wings, gold celestial palace with towers). Only the highest owned level stands.

## Island expansions
`expand1`, `expand2` grow the island through `ISLAND_RADII`; the outer ring holds the variety buildings
(bamboo grove, training ground, bell tower, koi pond, library, moon gate, pagoda). A breakthrough
shrinks the island back.

## Features
- **Recruiting** (Disciple Hall): costs qi (`recruitCost`: `RECRUIT_BASE` x `costMult` x +`RECRUIT_GROWTH`
  per disciple recruited in this realm, `data.realmRecruits`, which a breakthrough resets), rolls `RARITIES`. The best `maxDisciples`
  work; the rest rest until slots open. The roll is never sold for Robux (RULES R8); the Shop sells
  FIXED rarities behind realm gates and per-player limits, priced to their pacing impact (D28,
  MONETIZATION "Disciples for sale" and "Disciple price ladder"). Bought ones are kept in
  `data.boughtDisciples`, are never trimmed from the list, and survive breakthroughs and reincarnation.
- **Disciple slots:** `MAX_DISCIPLES` + one per owned pad in `SLOT_PADS` + `VIP_SLOTS` with the VIP pass.
- **Pill** (Alchemy Furnace): one brewed every `PILL_INTERVAL`; using it doubles qi/s for `PILL_DURATION`.
- **Qi orbs** (Qi Gathering Array): one every `ORB_INTERVAL`, up to `ORB_MAX`; worth `ORB_VALUE` seconds
  of income.

## Sect workers
A hire pad (`Hire_<id>`, PadKind `hire`) stands beside each owned building in `WORKERS` until it has
`WORKER_MAX` workers. The n-th costs `workerCost` (`WORKER_COST[n]` x the building's cost x `costMult`)
and adds `WORKER_BONUS` x that building's income (`data.workers[id]`). A breakthrough or a new life
sends them home with the buildings. The card shows one dot per worker the building takes; hire pads
are not `Pad_` so the HUD goal and the guide trail still lead to buildings. Looks, spots and tools:
`src/server/Workers.luau`; job loops on the client: `WorkerJobs.client.luau` (joints solved by hand,
`Rig.luau`, nothing moves off screen). Why: the peak should look worked and alive (research
2026-10-21_workers, owner picked hire pads and straw hats from mock `docs/art/mocks/workers.html`).

## Spirit Tide (server-wide)
Every peak on a server earns `TIDE_MULT` x for `TIDE_DURATION` s, first `TIDE_FIRST` s after the server
starts, then every `TIDE_INTERVAL` s; a toast warns `TIDE_WARN` s before. Workspace attributes `TideNext`
and `TideUntil` (server time) carry the schedule. Offline qi ignores it. Why: a shared moment worth
staying for (research 2026-10-21_tycoon_study, Grow a Garden weather).

## Playtime gifts
After `GIFT_TIMES[i]` seconds of play in one session a gift button on the HUD's left column can be
claimed (server `ClaimGift`) for `GIFT_VALUE[i]` seconds of income, counted without tide or pill. The
`GiftIn` player attribute is the seconds left (0 = ready, -1 = all claimed this session). Why: pushes a
first session past the ~8 minute benchmark (research 2026-10-21_tycoon_study). The HUD shows the next
tide under the qi counter (owner picked mock A for both, 2026-10-21).

## Pacing
`python tools/sim_pacing.py` replays these rules from Config and prints the minutes to each milestone
for an active, a casual and an idle player (`--set KEY=VALUE` tries a value first, `--trace` lists
every purchase). `python tools/sim_economy.py` plays the whole climb (realms 1 to 12, real days of
sessions with offline qi, tide, gifts, optional passes) and reports minutes and the day per realm;
`--waits` shows how long players stand with nothing to buy, `--passes 2x,vip,orbs` a paying player,
`--bought 9` a Shop disciple; `simulate(..., reinc=dict(...))` plays several lives of reincarnation.
Evidence: `docs/research/2026-10-21_first_session_onboarding.md` (first session) and
`docs/research/2026-10-21_economy_math.md` (the whole climb, passes, Robux disciples, reincarnation).

## Realms and breakthrough
All pads owned -> a gold breakthrough pad (`BREAKTHROUGH_COST` x `costMult`). Breaking through: realm + 1,
owned pads, qi and the pill reset; disciples stay. Names in `REALMS` (10 names, then "Immortal Realm N").
From `REINC_REALM` a player may reincarnate instead: [REINCARNATION](REINCARNATION.md).
