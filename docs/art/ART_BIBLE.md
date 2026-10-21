# Art bible: the look of Cultivation Tycoon

How the world looks and the rules `src/server/Style.luau` builds to. Research behind it: the
2026-10-21 look pass (lighting recipes, stylised building craft, phone budgets). Captures of every
pass live in [captures/](captures/); HUD mocks in [mocks/](mocks/).

## What makes it read "premium"
1. A dominant roof: as tall as the walls or taller, deep overhang, dark soffit and rafter ends underneath.
2. Coloured shadows: lifted lavender ambient, never black.
3. Few modules reused everywhere (clone, never regenerate): instancing keeps phones fast.

## Lighting (authored in Edit, saved with the place; the server never overrides it)
- LightingStyle Realistic, PrioritizeLightingQuality false (the vista needs view distance).
- ClockTime 16.9, Latitude 35, Brightness 2.5, Exposure -0.15.
- Ambient 105,95,120 · OutdoorAmbient 150,135,165 · ColorShift_Top 255,215,175.
- EnvDiffuse 0.5 · EnvSpecular 0.25 · ShadowSoftness 0.2.
- Atmosphere: Density 0.3, Offset 0.2, Color 255,215,175, Decay 125,145,195, Glare 0.18, Haze 1.5.
- ColorCorrection: Brightness 0.02, Contrast 0.1, Saturation 0.15, Tint 255,248,238.
- Bloom: Intensity 0.35, Size 28, Threshold 1.8 (high, so white plaster and clouds never glow).
- SunRays 0.17 / Spread 0.42 (more, longer rays). Sky SunAngularSize 11. DepthOfField off in gameplay.

## Sky and clouds
- Sky: `Lighting.ActiveSky`, a painted anime-style skybox from the Creator Store (asset 90335763728419).
  The uploader looks like a re-upload account; its hidden scripts were deleted on insert. If Roblox
  moderates it the sky falls back to default; the original is parked as `ServerStorage.Sky_Original`.
  MoonAngularSize 0. Long term: commission or paint our own six faces.
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
  pavilion (`Kit.pavilion`), the Bell Tower and the Moon Gate are built from the same column, bracket,
  railing, panel and tile-end pieces under a kit roof (`ClayRoofTiles`, round tile ends).
- Name boards (`Kit.plaque`): a dark board in a gold frame, the name in gold Fantasy. A one-roof hall
  hangs it in the middle bay (odd bay counts only), a two-roof hall on the upper storey between the
  eaves. The text is the pad name; the Sect Gate shows the sect's name.
- Moon Gate: the ring is cut from blocks whose outer corners sit on the circle, and the wall between
  ring and square is strips whose ends hide under the ring (24 long blocks read as a cog wheel).
Captures: [captures/57 to 60](captures/), before/after [63 to 69](captures/).

## Cultivators (disciples on the platform)
- Real R15 Roblox avatars built by `src/server/Cultivators.luau` from a HumanoidDescription: catalog
  hanfu (layered clothing, which any experience may put on an NPC), hair and beard. Lineup mock
  [cultivators_avatars.jpg](mocks/cultivators_avatars.jpg); the earlier part-built mock
  [cultivators_lineup.jpg](mocks/cultivators_lineup.jpg) set the colour and aura rules.
- Bodies and faces: Roblox's own Man and Woman bodies (shaped limbs and hands) and dynamic heads (Man
  Face, Woman Face, Classic Male Face, Old Man Jenkins). The blocky default body with the classic smile
  decal read cheap; a dynamic head's FaceControls let the client close the eyes in meditation, open
  them now and then and open them with a faint smile to watch a close player.
  Capture: [cultivators_vivid.jpg](mocks/cultivators_vivid.jpg).
- Four looks cycled by slot: sword disciple (black ponytail), lotus maiden (buns with hairpins),
  pill monk (shaved head with a strategist's moustache, since a bare default head read as a failed load),
  elder sage (white crown hair and beard).
- The rarity owns the robe: white, green, blue, purple, gold, Celestial teal (azure hanfu), Dao Ancestor
  crimson (robe under a red cloak), Heavenly Emperor red-gold, Primordial white under a white cloak. A
  dark robe hides the rarity, so every robe is checked in a capture before it ships (the long robe green
  and blue read black). Top tiers: [cultivators_premium_auras.jpg](mocks/cultivators_premium_auras.jpg).
- Premium aura = several soft layers at low rates, in the rarity hue pushed to full saturation
  (lightening only 20% at the edge, half additive: fading 60% to white, fully additive, read pale), one layer more per
  rarity: Inner a turning qi sigil on the ground, Core rising motes, Elder a halo ring behind the head,
  Immortal qi orbs with trails, Celestial a second wider sigil, Dao Ancestor an outer halo, Heavenly
  Emperor a ring pulse on each breath, Primordial runs through every colour. Orbs 3 / 5 / 7 / 7 / 9 from
  Immortal, at chest height. Built-in textures only (`rbxasset://textures/particles/`: vortex,
  shockwave ring, glow, sparkles), so nothing to upload. No Light instances (R3).
- Layer gotchas: an emitter on an Attachment emits from one point, inside the body, where the avatar
  hides it (motes rise from an invisible ring part instead); a flat ground sprite needs a positive
  ZOffset or the floor hides it; fire wisps and beam ribbons were tried and dropped (hidden, or faint
  white arcs over the bright sky).
- Phone budget: aura layers switch off beyond 90 studs and motion stops beyond 150 (client).
- Pose and motion: the server poses the rig cross-legged through its joint graph and anchors it (new
  rigs have AnimationConstraints, no Motor6D); `CultivatorIdle.client.luau` animates locally within 150
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
buttons (thick outline, solid shadow, shine), icons drawn from UI shapes. Mocks A and B were rejected
as AI-looking (D7). Every new screen gets a mock first.
