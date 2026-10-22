# Store icon and thumbnails: what gets clicked (2026-10-21)

Evidence for the Cultivation Tycoon icon and thumbnails, and the brief the mocks were built to.
Nothing here is uploaded; the owner picks from the mocks and uploads by hand on the Creator Hub.

## How Roblox measures it
- **Thumbnails are A/B tested by Roblox itself.** Activate 2 or more thumbnails and Thumbnail
  Personalization shows each player the one most likely to work for them, scored on **qualified
  play-through rate** (players who join AND stay a while), not raw clicks. Roblox reported +8.5% qPTR on
  average in testing; a 2026 update keeps the current winner on most traffic while new ones get measured,
  so always keep the best existing thumbnail in a new test.
  ([Creator Hub: thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails),
  [DevForum: personalization keeps winners](https://devforum.roblox.com/t/thumbnail-personalization-now-remembers-your-existing-winning-thumbnails/3793665))
- **The icon has no A/B test** (still a [feature request](https://devforum.roblox.com/t/icon-ab-testing/3274267)).
  Compare icons by swapping one at a time and reading the click rate in Analytics over equal weeks.
- **Specs:** icon 512 x 512 (shown down to ~150 px on the home grid, smaller in search); thumbnails
  1920 x 1080, 16:9 (other ratios are stretched, not cropped). Thumbnails must show real game content;
  misleading art can be moderated and loses players at join anyway (qPTR punishes it).
- Consequence: the **icon carries the click on the grid**, the thumbnails carry it on the game page and on
  personalized surfaces, and qPTR rewards honesty: show what the first minutes look like.

## The field (live pull 2026-10-21, 80 icons at 150 px)
Boards: `docs/art/mocks/store/ref_board_tycoon.png` and `ref_board_cultivation.png` (Roblox search
"tycoon" and "cultivation", top 40 each).
- **Tycoon icons are bright, busy and literal:** median brightness 135 / 255, none dark; a grinning
  avatar or a big object, glossy 3D, often a title in a fat outlined font and a NEW sticker. The repeated
  tropes are the "Day 1 / Day 100" split, avatars in pod-tubes, money piles.
- **Cultivation icons are dark and dramatic:** median brightness 104, 11 of 40 near-black; purple and gold
  energy, anime faces, long titles in serif caps, lightning. They read as one blur of "dark aura guy".
- **Nobody owns calm daylight.** No icon in either field is a bright, airy, uncluttered sky scene. Our
  game IS that (painted sky, a red and gold sect on a floating peak, cherry blossom). That empty corner is
  the novelty: a tile that looks like a holiday among 40 explosions.

## Rules the mocks follow
From the research, from Heavenly RNG's A/B history and from Gladiator RNG's store-art rounds:
1. **One subject, filling the tile, out-contrasting its background at 150 px.** Heavenly's proven A/B
   (1.82% vs 1.38% with identical type) was decided by subject contrast alone. Squint test at 150 and 64 px.
2. **Our art in our world.** Gladiator's winners were real Studio captures with the game's own light and
   VFX, lightly post-processed; composites, pasted sprites and code-drawn figures all failed.
3. **No title on the icon** (only big brands do it, and it dies at 150 px). Thumbnails carry at most a
   few words; the biggest thing in frame is the only thing that reads.
4. **No cheap type tells:** no Arial Black + thick outline + glow. The game's own Fredoka for any word,
   with a soft shadow, or a clean serif.
5. **No medallion, no circle-with-a-symbol, no frame around good art** (owner: generated-design tell).
6. **A face or a figure when it helps:** humans (and players' avatars) pull attention; a calm, closed-eye
   meditating disciple with a coloured aura is our version, and it is unlike the field's angry faces.
7. **Show the tycoon verb:** something rising, growing or getting richer. Before / after is a tycoon
   staple; done without text it still reads.
8. **Clear, normalized colour:** sky blue + vermilion + gold + white cloud, saturated but not neon,
   no muddy mid-tones; one warm accent against cool space.
9. Thumbnail set = **different angles on the same promise** so personalization has real choices: the
   whole peak, a face, growth, friends, a rarity ladder.

## The mocks (round 1)
Files: [docs/art/mocks/store/](../art/mocks/store/) (icons 512 px, thumbnails 1920 x 1080, pick boards
`board_icons.png` with the 150 and 64 px read, `board_thumbs.png`). Built from 14 Studio Play captures
of a temporary staged peak (the game's own builders: Main Hall level 5, leaf-card trees, all nine
disciple rarities, cloud sea; Play discarded it, nothing saved). The sect name "Azure Cloud Sect" and the
avatar in icon 08 / thumbnail 07 are stand-ins. Captures are 1808 x 833, so thumbnails are upscaled 1.3x:
a final pick gets re-shot at full resolution.

Icons: 01 floating peak · 02 main hall front · 03 golden eave · 04 Heavenly Emperor face · 05 day 1 / day 100
diagonal · 06 top-down sect · 07 dusk sect · 08 you and your hall · 09 sakura and roof · 10 emperor in the sun.
Thumbnails: 01 peak + title · 02 DAY 1 / DAY 100 · 03 disciple lineup · 04 hall symmetry + title · 05 dusk ·
06 top-down BUILD YOUR SECT · 07 YOUR SECT · 08 golden eave + title · 09 three-quarter peak · 10 disciples close.

Owner's verdict: "in game things are fun but we can generate it too" (do better).

## Round 2: drawn in code
Owner: "with scripts as you always do for my games". `python tools/store_art.py` draws all 20 (flat,
geometric, pastel sky with lavender shadows: a look neither field uses) into
[docs/art/mocks/store/drawn/](../art/mocks/store/drawn/) with both pick boards. Every shape is drawn at 4x and
downsampled. Gotcha: blurring an RGBA layer whose empty pixels are transparent black leaves a grey fringe;
the kit blurs premultiplied. (An image-generator prompt sheet also exists: [PROMPTS.md](../art/mocks/store/PROMPTS.md).)

Owner on round 2: "terribly bad", focus on 3 of each.

## Round 3: the Gladiator recipe, 3 + 3
Our real disciples shot big in Studio Play (staged in front of the Main Hall, the hero rebuilt per rarity,
plus a `_plate` with the hero hidden for the mask), then `python tools/store_post.py`: grade, backlight and
god rays behind the subject only, a warm rim, qi motes, gold Cambria caps. Raw shots
[docs/art/mocks/store/raw/](../art/mocks/store/raw/), results [final/](../art/mocks/store/final/):
icons Primordial, Heavenly Emperor, floating sect; thumbnails OUTER DISCIPLE to PRIMORDIAL, DAY 1 / DAY 100
(one island, half grown), RECRUIT LEGENDS.

## Rounds 4 and 5 (owner feedback, same evening)
- Island icon: picked; "a bit more zoomed", then "unzoom just a bit, use the light better". 5 colourways
  (day, sunset, blossom, jade, night): sky recoloured by a luminance gradient map, the game's own sakura
  canopy cut out for two corners, petals, sun rays from the upper right, underside shaded cool
  (`python tools/store_post.py icons5`).
- Thumbnails kept: common-to-rare (Lotus ➜ Celestial; Outer monk ➜ Immortal elder, aura made "way more
  distinctive": silhouette bloom, rising qi flames, a tilted orbit ring) and Day 1 / Day 100 (new angles
  and a soft-blend version). New: a Be a Fish style tile, one disciple on plain white, no text.
- Gotcha: cutting a white-robed disciple off the sky plate loses the robe into the clouds. Shoot against a
  magenta SmoothPlastic board (Neon blooms, green spills into jade robes) and key on min(R,B) - G.

## Owner picks (2026-10-21, late)
Kept, in [docs/art/mocks/store/picks/](../art/mocks/store/picks/):
- Icons: the dense sect from the round 5 camera, **day** and **night** (night relit: moon halo behind the
  island, lantern glow on the lawn). Source `raw/dense_wide.jpg`, rebuild `python tools/store_post.py icons5`.
- Thumbnails: **Day 1 / Day 100**, hard split, denser sect, **high** and **wide** framings
  (`raw/dd1_*` / `raw/dd100_*`, `day6()` in `tools/store_post.py`).
Still open: the rarity thumbnails (Outer ➜ Celestial / Immortal) and an aura "mental attack" thumbnail wait for
the redone disciple characters. Rejected along the way: plain captures, flat code-drawn art, the white tile,
the soft-blend split, low and close-up icon angles.

## Icon juice (2026-10-22)
Owner picked **level 4** of five (clean, sunlight, sakura corners, petals and qi, full ring/orbs/flare):
sunlight + sakura corners + petals + a few qi motes. Level 5 blurs at 64 px. `picks/icon_day.png` now holds it;
rebuild with `juice_ladder()` in `tools/store_post.py`. Open: picks among the rarity, aura burst and flying
thumbnails (page https://claude.ai/artifact/5iKSWQ3S5jHUC3JLkjGDkV; the thread is at its attachment cap).

## Aura burst and flying (2026-10-22)
Redone with the steel jian swords, sky only, each rarity with and without one word (AWAKEN / ASCEND):
`final/thumb13_*` (board `final/board_round13.png`). Owner: "keep them all for now", so all twelve stay as
candidates, no final pick yet. Personalization can A/B several thumbnails at once.

## Status when closed (2026-10-22)
Closed by the owner ("document and close for now"); nothing uploaded to Roblox yet (owner uploads on the Creator Hub).
- **Kept icons:** `picks/icon_day.png` (juice level 4) and `picks/icon_night.png`.
- **Kept thumbnails:** `picks/thumb_day1_day100_high.png`, `picks/thumb_day1_day100_wide.png`, and all twelve
  `final/thumb13_*` (aura burst and flying, each with and without one word) as candidates.
- **Review page:** https://claude.ai/artifact/5iKSWQ3S5jHUC3JLkjGDkV (private; the thread hit its 24-attachment cap).
- **To reopen:** stage scenes in a Studio Play session only (temporary `_StoreArtTemp`, camera via a client
  script, magenta SmoothPlastic board for cutouts, ask the coordinator for a slot), drop captures in `raw/`, then
  `tools/store_post.py` (`icons5`, `juice_ladder()`, `day6()`, `hero_sky()`).
- **Lessons:** plain captures and flat code-drawn art were both rejected; the Gladiator recipe (our real art
  shot big in Studio, light and juice in post) won. Show 3 to 5 options per round, not 10. Simpler beats noisy
  (juice 4 of 5; sky-only backgrounds read better than bursts). The cutout keys only board pixels connected
  to the frame edge (pink-lit robes went see-through otherwise), and `ImageDraw.floodfill` silently does
  nothing on an image made by `Image.fromarray` unless it is copied first.

**The picks live in [store/](../../store/) at the repo root** (owner 2026-10-22: one folder high in the tree); `docs/art/mocks/store/` is the working archive.

## Cinematic sect shots (2026-10-22)
Studio Play on the mock save (DebugSet: every pad, realm 21, lives 4 = Celestial Azure, VIP, 8 top disciples, 2 workers
each), HUD, BillboardGuis and the avatar hidden client-side, camera via `screen_capture` args, ClockTime 16.9 (day),
18.1 (dusk), 21 (night: plain black sky and dark hall windows, dropped). Raw: `raw/cine/`; grade + 16:9 crop:
`python tools/store_cine.py <in> <out> xshift yshift zoom warm`; candidates `final/cine/`.
Owner kept **day side** and **dusk disciples** -> `store/thumbnails/cine_day_side.png`, `cine_dusk_disciples.png`. Notes: realm 20 tints the halo red (realm 21 = gold);
low sky angles beat high ones (the cloud sea reads as flat teal from above); the Studio viewport was small (1405 px),
so a re-shoot with a wider window would be sharper.
