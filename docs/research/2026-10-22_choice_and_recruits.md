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
