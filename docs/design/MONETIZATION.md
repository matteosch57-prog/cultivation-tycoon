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

## How the shop works (built 2026-10-21, D24)
- **Screen = mock B** (`docs/art/mocks/shop_B_phone.jpg`): no board, toy tiles over a dark veil.
  Boosts row (the three passes + Instant Pill), Qi row (three packs). A phone that cannot fit both
  rows flips pages with a "More Qi" / "Boosts" tile. Opened by the HUD's gold Shop button (always on
  top of the left column). Code: `src/client/Shop.client.luau`, drawing kit `src/shared/Toy.luau`.
- **World shop:** purple pads in a ring around the hub cauldron (`Config.SHOP_PADS`), one item each;
  stepping onto one prompts that item (only for a player seen off it first; an owned pass shows a
  toast instead). Each pad is a `StepPad` (`PadKind` "shop", `ShopKey`), so the pad juice look can
  restyle it; the card with the price is drawn by `Shop.client`.
- **Ids and prices:** the owner pastes each pass / product id into `Config.SHOP_PASSES` /
  `Config.SHOP_PRODUCTS` (id 0 = "Soon", never prompts). Prices are never in code: the client reads
  them from `MarketplaceService` (passes are regionally priced, so one typed price would be wrong).
- **Server only** (`src/server/Shop.luau`): the client sends an item key; the server checks it and
  prompts. Products are granted in `ProcessReceipt`: grant + `PurchaseId` go into the save
  (`data.receipts`, last `RECEIPTS_KEPT`), and `PurchaseGranted` is returned only after that save
  landed. A retry finds the id and grants nothing twice. Passes: `UserOwnsGamePassAsync` on join
  (before the offline qi, so 2x counts on it) and `PromptGamePassPurchaseFinished` live; ownership is
  never saved (Roblox is the record).
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

## Price research (2026-10-21, Roblox's own pass / product listings)
Auto-collect 175 to 350 (RT2 200, RT3 299, Mall 350, PS99 175); 2x income 299 to 600 (Brainrot 299,
Mall 600); VIP 375 to 800 (Brainrot 375, PS99 400, Mall 800); income-sized cash packs 19 to 199
(Sell Lemons 5 min 19 ... 7 d 199). A one-time starter pack (~99) and a higher-tier anchor (~1199)
are common next steps. Prices are the owner's call (R5).
