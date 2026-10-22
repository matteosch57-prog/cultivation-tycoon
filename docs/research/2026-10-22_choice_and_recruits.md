# Real choices and recruit spam (2026-10-22)

Evidence file (write once). Owner: "There's no real choice, because you quickly have money to do it all"
and "Recruiting is too easy, once you get to the end of a realm, you can spam click like crazy. We
should add a x10, and maybe review the steep a bit." Tool: `tools/sim_game.py` (levers PRICE_FLOOR_S,
RECRUIT_POW, PRICE_PL_EXP added for this), Config of 2026-10-22 (D40), regular player 2 x 30 min a day,
median of 3 runs over 30 days.

## Research
- DevForum, "How to balance prices in tycoon?": price = income per second x the seconds you want a
  purchase to take; about 30 s per button, lower early, rising later.
  https://devforum.roblox.com/t/how-to-balance-prices-in-tycoon/3553154
- Idle games: costs grow by a fixed factor per purchase, 1.07 (AdVenture Capitalist) to 1.15 (a common
  default); linear growth "can make progress feel stagnant" and lets cheap buys pile up.
  https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i ·
  https://devforum.roblox.com/t/how-much-should-the-prices-of-an-upgrade-go-up-by-in-an-idle-game/2211689
- Meaningful choice needs a limited budget and options that pay differently (districts already do).
- Multi-summons (Pet Simulator 99): hatching several at once is a convenience unlocked later; each
  egg still costs its price. https://pet-simulator.fandom.com/wiki/Gamepasses_(Pet_Simulator_99)

## Measured today
| | life 1 | lives 5 to 9 | lives 10+ |
|---|---|---|---|
| seconds between buildings (median) | 11 | 5 | 5 |
| buys made while 3+ buildings were affordable | 75% | 88% | 82% |
| recruits one minute of income buys at a realm's end | 45 | 500+ | 500+ |
The walk to the pad (6 s) is the only thing between buys; the recruit price only grows +50% per roll,
so at a realm's end income buys hundreds.

## Options
| | s between buildings (life 1 / later) | recruits a minute buys at a realm's end | life 10 / life 20 |
|---|---|---|---|
| today | 11 / 5 | 45 / 500+ | day 3 (14 min) / day 7 (29 min) |
| recruit x1.25 each (no price change) | 8 / 2 | 7 / 21 to 30 | day 2 / day 4 |
| recruit x1.25 + a building costs at least 20 s of income | 11 / 10 | 2 / 2 | day 5 (42 min) / day 16 (86 min) |
| recruit x1.25 + at least 30 s of income | 16 / 15 | 1 / 1 | day 7 (56 min) / day 22 (114 min) |
| casual player, today / with the 20 s floor | 18 / 3 -> 17 / 10 | 51 / 500 -> 3 / 3 | life 10 day 8 -> day 15 |
- Each recruit costing x1.25 the last (per realm, restarting at a breakthrough) ends the spam on its
  own: the 20th recruit of a realm costs ~90x the first, the 30th ~800x. x10 then buys the next ten at
  their summed price (a convenience, not a discount).
- The minimum price (income x seconds, the DevForum rule) keeps every building a small saving goal
  in every life, so you pick which one comes first; it slows lives about 2 to 3x (the climb was fast).
- Not proposed: prices that follow Past Lives (x power^1 stalled life 10 at day 19).

## Keeping disciples (owner: "losing disciples is complicated, we should let people accumulate them")
Today a breakthrough keeps disciples but drops the Quarters seats (the extras rest until they are
rebuilt), a new life keeps only the sworn ones and the bought ones, and the list is capped at
`DISCIPLE_CAP` (8), so extra rolls leave. Roblox rebirth games differ: Pet Simulator 99 keeps every pet
through a rebirth (https://holdtoreset.com/pet-simulator-99-rebirth-system-explained/), Tap Simulator
and Build a Base and Steal wipe them (https://www.pockettactics.com/tap-simulator-guide). Sim: keeping
every disciple through a new life changes nothing measurable (life 20 day 16 with or without, option 2),
because only the best `maxDisciples` work and the best ones come back fast anyway. So keeping them is
free for the pace; it is a feel and collection decision.

## Built (D44, owner picks: pace 2, disciples A), simmed on integration f31cf5e (Sky Islets)
Medians of 3 runs, 3 weeks (`_local/cmp_pace.py`):

| | Hall / realm 2 | life 10 | life 20 | buy wait | recruits a minute at a realm's end |
|---|---|---|---|---|---|
| regular, before | 2.9 / 10.7 min | day 3 (16 min) | day 8 (33 min) | 3 s | 500 |
| regular, floor in every life | 4.5 / 13.9 min | day 7 (49 min) | day 20 (97 min) | 10 s | 2 |
| regular, floor from life 2 (shipped) | 2.9 / 8.9 min | day 7 (48 min) | day 20 (101 min) | 10 s | 2 |
| casual, floor from life 2 (shipped) | 4.9 / 15.6 min | day 19 (52 min) | - | 15 s | 3 |

The floor in the first life pushed realm 2 past the 5-10 min hook, so it starts in life 2
(`PRICE_FLOOR_FROM_LIFE`). Keeping every disciple costs nothing measurable.
