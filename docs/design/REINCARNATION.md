# Rebirth (Reincarnation)

Muscle Legends' rebirth, copied as it is (D63, owner: "copy the successful games, don't reinvent the
wheel"). Numbers live in `Config.luau` (`REBIRTH_*`); research `docs/research/2026-10-22_rebirth_standard.md`.

## The rebirth
- **Price:** qi, `Config.rebirthPrice(rebirths)` = `REBIRTH_PRICE` + `REBIRTH_PRICE_STEP` x rebirths
  (theirs: 10k strength, +5k each). Checked in the one server function `reincarnate`
  (`Main.server.luau`, remote `Reincarnate`). Qi goes to 0, so a repeat needs the whole price again.
- **Resets:** qi, buildings, realm (back to realm 1 with its pads built, D56), pill and boost, the
  recruit price.
- **Keeps:** every disciple (their pets, D44), `karma`, `lives`, passes, `best`. `soulPeak` is kept as
  a record only.
- **Boost:** `Config.rebirthMult(rebirths)` = 1 + `REBIRTH_BONUS` x rebirths (theirs: +5% each,
  adding up; Economy set +50%) on every qi source that goes through `rate`, never in the price income. `rebirths` = `lives` - 1.
- **Karma** (their gems): `Config.rebirthKarma(rebirths)` = `REBIRTH_KARMA` + `REBIRTH_KARMA_STEP` x
  rebirths each rebirth (x Soul Echo), spent in the Karma Shop.
- **Areas** (their gyms): `Config.REBIRTH_REALMS` names the rebirths a realm needs; the breakthrough
  pad into it does not appear before that.

## Karma Shop (the Dao Tree, owner: "a karma shop")
`Config.DAO`: permanent nodes, `costs[i]` = karma for level i, remote `DaoBuy(key)`, levels saved in
`data.dao`, published as `Dao_<key>`. Disciple Seat
(+1 slot), Elixir Mastery
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
- HUD: the Rebirth chip shows how much of the price you hold ("42%"), gold and wobbling at "Rebirth!".
  It opens `Reincarnation.client.luau`.
- Screen: "Rebirth N", the boost now -> after (x1.05 -> x1.1), a bar filling with your qi up to the
  price, the karma it pays, "Opens <realm>" when this rebirth opens the next realm, and a Rebirth!
  button that needs a second tap within 4 s. The Karma Shop button stays under it.
- Player attributes: `Lives`, `Karma`, `Rebirths`, `RebirthPrice`, `RebirthMult`, `NextRebirthMult`,
  `RebirthKarma`, `RealmNeedsRebirths`.

## Telemetry
`Reincarnate` event: life that ended, realm reached, hours in that life.

## Checked
- 2026-10-22 rebirth (D63): Studio Play with the branch scripts pushed over integration (mock save).
  Fresh player: price 100K, x1 -> x1.5, +2 karma; at realm 2 fully built no breakthrough pad (realm 3
  needs 1 rebirth). A call with too little qi refused; with 180K qi a rebirth gave life 2, realm 1 built
  (14 pads), qi 0, +2 karma, x1.5; a second call refused. After it, realm 2 fully built shows the
  breakthrough pad. HUD chip "74%". No script errors. Capture `docs/art/captures/rebirth_screen_play.jpg`.
- 2026-10-22 skins (D53): Studio Play on integration, DebugSet realm 1 / 3, then realm 4 life 3: every building Timber / Jade / Void Amethyst, Main Hall lanterns and motes, title over the head; no script errors (captures `docs/art/captures/2026-10-22_skin_play_*.jpg`). Known: the Celestial Palace roof (Kit GOLD_TILE) stays gold below Imperial Gold; a few Kit paints (PAINT_GREEN / BLUE) are not remapped.
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
