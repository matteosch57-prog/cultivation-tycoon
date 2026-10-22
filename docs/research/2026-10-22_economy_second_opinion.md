# Economy: second opinion (2026-10-22)

Evidence file (write once). An independent check of the whole qi economy on `integration` 042b15c,
read from `Config.luau` and `src/server/*`, with a new sim written from the code (`tools/sim_check.py`)
instead of trusting `tools/sim_game.py`. Player kinds: casual 1 x 20 min/day, regular 2 x 30 min,
hooked 3 x 60 min; median of 2 to 3 seeds; x10 recruit presses. Nothing here is built.

## Priority 1: the rebirth needs only qi, and the chip is gold almost all the time
`reincarnate` (Main.server) checks `qi >= rebirthPrice(rebirths)` and nothing else. The price rises
+50,000 a rebirth while the boost rises +0.5 x income a rebirth, so the wait for the next price
settles at 100,000 / (income without the boost) seconds and never grows. At realm 1 built with
ordinary disciples that is about 20 to 90 s. The HUD chip turns gold and wobbles (and the red dot
lights) as soon as the price is held (`Hud.client` rebirthChip, `Dots.luau`).

| regular, current Config | day 1 | day 7 | day 30 |
|---|---|---|---|
| presses Rebirth when the chip is gold | realm 2, 18 rebirths | realm 2, 676 rebirths (x339) | realm 2, 3,346 rebirths (x1,674) |
| min-maxer: spam until the gates open, then climb | realm 2 | realm 13 | realm 15 |
| rebirths only when a gate blocks (`sim_game.py`'s rule) | realm 4 | realm 11 | realm 12 to 14 |

- A child who obeys the gold chip is stuck at realms 1 to 4 forever (a trap, not a reward).
- A min-maxer skips the whole REBIRTH_REALMS table on day 1 (realm 11 on day 2 against realm 6).
- Robux Primordial (x101): a rebirth every ~45 s, 78 on day 1. Guard allows one a second.
- `sim_game.py` only models the third row, so its numbers describe a player the HUD does not make.

**Change:** the rebirth opens only when the next breakthrough waits for rebirths (all required pads
built and `rebirths < Config.rebirthsFor(realm + 1)`), the same check the breakthrough pad already
makes. That is the research's own option A ("reach the realm a table names") and Pet Simulator 99's
shrine. The chip shows gold only then. The qi price can stay (it barely binds, sim_game agrees).

## Priority 2: late realms are a wall, and the gate table ends
Costs x10 a realm from realm 5, income x3, rebirth boost additive: each realm past ~12 takes 3.3x the
last. The table stops at realm 17 (20 rebirths), so past it a rebirth has no reason to exist.

| current Config, gated rule | casual | regular | hooked |
|---|---|---|---|
| deepest realm day 7 / 30 / 60 | 8 / 12 / 14 | 11 / 14 / 14 | 12 / 14 / 16 |
| last lives | 6.3 h at R14 | 7 to 9 h each, all at R14, days 21 to 60 | 82 h at R16 |

A regular player finishes their last new realm on day 21 and replays realm 14 for 40 days.

**Change (simmed, gated rule):** `REALM_COST_LATE = 5` (one x5 ratio for every realm) and an endless
gate rule that continues the table's own steps (every odd realm, +ceil(i/2) rebirths: 19 = 25,
21 = 30, 23 = 36, 25 = 42 ...), e.g. `Config.rebirthsFor(realm)` from a formula instead of the table.

| proposal | casual | regular | hooked |
|---|---|---|---|
| deepest realm day 7 / 30 / 60 | 8 / 18 / 22 | 16 / 24 / 26 | 22 / 27 / 30 |
| life length | 14 min first, ~20 to 40 min to day 30, 80 min day 60 | 20 to 40 min to day 10, 1 h day 14, 4 h day 60 | 5 h by day 30, 19 h by day 60 |

First session unchanged (realm 2 at ~5 min, first rebirth at 10 to 14 min). Lives rise gently, like
the research's "cheap first rebirth, then a gently rising need". Tried and rejected: x8 (lives double
every 2 realms from R14), x6 (2 h at R18, 9 h at R22 for a regular), x4 (lives flat at 20 to 35 min
for two months: nothing gets harder).

