# Reincarnation after realm 10: a design for endless progress (2026-10-21)

Evidence and proposal file (write once). Nothing here is built. Once the owner picks, the decisions
go to DECISIONS.md, the system to `docs/design/REINCARNATION.md`, and the numbers to `Config.luau`.
Pacing numbers come from `tools/sim_economy.py` (branch integration, D24/D25) with one extra lever,
a permanent income multiplier (`--mult`, a local patch, not committed).

## 0. In plain words
- **Two kinds of reset.** A *breakthrough* is a step inside one life: the peak resets, income x3,
  your disciples stay. A *reincarnation* starts a new life at realm 1 once you have reached realm 10.
- **What a new life keeps, in one sentence:** your soul remembers the deepest realm you ever reached,
  and every life after it is faster because of it.
- **Two rewards, for two kinds of players** (your Heavenly RNG players split into "never reset" and
  "reset every few minutes"; both must feel good here):
  1. **Past Lives bonus (power):** every realm above 9 you have EVER reached gives x3 qi in all
     later lives. It only grows when you go deeper than ever before. This is what pushes people on.
  2. **Karma (choices):** each reincarnation pays karma, more the further that life went. Karma buys
     nodes in a small **Dao Tree**: quicker starts, disciples that follow you into the next life,
     an extra slot, longer pills, a building that builds itself. Mostly comfort and speed, capped,
     so resetting often finishes the tree but never beats going deeper.
- **The rhythm it gives** (a regular player, two 30 minute sessions a day): life 1 reaches realm 10
  in about 2.5 weeks. Each later life takes about a week to catch up to the old best and another
  week to beat it by one realm. Every life ends one realm deeper than any before, forever.
- **The trap to avoid:** the first five realms take at least ~5 minutes each even with huge income,
  because you have to walk to every pad. Replaying them every life is boring, so the tree's first
  nodes skip them (start a life with realm 1 already built, then start at a later realm).
- **Every breakthrough should change something you can see**, not only a number: realm names for
  6 to 10, a new palette or sky tint, the player's aura colour, a new Main Hall roof. Section 4.

## 1. What the research says
Sources are mostly design write-ups and fan wikis; the anchors that matter:
- **Deep prestige = new decisions, not one multiplier.** Shallow systems give one multiplier; deep
  ones add persistent systems (research trees) beside the reset currency, have a rising threshold so
  early resets are quick and later ones need planning, and include upgrades that improve the next
  reset. Make the first reset early and obviously worth it; add one new layer at a time.
  https://hustletycoon.com/en/best-idle-games-with-prestige ·
  https://onirealms.com/guides/how-to-design-an-idle-game/
- **The math:** costs grow exponentially and income polynomially, so progress slows by design and
  prestige reins it back (Pecorella, The Math of Idle Games).
  https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii
- **Egg, Inc.:** prestige pays Soul Eggs (+10% each, permanent) and keeps a separate permanent
  "epic research" tree that never resets; a second currency (Prophecy Eggs) multiplies the first.
  Two layers: one for raw power, one for chosen upgrades.
  https://egg-inc.fandom.com/wiki/Earnings_Bonus/Soul_Eggs
- **Cookie Clicker:** the reset currency is about the cube root of everything ever earned, so each
  extra point needs much more progress and late resets stay meaningful (from memory, not verified).
- **Sell Lemons (Roblox, 2025 hit):** rebirth, then later layers (evolve, ascend) with permanent
  tokens and a permanent multiplier; after the first rebirth a Powers menu where "Remote Buy" (buy
  without walking) is the most valued early power.
  https://allthings.how/sell-lemons-on-roblox-how-to-farm-cash-rebirth-and-evolve/
- **DevForum:** a reset feels bad unless the payoff is clear before you press it; the server decides
  everything and rate-limits the remote.
  https://devforum.roblox.com/t/rebirthing-in-obbies-is-it-worth-it/1523934

**Our own lessons (Heavenly RNG reincarnation studies, memory):**
- Real players were bimodal: ~37% never reset, ~30% reset every few minutes. Design for both.
- A reward indexed on something the reset zeroes pays the player who never resets: index power on
  the monotonic PEAK (best realm ever), stamped at the reset.
- If a reset lands the player above its own gate it becomes free to repeat, and every reward keyed
  to the reset COUNT leaks: keep the landing (realm 1 to 5) below the gate (realm 10) and put the
  gate in the one server function every caller goes through.
- A decaying early bonus keyed to the reset count punished veterans: no count-keyed decay.
- The first reincarnation menu was "horrible, unplayable on mobile": mocks on a phone first (R4).

## 2. The numbers behind the rhythm
A permanent income multiplier `M` (all qi, live and offline), regular player, day each realm ends:

| realm reached | M = 1 (life 1) | M = 3 | M = 10 |
|---|---|---|---|
| 5 | day 1 | day 1 | day 1 |
| 8 | day 4 | day 2 | day 2 |
| 10 | day 18 | day 8 | day 4 |
| 11 | day 51 | day 18 | day 8 |
| 12 | - | day 44 | day 16 |
| 13 | - | - | day 42 |

- Past realm 9 every realm costs x10 and pays x3, so each one takes ~2.5 to 3x longer than the last.
  An x3 bonus is worth about one realm of depth. That is why the Past Lives bonus is **x3 per realm
  above 9 ever reached**: it buys back exactly the realm you just conquered.
