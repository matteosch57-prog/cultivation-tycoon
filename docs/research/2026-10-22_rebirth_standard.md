# Rebirth like other Roblox games (2026-10-22)

Evidence and proposal file (write once). Owner: "full study of our reincarnation system, let's just do
like other games. Don't reinvent the wheel." Nothing here is built. Mocks: `docs/art/mocks/rebirth_A/B/C.jpg`
(`rebirth.html`). Every number below is a placeholder: the Economy sim sets them.

## 1. What we have today (code, integration 48dc119)
- Gate: realm `REINC_REALM` (2) AND one realm deeper than every life before (`reincarnate`, Main.server).
- Lands at half the soul peak, that realm fully built (D40, D56). Disciples kept (D44).
- Power: Past Lives = `PAST_LIVES_MULT` (2.5) ^ (soulPeak - 1). Karma only for a new record depth.
- `tools/sim_game.py --kind regular --days 30`: every life ends exactly one realm deeper than the last
  (life N ends at realm N + 1), lives grow 5 min -> 1.8 h by life 14, Past Lives x372,529 by then.
- So "lives" is just depth, a reset is never a choice, and nothing in it matches a game players know.
  The audit blocker (a free repeat from landing ON the gate) came from the custom half-landing.

## 2. What successful Roblox games do (sources: research pass 2026-10-22, guide sites; Fandom blocked fetches)
| Game | Trigger / cost | Resets | Kept | Reward | Gates |
|---|---|---|---|---|---|
| Pet Simulator 99 | reach area 25 / 50 / 75 ... (9 rebirths) at a shrine | coins, areas | pets, unlocks | +% pet power + a FEATURE each (R1 teleport, R2 auto hatch + clans, R4 world 2) | worlds |
| Muscle Legends | 10k strength, +5k each (linear) | stats | pets, gyms, gems | +5% per rebirth, additive | gyms by count |
| Clicker Simulator | 750 clicks, rising; up to x10 at once | clicks | pets, islands | click mult + gems | bigger rebirth buttons per island |
| Tap Simulator | buttons 1 / 5 / 25 / 125 / 625 rebirths | coins | pets, islands | gems + tap mult | bigger buttons per zone |
| Arm Wrestle Sim | 25 wins first | strength | pets | % bonus + tokens; 38 named ranks | Super Rebirth layer (tokens -> slots) |
| Sell Lemons (tycoon) | base value | cash, base | Investors (+1% each) | Investors; Remote Buy / Manage bought with them | Evolve x42, Ascend x7.77 layers |
| Grow a Garden | 1T + mutated fruits | sheckles | pets, seeds | 10 coins -> slots / capacity shop | - |
| Miner's Haven (tycoon) | huge cash, rising | base, cash | lives, Reborn items | an exclusive item per life | items by life count |
| Survive LAVA for Brainrots | speed threshold (12 rebirths) | speed | cash, brainrots | +0.5x cash each (x1.5 -> x7) | - ; Robux skip 44-67 R$ |
| Tank vs Train / +1 Muscle Evo | level threshold | level, power | tanks, titles | x(N+1) power, raised level cap | worlds at R2 / R3; Robux skip |
URLs: holdtoreset.com (PS99), driffle.com + earnaldo.com (Muscle Legends), allthings.how (Clicker Sim,
Sell Lemons, Survive LAVA, Muscle Evo, Tank vs Train), tapsimulator.net/rebirth, mobilematters.gg +
itemlevel.net (Arm Wrestle), beebom.com (Grow a Garden), miners-haven fandom (snippet only).
DevForum: compounding costs explode (t/1047686, t/2670322); use a table or linear / triangular costs
(t/1943788); the server decides, cost derived from the saved count (t/2046513).

**The shared pattern:** (1) a cheap first rebirth, then a gently rising need, from a table; (2) the
reward is a small readable number per rebirth ("x3"), not a formula of earnings; (3) the count unlocks
things (zones, features, slots); (4) collectibles (pets = our disciples) are always kept; (5) one Rebirth
button and a menu that shows the need, the gain and what resets, with one confirm; (6) money sits on the
loop: Auto Rebirth pass (150 to 499 R$), Robux skip, 2x passes stack. Idle-game cube-root currencies
(Cookie Clicker, AdCap) are the PC way, not the Roblox way.

## 3. Three options (mocks A / B / C)
- **A. Rebirth (sim style; Muscle Legends, Survive LAVA, Tank vs Train).** Need: reach the realm a
  table names for your next rebirth (rises slowly). Every rebirth: back to realm 1 built (D56), +0.5x
  Qi (x1.5, x2, x2.5 ... shown as one number), a fixed karma amount for the Karma Shop (Arm Wrestle's
  tokens). Rebirths 5, 10, 15 ... unlock something (an islet, an aura, a feature). Count over the head
  and on the board. Endless; landing (realm 1) is always below the need, so no free repeat. Optional
  products: Auto Rebirth pass, Robux skip.
- **B. New Life (tycoon style; Sell Lemons, Miner's Haven).** Need: the whole island built. Pays karma
  from all qi spent this life (+1% Qi each, forever) and one exclusive building per life. Most "tycoon",
  but the first rebirth comes late (against D37's 5 to 10 min hook).
- **C. Rebirth Shrine (Pet Simulator 99).** A short named list (~10), each at a fixed realm, each a
  bundle: +Qi% and one new feature (Heavenly Hands, an islet, auto recruit, a seat ...). Calm and
  ceremonial, but finite: endless play needs a second layer later.

**Recommended: A**, with C's idea folded into its milestones (PS99 and Muscle Legends both gate
features by count). It is the most common pattern, endless, repeatable without the record rule, and
the Rebirth screen shrinks to: count, x -> x, need, karma, button.

## 4. What A changes in code (once picked)
- `reincarnate`: gate = `Config.rebirthNeed(lives)` (a table), lands at realm 1 built; drop
  `REINC_LAND_SHARE` and the soulPeak gate. Power = `1 + REBIRTH_STEP x rebirths` replaces
  `pastLivesMult`; karma = a fixed amount per rebirth (+ milestone bonus), not record-only.
- Saves: keep `lives`; old saves map soulPeak to a starting count (migration rule set with Economy).
- Kept as they are: disciples, Karma Shop, skins by lives, Reborn badge, Ranks, Telemetry `Reincarnate`.
- Risk for Economy: realm costs are x10 per realm late and the multiplier is additive, so the need
  table must rise slowly or deeper realms stop; Economy's sim sets the table and the step.
