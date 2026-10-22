# Easy wins: ambience (look + sound) and performance

Research 2026-10-22 (owner ask: "deep research on Roblox forums for easy stuff to make the whole
ambient better, graphically and sound; same for optimizing"). Sources: create.roblox.com docs and
DevForum threads, every URL below opened. Matched against the code on `integration` the same day:
items the game already does are listed at the end, not proposed again.

## Ambience: ranked by value for the effort

| # | Idea | Why it helps | Effort | Phone cost |
|---|---|---|---|---|
| A1 | **Area sound emitters**: a looped wind / bird bed on a big invisible part over each peak; each waterfall's sound on a part sized to the falling water (a Sound in a block part plays from its whole volume) | the world sounds wide and alive instead of one flat loop everywhere | 30 min | ~0 |
| A2 | **Reverb per place**: `SoundService.AmbientReverb` switched by a client distance check (`Mountains` / `Plain` on peaks, `StoneRoom` / `Hallway` in halls, `Cave` behind waterfalls) | halls and the open sky feel different | 20 min | ~0 |
| A3 | **Music ducks under big moments**: CompressorSoundEffect on the Music group, `SideChain` = the SFX group | breakthrough, recruit and the hall bell stop fighting the music | 15 min | 0 |
| A4 | **Muffle outside sound indoors**: EqualizerSoundEffect on Ambience, high band down inside a hall | "I walked inside" without words | 15 min | 0 |
| A5 | **GlobalWind with gusts**: `workspace.GlobalWind` sways grass, Fire and smoke; set `WindAffectsDrag` + `Drag` on clouds, petals and mist so all lean one way; a slow gust loop paired with a swell on the wind bed | the whole scene breathes together | 20 min | ~0 |
| A6 | **Falling petals / dust motes** near sakura and the hub: one 2x2 flipbook petal, `FacingCameraWorldUp`, low Rate, long life, wind drag; `LightEmission = 0` (lit by the sun, R3 safe) | calm motion in the air, very "xianxia" | 1 h | low (mobile caps 100 particles/s per emitter) |
| A7 | **Atmosphere Offset / Decay**: a little more Offset so the five other peaks stand as layered silhouettes over the cloud sea; Decay tints the haze away from the sun | depth at the golden hour | 15 min | 0 |
| A8 | **Light tuning**: softer `ShadowSoftness`, `EnvironmentSpecularScale` toward 1 so ponds and lacquered roofs pick up the sky | richer materials for free | 15 min | 0 |
| A9 | **Footsteps by floor**: `Humanoid.FloorMaterial` to grass / stone / wood steps, swapped only when it changes (our memory: the default character sounds are replaced at Play, so hook the playing sound) | grounding, premium feel | 1 to 2 h | ~0 |
| A10 | **Hand-painted stone / roof / wood**: a MaterialVariant named after a built-in material overrides it everywhere; `MaterialPattern = Organic` breaks tiling | less "default Roblox", less generic | 1 to 2 h | a few textures of memory |
| A11 | **Slow sky drift**: `Sky.SkyboxOrientation` Y at ~0.2 deg/s | clouds in the skybox move | 10 min | 0 |

Later, bigger: the new Audio API (AudioEmitter with exact distance curves, one stream for every
waterfall, a real sidechain compressor, AudioFader crossfades). Acoustic Simulation went live in
beta 2026-01-29 but may be disabled on low-end devices: a bonus for good devices only.

**Against R3 (no fake light), do not do:** beam or part "god rays" (fake light, and DevForum reports
they are slow on low-end phones; keep SunRays + Atmosphere Glare); additive glowing fireflies with no
real Light (only if the owner accepts the particle as its own visible source).
Untested: terrain Dynamic Clouds (no phone numbers, fixed height may clash with our cloud sea).

## Performance: ranked by gain for the effort

Budget check first: a full peak (~192k triangles, ~33 draw calls) is far under the phone budgets
quoted (500k / 500 draw calls / under 1.3 GB memory). So phone drops, if any, are more likely fill
rate (transparent particles), CPU (Humanoids) or memory. **Measure first** on the phone: Ctrl+F2
stats (CPU ms vs GPU ms says which), then our `/perf` and `/clouds`.

| # | Idea | Gain | Effort | Risk |
|---|---|---|---|---|
| P1 | **Cloud sea overdraw**: fewer, smaller, more opaque cloud particles near the camera, or a few big textured planes for the far layer; scale any `:Emit()` burst by `SavedQualityLevel` (Emit skips the engine's quality scaling; `Style.softCloud` pre-fills with `Emit`) | high if `/clouds` shows a gap | low | look only: owner OK |
| P2 | **Disciple and worker NPCs**: they are full R15 Humanoids (`Cultivators.luau`, `Workers.luau`). Disable unused Humanoid states (`SetStateEnabled`: physics, falling, climbing, swimming...), keep them anchored, one manager loop (we have it); seated disciples could use an AnimationController instead | medium to high CPU with 6 full peaks | low to medium | test the poses and the arrival walk |
| P3 | **Decor off the physics**: `CanTouch` / `CanQuery` false (and `CanCollide` where nobody stands) on decoration parts built through `Style.P` / Kit; collision geometry costs memory even untouched. Never on pads, floors, stairs or anything a ray must hit | medium memory | low | a pad or floor flag set by mistake |
| P4 | **Streaming**: `StreamOutBehavior = Opportunistic` (the docs' recommended setting). Only helps memory if the target radius is lowered below the peak spacing, which would make far peaks pop: decide after the phone memory numbers | medium memory | low | far peaks streaming out |
| P5 | **Leak hygiene**: `Workspace.PlayerCharacterDestroyBehavior` on; watch Signals and LuaHeap in the console Memory tab over a long session | long sessions | low | none |
| P6 | **Join time**: ReplicatedFirst = the loading screen only; PreloadAsync only the first screen's assets; Studio "Print Join Size Breakdown" to measure | first impression | low | none |
| P7 | **Creator Hub Performance dashboard** (Monitoring, Performance: fps, crashes, memory, out-of-memory exits by device; compare place versions). Needs 100+ daily users | free evidence after launch | 0 | none |

Answered open question: **SLIM imposters cannot apply to our script-built peaks** (`Model.LevelOfDetail`
is plugin / Open Cloud only, needs static geometry made in Studio, excludes Humanoid models).

## Already done (checked in code, not proposed again)
Lantern and lamp lights have `Shadows = false` (Style, Nature, Altar, RankBoard); every
BillboardGui has a MaxDistance (70 to 300); emitters and loops sleep off screen (R16); positional
sounds use InverseTapered roll-off; three SoundGroups; low-poly meshes for small round parts;
CastShadow off on small parts.

## Sources
- Sound: https://create.roblox.com/docs/sound/objects · https://create.roblox.com/docs/reference/engine/classes/SoundService ·
  https://create.roblox.com/docs/reference/engine/enums/ReverbType · https://create.roblox.com/docs/sound/groups ·
  https://create.roblox.com/docs/sound/dynamic-effects · https://create.roblox.com/docs/audio/objects ·
  https://create.roblox.com/docs/reference/engine/classes/AudioEmitter · https://devforum.roblox.com/t/beta-acoustic-simulation/3634265 ·
  https://devforum.roblox.com/t/2221267 (footsteps)
- Look: https://create.roblox.com/docs/environment/global-wind · https://create.roblox.com/docs/environment/atmosphere ·
  https://create.roblox.com/docs/environment/lighting · https://create.roblox.com/docs/effects/particle-emitters ·
  https://create.roblox.com/docs/reference/engine/classes/MaterialVariant · https://create.roblox.com/docs/reference/engine/classes/Sky ·
  https://create.roblox.com/docs/environment/clouds · https://devforum.roblox.com/t/creating-volumetric-lighting/871150
- Performance: https://devforum.roblox.com/t/3127146 (phone budgets) · https://create.roblox.com/docs/performance-optimization/improve ·
  https://create.roblox.com/docs/performance-optimization/design · https://create.roblox.com/docs/performance-optimization/identify ·
  https://create.roblox.com/docs/workspace/streaming · https://create.roblox.com/docs/workspace/streaming/slim ·
  https://devforum.roblox.com/t/future-is-bright-phase-3-released/878634 · https://devforum.roblox.com/t/how-to-optimize-humanoids/389801 ·
  https://create.roblox.com/docs/studio/optimization/memory-usage · https://create.roblox.com/docs/production/analytics/performance
