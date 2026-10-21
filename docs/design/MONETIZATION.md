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
