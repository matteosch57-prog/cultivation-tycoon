# Reincarnation

A new life after realm 10 (D29). Numbers live in `Config.luau`; research and pacing in
`docs/research/2026-10-21_reincarnation_design.md`.

## The reset
- **Gate:** realm `REINC_REALM` or deeper in this life, checked in the one server function
  `reincarnate` (`Main.server.luau`, remote `Reincarnate`). Lands at `REINC_LAND_SHARE` of the
  deepest realm, fully built (D40, at least realm 1): always below the next paying depth.
- **Resets:** qi, buildings, realm, pill and boost, the recruit price.
- **Keeps:** every disciple (D44, owner: "let people accumulate them"; the sim shows no pace cost), `soulPeak` (deepest realm of any finished life), `karma`, `lives`, passes, `best`.

## Past Lives (power)
`Config.pastLivesMult(soulPeak)` = `PAST_LIVES_MULT` ^ (soulPeak - (`REINC_REALM` - 1)), on every qi
source that goes through `rate` (live and offline). The gate is realm 2 (D37): the first new life
comes ~10 min in and each later life runs a little longer than the last. It changes only when a life ends deeper than any before.

## Karma (choices)
`Config.karmaFor(realm, builtShare)` = `KARMA_GROWTH` ^ (realms past the gate + builtShare): 1 at the
gate, ~25 eight realms deeper (x(1 + `DAO_ECHO` x Soul Echo level)). Paid only when the life ends
deeper than every life before (D37): a reset at the same depth takes minutes, so it pays nothing.

## Karma Shop (the Dao Tree, owner: "a karma shop")
`Config.DAO`: permanent nodes, `costs[i]` = karma for level i, remote `DaoBuy(key)`, levels saved in
`data.dao`, published as `Dao_<key>`. Disciple Seat
(+1 slot), Old Foundations (a new life starts with every building of realm 1), Elixir Mastery
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
- 9 Tribulation Transcendence: lightning only (owner pick B: two particle hazes and a puff cloud all
  read wrong). `RealmLook.client.luau` strikes the air just past the rim behind the peak every
  `STORM_EVERY` s while it is on screen (R16). Built from research: a midpoint-displacement channel with
  1 or 2 dimmer branches (gamedev.net "Lightning Bolts", krazydad bestiary), a white core inside a pale
  sheath, 2 to 4 strokes ~60 ms lit and 40 to 80 ms apart like real return strokes (NAP "The Earth's
  Electrical Environment" ch. 21, WTOC "Anatomy of Lightning"), a PointLight at the foot only while a
  stroke shows (R3 event flash, DevForum "Lightning Effect": impact needs a flash and a sound) and
  thunder after distance / `STORM_SOUND_SPEED` within `STORM_HEAR`.
- 10 True Immortal: a gold Foil halo over the Main Hall spot (no light, sunlit metal); from 11 its
  colour climbs the rarity ladder from Celestial.
A breakthrough to a realm with a look toasts its line to the owner (`Config.realmLookLine`, Notify
`realmLook`).

## Building skins and status (D53)
`Skin.apply` recolours each building after `Builders` makes it (nearest `Style.PAL` colour, same
offset, Neon untouched) to the grade `Config.skinFor(realm, lives)` names: `SKIN_REALM_GRADES` for
realms 1 to 4, `SKIN_LIFE_TOP` from realm 4 in later lives. `Skin.extras` (not for previews) adds
`SKIN_LANTERNS` stone lanterns round the Main Hall per life and a mote emitter over buildings at least
`SKIN_MOTE_MIN` wide from `SKIN_MOTE_FROM` (`Config.skinLevel`). `StatusTitle.client` draws the realm
name in `Config.realmColor` and "Nth Life · grade" over every head from the Realm / Lives attributes.
Studio: `DebugSet:Invoke(player, "lives", 3)` rebuilds with that life's look.

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
The storm cloud never read right (two particle hazes, then solid puffs); owner picked lightning only (B). Captures: `realm6_void_clouds.jpg`,
`realm10_all_looks.jpg`, `hands_next_card.jpg`.
Lightning (pick B) checked in Studio Play 2026-10-21 by a temporary script push: a 48-segment bolt with
branches struck behind the peak ~10 s after realm 9 (`realm9_lightning.jpg`, the bolt held for the shot).
