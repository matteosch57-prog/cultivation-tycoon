# Monetization

Robux buys speed and comfort, never a random reward (RULES R8). The owner creates every pass and
product in the Creator Dashboard and owns prices; the ids go in `Config` (keys named when built).

## First release (chosen 2026-10-21, D17)
| Type | Product | What it does |
|---|---|---|
| Game pass | 2x Qi | Permanent double income |
| Game pass | VIP Sect | +1 disciple slot, gold name on the entrance arch |
| Game pass | Auto-collect orbs | Qi orbs fly to the player anywhere on their peak |
| Developer product | Qi packs (3 sizes) | Qi worth 10 min / 1 h / 6 h of current income |
| Developer product | Instant pill | 2x qi for 60 s now, no brewing wait |

## Rules for any new product
- Grant on the server only, through `ProcessReceipt` (idempotent by `PurchaseId`, saved before
  returning `PurchaseGranted`).
- Show recruit odds in the game even though recruits cost qi only.
- Anything random bought with Robux needs `PolicyService` paid-random-item checks: avoid it.
- Qi is sold for Robux and buys random recruits, so qi recruits count as paid random items (D77):
  where `ArePaidRandomItemsRestricted` is true (or unknown) the items that sell qi (`seconds`: the Qi
  packs and the Starter Pack) are not offered or prompted (`Shop.luau` `checkPolicy`, player
  attribute `QiSaleOff`); qi there is only earned. A new product that grants qi must carry `seconds`
  or be added to `sellsQi`. Store questionnaire: paid random items = yes, respects the restriction = yes.

## How the shop works (built 2026-10-21, D24)
- **Screen = mock B** (`docs/art/mocks/shop_B_phone.jpg`): no board, toy tiles over a dark veil.
  Boosts row (the three passes + Instant Pill), Qi row (three packs). A phone that cannot fit both
  rows flips pages with a "More Qi" / "Boosts" tile. Opened by the HUD's gold Shop button (always on
  top of the left column). Code: `src/client/Shop.client.luau`, drawing kit `src/shared/Toy.luau`.
- **World shop (D33, replaces the one-island market of D28; research
  `2026-10-21_shop_placement.md`, mock `docs/art/mocks/shop_layout_A.png`):** every item stands where
  it acts, beside the path, never on it. On the owner's peak (`Config.SHOP_PEAK_PADS`,
  `Shop.refreshPeak`, called from every pad refresh): 2x Qi right and VIP left just inside the
  entrance arch (they follow the rim when the island grows; the VIP arch name turns gold right
  there), Instant Pill beside the Alchemy Furnace and Auto Orbs beside the Gathering Array (each only
  once that building stands). The side island is now the **Disciple Garden**
  (`Config.SHOP_ISLAND_AT`, `SHOP_ISLAND_RADIUS`, joined to the rim by a bridge): only the six
  disciples for sale (`SHOP_DISCIPLE_PADS`), as real cultivators along a stone walk from its gate,
  cheapest first on alternate sides, Primordial last under a pavilion. Qi packs have no pad: standing
  on one of your own pads you cannot afford shows a quiet "Need [qi] N more · Get Qi" for 4 s (once
  per step onto it, only while a pack is on sale; Studio always), which opens the Qi page (open
  source `short`). Stepping onto a shop pad prompts its item (only for a player seen off it first;
  an owned pass shows a toast instead). Pads are invisible `StepPad` anchors (`PadKind` "shop",
  `ShopKey`) drawn by the pad look (D27); `Shop.client` draws the bobbing item icon (near, on-screen
  cards only) and the price card. Anyone may shop on any peak.
- **Checked in Studio Play (D33, 2026-10-21, full peak via DebugSet, ids at 0):** the four peak
  pads stand 7+ studs from every building at radius 90 (the first pill and orbs spots touched the
  furnace pavilion and the Training Ground and were moved); the entrance pair flanks the arch; the
  garden walk, its six disciples and the Primordial pavilion build with no script errors; the screen
  lands on Qi and Disciples from `ShopOpen` with icon tabs and rarity names. Not checked: the Get Qi
  offer (needs the avatar on a pad), a real purchase. Captures: `docs/art/captures/shop_peak_top_play.jpg`,
  `shop_entrance_play.jpg`, `shop_disciple_garden_play.jpg`, `shop_qi_tab_play.jpg`,
  `shop_disciples_tab_v2_play.jpg`.
- **Screen ergonomics (D33):** the tabs carry their icon; it opens on Boosts from the HUD and on Qi
  from Get Qi; disciple names are in their rarity colour; one "Best value" ribbon on the Qi Vault
  (most qi per Robux, no fake discount); the close X sits in the screen's top right corner.
