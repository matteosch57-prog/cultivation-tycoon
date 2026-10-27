# Heavenly Weather and mutations

This system copies Grow a Garden's weather and mutations. The owner picked option B (weather only) on 2026-10-25.

## Weathers
`Config.WEATHERS` has one row per weather. Each row carries:
- `key`, `name` and `mut`.
- The mutation's `chance` and qi `mult`.
- The slot `weight` and `duration`.
- `color` for the sky, and `tint` + `motion` for the mutation (`Config.mutLook`).

| key | weather | mutation | chance | mult | look |
|---|---|---|---|---|---|
| rain | Spirit Rain | Dewy | 20% | x2 | blue ebb |
| thunder | Thunder Tribulation | Thunderborn | 10% | x4 | yellow spark flicker |
| blood | Blood Moon | Bloodlit | 10% | x5 | red heartbeat |
| star | Starfall | Starforged | 5% | x10 | rainbow, green to violet (PS99 Rainbow) |

Timing:
- A slot opens every `WEATHER_INTERVAL`, half a tide cycle off the tides, with a 20 s warning toast.
- A save that has never seen weather gets a rain at 220 s (`WEATHER_NEWCOMER_AT`).
- The server sets workspace attributes `Weather`, `WeatherUntil`, `WeatherNext` and `WeatherLast`.
- Studio test: set `WeatherNext` to `workspace:GetServerTimeNow()` on the server and a weather starts.

## Mutated disciples
- **Save data:** `data.discMut` is parallel to `discShiny`, with "" meaning none. It is published as the `DiscMut` attribute.
- **Rate:** mutated disciples are counted in priceRate, like Shiny.
- **On the platform:** `src/client/MutationAura.client.luau` (owner pick A, Sol's RNG layers) builds:
  - a pool on the cushion,
  - a rising ring,
  - orbiters with trails,
  - a Starforged halo,
  - pooled Thunderborn arcs.

  It runs client-side from the posed figure. Budget: nearest 6 on phone and 14 on PC, within 60/90 studs. The server only sets the `Mutation` attribute. There are no PointLights (owner rule).
- **In menus:** `Toy.discipleTile` washes the card in the tint with a light sweep. `Toy.mutationMark` adds a glow plus the weather's icon in the bottom-left corner. `Toy.mutMove` is the shared 20 Hz animator.

## Index weather marks
These copy Bee Swarm Simulator's gifted marks.
- **Save data:** `data.mutIndex["rarity|look#Mut"]`, published as the `MutIndex` attribute.
- **Rewards:** every `MARK_STEP` (12) marks pays `MARK_STEP_SUMMONS` (3) free summons (`data.markSteps`). All 144 marks pay +`MARK_FULL_BONUS` (10%) qi forever in `Config.indexMult`, kept out of prices.
- **Pace:** checked with tools/sim_game.py and tools/sim_check.py; pace is unchanged.

## Weather icons
On 2026-10-27 the owner asked: "Weather in index should use an icon, and the weather event too". The mock is docs/art/mocks/weather_icons.html, and the owner picked A: the icon alone.
- **Atlas:** the icons live in docs/art/mocks/icons.js, cells rain 41, thunder 42, blood 43, star 44. The sheet is `Config.ICON_ATLAS`, rbxassetid://97289085176965, 58 cells; Sect Style looks are at 45-57.
- **Drawing:** `Toy.weatherIcon(parent, w, size, props, dark)`. With `dark` set, a mark not found yet draws as a dark silhouette, like the PS99 index.
- **Used in:**
  - Index card marks,
  - the card mutation mark,
  - the weather banner,
  - the HUD weather line,
  - the Odds "During weather" list.
- **New icons:** render the atlas from the latest integration icons.js (`icons.html?view=atlas&style=A`), since other threads add cells too. Make one upload for everyone.

## Analytics
`Telemetry` event `Weather` (docs/design/DATA.md) logs:
- `seen` (once per session per weather, with the realm bucket),
- `mark` (a new index mark),
- `markStep`,
- `markFull`.

## Open
- A still Dewy card can look like a blue Core card. A mutation-colour frame was offered.
- Index marks are about 12 px on PC, and the silhouettes are dim on the dark book. Enlarge them if players find them hard to read.
- The AuraOrb dimming under a mutation aura is only partial.
- There is no rain sound yet. Phone fps has not been measured with many mutated disciples.
- Captures: docs/art/mocks/caps/ (mut_, aura*, icons_*) and /mnt/project-files/2026-10-26_mutation_*/, 2026-10-27_weather_icons/.
