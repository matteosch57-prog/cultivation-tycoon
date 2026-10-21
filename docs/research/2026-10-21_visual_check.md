# Visual check, 2026-10-21

Read-only pass over every building, every Main Hall level, two island sizes and the HUD text, checked
against [ART_BIBLE](../art/ART_BIBLE.md), RULES R3 / R4 and BACKLOG "Look". Built in an Edit scratch
peak at x = 2000 from clones of `Style` + `Builders` (realm 1 palette), captured, then deleted.
Captures: [captures/26_check_* to 48_check_*](../art/captures/).

**Rungs used:** Edit captures + Edit measurements, then a Studio Play pass (touch emulator,
749 x 381, top bar 58) with HUD rects measured on the client: captures 44 to 48. Test data was faked
client-side only (7 disciples, pill ready, 1.2M recruit, a long goal title), no save touched.
Camera-argument captures (38 to 43) render one frame: terrain shows as flat green there; judge the
ground only from 26 to 33.

## Ranked findings

1. **Every name plaque is blank.** Sect Gate, Main Hall 2 to 5 (and its wings), Disciple Hall,
   Quarters, Library: an empty gold board in a frame, at eye level, under the gate the player walks
   through first. Reads unfinished. Captures 27, 28, 35, 37, 40.
2. **Half the visible lawn on a full peak is bare earth.** Raycast count over the r = 90 top:
   49% of visible ground cells are `Ground`, 51% grass. `paintGround` paints each ground-touching
   part's world bounding box snapped outward to the 4-stud grid, so rotated buildings, stairs,
   balustrades and lantern bases each paint a square larger than themselves. ART_BIBLE says the lawn
   is LeafyGrass. Captures 27, 29, 30.
3. **Up close, your own avatar covers the price card.** Standing next to a pad, the card drops to
   2.4 studs (head height) and is not AlwaysOnTop, so the follow camera sees the avatar's head over
   the name and price. Capture 48. Far away, the feature line ("Your sect's heart: upgrade it")
   shrinks to ~8 px and sits in the beam: unreadable. Capture 46.
4. **Moon Gate reads as a white cog wheel** (BACKLOG "skewed arc", more detail): the ring segments'
   corners stick out as teeth, the sakura behind pokes through the wall, the roof cap is a thin strip.
   Capture 39.
5. **HUD top row is jammed with a long goal.** Measured in Play: "Next: Breakthrough: Foundation
   Establishment" starts 16 px left of the qi counter's right edge, 7 px below it (captures 45, 46).
   No overlap at a 58 px top bar, but on a 667 px phone the horizontal overlap grows to ~54 px and a
   44 px top bar would make them touch (computed).
6. **The disciples card is a panel** (cream box with an outline), which mock C and R4 rule out; the
   rest of the HUD matches mock C. Capture 46.
7. **The full island looks like a table top.** The rock body ends at ~0.77 x radius at every size
   (chunks capped at 14 studs), so the overhang grows from ~13 studs at r = 62 to ~20 at r = 90.
   Mock C draws the rock as wide as the top. Captures 32 vs 33.
8. **Main Hall 1 and 2 break ART_BIBLE rule 1 (dominant roof).** The Thatched Hut's roof is short and
   its gold ridge horns are oversized (read as antennae); Sect Hall's roof is shorter than its
   columns. Levels 3 to 5 are fine. Captures 34, 35.
9. **Incense haze smears the courtyard.** The meditation platform's 4 legacy `Smoke` objects make a
   white fog patch in front of the Main Hall stairs. Captures 28, 30.
10. **Qi Gathering Array orb blows out to a white disc**, and the brazier tops are flat yellow neon
   squares. Allowed by R3 (glowing objects with a real Light) but reads as a blown highlight. Capture 41.
11. **Spirit Vein crystals hover over a tilted slab** that reads as a loose board. Captures 29, 30. Low.

## Passed
- **R3 audit (numbers):** 15 PointLights in a full peak, every one parented to a visible Neon object
  (6 lantern cores, 2 vein crystals, furnace fire, array orb + 4 braziers, bamboo lantern). No
  fixture-less light, no Beam or glow strip in any building.
- **Nothing over the void:** every ground-level part of the rim buildings (library, moon gate, bell,
  koi, bamboo, pagoda, training, quarters) has terrain under it at r = 90.
- **R4 text:** no `TextTruncate` and no dash in any player string in `Hud`/`Build`. Longest toast
  (a 20-letter display name breaking through to Foundation Establishment) measures 621 px at a
  667 px phone: fits without a cut. Progress bar text 131 px inside a 230 px bar.

- **HUD in Play:** no pairwise overlap among the counter, left column, disciples card, progress bar,
  recruit button and goal (phone layout); recruit sits above the jump button; beacons and the jade
  build preview read clearly (captures 44, 48).

## Not checked
A real phone's safe insets (Studio Play has none) and the build animation itself. Note: in this
Play pass `screen_capture` did draw the price card BillboardGuis, unlike the Gladiator note.

## Research
- Roblox: interactive HUD belongs in a `CoreUISafeInsets` ScreenGui; `DeviceSafeInsets` does not
  clear the top bar, and the Device Emulator is the recommended phone check
  ([ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets),
  [On-screen containers](https://create.roblox.com/docs/en-us/ui/on-screen-containers)).
- Gladiator RNG lessons applied: a text-only check is not "nothing overlaps" (measure rects of every
  piece), budget phone layouts against the real phone height, Studio Play has no safe insets, and
  `screen_capture` omits BillboardGuis.
