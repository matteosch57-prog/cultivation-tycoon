# Phone fps near the disciples (2026-10-23)

The owner's Pixel 10 Pro lost a lot of fps while walking past the Meditation Platform and its
8 Floating Lotus Isles, where up to 41 disciples sit.

## What sits there (counted from the code)

Each seated disciple is a full R15 avatar from a HumanoidDescription, with 1 or 2 layered
clothing robes, hair, props and ornaments. Its aura grows with its rarity tier (Cultivators.luau):

| Tier | Orbs | Swords | Live particles (Rate x life), before | Highlights, before | after (particles / Highlights) |
|---|---|---|---|---|---|
| 3 (Core) | 3 | 0 | ~125 | 1 | ~45 / 1 |
| 5 (Immortal) | 5 | 3 | ~215 | 4 | ~85 / 2 |
| 9 (Primordial) | 9 | 9 | ~400 | 10 | ~150 / 2 |

- **Orbs of light** cost the most. Each orb had 3 emitters (Glow and Heart at Rate 40 x 0.3 s,
  Tail at 18 x 0.6 s), about 35 live additive sprites stacked on one spot. That is pure overdraw:
  12 copies of the same sprite drawn on the same pixels.
- **One Highlight per spirit sword**, plus the body rim. A late-game sect with 20 tier-5+
  disciples had 100+ Highlights in view, far past what the engine draws (the 22-rim budget in
  CultivatorIdle did not count the swords).
- **41 layered-clothing Humanoids** moved through their joints every frame within 150 studs.
- The isles add 8 PointLights, light-stair sparkles (Rate 2) and the Shiny glints (Rate 34).
- Every figure within 90 studs had all its layers on. The isles are within 70 studs of the
  platform, so a player standing there had all 41 lit at once.

## What Roblox says (sources below)

- **Highlights.** "The first Highlight rendered on the screen incurs most of the performance cost
  (up to 1 millisecond of GPU time on mobile devices)". On mobile, highlights "are more costly on
  performance when they cover more of the screen". Highlights that are not visible cost nothing.
  Adding or removing one "can cause a geometry rebuilding step": toggle Enabled instead, which we
  already do.
- **Overdraw.** "Placing objects with partial transparency near each other forces the engine to
  render the overlapping pixels multiple times." Particles "don't batch well and introduce
  additional draw calls". DevForum advice: keep an emitter's live particles in the tens, not hundreds.
- **Humanoids.** They "can be intensive for the engine to process, particularly if these models use
  layered clothing". The advice is to disable unused humanoid states and to only show NPCs when
  users are nearby. Watch for `updateInvalidatedFastClusters` over 4 ms in the MicroProfiler.
- **Lights.** Use fewer light instances, short ranges and no shadows. Ours already follow this.
- Phone budgets (earlier research, docs/research/2026-10-22_ambience_and_perf_easy_wins.md): about
  500k triangles, under 500 draw calls and under 1.3 GB memory.

## How we compare

| Practice | Us before | Now |
|---|---|---|
| Distance culling of effects | all layers on within 90 studs | heavy layers only on the nearest 8 within 45 studs on phones (16 within 70 on PC) |
| Particle counts | ~35 live particles an orb | ~12 an orb, with the same look (4 copies drawn brighter, fading in and out) |
| Highlight count | rims budgeted, swords not | one glow a sword fan; rims, fans and Shiny outlines share 10 slots on phones (28 on PC), nearest first |
| NPC update rate | every on-screen figure every frame | full set every frame, the rest every 3rd frame |
| Telemetry | /perf for the owner only | every player: ClientFps and ClientLoad by zone |
| Lights | short range, no shadows | unchanged |
| Triangles | Lowpoly swap done 2026-10-21 | unchanged |

## Telemetry added

`PerfReport.client` keeps frame times per zone (disciples, hub, peak, bridge, sky; PerfScene.zone)
and sends one window per zone visit (12 to 60 s). The server checks the values and buckets them into
two events (Telemetry.clientPerf):

- **ClientFps**: the zone, the median fps bucket (an "s" suffix marks stutter: the slow 5% of
  frames ran under half the median), and the device (phone, tablet, pc or console).
- **ClientLoad**: the zone, the live particles within 80 studs, and `h|g|p` buckets for
  Highlights, in-world guis and visible parts.

The scan walks the workspace by hand, 1,000 instances a frame, every 25 s, so it causes no hitch
of its own. The owner's `/perf` rows now also show the zone and those counts.

## Studio check (2026-10-24, owner's PC)

A full late-game sect: 41 seated disciples (5 Primordial, 8 Heavenly Emperor, 9 Dao Ancestor,
9 Celestial, 8 Immortal, 2 Elder, 2 Shiny), all 8 isles, the camera behind the avatar on the platform.
Studio is capped at 60 fps on this PC, so the render CPU time is the number that moves. "Old" is
the old look rebuilt on the client: the old orb rates, every layer and Highlight on, one Highlight a sword.

| Run | Render CPU ms (median/95%) | Draw calls | Triangles | Live particles near | Highlights near |
|---|---|---|---|---|---|
| New, quality 10 | 8.0 / 9.2 | 1,387 | 2.87M | 4,094 | 28 |
| Old, quality 10 | 9.3 / 10.6 | 2,192 | 3.16M | 10,288 | 226 |
| New, quality 3 | 7.1 / 8.5 | 1,148 | 2.85M | 4,094 | 28 |
| Old, quality 3 | 8.2 / 9.7 | 2,070 | 3.14M | 10,296 | 226 |

Changes from the old state: all emitters off saved 940 draw calls and 2.4 ms (the biggest lever).
All Highlights off saved 604 draw calls and 0.94M triangles, but only 0.1 ms of CPU, because their
cost is screen fill that a PC GPU hides. Hiding the avatars saved 498 draw calls, 1.08M triangles
and 0.5 ms. The fix overall cut draw calls by 37%, particles by 60% and Highlights from 226 to 28.
These runs used the PC budget, since scripts cannot set the graphics level, so a phone also gets the
smaller budget (8 full figures, 10 Highlights).

**Main Hall preview** (the owner's -30 fps): the Celestial Palace preview had 4,269 parts. Its
per-frame work was 2.58 ms of Lua for all of them, plus drawing 4,269 see-through Neon parts. With
the 300 biggest parts it is 0.16 ms, with no fps drop while it fades in, and it still reads as the
palace.

Found and fixed during the check: disciples streamed in piece by piece, so late emitters missed the
budget (now Atomic, and late layers join the budget). The zone check also counted a shop card's
viewport figure at the hub as a disciple.
Still open: CultivatorIdle costs about 2.4 ms of Lua a frame with 41 figures (PC budget), with rare
spikes. The phone emulator run needs the Device emulator set by hand.

## Next if the phone is still slow

- Swap the far seated avatars for a cheap stand-in (a posed MeshPart copy without Humanoid and
  without layered clothing) beyond about 45 studs. This is the "only show NPCs when users are
  nearby" advice. It is a bigger change, so do it only if ClientFps still shows the disciples zone low.
- Disable unused Humanoid states on the seated rigs.

## Sources

- https://create.roblox.com/docs/effects/highlighting
- https://create.roblox.com/docs/performance-optimization/improve
- https://devforum.roblox.com/t/how-to-optimize-humanoids/389801
- https://devforum.roblox.com/t/2640095 (particle fps drop)
- https://devforum.roblox.com/t/rigwrap-clothing-without-humanoids-more-fps-no-lag-and-high-res-plugin/3751017 (NPC clothing cost, the author's own benchmark)
- https://devforum.roblox.com/t/increase-highlight-limit/2628557
