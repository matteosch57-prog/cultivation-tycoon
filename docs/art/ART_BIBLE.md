# Art bible: the look of Cultivation Tycoon

How the world looks and the rules `src/server/Style.luau` builds to. Research behind it: the
2026-10-21 look pass (lighting recipes, stylised building craft, phone budgets). Captures of every
pass live in [captures/](captures/); HUD mocks in [mocks/](mocks/).

## What makes it read "premium"
1. A dominant roof: as tall as the walls or taller, deep overhang, dark soffit and rafter ends underneath.
2. Coloured shadows: lifted lavender ambient, never black.
3. Few modules reused everywhere (clone, never regenerate): instancing keeps phones fast.

## Lighting (authored in Edit, saved with the place; the server never overrides it)
The values below are the DAY look: light C, owner pick 2026-10-23 (captures `2026-10-22_light_*`).
Night = `Config.NIGHT` (blue hour, mock `docs/art/mocks/2026-10-23_night_N2_*`); `DayNight.client` blends
from these place values to it and back (`Config.DAY_SECONDS` / `NIGHT_SECONDS` / `NIGHT_FADE`).
- LightingStyle Realistic, PrioritizeLightingQuality false (the vista needs view distance).
- ClockTime 17.25, Latitude 35, Brightness 2.5, Exposure -0.15.
- Ambient 105,95,120 · OutdoorAmbient 150,135,165 · ColorShift_Top 255,215,175.
- EnvDiffuse 0.5 · EnvSpecular 0.6 · ShadowSoftness 0.35.
- Atmosphere: Density 0.3, Offset 0.32, Color 255,215,175, Decay 125,145,195, Glare 0.18, Haze 1.8.
- ColorCorrection: Brightness 0.02, Contrast 0.1, Saturation 0.15, Tint 255,248,238.
- Bloom: Intensity 0.35, Size 28, Threshold 1.8 (high, so white plaster and clouds never glow).
- SunRays 0.22 / Spread 0.42 (more, longer rays). Sky SunAngularSize 11. DepthOfField off in gameplay.

## Sky and clouds
- Sky: `Lighting.ActiveSky`, a painted anime-style skybox from the Creator Store (asset 90335763728419).
  The uploader looks like a re-upload account; its hidden scripts were deleted on insert. If Roblox
  moderates it the sky falls back to default; the original is parked as `ServerStorage.Sky_Original`.
  MoonAngularSize 0. Long term: commission or paint our own six faces.
- Sky all round (owner pick A 2026-10-23, mocks `docs/art/mocks/2026-10-23_skybox_*`): the pack is flat blue
  below the horizon, so `Config.SKY` swaps in re-authored faces (each side's painted top half mirrored under the
  horizon, Dn = Up flipped) and sets Atmosphere Density 0.12 / Offset 0 / Haze 0 at boot. Any Haze above 0 paints
  the whole lower skybox flat teal and hides the mirror, so night Haze is 0 too. The place keeps the originals.
- Cloud sea: `Style.softCloud`, big slow particles with the built-in smoke texture
  (`rbxasset://textures/particles/smoke_main.dds`, no upload): blue-shaded base, white body, crown.
  Solid-ball cumulus read as plastic next to the painted sky; mist on balls did not fix it (D9).

## Ground
- Island tops are terrain. The lawn is **LeafyGrass** (no blades); tall **Grass** only in a few meadow
  patches near the rim (D14). Grass blade length and Decoration are not scriptable (Studio Properties).
- FillCylinder snaps the surface to the 4-stud grid: the whole map stands at world y = 2 (`BASE_Y` in
  `Main.server.luau`) and every grass cylinder is centred at world y = -4 (RULES R6).
- Under every ground-touching part the bladed Grass (meadow patches) turns to packed earth
  (`paintGround`), so blades never grow through stairs and floors. The LeafyGrass lawn has no blades and
  is left alone (painting it too turned half the lawn to earth, visual check 2026-10-21).

## Islands
- Lobed top (lobes reach at most 1.05 x radius: Main clears terrain on that promise), darker lip,
  dirt band, a light sandstone shelf, rock rings fading from sandstone A08A74 to slate 5A5670 downward,
  hanging spires, grass drips over the rim, dangling roots, small floating rocks.
- One waterfall per peak (`Style.waterfall`, particle stream + mist) at the angle in `WATERFALL_ANGLE`.
- Round water (D45, `Style.pond` / `koiPond` / the waterfall pool): a ring of low-poly boulders
  (`Lowpoly.rock`, Slate in the three stone tones) half sunk with pebbles between, water at ground
  level reaching under them, ripples cut to the circle. Never a square ripple patch on round water.
  Captures `docs/art/captures/2026-10-22_pond_rims_*.jpg`.
- Koi pond (D46): red drum bridge rim to rim, koi = the `Config.KOI` mesh (never fish built from
  parts). Capture `docs/art/captures/2026-10-22_koi_pond_bridge_koi.jpg`.

