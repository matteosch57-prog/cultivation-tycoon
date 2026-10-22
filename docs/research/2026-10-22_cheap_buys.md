# Very cheap buys (1 to 5 Robux): study (2026-10-22)

Owner ask (2026-10-21): "study now the idea of adding really cheap buys like 1-5 robux".
Status of the shop when studied: MONETIZATION and SHOP_ITEMS (cheapest item today: Instant Pill 25,
Qi Pouch 29; ids still 0).

## What Roblox allows
- A developer product can cost **1 to 1,000,000,000 Robux**; a repeatable buy is a developer product,
  a one-time unlock is a pass (Creator Hub, Developer products).
- The creator keeps about **70%** of each sale. On 1 to 5 Robux that is 0.7 to 3.5 Robux per sale;
  how a fraction is rounded is not stated in the docs, so read it off one test sale in the sales
  report before pricing (inferred: a 1 Robux item likely pays 0 or 1).
- Prices must be read from `MarketplaceService` (we already do): Roblox's managed pricing and price
  tests only work on scripted prices, and only once a game has ~60,000 transactions in 30 days.

## What the evidence says about tiny prices
- The first purchase is the hard one. Most players who ever pay do it early: one industry dataset has
  77% of payers making their first in-app purchase in their first two weeks. Only ~2 to 5% of players
  ever pay.
- Starter offers convert best in the cheap band (the "$1 to $5" first-purchase range is the common
  advice), but a survey of 54 free-to-play teams warns that chasing conversion makes teams price
  starter packs too low. A cheap offer should be **once**, so it opens the wallet without becoming
  the place players spend.
- A Roblox player already holds Robux (the smallest Robux bundle is bigger than 5), so a 1 to 5 Robux
  item asks for no new payment, just a tap: it mostly turns leftover Robux into a first buy.
- Risks: cheap repeatable items can **anchor** the shop low (why pay 29 for a Pouch when 5 buys a bit
  of the same?), each sale earns almost nothing, and a tiny paid power boost reads as nickel-and-diming.

## What fits this game (calm, fair, R8: never a random reward for Robux)
| Idea | Price | Kind | Gives | Why |
|---|---|---|---|---|
| **Welcome Pouch** | 5 | once per player | 20 min of income in qi + one Instant Pill | the first purchase; clearly better value than anything else, but only once |
| **Incense Offering** | 1 or 5 | repeatable | no power: a stick lights at the Peak Shrine, a temple bell, the buyer's name on a "Patrons" board on their peak | a tip jar that fits a sect; can't anchor qi prices because it buys no qi |
| Pocket Qi | 5 | repeatable | 2 min of income | **not recommended**: undercuts the 29 Pouch (anchoring) and earns ~3 per sale |
| Short pill | 5 | repeatable | 2x for 15 s | **not recommended**: same anchoring problem as Pocket Qi, too short to feel |

**Recommendation:** add the Welcome Pouch (5, once) and the Incense Offering (1 and 5), nothing
repeatable that gives qi. The Pouch is offered once, after the first breakthrough (the player knows
what qi is worth by then), from the Shop's Qi tab and the existing "Get Qi" nudge; the Offering
lives at the Peak Shrine pad and in the Shop's Boosts row. Measure with the existing `Shop` telemetry:
first-time buyers per day before and after, and whether Pouch buyers go on to a second purchase.

Prices stay the owner's (R5). New tiles, the shrine pad and the Patrons board get a mock first (R4).

## Sources
- Roblox Creator Hub, Developer products: https://create.roblox.com/docs/production/monetization/developer-products
- Roblox Creator Hub, Price optimization: https://create.roblox.com/docs/production/monetization/price-optimization
- Deconstructor of Fun, "Pricing Starter Packs: When Conversion is King, We May Price Too Low" (2024): https://www.deconstructoroffun.com/blog/2024/4/8/free-to-play-starter-pack-pricing-when-conversion-is-king-we-may-price-too-low
- Pocketgamer.biz, best practices for starter bundles: https://www.pocketgamer.biz/best-practices-starter-bundles/
- Xsolla, attracting in-game shopping newbies: https://xsolla.com/blog/attracting-in-game-shopping-newbies
- Fungies, monetizing a player base (first-two-weeks figure): https://fungies.io/how-to-effectively-monetize-your-player-base-in-mobile-games
