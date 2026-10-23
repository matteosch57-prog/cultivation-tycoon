# Player auras by realm and lives (2026-10-22)

Owner ask: "we should give the user auras based on realms and or reincarnation. May you mock that?"

## The game we copy: Super Power Fighting Simulator

Its aura is the standard rank aura of fighting simulators
([wiki](https://super-power-fighting-simulator.fandom.com/wiki/Auras)):

- Nobody buys it. It appears on its own from the second rank (F-Class has none, E-Class is white)
  and evolves at every rank after that.
- Each rank has its own colour, and the shape grows in steps: a plain glow first, then two-tone
  arms and body, then bubbles, lightning and smoke, and at the top galaxies and nebulae.
- Players can turn other players' auras down or off in settings (Low/High, hide others).

## What we already have, and what stays separate

- The status title over every head already shows the realm (in `Config.realmColor`) and, from life 2,
  "Nth Life". The aura reuses that same colour, so the title and the aura say the same thing.
- The altar winner wears a gold rim light (a Highlight plus gold sparkles, D-altar W3). The player
  aura uses no Highlight, so the winner stays unmistakable.
- No paid player aura exists in the Shop. Paid auras belong to disciples (the Elder in the Welcome
  Pouch and the rarity products), so an earned player aura takes no paid value away.
- Realm resets on rebirth (D63). An aura that follows only the realm drops back to nothing every
  rebirth, which is why B and C exist.

## The three mocks (`tools/mock_player_auras.luau`, `src/server/PlayerAura.luau`)

Steps for all: realm or life 1 none, then wisps rising from a ring at the feet, flames up the
body from step 3, twinkling sparks round the body from step 5, every layer larger and denser up to step 9.

- **A Realm aura** (Super Power Fighting Simulator as it is): the aura follows the current realm.
  Gone again after a rebirth until the player climbs back.
- **B Realm aura + life beads**: A, plus one gold bead per rebirth on a halo behind the head,
  kept forever (up to 9).
- **C Life aura**: the aura grows with lives instead of realms (life 2 wisps, and so on), in the
  disciple rarity colour of that life. Never lost, but nothing changes during a life.

Budget: at most 3 particle emitters a player and ~60 live particles at the top step; neon beads only, no Light (R3).

## Owner pick B, then "way better, a bit like Warcraft 3" (2026-10-22 21:48)

Warcraft 3's hero auras (Devotion, Unholy, Brilliance, Endurance) are a glyph circle on the ground
under the hero, turning slowly, with light rising from it; the hero's body itself stays clean. So
the realm aura is now that circle in the realm colour, and the layers SPFS adds with the rank stack on it:
glyph and rising motes (realm 2), a counter-turning outer ring (3), wisps up the body (4), pulses
across the ground (6), flames (8), all larger and brighter up to realm 10.

Beads (owner: "premium... 20 yellow then 20 red then 20 blue and with more aura each time... easily to
100"): a gold-chain prayer-bead halo of 20 slots behind the head. Rebirths 1-20 fill it gold, 21-40
re-fill it crimson over the gold, then azure, violet and white jade up to 100. Each band the beads
grow and the halo sparkles more. Past 100 it stays full white jade.

## v3 (owner 2026-10-23: "beads can get more aura starting red already", "the ground ones are too
blurry, Warcraft 3 has different shapes")

The blurry particle glyph is replaced by a crisp array drawn with UI lines and circles on a flat
SurfaceGui (`src/server/AuraGlyph.luau`), a different figure per realm: ring and ticks (2), the square
(3), the hexagram (4), lotus round a pentagram (5), the eight trigrams (6), two squares turning apart
(7), trigrams round a hexagram (8), the great lotus and nine-point star (9), the full array (10+).
Two layers turn opposite ways on the client (`AuraSpin.client`, Motor6D Transforms, near and on
screen only). Beads from the second colour (red) on: a soft glow in the band colour behind the halo and
more sparkles; from the third (blue) light also rises off it.

## v4 (owner 2026-10-23 07:21: "remove the bronze circle from beads", "search more online", "colour plus
light intensity slightly higher", "more difference between each", "keep some of the aura we add before")

Online search found no written description of the Warcraft 3 aura art (wikis list stats only), so the
motifs come from the auras as they look in game (from memory, not a source): Devotion's sun ring of
short rays, Endurance's arrows, Thorns' spikes, Brilliance's rune circle; and from Taoist formation
arrays: the eight trigrams, the taiji, the 28 lunar mansions, a ring of seal characters, the lotus.
Each realm now has its own silhouette: sun rays (2), square with arrows in (3), hexagram (4), lotus
round the pentagram (5), trigrams round a taiji with seal script (6), thorns round two squares (7),
28 mansions round trigrams (8), lotus in a crown of rays (9), the full array (10+). Lines are 1.4x
bolder, a soft disc of the realm colour lights the ground under them, SurfaceGui brightness 3 to 4.5,
and the v2 particle glow, counter ring and pulse are back under the lines. The beads lost their chain.
