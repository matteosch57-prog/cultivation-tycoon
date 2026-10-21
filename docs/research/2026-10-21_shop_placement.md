# Shop placement and conversion: how top Roblox tycoons sell (2026-10-21)

Question: the world shop puts 13 pads on one side island per peak (D28) and reads crowded. Where
should each product stand, and what makes a Robux offer convert without feeling pushy?
Mocks: `docs/art/mocks/shop_layout.html` (`?view=now|A|B|ui|qi|short`, renders `shop_layout_*.png`).

## What the evidence says
**Hard data is thin.** No public source compares in-world pads with a UI shop or gives a per-spot
conversion rate (a DevForum thread notes Roblox does not track the prompt source: tag it yourself).
Several fan wikis refused automated reads, so per-game layouts for Lumber, Theme Park, Retail
Tycoon 2, PS99 and Bubble Gum are not verified here.

Documented:
- **Roblox's "right item, right time" guide** names five offer kinds: in-play, pre-play, lobby
  (3D displays), complementary, UI. A lobby display should open the main shop so players do not
  think the display is the whole catalogue; "be thoughtful about how many sales prompts" you use.
  Bee Swarm groups its complementary passes side by side in the world.
  https://create.roblox.com/docs/production/game-design/contextual-purchases
- **Products beside what they boost:** War Tycoon sells its oil extractor pass in the oil rig room
  (search summary only, article blocked); tycoon guides put upgrade buttons next to the thing they
  upgrade and section unlocks at the section's entrance, because scattered buttons confuse.
  https://www.creation.dev/blog/how-to-make-a-tycoon-game
- **Build-mode tycoons sell through UI** (Restaurant Tycoon 2 and 3: a shop menu with Auto Money,
  item limits). Grow a Garden sells Robux inside the vendor's own screen (buy a sold-out seed, skip
  a restock): the offer appears exactly where the player is short. https://rt3.fandom.com/wiki/Shop
- **Prompts:** check ownership first and show a message instead of a prompt; read prices live
  (`GetProductInfo`), never paint them (regional pricing and price tests change them per player);
  walk-on and Touched prompts need a per-player debounce; on Xbox the jump button confirms a
  purchase, so a prompt that opens while moving causes accidental buys; a prompt cannot be
  cancelled by code. https://create.roblox.com/docs/production/monetization/game-passes ·
  https://devforum.roblox.com/t/make-confirming-a-purchase-harder/462748
- **Tone (official):** "Users must never be misled, confused, or pressured"; no fake discounts, no
  restarting timers; wording "View Item / Open Shop", not "GET IT NOW". Tourists buy what has a
  visible effect now; locals (most engaged players) value long-term items.
  https://create.roblox.com/docs/production/monetization
- **Native Shop button** (Roblox's own, off by default) lists every pass and product; Roblox
  recommends turning it on. https://create.roblox.com/docs/production/monetization/shop
- **Numbers:** regional pricing raised the share of spenders by a median 26% in tested countries;
  Price Optimization tests +4% median earnings.
  https://about.roblox.com/newsroom/2025/04/roblox-launches-regional-pricing-for-in-experience-items
- **Perception:** developers rate Auto Collect the best-liked tycoon pass; raw 2x cash reads as
  pay-to-win to some (opinion, not data). https://devforum.roblox.com/t/best-gamepasses-for-a-tycoon/485468

Inferred (genre knowledge, not sourced): classic button tycoons put a few pass pads at the base
entrance or inline with the build path; prices on in-world displays come from live product info.

## What it means for us
1. **Sell each item where it acts** (contextual + complementary): 2x Qi and VIP at the peak
   entrance (the VIP arch turns gold right there), Instant Pill at the Alchemy Furnace, Auto Orbs at
   the Gathering Array. Items for a building appear only when that building stands, so no pad
   offers something the player cannot use yet.
2. **Pads beside the path, never on it**: a pad on the walking line prompts by accident (and on
   Xbox, jump confirms). Our prompt already needs a step off first; add a longer per-player
   cooldown per item.
3. **Displays open the shop** where it is a catalogue (the disciples): the screen lands on the
   matching tab, so the full list is one tap away.
4. **Qi packs are a "short of qi" offer**, not a pad: one quiet Get Qi under a build pad the
   player cannot afford, opening the Qi tab. No timers, no "now" wording.
5. **Measure it**: the `Shop` event already logs `open` by source and `prompt` per key; add the pad
   spot to the source so in-world vs screen conversion is readable after the first batch.
6. Owner to consider: the native Roblox Shop button (Creator Dashboard / experience settings).
