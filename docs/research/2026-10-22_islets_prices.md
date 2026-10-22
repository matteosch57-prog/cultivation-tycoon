# Sky Islets prices (D42), simmed 2026-10-22

`tools/sim_game.py` now reads the islets: a pad on an islet needs its bridge (`islet`, `ISLETS[*].bridge`),
paths and groves raise Harmony (`HARMONY_STEP`, capped `HARMONY_MAX`), and `--set WALK_SCALE=x` stretches
the walk to each pad (the islets' bridges are 12 to 19 studs; the hub bridge walk is about 11 s against 7 s).
Comparison script: `_local/cmp_islets.py` (3 runs, 14 days, median).

| build | casual: Hall / realm 2 | regular: Hall / realm 2 | regular lives in 14 days |
|---|---|---|---|
| integration (before islets) | 3.2 / 12.9 min | 2.4 / 9.6 min | 30 |
| islets, same walks | 4.9 / 16.3 min | 2.9 / 10.7 min | 29 |
| islets, walks x1.2 | 5.6 / 18.8 min | 3.3 / 12.1 min | 29 |
| islets, walks x1.5 | 6.9 / 23.4 min | 3.6 / 12.7 min | 28 |

- **Prices kept.** Each bridge, path and grove sits on the ladder at its unlock rung like the buildings
  beside it; when bought it costs under about 12 s of income. Raising them changes nothing while income
  outruns the whole ladder (the "no real choice" finding, docs/research/2026-10-22_choice_and_recruits.md):
  the fix for that is the pace pick (price floor), which would cover these pads too.
- **The pace cost is the walking.** A breakthrough needs every pad, so the 14 new pads add 14 walk-and-buy
  steps a realm. Realm 2 moves from 9.6 to 10.7-12.7 min for a regular and 12.9 to 16-23 min for a casual
  player, against the 5-10 min hook (D39). Keep the pads on the line the player already walks (beside the
  bridge they follow) so the walk stays near x1.2 or under.
- Harmony reaches its cap (+20%) with the 10 paths and groves; late lives are unchanged (income dwarfs it).

## Paths and groves optional (branch islets-walk, `DECOR_OPTIONAL`)

The sim follows `Config.neededForBreakthrough`: once every required pad is owned the player saves for
the breakthrough. Realm 2, minutes (casual / regular):

| islets-walk | walks x1 | walks x1.2 |
|---|---|---|
| buys every path and grove (cheap, so bought on the way) | 16.3 / 10.7 | 18.8 / 12.1 |
| skips every path and grove | 14.0 / 10.1 | 15.9 / 11.1 |

The numbers hold: skipping saves 1-3 min to realm 2, buying gives +20% income; either way the pace
stays within a minute for a regular player, so it is a real choice without a trap.