## Palette
Vermilion B8352B · tile 3E4656 · gold D4A445 · plaster EDE3CF · timber 5A3A29 · jade 6FB59C ·
stone 9C978C · sakura F4B6C2 / E98FA6 / FAD4DC · pine 2E5B47 / 3F7A5C · lawn 7DAA5C · earth A8957A.

## Building craft
- The avatar is ~5 studs: doors 7 to 8 tall, columns 1.2 to 1.6 thick, hero halls 1.3 to 1.6x real scale.
- Three parts: plinth (stone, stair, balustrade) / colonnade (vermilion, gold collar, jade bracket
  sets) / roof. Curved hip roof = rows of slabs on a concave profile; hip ridges end in an upturned curl.
- Detail lives at the ridge, the eave line and eye level; wall fields stay plain.
- Buildings on the sides face the centre of the peak (`facingCentre` in Builders), never the void.

### The kit: small to big (`src/server/Kit.luau`)
Halls are assembled from finished pieces, never drawn one-off: piece (column, bracket set,
railing, lattice panel, tile ends) -> bay (two columns, beam, panel, railing) -> hall (platform,
bays, one or two roofs). Learned from studying reference temple halls (2026-10-21):
- Long and low: a hall is several bays wide and two deep, roofs shallow; a level grows by bays and
  a second roof, not by height.
- Detail lives at eye level and repeats: railings round the deck, a lattice panel in every bay
  behind a porch, a bracket set on every column, round tile ends along every eave.
- Detail comes from the material where it can: roofs use `ClayRoofTiles` instead of rib parts,
  walls use `Plaster`.
- One method everywhere: the Main Hall levels, Disciple Hall, Quarters, Library and Peak Shrine all
  call `Kit.hall`; gates (`Kit.gate`: the Sect Gate, the peak entrance, the Sect Market), the furnace
  pavilion (`Kit.pavilion`), the Bell Tower, the Moon Gate and the pagoda (`Kit.pagoda`, also the
  Main Hall level 5 towers) are built from the same column, bracket,
  railing, panel and tile-end pieces under a kit roof (`ClayRoofTiles`, round tile ends).
- Name boards (`Kit.plaque`): a dark board in a gold frame, the name in gold Fantasy. A one-roof hall
  hangs it in the middle bay (odd bay counts only), a two-roof hall on the upper storey between the
  eaves. The text is the pad name; the Sect Gate shows the sect's name. The SurfaceGui goes on the
  board's Back face (its +Z side, toward the viewer) with SizingMode PixelsPerStud. Captures 70, 71 (Play).
- Moon Gate: the ring is cut from blocks whose outer corners sit on the circle, and the wall between
  ring and square is strips whose ends hide under the ring (24 long blocks read as a cog wheel).
Captures: [captures/57 to 60](captures/), before/after [63 to 69, 72](captures/).

## Cultivators (disciples on the platform)
- Real R15 Roblox avatars built by `src/server/Cultivators.luau` from a HumanoidDescription: catalog
  hanfu (layered clothing, which any experience may put on an NPC), hair and beard. Lineup mock
  [cultivators_avatars.jpg](mocks/cultivators_avatars.jpg); the earlier part-built mock
  [cultivators_lineup.jpg](mocks/cultivators_lineup.jpg) set the colour and aura rules.
- Bodies and faces (owner pick A + C, 2026-10-21, mocks `characters_AC2_*.jpg`): Roblox's Man and Woman
  bodies and ONE anime dynamic head for everyone (Anime Black, 14506610025): one cohesive style reads
  premium, a mix of catalog faces read cheap. FaceControls let the client close the eyes in meditation,
  open them now and then and smile at a close player. Hands meet in the lap (a mudra), which also hides
  the blocky hands. Each look carries a signature item: sword, fan, flute, guqin.
- Four looks cycled by slot: sword disciple (black cultivator hair), lotus maiden (buns with hairpins),
  pill monk (cultivator hair), elder sage (white cultivator hair and beard).
- The rarity owns the robe: white, green, blue, purple, gold, Celestial teal (azure hanfu), Dao Ancestor
  crimson (robe under a red cloak), Heavenly Emperor red-gold, Primordial white under a white cloak. A
  dark robe hides the rarity, so every robe is checked in a capture before it ships.
- Aura ladder, every piece in the rarity colour and made of light (glowing meshes and particles, no
  Lights, R3): Inner a magic circle on the ground; Core orbs of light (a halo, a star heart, a sparkle
  tail; never solid balls) and a rim glow (Highlight); Elder the circle again as a halo behind the head;
  Immortal a fan of spirit swords behind the back (3, then 5 / 7 / 7 / 9); Celestial a second wider
  circle; Dao Ancestor a lotus seat; Heavenly Emperor a ring pulse on each breath; Primordial runs through
  every colour. Circle, swords and lotus are free Creator Store meshes drawn through SpecialMesh
  (Cultivators.luau names the ids). The swords are a real steel jian with a black and gold hilt (owner
  pick D, `characters_sword_options.jpg`): never painted in the rarity colour, the rarity shows as a
  rim glow (Highlight) and light orbs along the blade (`characters_sword_D.jpg`). Captures: `characters_play_*.jpg`.
