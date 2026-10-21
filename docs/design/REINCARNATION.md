# Reincarnation

A new life after realm 10 (D29). Numbers live in `Config.luau`; research and pacing in
`docs/research/2026-10-21_reincarnation_design.md`.

## The reset
- **Gate:** realm `REINC_REALM` or deeper in this life, checked in the one server function
  `reincarnate` (`Main.server.luau`, remote `Reincarnate`). Lands at realm 1, below the gate.
- **Resets:** qi, buildings, realm, pill and boost, the recruit price, disciples except Shop-bought
  ones (permanent, counted in `data.boughtDisciples`, they take no sworn seat) and the `SWORN_BASE` strongest
  of the rest.
- **Keeps:** `soulPeak` (deepest realm of any finished life), `karma`, `lives`, passes, `best`.

## Past Lives (power)
`Config.pastLivesMult(soulPeak)` = `PAST_LIVES_MULT` ^ (soulPeak - 9), on every qi source that goes
through `rate` (live and offline). It changes only when a life ends deeper than any before.

## Karma (choices)
`Config.karmaFor(realm, builtShare)` paid at each reincarnation: ~10 at realm 10, x2.15 per realm deeper,
and the share of the current realm's pads counts (x(1 + `DAO_ECHO` x Soul Echo level)).

## Karma Shop (the Dao Tree, owner: "a karma shop")
`Config.DAO`: permanent nodes, `costs[i]` = karma for level i, remote `DaoBuy(key)`, levels saved in
`data.dao`, published as `Dao_<key>`. Sworn Bond (+1 disciple follows you per level), Disciple Seat
(+1 slot), Old Foundations (a new life starts with every building of its landing realm), Rebirth Gate
(a new life lands at `DAO_REBIRTH_REALMS[level]`, realm 3 then 5, always below the gate), Elixir Mastery
(a brewed pill lasts `DAO_PILL_SECONDS` more per level), Deep Meditation (+`DAO_OFFLINE_SECONDS` offline
cap per level), Soul Echo (+`DAO_ECHO` karma per level), Heavenly Hands (a gold hand on the HUD "Next"
card builds that pad from anywhere: remote `HandsBuild(padId)`, the server checks the node, the owner,
the price and `HANDS_COOLDOWN`, then pays through the same `buyPad` as standing on the pad). Nothing copies a paid pass. A node with `lines` shows the line of its next level. Opened from the
"Karma Shop" button under Reincarnate; tiles in 2 rows of 4; tiles in the Shop's language (icon, name, one line, level pips,
price). Event `KarmaShop`: node, level, life.

## What each realm shows (realms 6 and up)
`src/server/RealmLook.luau` builds `plot.look` (folder `RealmLook`) from the peak's realm and island
size; `RealmLook.apply` runs at the end of `buildGrounds` and in `rebuild`, and does nothing when
neither changed. Cumulative inside a life, gone after a reincarnation:
- 6 Void Refinement: three soft clouds hug the rim, tinted `Config.realmTint`.
- 7 Body Integration: floating rocks ring the peak (blocks only; the front sixth stays clear).
- 8 Mahayana: a second waterfall at `REALM_FALL_ANGLE`.
- 9 Tribulation Transcendence: a solid slate storm cloud of ~8 Ball puffs behind the hall (attribute
  `Storm`; owner pick A after a particle haze read as a smudge);
  `RealmLook.client.luau` flashes a short neon bolt in it every 9 to 20 s while it is on screen (R3
  event flash, R16) and a soft thunder within 260 studs.
- 10 True Immortal: a gold Foil halo over the Main Hall spot (no light, sunlit metal); from 11 its
  colour climbs the rarity ladder from Celestial.
A breakthrough to a realm with a look toasts its line to the owner (`Config.realmLookLine`, Notify
`realmLook`).

## Screen and HUD
- HUD: a "Rebirth 3/10" chip beside the realm name above the progress bar; gold and wobbling from
  realm 10 ("Rebirth!"). It opens `Reincarnation.client.luau`.
- Screen (Shop language, no board, as little text as possible: owner "too much text"): the road of
  realms 1 to 10 as dots (done jade, now gold), one NEXT line (build N more, break through, or
  reincarnate), two numbers (the Past Lives multiplier a new life would give, the karma), and a
  Reincarnate button that needs a second tap within 4 s.
- Player attributes: `Lives`, `Karma`, `SoulPeak`, `PastLives`, `NextPastLives`, `ReincKarma`.

## Telemetry
`Reincarnate` event: life that ended, realm reached, hours in that life.

## Checked
Studio Play on integration (mock save), 2026-10-21: the chip reads "Rebirth 1/10", gold "Rebirth!" at
realm 10; a reincarnation from realm 10 gave life 2, +10 karma, Past Lives x3 (rate x3), kept the
strongest disciple (sworn) and the Shop-bought one, and a second call was refused. Captures:
`docs/art/captures/reinc_screen_realm1.jpg`, `reinc_screen_realm10.jpg`, `reinc_screen_life2.jpg`.
Studio Play on integration (mock save, camera only), 2026-10-21 evening: realms 6 to 10 build their
looks (clouds, 6 rocks, second waterfall, storm, halo); a storm strikes about twice in 30 s; a
reincarnation with Rebirth Gate 2 + Old Foundations landed at realm 5 with 27 / 27 built; Heavenly
Hands built the breakthrough from the HUD (a wrong pad id and a call inside the cooldown were refused)
and the realm 6 line toasted. Particle clouds made on the server fill in over ~15 s on clients.
The first storm (a particle haze) read as a grey smudge twice; owner picked solid puffs (A). Captures: `realm6_void_clouds.jpg`,
`realm10_all_looks.jpg`, `hands_next_card.jpg`.