- Life by life (regular player, Past Lives only, no tree): life 1 ends at realm 10 (~day 18). Life 2
  (x3) catches up by day 8 and reaches 11 by day 18. Life 3 (x9) reaches 11 by ~day 8 and 12 by
  ~day 16. Life 4 (x27) reaches 12 by ~day 8 and 13 by ~day 20. The pattern holds at any depth.
- Floor: with M = 10, realms 1 to 7 still take ~5 to 10 minutes each (walking to pads). That is
  ~40 minutes of replay per life, hence the quick-start nodes.
- Hooked players (3 x 60 min) run each life about twice as fast; casual (1 x 20 min) about half.
- These runs were made in this thread for the proposal; the Economy thread owns the model and will
  confirm the final numbers.

## 3. The proposal
### 3.1 Reincarnation (the reset)
- **Gate:** realm 10 reached in this life. One server function `reincarnate(player)` checks it.
- **Lands at:** realm 1 (or the realm a tree node sets, never above 5, below the gate).
- **Resets:** qi, buildings, realm, pill, recruit price, disciples (except sworn ones, 3.3).
- **Keeps:** best realm ever (`peakRealm`), karma and the Dao Tree, lives count, passes, cosmetics.
- **Before pressing:** a preview screen shows exactly what you keep and gain ("Past Lives x9 -> x27,
  +34 karma"). A confirm, never a surprise.

### 3.2 Past Lives bonus (power, monotonic)
- `pastLives = 3 ^ max(0, peakRealm - 9)`, applied to all qi. `peakRealm` = the highest realm ever
  reached, updated live (`max(stored, current)`), so going deeper than ever pays instantly too.
- It never decays and cannot be farmed: only a new record raises it.

### 3.3 Karma and the Dao Tree (choices)
- **Karma earned** when reincarnating: `floor(10 * (lifeQi / Q10) ^ (1/3))`, where `lifeQi` is all
  qi earned this life and `Q10` is the realm 10 breakthrough cost. Reaching realm 10 pays ~10; one
  realm deeper (x10 qi) pays ~22; two deeper ~46. Fast resets pay a steady trickle; deep lives pay more
  per life.
- **Dao Tree** (each node a few levels, all capped; first nodes cheap):
  | Node | Effect | Why |
  |---|---|---|
  | Remembered Foundations | start each life with realm 1 already built; level 2: realms 1 to 3 | skips the walking floor |
  | Rebirth Gate | start the life at realm 3 / 5 (never above 5) | skips the named realms on later lives |
  | Sworn Disciples | 1 / 2 / 3 best disciples follow you into the next life | keeps the collection alive |
  | Heavenly Hands | buy any affordable pad from the Main Hall without walking | Sell Lemons' favourite power; phone comfort |
  | Elixir Mastery | pill lasts 60 -> 90 -> 120 s | small, felt every few minutes |
  | Deep Meditation | offline cap 4 h -> 6 h -> 8 h | rewards coming back |
  | Disciple Seat | +1 disciple slot (stacks with VIP) | power, capped at one |
  | Soul Echo | +10% karma per level (5 levels) | the "improve the next reset" loop |
- Nothing in the tree copies a paid pass (2x qi, auto orbs, VIP) so the passes keep their value.

### 3.4 Showing who you are
- A **lives** count and the **peak realm** under the player's name and on the realm leaderboard
  (ranked by peak realm, then lives), so depth is visible to everyone.
- The avatar's **aura** follows the peak realm (same colour ladder as the disciple rarities, branch
  cultivators), and the entrance arch shows "Nth Life".

## 4. What each breakthrough builds up (inside a life)
Today: income x3, buildings reset, disciples stay, recruit price restarts, the palette cycles
through 3 colour sets. Proposal: every realm also changes one thing you can see.
| Realm | Name (proposal for 6+) | What changes on screen |
|---|---|---|
| 1 to 5 | Qi Condensation ... Soul Transformation | palettes as today; a new Main Hall look each life |
| 6 | Void Refinement | clouds under your peak tint with the realm colour |
| 7 | Body Integration | floating rocks circle the peak |
| 8 | Mahayana | a second waterfall, gold roof trims |
| 9 | Tribulation Transcendence | storm clouds and distant lightning over the peak (R3: event flash only) |
| 10 | True Immortal | a halo on the Celestial Palace, the reincarnation altar appears |
| 11+ | Immortal Realm N | the halo colour climbs the rarity ladder each realm |
Each breakthrough keeps one toast line saying what changed.

## 5. Telemetry (the questions, Gladiator R23 style)
- Do players reincarnate at the gate or push deeper? Event on reincarnation: life number, realm
  reached, minutes in that life, karma gained.
- Which tree nodes are bought first? Event on node buy: node, level, life number.
- Do lives 2 to 4 hit the "a week to catch up" target? Realm events already carry minutes played.

## 6. Open choices for the owner
1. Past Lives at x3 per realm above 9 (recommended: matches the cost step) or gentler (x2).
2. Disciples reset at reincarnation except sworn ones (recommended) or all disciples stay.
3. Realm names 6 to 10 as above, or the owner's own list.
