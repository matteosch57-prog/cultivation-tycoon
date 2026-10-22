# Feel: sound, motion, light

The juice layer (D16). Reference: research on top Roblox clicker/tycoon games (2026-10-21): constant
small rewards, rewards fly to the counter, the most frequent sound is the quietest.

## Launch (src/first/Launch.client.luau, D43)
- From the first frame: jade veil, title, a qi drop that fills with the real progress (game loaded,
  HUD drawn, server `PeakReady`, avatar on the peak; a slow creep while one is pending; offered
  anyway after 30 s). Full: rays, the drop swells, "TAP TO ENTER" (tap, click, Space, Enter, A).
- The tap fades the veil while the camera dives from 150 studs above onto the follow view (1.6 s),
  then the local attribute `LaunchDone` opens the Heavenly Gift (Intro) or the return screen.
- Server: `Players.CharacterAutoLoads = false`; onJoin calls `LoadCharacter` once the peak is built
  (`watchDeath` respawns after `RespawnTime`), so the avatar never stands on the hub first.

## First-time tips (src/client/Tips.client.luau, D50)
- One at a time, after the launch screen and the Heavenly Gift: the idle chest pad ("Step on the
  green pad"), then the nearest qi orb ("Walk into it"), then a ready pill ("Tap: 2x qi").
- World tips: a BillboardGui bubble with a bobbing gold arrow over the target, and the guide trail
  points there (local attribute `TipTarget`, Guide.client). The pill tip sits right of the HUD's
  `PillButton` and points at it.
- The server marks each one done when the player does it (orb taken, pill used, chest opened):
  `data.tips`, player attribute `Tips`.

## Daily Blessing (src/client/Streak.client.luau, D58)
- Once a day after the launch screen and the gift (a brand-new save's first session waits 90 s):
  a veil, slow gold rays, "Daily Blessing", seven tiles (done = jade with a tick, today = gold,
  lifted and breathing, disciple days pale gold with the disciple in its aura), a shining Claim.
- Claim: today's tile turns jade, the reward line replaces the "streak waits for you" note, the
  button reads "See you tomorrow!" and closes the card. Studio hooks `StreakOpen`, `StreakClaim`.

## HUD (src/client/Hud.client.luau, D54 D55 D59)
- Two quiet rails. Left = what you open: Shop (the only gold button), Disciples (count), Karma (opens
  the Karma Shop page straight away, `ReincOpen:Fire("karma")`), Friends (`Friends.client`, caption =
  friends bonus). Right edge, under the next goal = what ticks, round chips: gift (its next reward
  always shown: qi + free summons, then its timer or the time to the daily reset), pill, the altar row
  (`Altar.client`). Numbers under buttons, no words. Karma counter beside qi once the player has karma
  or a past life. Mocks `docs/art/mocks/hud_menus_*`, `hud_phone_*`; render `tools/mock_hud_menus.py`.
- `PlayerGui.HudSlots`: `Left` / `Right` (ObjectValues, the current rails) and `Rebuilt` (fired after
  every HUD rebuild). Another script's row parents itself to a rail and re-parents on every Rebuilt;
  before a rebuild clears the HUD, rows without the `HudOwn` attribute step out (else the clear
  destroyed them: the altar row's "Parent property locked" errors). LayoutOrder: right = gift 1,
  pill 2, altar 3; left = Shop 0, Disciples 1, Karma 2, Friends 3.
- Phone fit (layout()): the Recruit seal sits left of the jump button, lifted above the realm bar when
  it reaches over the bar's end (above the jump button it covered the goal on big touch screens). The
  right stack is placed from the seal's computed rectangle plus its x10/x50 picker: a column if it
  ends above them, else one row, else it moves left of the seal. Studio check: HudDevice "phone", the
  root scaled to 427 px tall, a fake `TouchGui.JumpButton` (70 px at 1,-95 / 1,-90).
- Red dots (D59): one look, `Toy.dot` (ruby gem: outline, light-to-deep fill, glint, red glow, slow
  breathing). The server lights them in `Dots.luau` and publishes JSON attribute `Dots`; `MenuOpened`
  marks one followed (saved in `data.dots`). Every HUD dot leads to a dot inside, drawn from a
  snapshot taken when the screen opens (the server has already cleared it by then):
  Disciples (new names since the list was opened) -> each new disciple in the list; Karma (a node
  newly affordable; lights again only for another node) -> each such tile, the Karma Shop link and
  bought tiles clear; Rebirth chip (a new life open) -> the Reincarnate button; Friends (Sect Gift
  unclaimed, at most once a day) -> the card's Claim; Shop -> the Boosts tab -> the free Daily Gift
  tile. Gift and pill dots come from their own ready attributes; claiming clears them.
- Daily Gift: first tile of the Shop's Boosts, `SHOP_FREE_SECONDS` of income once per UTC day, first
  after `DOT_SHOP_FIRST` s of play (`ClaimShopFree`, `data.shopFreeDay`, attribute `ShopFreeIn`).
  Claiming is the only thing that clears the Shop's dot.

## Buying (src/client/Build.client.luau)
- Pads are concept C "Formation" (D27, playable mock `docs/art/mocks/pads_formation_mock.html`). The
  server places an invisible anchor tagged `StepPad` (`PadKind` build / breakthrough / shop); every
  client draws it: a carved slate disc, a stone octagon, a gold heart holding a PointLight, and two Neon
  rune rings (12 + 8 segments) turning in opposite ways. About 550 triangles a pad; rings only turn
  within 120 studs of the camera, and only pads within 70 studs keep their light on.
- One colour language (`src/shared/PadLook.luau`): ready = the kind's colour (build jade, breakthrough
  gold, shop amethyst) on rings, light, beam and price; not affordable = red, rings still, light dim.
- Ready pads breathe (light pulse, a ground ring pulsing outward). The moment a pad becomes affordable:
  a soft ding, a ripple and a quick spin.
- Price card: HUD style (outlined text, no panel), drawn on top: name, feature line, price in the
  kind's colour with its currency icon (the qi drop; shop cards the Robux mark); "Need X more" in red when standing on a pad you cannot afford. Shop cards
  (`Shop.client`) use the same sizes and colours.
- Guide trail (`Guide.client.luau`, D22): jade chevrons painted on the ground from the feet to the
  HUD's "Next:" pad, drifting toward it; always in realm 1 until `GUIDE_BUILT` buildings, then only
  after `GUIDE_IDLE` s standing still. Objects, not light (R3).
- Preview: within 18 studs the building appears as a jade hologram floating in pieces, pulled apart and
  tilted; the closer you walk the tighter it gathers (never whole before the buy). A soft sparkle when
  it wakes. Piece offsets come from each piece's position, so the real building continues from them.
- Step on: the rings spin up (flutter), snap inward with a stone snap, a column flash, a ripple and
  sparks; coins + chime; the pad sinks away. A step that cannot buy: one soft boink and a twitch.
  After a buy every pad waits until you stand on none (the step-out once chained 5 buys).
- Build-in: the pieces drift out a little, swirl in and lock together bottom first (accelerating, a
  snap rather than a drift), then a stone snap, a small temple bell (the big bell for a Main Hall
  level), sparks, dust and a warm light flash. The pieces do not collide while they fly (they shoved
  the avatar onto the next pads in Play).

## Recruit reveal (src/client/RecruitReveal.client.luau, D34)
- A qi orb flies from the Recruit button to the screen centre (`REVEAL.fly`), charges one `step`
  per rarity above Outer Disciple (colour climbs grey, green, blue, purple..., each step a rising
  `padReady` ding and a harder shake), then bursts (white ring, drops) into the disciple card.
- Burst sounds climb: `recruit` always, `rareChime` from Core, `powerUp` from Elder, `gong` from
  Immortal, `thunder` from Dao Ancestor. Aura: glow for all, rays from Core, a white counter ring
  from Elder, sparkles from Immortal, Primordial cycles every colour. Juice lights the platform
  column at the burst (`Config.revealBurst`). A tap skips to the burst, then to the end.
- **x10 / x50** (D52, `REVEAL_MULTI`): every orb flies out of the seal (`rise` whoosh), lands in a grid
  (5 x 2, or 10 x 5; `padSnap` ticks) and breathes faster under a `padSpin` swell; a rare orb (Core or
  better at x10, Elder or better at x50: `Config.revealMultiRare`) shakes harder and tints toward its colour. They open in a wave (`Config.revealMultiTimes`): a white
  flash, a ring, sparks and a rising `padReady` ding each (every third at x50); a rare one holds the
  wave `rarePause` s with `rareChime`, a screen shake and rays. Then the best grows into the usual card
  (white flash, shake, the single reveal's burst sounds), the tiles slide into tray rows under it
  (`land` chime) with a count per rarity. A tap skips to the card, then to the end.
  Studio captures: the local player attribute `RevealAt` (seconds) holds the reveal at that moment.
- **The x1 / x10 / x50 selector** shows above the seal on a press or a hover (even without the qi) and
  hides `RECRUIT_PICK_SECONDS` after; each chip shows its batch price and greys out when out of reach.

## Moving (src/client/Movement.client.luau, D34)
- A cultivator's light step: walk, jump height and the soft fall are `Config.MOVE`. While falling an
  upward VectorForce takes `floatFall` of gravity away, so landings float down.
- **Cloud step:** a new jump press in the air (keys, pad or the phone's jump button) kicks the avatar
  up once per jump and leaves a jade ring under the feet (a plain part, not a light, R3).
- Run, jump and fall play the player's own avatar animations (owner 2026-10-22: "I want to use my
  avatar fully"; the Ninja run and Levitation jump that replaced them are gone).

## Constant motion (src/client/Juice.client.luau)
- "+qi" floats off every earning building every 3 s (staggered).
- Orbs bob and spin; collecting one flies qi drops into the HUD counter, which bounces.
- Toy buttons grow on hover, squish on press, spring back.

## Sound (src/shared/Sfx.luau)
- All Roblox-licensed library audio (no uploads). Pools per sound, random pitch, SoundGroups SFX /
  Music / Ambience. Onsets and loudness measured in Play and trimmed (`from`, `vol`, `to`).
- Frequent sounds (click, toast) are the quietest layer; big ones (gong, thunder) only on rare events.
- Ambience: quiet birds + a positional waterfall loop. Music: 3 candidates, Workspace attribute
  `MusicTrack` switches live; the owner picks by ear.

## Light events
Recruit: a column in the rarity colour on the platform (taller for rarer). Expansion: a big column over
the peak. Pill: gold column around the player. Orb: a flash. Spirit Tide: a pale blue column over the peak and a soft gong.