- **Ids and prices:** the owner pastes each pass / product id into `Config.SHOP_PASSES` /
  `Config.SHOP_PRODUCTS` (id 0 = "Soon", never prompts). Prices are never in code: the client reads
  them from `MarketplaceService` (passes are regionally priced, so one typed price would be wrong).
- **Server only** (`src/server/Shop.luau`): the client sends an item key; the server checks it and
  prompts. Products are granted in `ProcessReceipt`: grant + `PurchaseId` go into the save
  (`data.receipts`, last `RECEIPTS_KEPT`), and `PurchaseGranted` is returned only after that save
  landed. A retry finds the id and grants nothing twice. Passes: `UserOwnsGamePassAsync` on join
  (before the offline qi, so 2x counts on it) and `PromptGamePassPurchaseFinished` live; ownership is
  never saved (Roblox is the record).
- **Disciples for sale (D28, owner pick C "but price accordingly"):** a FIXED rarity, never a roll
  (R8), every tier from Elder to Primordial. No buy limit (D75, owner 2026-10-23: "let people buy
  the disciples as much as they want"; it was 8 Elders / 8 Immortals and one of each higher tier).
  Every tier is on sale at every realm (owner 2026-10-22); an item may still set `minRealm` (the pad
  then says "Opens at ..."). Bought ones are counted in
  `data.boughtDisciples`, survive breakthroughs and are never trimmed by the disciple cap (the
  cap drops the weakest unbought one); a reincarnation must keep them. A rarity
  the player rolled shows a gold "first pulled" dot in the disciples row (`data.pulled`). Event
  `DiscipleBought` (key, realm, minutes played). The server refuses the prompt when the sect is
  full of stronger ones (it could not stay) or already holds `DISCIPLE_CAP` bought ones (they are
  never trimmed, so this is what bounds the list and the save without a buy limit). A bought one joins
  like a recruit and, if no seat is free, rests on the bench (`DISCIPLE_CAP`). Whether bought ones
  count in the recruit price (`priceRate`) is an open owner decision, unchanged here.
- **Effects:** 2x Qi = `PASS_QI_MULT` on every qi/s, offline and gifts too (economy check: keep it);
  VIP = `VIP_SLOTS` more disciple seats and the arch name in bright gold; Auto Orbs = every orb on the
  owner's peak is collected 1.5 s after it appears while they stand on the peak; Instant Pill = 60 s
  of 2x added on top of any running boost; Qi packs = `seconds` x the buyer's away rate (no tide, no
  pill), shown live on the tile.
- **Telemetry:** custom event `Shop` (open | prompt | bought | closed, source or item key, realm) and
  an IAP economy source for Qi packs. Funnel to read: opens by source, prompts per item, bought /
  prompts.
- **Studio test:** `ServerStorage.DebugSet:Invoke(player, "pass", "x2")` owns a pass without buying;
  player attribute `HudDevice = "phone"` forces the two-page phone layout.
