# Something new to build every rebirth (2026-10-25)

Owner (2026-10-25): "I'm afraid long term isn't so interesting once you build the same things 50
times." Then "We can do it all."

## What the game does now
- Every breakthrough wipes the island and every rebirth goes back to realm 1 built (D56, D63); the
  realm rebuilds 16 / 31 / 43 / 63 pads. Between minute 10 and 60 a player presses ~390 pads, and only
  ~25 of them are a building they have never seen (`2026-10-24_core_loop_after_10.md`).
- The look ladder (D53, `Skin.luau`) is colour only: Timber, Red Lacquer, Jade, Imperial Gold over
  realms 1 to 4, then White Jade / Void Amethyst / Celestial Azure at realm 4 in lives 2, 3, 4+.
  **From rebirth 3 on nothing changes any more**: every rebuild is Celestial Azure, same shapes.
- Realms 6 to 10 dress the sky round the peak (RealmLook), but the buildings stay the same.
- Rebirth 10 comes at ~4.8 h for an engaged player (qisim), so a player sees ~10 rebirths in the
  first week and the ladder is spent by the first hour.

## What top games do
- **Build Your Backrooms** (2026): every rebirth adds rooms and monsters that did not exist before
  (rebirth 1: Pipe Corridor, Electrical Room...; rebirth 3: Hotel Corridor, Old Lobby...; rebirth 6:
  Red Pool), and rebirth 1 opens "biomes, which let you change the visual style of your maze"
  ([allthings.how](https://allthings.how/build-your-backrooms-how-to-rebirth-and-every-rebirth-unlock/)).
- **Pet Simulator 99**: 99 zones, each its own theme (Colorful Forest, Desert Pyramids, Ice Castle,
  Underworld, Cloud Palace); the next step is always a place that looks new
  ([progameguides](https://progameguides.com/roblox/all-areas-in-pet-simulator-99-roblox/)).
- **Military Tycoon**: a rebirth unlocks new units and base improvements that were locked before
  (Demolition Squad at rebirth 1, Elite Squad at rebirth 2)
  ([allthings.how](https://allthings.how/military-tycoon-how-to-rebirth-fast-and-progress-in-roblox/)).
- **Clash of Clans**: every Town Hall level redraws the buildings (shape and ornaments, not only
  colour), so a base's level reads from far (already used for D53's colour ladder).
- Rebirth rewards that stay and show are the standard ([creation.dev](https://www.creation.dev/glossary/rebirth)).

The common rule: **a rebirth must unlock something you have not seen**, either a new look for what
you rebuild (Backrooms biomes, CoC levels) or a new thing to build (Backrooms rooms, Military Tycoon
units), and it should be a collection you can browse (PS99 index).

## Options (mocks: `docs/art/mocks/2026-10-25_sect_styles_*.jpg`)
- **A Sect Styles** (Backrooms biomes + CoC): each rebirth unlocks a whole-sect style that changes
  shapes and ornaments, not only colour: roof ornaments, materials, ground props and an ambience
  particle. Rebirths 1 to 10 one each, then one every 5 rebirths. Collected in a Styles page; the
  player picks which unlocked style the sect builds in (default = newest).
- **B A new building every rebirth** (Backrooms rooms, Military Tycoon units): each rebirth opens one
  extra pad with a building never seen before (Sword Forge, Star Observatory, Spirit Beast Den...),
  paying a little qi. Touches the economy: sims first.
- **C Relic Terrace** (PS99 index, rebirth trophies): each rebirth leaves a relic statue on a terrace
  behind the Main Hall that no reset takes; sets of 5 give a small bonus.

## Built (A, on the recommended pick)
`Config.SECT_STYLES` (12 styles: rebirths 1 to 10, then 15 and 20), `SectStyle.luau` (recolour +
ridge ornaments + one ambience emitter a peak), `Skin.apply` wears the style (else the D53 ladder),
a rebirth that unlocks one wears it at once ("New style!" toast), the Rebirth screen names the style
the next rebirth unlocks, and a Sect Styles page (Rebirth screen) wears any unlocked one or Classic
(`SetSectStyle` remote). The overhead title says "3rd Life · Volcano Forge".

## Each style's reference (2026-10-25, owner: "mock all styles ... from close, base it on research")
PS99's 99 areas each own one theme (Snow Village / Icy Peaks, Volcano / Obsidian Cave, Cherry Blossom,
Autumn, Atlantis, Fire Dojo...: [thenerdstash](https://thenerdstash.com/all-biomes-in-pet-simulator-99-how-to-unlock-them/));
our styles take one of those themes each and dress it in real Chinese palace rules
([Wikipedia, imperial roof decoration](https://en.wikipedia.org/wiki/Imperial_roof_decoration): ridge
beasts, a dragon at the tail; [chinatravel, Forbidden City](https://chinatravel.com/beijing/forbidden-city/architecture):
yellow glaze for the emperor, red walls and columns, white marble terraces, black tiles on the library
against fire, green for princes, blue for calm).
| Rebirth | Style | Theme source | Signature |
|---|---|---|---|
| 1 | Snow Lotus | PS99 Snow Village / Icy Peaks, winter temples | snow roofs over deep lacquer, ice crystals on ridges, falling snow |
| 2 | Volcano Forge | PS99 Volcano / Obsidian Cave; black fire-guard tiles | black tiles, basalt walls, orange trim, lava pearl + ridge beasts, embers |
| 3 | Sakura Spring | PS99 Cherry Blossom | pink roofs, white walls, petals |
| 4 | Moon Palace | Chang'e's Guanghan Palace; Temple of Heaven blue | deep blue tiles, white marble, crescent finials |
| 5 | Thunder Peak | storm peaks (realm 9 lightning) | violet slate, gold lightning rods, sparks |
| 6 | Dragon Emperor | Forbidden City | yellow glaze, red walls, white marble, gold pearl + green ridge beasts |
| 7 | Autumn Maple | PS99 Autumn | maple-red roofs, amber trim, falling leaves |
| 8 | Abyssal Jade | PS99 Atlantis / Coral Reef; green princely tiles | deep teal tiles, jade marble, glowing pearls |
| 9 | Phoenix Flame | PS99 Fire Dojo; fenghuang at the ridge head | crimson tiles, gold feather finials, rising sparks |
| 10 | Heavenly Cloud | xianxia heavenly palace | white marble, pale gold tiles, cloud motes |
| 15 | Starfall | night sky | navy tiles, silver, star finials |
| 20 | Golden Lotus | the top grade | gold everywhere |
