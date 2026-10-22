# Visible progression: building skins and status (2026-10-22)

Owner feedback (2026-10-22): "What are reincarnations worth if you can't see any change, like social
status. We probably need skinning on buildings to evolve with them or realms too", and "tycoons are
interesting because you get a bigger, more beautiful island slowly".

## What the game did before
- A breakthrough resets the pads and the island is rebuilt, but every building came back in the same
  art colours (`Style.PAL`). `Config.PALETTES` cycled with the realm but only reached a few old
  Builders paths; the Kit halls never read it.
- Realms 6 to 10 dress the peak (D32: clouds, rocks, second waterfall, storm, halo). Realms 1 to 5
  and every life looked the same, and a reincarnation wiped the realm looks.
- Nothing over a player's head said how far they had come.

## Sources and patterns
- **The base is the progress bar.** Tycoons get their pull from watching a physical base grow rather
  than numbers ([creation.dev, simulator vs tycoon](https://www.creation.dev/compare/simulator-vs-tycoon));
  skipping visual feedback on purchases loses the satisfaction
  ([creation.dev, tycoon](https://www.creation.dev/glossary/tycoon)). Economy owns the island growth
  (it now opens over 4 realms, `Config.REALM_PADS`); this note covers the look of what stands on it.
- **A material ladder reads from far away.** Clash of Clans walls climb wood, uncut stone, cut stone,
  iron, gold, then crystal colours, each tied to the Town Hall level
  ([lowendmac, CoC defenses](https://lowendmac.com/2015/introduction-to-clash-of-clans-part-4-defenses/)):
  an attacker reads a base's level from its colours before reading any number. Our peaks stand side
  by side (playing-together research, "visit and show off"), so the same read works between peaks.
- **Rebirth needs something that stays and shows.** Rebirth resets the base for a permanent bonus
  ([Roblox wiki, Tycoon](https://roblox.fandom.com/wiki/Tycoon)); cosmetics that carry over through
  rebirths are a standard reward ([creation.dev, rebirth](https://www.creation.dev/glossary/rebirth)).
  Simulators show rebirths and rank over the head and on leaderboards
  ([fandom example](https://roblox-the-maze-runner-remake.fandom.com/wiki/Titles_and_Rebirths),
  [Roblox wiki, Simulator](https://roblox.fandom.com/wiki/Simulator)); the DevForum pattern is a
  BillboardGui on the head driven by saved data
  ([DevForum overhead title](https://devforum.roblox.com/t/player-ui-overhead-title-username-display-name/1682758)).
- Our own reincarnation design already planned "lives and peak realm under the name" and "a new
  Main Hall look each life" (`2026-10-21_reincarnation_design.md` 3.4 and 4); never built.

## Options mocked (Studio, the real Great Hall, `docs/art/mocks/2026-10-22_skins_*.jpg`)
- **A, material per realm:** Timber, Red Lacquer (the art), Jade, Imperial Gold over realms 1 to 4
  (the island's 4 opening realms), White Jade from the 2nd life.
- **B, gilding per realm:** the art colours, gold ridges, then beams, then gold leaf. Subtle from far.
- **C, the life picks the grade, the realm adds gilding:** life 1 Red Lacquer, 2 Jade,
  3 Imperial Gold, 4+ White Jade; gilding climbs over realms 2 to 4. Reincarnation is the big jump
  (rare, the status), the realm shows through the growing island plus the gold.
- All: a title over the head, the realm name in its colour, then "3rd Life · Jade" from life 2.

## How it is built
A recolour pass after each build (`src/server/Skin.luau`): each part is matched to its nearest
`Style.PAL` colour and moved by the same offset, so the shading the builders baked in survives;
Neon is left alone. The title is drawn by each
client from the Realm and Lives attributes the server already sets (nothing new on the wire).

## Outcome
Owner picked A ("A is better still"), with the material on realms and lives adding the extras (D53).