- **Checked in Studio Play (2026-10-21, ids still 0):** the screen opens with both rows and every tile
  reads "Soon"; pack tiles show the live amount; DebugSet passes: 2x Qi doubled the rate (1 to 2/s),
  VIP raised the seats 5 to 6 and turned the arch name gold, Auto Orbs collected a fresh orb after
  ~1.5 s; six purple pads stand around the cauldron with their cards (owned passes say "Owned");
  `Shop` open event printed; no script errors. Not yet tested: a real prompt and ProcessReceipt (need
  real ids: test with Studio's test purchase), the phone page flip. Captures:
  `docs/art/captures/shop_screen_play.jpg`, `shop_hub_pads_play.jpg`.

The list to create in the dashboard (name, description, price, icon): [SHOP_ITEMS](SHOP_ITEMS.md).

## Welcome Pouch (D38, research `2026-10-22_cheap_buys.md`, mock `docs/art/mocks/welcome_pouch_a.jpg`)
- The entry door: **5 Robux, once per player** (`SHOP_PRODUCTS` key `welcome`, `limit = 1`): an Elder
  (bought disciple, permanent) and `qiBonus` +10% on every qi/s forever (`data.qiBonus`, kept through
  every life; Main's `rate`). Economy check (sim_economy `--bought 1.5,0.1`): realm 10 lands the same
  day as without it.
- Offered once (`Config.WELCOME`, `data.welcomeOffered`): right after a building with a `feature`
  once 5 min are played, or after any building from 10 min. The card (`Shop.client`, ScreenGui
  `WelcomeOffer`) shows the Elder with its aura and the bonus, a price button and "Not now"; the
  Boosts tab keeps a "Once" tile first until it is bought. Bought: the recruit reveal plays its Elder,
  then a "+10% forever" toast. Telemetry `Shop` "offer" / "prompt" / "bought" with key `welcome`.
- Repeatable cheap qi (Pocket Qi, short pills) was studied and left out (anchors the 29 Pouch low).

## Tide Bell (D75, owner 2026-10-23; Bee Swarm Simulator's Night Bell)
- A repeatable developer product (`SHOP_PRODUCTS` key `tidebell`): buying it starts a Spirit Tide for
  the whole server right now (`TIDE_DURATION` s of `TIDE_MULT` qi, the same tide as the schedule:
  Main `startTide`). Everyone gets a blue banner, "<name> rang the Tide Bell!" over "Spirit Tide x2 Qi
  for everyone" and the countdown (Hud `tideBanner`, mock `docs/art/mocks/tide_bell_banner.jpg`);
  the gong and the pillar play as for any tide.
- The regular schedule (`TideNext`) never moves. A tide that starts while another runs adds its
  `TIDE_DURATION` on top of the time left instead of restarting it, so a bought tide is never eaten.
- The prompt is refused, with one short line, while a tide runs or the Heavenly Altar is open or its
  heads-up is out (`ALTAR_WARN`): the altar never shares the sky with a tide.
- Shop: a "New" tile in Boosts (icon `tidebell`: the HUD sheet's bell, cell 31 once the new sheet is
  uploaded; the tide wave until then). Telemetry `Shop` "prompt" / "bought" with key `tidebell`.

## Sect Starter Pack (D75, owner 2026-10-23, card "B night jade")
- **75 Robux, once per player** (`SHOP_PRODUCTS` key `starter`, `limit = 1`). One product, three
  grants (Shop `grantProduct` handles each field of an item): an Immortal (`rarity`, a bought
  disciple), `seconds` of income in qi (like the Qi Chest, counted before the Immortal joins) and
  `pill` s of 2x Qi added to `boostUntil` (like the Instant Pill). No discount is claimed.
- Offered once (`Config.STARTER_OFFER`, `data.starterOffered`): the first time a building with a
  `feature` is bought after the Welcome Pouch was bought or its card was shown, at least `after` s of
  play after that (`data.welcomeAt`). The card (`Shop.client`, ScreenGui `StarterOffer`, mock
  `docs/art/mocks/starter_pack_B_jade.jpg`, source `starter_pack.html`): gold frame, night-jade panel,
  turning gold rays and a glow behind the Immortal with its aura, "Only once", two chips (Qi Chest,
  2x Qi), the green Robux button with a shine, "Not now", gold corner ornaments. The Boosts tab keeps
  a "Once" tile first until it is bought. Bought: the recruit reveal plays its Immortal, then a toast
  with the qi and the 2x. Telemetry `Shop` "offer" / "prompt" / "bought" with key `starter`.
- A Boosts row too wide for a phone (both once-only tiles still up) scrolls sideways (`fitRow`).

## Disciple price ladder (economy check, D28)
Relative to the 2x Qi pass price P: Elder 0.15P, Immortal 0.3P, Celestial 0.6P, Dao Ancestor 1P,
Heavenly Emperor 2P, Primordial 4P. With P = 249: about 39 / 79 / 149 / 249 / 499 / 999 Robux.
Owner (2026-10-21): "can be more expensive even for high ones", so the suggested ladder is steeper at
the top: Elder 49, Immortal 99, Celestial 249, Dao Ancestor 599, Heavenly Emperor 1,299, Primordial
2,999 (the top tiers are once per player and realm-gated, so they work as the premium anchor). The
owner sets the final prices (R5). Sim (regular player, realm 10 in ~1,026 min with nothing bought):
Celestial -9%, Dao -30%, Heavenly Emperor -45%, Primordial -65%, all three top -74%.

## Price research (2026-10-21, Roblox's own pass / product listings)
Auto-collect 175 to 350 (RT2 200, RT3 299, Mall 350, PS99 175); 2x income 299 to 600 (Brainrot 299,
Mall 600); VIP 375 to 800 (Brainrot 375, PS99 400, Mall 800); income-sized cash packs 19 to 199
(Sell Lemons 5 min 19 ... 7 d 199). A one-time starter pack (~99) and a higher-tier anchor (~1199)
are common next steps. Prices are the owner's call (R5).

## Shop island check (Studio Play, 2026-10-21)
Six islands, 13 shop pads each (78 tagged), all six disciples for sale load their avatars, no script
errors. The first layout (radius 22, pavilion) crowded the pads into each other; radius 28 with the
disciples on a back arc facing a cauldron gives every pad room. The screen's Disciples row shows the
realm gates ("Realm 3" ... "Realm 9"). Not checked: billboard cards (the Studio capture omits
BillboardGuis), a real purchase (ids still 0), tab taps (no mouse input through the MCP).
Captures: `docs/art/captures/shop_island_play.jpg`, `shop_island_disciples_play.jpg`,
`shop_disciples_tab_play.jpg`.

## Flying Swords (D76, owner 2026-10-23; v2 real flight, Adopt Me's flying pets)
- Three game passes (`SHOP_PASSES` keys `swordJade` / `swordHeavenly` / `swordCelestial`, field
  `ride` = tier; suggested 199 / 399 / 1,199): each is a sword to ride, kept forever; owning a higher
  one keeps the lower ones. Three "New" tiles in the Boosts tab (icons: cells 32 to 34 of the icon
  sheet).
- **Real flight** (owner after trying the first build, a hover ride: "i cant fly with them? When i
  jump they got removed? this is bad"; Adopt Me's flying pets and the cultivation games' Fly key
  copied). `SwordFly.client` flies the own character (the client owns its physics: PlatformStand, a
  LinearVelocity eased toward the input, an AlignOrientation facing the way you go, banked ~15
  degrees into turns, pitched into climbs and dives): WASD / the thumbstick where the camera looks,
  Space / held Jump / gamepad A rises, Ctrl or Q / the phone's down arrow / B sinks, no input
  hovers with a bob. Speed `MOVE.walk` x 1.5 / 1.75 / 2 (42 / 49 / 56), rising and sinking at
  `rise` of it. Near the ground it hovers a little over it. Jump never steps off. The climb eases off
  over the last 8 studs under the ceiling. Stepping off in the air glides down (fall capped at 25
  studs/s, Adopt Me's glide); over the void (no ground within 200 studs) the server refuses: "Fly over
  land to step off".
- The rider plays their OWN avatar's idle on the sword (and its fall in a fast dive), from their
  character's Animate values, Action priority, 0.2 s fades (PlatformStand stops the default
  Animate's tracks); the stock idle and fall when an avatar has none (owner: "ON SWORD I SHOULD HAVE my
  animations too").
- The rider stands on the blade: `SwordPose.client` (every client, in each joint's Transform after
  the Animator, Motor6D and AnimationConstraint rigs alike) lifts the body `lift` studs (a per-rider correction of up to +-1.5 eases the lowest foot
  onto the sword's BladeTop every frame, so any animation pack stands on the blade) and leans it
  `lean` degrees, the waist `waistLean` more; the sword is welded under the lifted feet (at the real
  feet when a rig has no root joint). Everyone sees it. No qi, so the economy does not move.
- Progression and limits (server, R9, `SwordRide.luau`): under `ceiling` (world Y, the highest Lotus
  Isle deck + 60), inside `bound` studs of the hub, and out of the closed islets of the rider's own
  peak (bridge not built: "Open its bridge first"; their pads need the bridge anyway). The server
  snaps back anyone over those or faster than `speedSlack` x the tier allows for `speedStrikes`
  checks (a server teleport restarts the check). Lotus Isles do not exist until built (their pads
  need the karma node), so flight reaches nothing early.
- HUD: a sword button in the right stack (after the gift, the pill and the altar row) once one is
  owned: tap = fly the last one (`data.swordPick`), tap again = land; several owned = the first tap
  opens a picker that floats beside the button.
- Off by itself near any pad (`padRadius`; a pad also ignores a rider, so a ride never buys), on the
  Heavenly Altar while a round runs (the platform and the plaza ring under it), and on death or
  reset; the rider then drops softly (Movement.client). A short line says why.
- The look (`src/server/SwordLook.luau`) is the owner-reviewed Studio mock v9
  (`tools/mock_swords_tiers.luau`, mock branch): the Creator Store blades 74897223654299 /
  13467141475 / 5131677948 with a Highlight in the tier colour, wound ribbons (1 / 2 / 3), motes, a
  shimmer and a second trail (tiers 2-3), sparks off the hilt, the Heavenly Sword's own gold bloom
  and rising sparkles (its aura asset 17781650714 turned out to be a hat mesh with no emitters), the double gold halo over the front
  half of the tier 3 blade (moved off the rider's legs), real Trails off the hilt. Effects hang on
  the sword only. The blades and aura emitters ship as data (`src/server/SwordData.luau`, dumped in
  Studio by `tools/dump_swords.luau`, dumped 2026-10-23).
- Studio test: `DebugSet "pass", "swordJade"` then `DebugSet "ride", "swordJade"` (false lands).
  Telemetry `Sword` "ride" with the key.