- Ornaments grow with the rarity: blossom hairpins (lotus maiden, Inner to Elder), jade bead necklace
  from Core, the RUYI sun crown (Xi Guan) from Immortal, the great gold crown (Jin Guan) from Heavenly
  Emperor. Top female gowns: Ethereal Blossom black (Dao Ancestor), Gold Koi Empress red (Emperor).
- Life (client): a raised-hand mudra now and then, a qi surge every 14 to 28 s (deep breath, orbs and
  circles race, the rim brightens a little), a small bow to a visitor. Timers restart when a figure
  comes into view, or every overdue surge fires at once.
- Arrival (D41): a new recruit's seat gets a standing copy behind the cushion; the client walks it in
  with Roblox's R15 walk (rbxassetid://507777826, plays in any experience), it bows, then the seated
  figure fades in with a puff of motes. Late joiners see only the seated figure.
- Flying pose (thumbnails, showcases): `Cultivators.build(..., { pose = "fly" })` stands the disciple
  on a big spirit sword in the rarity colour (wind sparkles off the hilt), right hand forward in a sword
  mudra, left arm trailing back; no ground circles. Capture `characters_flying.jpg`.
- Layer gotchas: an emitter on an Attachment emits from one point, inside the body, where the avatar
  hides it (motes rise from an invisible ring part instead); a flat ground sprite needs a positive
  ZOffset or the floor hides it; fire wisps and beam ribbons were tried and dropped (hidden, or faint
  white arcs over the bright sky).
- Phone budget: aura layers switch off beyond 90 studs and motion stops beyond 150 (client).
- Pose and motion (D47): the server bakes the cross-legged pose into the rig's joints and keeps the
  body live on them, only the root anchored (`Rig.luau`; new rigs have AnimationConstraints, no
  Motor6D), so robes, hair and props follow every move; `CultivatorIdle.client.luau` animates locally
  through the joints, each easing at its own pace (head and arms a beat after the chest), within 150
  studs and only on screen: the whole figure floats 0.7 studs over its cushion (legs seated on it in the template; 2 studs read as detached in Play), and bobs (halo and orbs
  float along), the head watches a player within 24 studs (up to 55 degrees) and otherwise glances aside
  now and then, breath (rise and lean), a slow side sway, a head drift on its own rhythm, a sparkle puff
  every 8 to 14 s, the ground pulse on each in-breath, orbs circling (alternate directions from
  Celestial up) and bobbing, the Primordial colour cycle. No animation upload. An uploaded meditation animation
  (owner uploads, R5) would be the upgrade path.
- Templates are built once per look and rarity per server, then cloned. If a catalog item is ever
  taken down, that robe or hair goes missing until its id is replaced in `ROBES` / `LOOK`.

## Step-on pads
Concept C "Formation" (D27): a slate disc, a stone octagon, a gold heart and two Neon rune rings.
Ready = the kind's colour (build jade 59D39F, breakthrough gold FFC94A, shop amethyst A97CF0), not
affordable = red E0544B, all from `src/shared/PadLook.luau` (never hand-pick a pad colour). Feel,
motion and sounds: [FEEL](../design/FEEL.md) "Buying". Captures 50 (ready) and 51 (locked).

## Light (RULES R3)
Scene light comes only from the sky or a visible lamp holding a real Light (stone lanterns, braziers,
the cauldron fire, the spirit crystals and orbs, which are glowing objects). Gameplay markers are the
one exception the owner asked for: pad beacons (beams, the glowing rune rings and the light in
each pad's gold heart, colours from `PadLook`) and short event flashes.

## UI
The HUD language is mock C (approved): no panels, chunky Fredoka One text with a dark outline, toy
buttons (thick outline, solid shadow, shine). Mocks A and B were rejected as AI-looking (D7). Every
new screen gets a mock first.

**Icons (D51):** one sheet, `art/ui/icon_atlas.png` (`Config.ICON_ATLAS`, drawn by
`docs/art/mocks/icons.html` + `icons.js`, style A "sticker"); every icon goes through `Toy.icon(key)`.
Set rules (research: one light, one outline, one palette, one detail level): ink outline `1B1420` 4.5
units of a 64 box, flat colour with one hard shade toward the bottom right (light from the top left),
real silhouettes (SVG paths, not stacked boxes), 2 to 4 parts each, 6 units of padding. Robux is
always Roblox's own gold icon (`Config.ROBUX_ICON`); the disciple icon is the disciple atlas figure
(owner: its shape is better). A new icon: add its geometry to `icons.js`,
re-render the sheet (`?view=atlas&style=A`, Edge headless, transparent, 1024 px max), upload, put the
new id and its cell in `Config.ICON_ATLAS` in one pass.
