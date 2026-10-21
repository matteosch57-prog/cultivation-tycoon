# Tycoon study: what the successful Roblox tycoons do (2026-10-21)

Evidence file (write once). Decisions that come out of it go to DECISIONS.md; numbers to `Config.luau`.

## 0. In plain words
The biggest Roblox games of the last two years (Grow a Garden, Steal a Brainrot) are idle tycoons at
heart: you own a plot, it earns money every second, you buy things that earn more. Three things set them
apart from the old tycoons, and we have only some of them.

1. **Shared moments.** Every few minutes something happens to the whole server at once (weather in Grow
   a Garden, the shop restock everyone watches). Players stay "just a bit longer" for the next one, and
   they talk about it. We had nothing like this, so this branch adds the **Spirit Tide**.
2. **A collection with rare pulls.** Rare characters you show off. Our disciples are this already; the
   Cultivator models thread gives them looks by rarity.
3. **Coming back is rewarded and visible.** Offline growth you see on return, daily and playtime gifts.
   We have offline qi but only as a toast; B01 step 6 plans the screen.

What we do NOT copy: stealing (Steal a Brainrot's core tension). It breaks our "fair and calm" pillar
and the press is mostly about children crying over stolen characters.

## 1. Sources and how much to trust them
Most search results were fan wikis and SEO pages; the only first-party source is the Roblox retention
doc. Treat game details below as community-reported.
- Roblox Creator Docs, Retention: D1 levers are the core loop, the first-time experience and
  performance; "get users to the fun ideally in 5 minutes or less"; a joyful moment after the first loop;
  D7 = short and long goals; D30 = small updates every 2 to 4 weeks, big ones every 2 to 3 months.
  https://create.roblox.com/docs/production/analytics/retention
- DevForum, session time and D1 (community): a benchmark of at least 8 min playtime and 10% D1;
  playtime rewards at 10, 20 and 60 min; daily rewards; most players are on phones.
  https://devforum.roblox.com/t/suggestions-to-improve-average-session-time-day-1-retention/2935525
- DevForum, first join (community): daily or hourly rewards, a skippable tutorial, a welcome gift.
  https://devforum.roblox.com/t/what-can-i-do-to-improve-the-experience-of-a-player-who-joined-the-first-time/1693241
- DevForum tycoon dev: most players skip the tutorial; the first action has to be impossible to miss.
- Grow a Garden (fan guides, GameSpot): shops restock every ~5 min with the same stock for everyone;
  random server-wide weather plus event weather on its own countdown; weather causes crop mutations that
  multiply value; offline only grows crops (no mutations), so the return is a visible before/after.
  https://www.gamespot.com/gallery/grow-a-garden-weather-events/2900-7058/
- Steal a Brainrot (Wikipedia, Kotaku, guides): buy characters off a central conveyor, they earn cash
  per second on your base, rarity drives the hunt, stealing adds risk; passed 25 M concurrent users.
  https://en.wikipedia.org/wiki/Steal_a_Brainrot
- Sell Lemons (fan wikis): income upgrades first, managers automate selling, 100% offline income,
  rebirth then later prestige layers; after the first rebirth a "Powers" menu where Remote Buy (buy
  without walking) is rated the best early power.
  https://allthings.how/sell-lemons-on-roblox-how-to-farm-cash-rebirth-and-evolve/
- Classic tycoons (Restaurant / Retail / Theme Park Tycoon 2, tutorials): build from nothing,
  rebirth = reset for a permanent multiplier, convenience passes (auto-collect, 2x cash) sell best;
  Mall Tycoon sells Auto Collect for 350 Robux. https://mall-tycoon-roblox.fandom.com/wiki/Auto_Collect

## 2. Ideas, ranked for Cultivation Tycoon
| # | Idea | From | Fits us? | Status |
|---|---|---|---|---|
| 1 | **Spirit Tide**: a server-wide 2x qi window on a timer, with a 30 s heads-up | Grow a Garden weather and event timers | Yes: calm, shared, no UI screen | Built on branch `tycoon-ideas` (ECONOMY, Config `TIDE_*`) |
| 2 | **Playtime gifts** at 5 / 15 / 30 min of a session | DevForum, GaG | Yes, pushes past the 8 min benchmark | Owner picked mock A (gift button); built on `tycoon-ideas` |
| 3 | **Tide countdown on the HUD** (when the next tide comes) | GaG event countdowns | Yes, makes #1 a goal | Owner picked mock A (line under the counter); built |
| 4 | **Each realm faster, not slower**: today costs x8 and income x3 per realm, so a realm takes ~2.7x longer than the last (disciples aside). Rebirth games make each run shorter or equal | Classic rebirth, Sell Lemons | Needs a pacing check | For B01 step 5 (pacing sim), owned by the First session thread |
| 5 | **Breakthrough perk: Remote build** (buy an affordable pad from the Main Hall without walking) after realm 2 | Sell Lemons Powers | Good for phones and calm players | Later; mock first |
| 6 | **Offline before/after** on return (what grew, not only the number) | GaG offline growth | Yes | B01 step 6 already plans the offline screen |
| 7 | **Bless a sect**: visit another peak and give it a small qi gift (both get a little) | Social touchpoint without stealing | Yes, replaces stealing | Later; mock first |
| 8 | **Disciples you can see**, coloured by rarity | Brainrot collection, Restaurant Tycoon staff | Yes | Cultivator models thread |
| 9 | Convenience passes (auto-collect, 2x) | Mall Tycoon, guides | Already D17 | No change |
| 10 | Small update every 2 to 4 weeks after launch | Roblox docs | Yes | Plan after M2 |

## 3. Spirit Tide, as built
- `Config.TIDE_FIRST` s after a server starts, then every `TIDE_INTERVAL` s, every peak on the server
  earns `TIDE_MULT` x for `TIDE_DURATION` s. A toast warns `TIDE_WARN` s before.
- State is two Workspace attributes in server time, `TideNext` and `TideUntil`, so a HUD countdown
  (idea 3) needs no new remote. Offline qi never counts the tide.
- Feel: a toast in the HUD style, a soft gong, a pale blue column over the player's peak (an event
  flash, allowed by R3).
- **Telemetry question:** does a tide keep players longer? Measure session length and leave time
  relative to `TideNext` (do fewer players leave in the 30 s before a tide?). The server prints
  `[Tycoon] spirit tide started, N players`; the analytics event belongs with the First session funnel
  work (B01 step 7), handed to that thread.
- **Checked:** Luau parse (selene, Luau std) and a Rojo build. Not yet run in Studio Play (Studio is
  shared with three other threads); a Play check with `TIDE_FIRST` lowered is the next rung.
