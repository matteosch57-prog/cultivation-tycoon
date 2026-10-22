# Space and gradual building (2026-10-22)

Evidence file (write once). Owner: "everything is too closed, it's feeling small, give some space",
"all the farming spots should have 2 farmers on it, not 3 on one only", "Everything can be buildable
slowly, roads too, don't put any by default, we can add trees too". Mock:
`docs/art/mocks/peak_layouts.html` (A Wide Peak, B Sky Islets, C Long Ridge, drawn to scale from
Config.PADS). Owner picked **B** ("looks great with nice bridges"). Decision: DECISIONS D42.

## Research
- Open feel comes from land you can see but not use yet. Theme Park Tycoon 2: 64 plots of 16x16
  cells, you start on 4; locked land is "dry grass", a "Land for sale" sign only next to land you own.
  https://tpt2.fandom.com/wiki/Plot_expansions (fandom refuses fetches: from search snippets)
- Land as a product elsewhere: Lumber Tycoon 2 keeps 2 of 8 plots empty; Restaurant Tycoon 2 sells
  Expanded Plot 1 to 3 then a second floor; Retail Tycoon 2 sells more land.
- Decor pays through a rating, not as income: Retail Tycoon 2 averages decoration over the tiles
  customers stand on, a better rating brings more customers
  (https://retail-tycoon.fandom.com/wiki/Ratings, https://devforum.roblox.com/t/retail-tycoon-2-changelog/858524);
  Restaurant Tycoon 2: every 7 nature decorations = 1 star, small items capped
  (https://restaurant-tycoon-2.fandom.com/wiki/Restaurant_Ratings).
- No top tycoon found with upgrade-line roads (dirt -> stone -> jade); the common pattern is cheap
  decor feeding a capped rating.
- Price = income/s x target wait (~30 s early, ~60 s late); choice only when buying A delays B
  (https://devforum.roblox.com/t/how-to-balance-prices-in-tycoon/3553154,
  https://www.gamedeveloper.com/design/designing-interesting-decisions-in-games-and-when-not-to-).
- Repeatable buys: cost = base x growth^owned (1.07 in AdVenture Capitalist).
- Not found: published plot sizes or plot distances in studs for the big tycoons, a "tolerable walk"
  number, DevForum plot-size advice. Walk speed 16 studs/s (default).

## Measured on our map (tools/islet_layout.py, Config of 2026-10-22)
| | before | Sky Islets |
|---|---|---|
| median gap between building edges | 2 studs | ~10 studs |
| bridge spans between islets | none | 12 to 19 studs (~1 s) |
| hub to peak bridge (PLOT_RADIUS 215 -> 280) | ~7 s | ~11 s |
| nearest neighbour land | ~5 studs | 15.6 studs |
Walking is now part of the pace: the economy sim (2026-10-22_choice_and_recruits) found the ~6 s
walk to a pad is the only gap between buys, so longer walks slow the climb a little.
