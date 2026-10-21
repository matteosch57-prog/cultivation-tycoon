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
- Under every ground-touching part the terrain turns to packed earth (`paintGround`), so blades never
  grow through stairs and floors.

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

## Cultivators (disciples on the platform)
- Built by `src/server/Cultivators.luau`; lineup mock [cultivators_lineup.jpg](mocks/cultivators_lineup.jpg).
- Four looks cycled by slot: sword disciple (topknot, sword on the back), lotus maiden (long hair, twin
  buns, flower), pill monk (shaved head, beads, gourd), elder sage (white beard, crown, horsetail whisk).
- The rarity owns the colour: robe = the rarity colour toward cream; trim cream, silver at Core, gold at
  Elder, cream on the gold Immortal robe.
- Aura grows one step per rarity: Outer none, Inner a small ForceField ground ring, Core a wide ring and
  rising sparkles, Elder adds a halo behind the head, Immortal adds three qi orbs. No Light instances
  (R3) and one emitter per figure at most, so a full platform stays cheap on phones.

## Light (RULES R3)
Scene light comes only from the sky or a visible lamp holding a real Light (stone lanterns, braziers,
the cauldron fire, the spirit crystals and orbs, which are glowing objects). Gameplay markers are the
one exception the owner asked for: pad beacons (green / red beams) and short event flashes.

## UI
The HUD language is mock C (approved): no panels, chunky Fredoka One text with a dark outline, toy
buttons (thick outline, solid shadow, shine), icons drawn from UI shapes. Mocks A and B were rejected
as AI-looking (D7). Every new screen gets a mock first.
