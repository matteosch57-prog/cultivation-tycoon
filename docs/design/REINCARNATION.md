# Reincarnation

A new life after realm 10 (D29). Numbers live in `Config.luau`; research and pacing in
`docs/research/2026-10-21_reincarnation_design.md`.

## The reset
- **Gate:** realm `REINC_REALM` or deeper in this life, checked in the one server function
  `reincarnate` (`Main.server.luau`, remote `Reincarnate`). Lands at realm 1, below the gate.
- **Resets:** qi, buildings, realm, pill and boost, the recruit price, disciples except Shop-bought
  ones (permanent, counted in `data.shopBought`, they take no sworn seat) and the `SWORN_BASE` strongest
  of the rest.
- **Keeps:** `soulPeak` (deepest realm of any finished life), `karma`, `lives`, passes, `best`.

## Past Lives (power)
`Config.pastLivesMult(soulPeak)` = `PAST_LIVES_MULT` ^ (soulPeak - 9), on every qi source that goes
through `rate` (live and offline). It changes only when a life ends deeper than any before.

## Karma (choices)
`Config.karmaFor(realm, builtShare)` paid at each reincarnation: ~10 at realm 10, x2.15 per realm deeper,
and the share of the current realm's pads counts. Spent in the Dao Tree (not built yet).

## Screen and HUD
- HUD: a "Rebirth 3/10" chip beside the realm name above the progress bar; gold and wobbling from
  realm 10 ("Rebirth!"). It opens `Reincarnation.client.luau`.
- Screen (Shop language, no board): the road of realms 1 to 10 as dots (done jade, now gold), the
  NEXT step (build N more, break through, or reincarnate), what a new life gives (Past Lives before
  and after, karma, the sworn disciple), and a Reincarnate button that needs a second tap within 4 s.
- Player attributes: `Lives`, `Karma`, `SoulPeak`, `PastLives`, `NextPastLives`, `ReincKarma`.

## Telemetry
`Reincarnate` event: life that ended, realm reached, hours in that life.