## Priority 3: smaller fixes
- **Daily Blessing gives a free Immortal (day 2) and Celestial (day 7)**: x5 and x10 qi each, the same
  disciples the Shop sells for Robux. Disciples reach x18 on day 1 and x50 to x120 by day 3 in every
  run. Suggest Elder on day 2 and Immortal on day 7, so the Shop's Immortal / Celestial stay the
  first real upgrade (money call: yours).
- **Offline is 63 to 80% of all qi** (regular / casual), because the 4 h cap (+2 h per Deep
  Meditation) at 0.5 is worth 2 to 4 h of play per return against 30 min sessions. It does not move
  the pace (the floor and gates bind): `OFFLINE_CAP = 7200` and Meditation +1 h left every realm day
  within one day. Benchmark: Muscle Legends, PS99 and most tycoons pay nothing offline. Optional.
- **Harmony is inside `priceRate`**, so the floor and breakthrough rise with it and eat most of its
  +20%. Leave it out like the rebirth boost if decor should feel worth it.
- **Old saves:** no conversion runs. `soulPeak` is ignored, Past Lives x2.5 per realm becomes
  1 + 0.5 x (lives - 1) (an old life-6 save goes from x244 to x3.5). Harmless only if no real players
  saved before D63; otherwise map them once.

## What sim_game.py misses or gets wrong
1. Rebirth only when gated; the HUD asks for it whenever the price is held (above).
2. `Config.STREAK` is a table of tables the loader skips: no streak at all, so no free Immortal and
   Celestial (its biggest early disciple source).
3. Not modelled: Shop free gift (300 s/day), Incense Blessing (120 s each way), starter chest (150 qi +
   3 summons), group +10%, Welcome Pouch (+10% and an Elder), Robux disciples, Qi packs.
4. Recruits are x1 presses only; the HUD sells x10 / x50.
5. Stale bits (no effect): docstring still says `BREAKTHROUGH_COST`; `DAO_ORDER` lists removed nodes.
Correct and checked: live rate, offline (x2 and index in, tide / pill / friends out), price floor
from life 2, breakthrough frozen at 90 s of priceRate, orbs on the live rate, daily gift ladder,
index stars, workers unfloored, rebirth landing and karma.

## Everything that moves qi (code)
Sources: live `rate` (buildings x workers x district x realm x3 x disciples x pill x2 x tide x2 x
2x pass x rebirth 1+0.5r x friends +10% each (3) x group +10% x Welcome +10% x Harmony <=+20% x index
+0.25%/star), offline 0.5 x away rate capped 4 h (+2 h a Meditation level), orbs (15 s of live rate
every 20 s, up to 3: +75% live if collected), playtime gifts 120 to 900 s x8 a day, Daily Blessing,
Shop free gift 300 s, Incense Blessing 120 s, altar 300 / 120 / 60 s, Heavenly Gift 200, starter
chest 150, Qi packs 600 / 3,600 / 21,600 s. Disciple sources: recruits, idle chest (1/h away, max 4),
gift and streak summons, index steps (3 per 10 stars), Shop. Sinks: pads (cost x costMult, floor 20 s
of priceRate from life 2), workers (unfloored), recruits (500 x costMult x 1.05^n, restarts each realm
and rebirth), breakthrough 90 s of priceRate, rebirth 100k + 50k a rebirth, and qi wiped by both resets.

## Benchmarks (thin: guide sites only, Fandom blocked)
Muscle Legends: 10k strength first rebirth, +5% each, additive, rebirths are the loop and gyms open by
count (driffle.com). Military Tycoon: first rebirth at $250K, ~20 to 30 min (allthings.how). Mall
Tycoon: rebirth after the whole build (progameguides.com). Roblox / DevForum: 8 min first session, 10%
D1 (research 2026-10-21_tycoon_study). The proposal keeps every life inside the 10 to 40 min band of
these games for the first two weeks.

Rerun: `python tools/sim_check.py --kind regular --policy gated --days 60 --set REALM_COST_LATE=5 --set GATE_EXTEND=1`
(`--policy eager | hybrid`, `--buy Primordial,x2,...`, `--batch 1|10|50`).
