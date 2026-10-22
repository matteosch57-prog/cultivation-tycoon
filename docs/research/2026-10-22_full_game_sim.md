# Full game sim: every qi source and sink (2026-10-22)

Evidence file (write once). Owner, 2026-10-21: "check all the game codes for all Qi sources and sinks,
make a full simulation now. Sims will be our single most important thing to a good game. Pace."
Tool: `python tools/sim_game.py` (one sim for the whole game; `tools/sim_pacing.py` and
`tools/sim_economy.py` stay for their older questions). Numbers below: 60 days, median of 3 runs.

**Config used:** the main checkout's `Config.luau` (layout A, 41 pads, districts, workers, Friends here,
the Heavenly Gift) with D37 (reincarnation at realm 2) and the Heavenly Altar block applied, i.e. the
game as it stands once every open branch is merged. Rerun on the merged Config to refresh.

## 1. The audit: where qi comes from and goes (code, 2026-10-22)
| | What | Code | Rule |
|---|---|---|---|
| source | live income | Main income tick | `rate(s)` every second |
| source | offline | onJoin | `rate(s, away)` x min(away, `OFFLINE_CAP` + Deep Meditation) |
| source | qi orbs | Main checkOrbs | `rate(s)` x `ORB_VALUE` each, one per `ORB_INTERVAL`, `ORB_MAX` waiting |
| source | playtime gifts | ClaimGift | `rate(s, away)` x `GIFT_VALUE[i]` at `GIFT_TIMES[i]` |
| source | Heavenly Gift | Welcome | `WELCOME_QI` once per save |
| source | Heavenly Altar | Altar.luau (branch) | `rate(s, away)` x `ALTAR_WIN/SOLO/JOIN_SECONDS` |
| source | qi packs | Shop.luau | `rate(s, away)` x item seconds (Robux) |
| multiplier | in `rate` | Main rate | pads x workers x district, x `incomeMult`, disciples, pill, tide, 2x pass, Past Lives, friends (live), group |
| sink | buildings | buyPad | cost x `costMult(realm)` |
| sink | workers | hire pads | `workerCost(pad, n, realm)` |
| sink | recruits | Recruit | `recruitCost(realm, realmRecruits)` |
| sink | breakthrough | breakthrough pad | `BREAKTHROUGH_COST` x `costMult(realm)` |
| loss | reset | breakthrough, reincarnate | leftover qi is set to 0 |
Debug only: `DebugGrant` (Studio). Nothing else writes `data.qi`.

## 2. Pace today (no changes)
Day each life ends (play time inside that life):

| player | life 1 | life 5 | life 9 | life 12 | life 14 |
|---|---|---|---|---|---|
| casual 1 x 20 min | day 1 (13 min) | day 8 (24 min) | day 11 (25 min) | day 19 (78 min) | day 33 (2.7 h) |
| regular 2 x 30 | day 1 (10 min) | day 2 (25 min) | day 4 (36 min) | day 7 (82 min) | day 12 (3.3 h) |
| hooked 3 x 60 | day 1 (10 min) | day 1 (35 min) | day 2 (34 min) | day 3 (87 min) | day 5 (4.6 h) |
| regular + 3 passes | day 1 (7 min) | day 2 (26 min) | day 4 (26 min) | day 6 (51 min) | day 9 (1.9 h) |
| regular + 2 friends + altar | day 1 (9 min) | day 2 (25 min) | day 4 (32 min) | day 7 (62 min) | day 11 (3.0 h) |
The first session works: first building 0.1 min, Main Hall 0.5, Disciple Hall 2.4, first new life 10.

Where a life's qi comes from (share per life, regular player):
- lives 1 to 4: qi orbs 34%, live income 32%, offline 15%, pill 8%, tide 6%, gifts 5%
- lives 15 to 18: **offline 81%**, orbs 7%, live 5%, pill 3%, tide 1%, gifts 1%
Where it goes: lives 1 to 4 **reset loss 84%**, recruits 11%, buildings 3%; lives 15 to 18 recruits
57%, reset loss 19%, buildings 14%, breakthrough 9%.

## 3. Findings
1. **Late game is idle: being away earns 4 of every 5 qi.** Offline pays the full rate (no tide or
   pill) for up to 4 h, and a regular player is away ~22 h a day. Idle games usually pay offline at
   a fraction so playing beats waiting.
2. **Qi is thrown away at every reset.** A breakthrough sets qi to 0 after paying, so the rest of an
   offline windfall vanishes (19% of late qi). In the first lives most qi is lost at reincarnation (84%):
   lives are 10 to 30 min, so a 4 h offline pile is far more than a life can spend. Players will see
   "+50K offline qi" and then lose it.
3. **Qi orbs are the strongest thing an active player does:** a third of early qi. One orb every 20 s
   worth 15 s of income is +75% while collecting, more than the pill (+33%) or the tide (+15%). This also
   makes Auto Orbs the strongest pass, as strong as 2x Qi for an active player.
4. **Recruits are the main sink late (57%)**, as designed: the disciple chase stays alive every realm.
5. **Small things stay small:** gifts, tide, altar, friends, the welcome gift are 1 to 7% each. Good:
   flavour, not pacing.
6. **Lives 5 to 7 are shorter than life 4** (Old Foundations and Heavenly Hands, bought with the first
   karma, skip the walking). That is the "the loop gets faster" moment, fine.

## 4. Proposal (both levers together keep today's pace)
| change | regular: life 14 | casual: life 14 | late qi from offline | late reset loss |
|---|---|---|---|---|
| today | day 12 (3.3 h) | day 33 | 81% | 19% |
| A. a breakthrough keeps leftover qi | day 9 (2.0 h) | | 82% | 10% |
| B. offline pays 50% of the rate | day 13 (3.9 h) | | 68% | 6% |
| **A + B** | **day 11 (2.8 h)** | **day 28** | **68%** | **6%** |
A + B: almost the same pace, no qi a player can see vanishes at a breakthrough, and an hour played is
worth twice an hour away. Not proposed: carrying qi through a reincarnation (a new life starts at
zero by design). Orbs: leave as they are (they are what makes playing pay); price Auto Orbs as the
strongest pass.

## 5. Keep it measured
The live funnel and realm events already log minutes per step; `Reincarnate` logs life, depth and hours.
Read the first batch against section 2 and rerun this sim with the live numbers.
