# Generated store art: 10 icon and 10 thumbnail prompts (round 2)

Round 1 (in-game captures) was "fun but we can do better". These prompts are for an image generator
(Gemini / Nano Banana, or Midjourney). Mattéo generates; Claude reads every output before the next
prompt (never iterate blind), then adds any words in post and checks each icon at 150 and 64 px.

**How to run:** attach 2 reference captures from [ref_captures/](ref_captures/) so the buildings,
robes and palette stay ours (`hall_axis.jpg` + `lineup.jpg` for most; `island.jpg` for the peaks).
Paste the STYLE block, then one concept. Icons 1:1, thumbnails 16:9. **Ask for no text**: titles go on
in post (the generator spells badly and the type must match the game). Drop results in
`docs/art/mocks/store/gen/` named after the concept number (`icon_03_a.png`, `thumb_07_b.png`).

## STYLE (paste first, every time)
> Premium Roblox game key art, glossy stylised 3D render, characters are Roblox R15 avatars (smooth
> rounded blocky bodies, simple friendly faces) in Chinese hanfu robes. Calm, bright, airy daylight:
> clear sky blue, soft white clouds, vermilion red columns, gold roof tiles, cherry blossom pink,
> jade green accents. One clear subject, big and centred, strong silhouette, high contrast between
> subject and background, clean uncluttered background, soft warm sunlight with coloured (lavender)
> shadows, no black outlines, no text, no logos, no UI, no watermark. Peaceful and wondrous, not dark,
> not aggressive, no lightning, no purple storm.

## Icons (1:1, must read at 150 px)
1. **Lone peak.** A single small floating rock island far below a vast clear blue sky, on it one red
   and gold Chinese temple hall and a pink cherry tree, a thin waterfall falling off the edge into a
   sea of soft white clouds. Huge empty sky around it, the island in the lower middle third.
2. **Serene disciple.** Close-up of a Roblox avatar disciple in a white and gold hanfu, eyes closed,
   a calm small smile, floating cross-legged in meditation; soft jade-green qi swirls rise around
   the hands. Plain pale sky-blue background. The face fills the upper half of the frame.
3. **The build moment.** A Roblox avatar in red hanfu stands on a glowing jade circle on green grass,
   arms raised in joy, and a golden temple hall bursts up out of the ground behind them in a column
   of warm light and gold sparkles. Blue sky behind.
4. **One curl of roof.** Extreme close-up of a single upturned golden roof corner of a Chinese hall,
   curving up against a deep clear blue sky, one cherry blossom petal drifting past. Nothing else.
5. **Qi drop world.** One big glossy jade-green water droplet hanging in a soft blue sky; inside the
   drop, refracted, a tiny floating island with a red and gold temple. The drop fills the frame.
   (No circle, ring, badge or frame around it.)
6. **A sect in your hands.** A Roblox avatar in blue hanfu holds a tiny floating island in cupped
   hands like a bonsai, the island carries a miniature red and gold temple and a cherry tree, a soft
   glow on the avatar's delighted face. Shot from slightly below, sky behind.
7. **Above the clouds.** A tall slender vermilion pagoda pierces up through a flat sea of white
   clouds at sunrise, its golden top catching the first light, pale gold and blue sky.
8. **The rare pull.** A majestic Roblox avatar elder with a long white beard and a golden crown, in a
   red and gold dragon robe, floating in meditation, a brilliant golden aura and a soft halo ring
   behind the head, orbs of light circling. Sky-blue background, face and halo fill the frame.
9. **Day 1 / Day 100.** One floating island split diagonally: the top-left half is bare grass with a
   single small tent, the bottom-right half is a grand red and gold palace with cherry trees. Same
   island, same sky, a clean diagonal seam.
10. **The way up.** A long narrow wooden bridge leads from the viewer across open sky to a floating
   peak crowned by a glowing red and gold hall; a small Roblox avatar walks along it, seen from
   behind. Clouds below, warm light at the end of the bridge.

## Thumbnails (16:9, leave the top quarter clear for a title)
1. **The archipelago.** Golden-hour vista of many floating peaks over a sea of clouds; the nearest is
   a full sect (grand red and gold main hall, pagodas, cherry trees, waterfall, disciples meditating
   on the lawn), farther peaks smaller and still bare, wooden bridges between them.
2. **Day 1 vs Day 100.** Split screen, same camera: left a bare floating island with one tent and one
   avatar holding a hammer, right the same island grown into a grand golden sect with many disciples.
3. **The rarity ladder.** Nine Roblox avatar disciples meditating in a row on a temple lawn, robes from
   plain white on the left through green, blue, purple, gold, teal and crimson to a radiant
   rainbow-white master on the right, auras growing brighter left to right.
4. **Building with light.** A Roblox avatar steps onto a glowing jade pad and a temple hall rises in
   front of them out of beams of golden light, half built, gold sparkles and floating roof tiles
   clicking into place.
5. **Rooftop dawn.** A Roblox avatar meditates on the ridge of a golden roof at dawn, the whole sect
   spread out below, sun rising over a sea of clouds.
6. **Neighbours.** Three Roblox avatars wave to each other from three neighbouring floating peaks
   joined by wooden bridges, each peak a different little sect, bright midday sky.
7. **Breakthrough.** A disciple floats above the main hall in meditation as a pillar of white-gold
   light shoots into the sky and the clouds part in a ring around it; disciples below look up.
8. **Small to great.** A tiny Roblox avatar at the foot of an enormous white stone staircase that
   climbs up through clouds to a colossal golden palace in the sky.
9. **Lantern night.** The sect at blue night, hundreds of warm paper lanterns rising from the lawn
   into the sky, cherry trees lit from below, calm and magical.
10. **Diorama.** Top-down three-quarter view of one round floating island like a perfect tiny garden
   diorama (tilt-shift): the hall, a koi pond, cherry trees, a training ground, disciples, clouds
   drifting past the edge.

## After generation
Claude picks the strongest per concept, fixes Roblox-honesty (every element must exist in the game:
if a generated thing is not in the game, it gets cut or the concept flagged), adds the title in
Fredoka with a soft shadow where wanted, and builds the 150 / 64 px pick board.
