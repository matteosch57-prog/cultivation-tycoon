# Tech

## Code layout (Rojo: `default.project.json`, port 34875)
| Place path | Source | Role |
|---|---|---|
| ReplicatedStorage.Shared.Config | `src/shared/Config.luau` | every number, pad list, realm/feature helpers |
| ReplicatedStorage.Shared.Sfx | `src/shared/Sfx.luau` | client sound kit |
| ServerScriptService.Server.Main | `src/server/Main.server.luau` | plots, grounds, qi, pads, features, saving |
| ServerScriptService.Server.Builders | `src/server/Builders.luau` | one function per pad id |
| ServerScriptService.Server.Style | `src/server/Style.luau` | hero-quality geometry (halls, roofs, islands, clouds) |
| StarterPlayerScripts.Client.Hud | `src/client/Hud.client.luau` | HUD (mock C), phone/computer layouts |
| StarterPlayerScripts.Client.Build | `src/client/Build.client.luau` | price cards, beacons, previews, build animation |
| StarterPlayerScripts.Client.Juice | `src/client/Juice.client.luau` | floating qi, orbs, fly-to, event sounds and light |

Place-only content (not in Rojo): Lighting and `ActiveSky`, `ServerStorage.Sky_Original`, the Edit
`Showcase` island, Terrain decoration. It persists only when the owner saves the place.

## Sync
Normal: `start-rojo.bat` (port 34875), then Connect in the Studio Rojo plugin.
Fallback used before Rojo existed: `python -m http.server 8765` in `src/` and an `execute_luau` that
fetches each file and calls `ScriptEditorService:UpdateSourceAsync` (HTTP requests are enabled).

## World layout
Hub at the origin, 6 peaks at `PLOT_RADIUS` (215) around it, all standing at world y = `BASE_Y` (2).
Each peak's `frame` has +Z facing the hub. `buildGrounds(plot, radius)` rebuilds island, terrain,
trees, waterfall, bridge and arch when the island grows or shrinks.

## Data
DataStore `CultivationTycoon_v1`; Studio uses `CultivationTycoon_v1_studio` so tests never touch live
saves. Saved on leave, every `AUTOSAVE` s and on close. A failed load disables saving for that session.

## Studio test hooks (Studio only, ServerStorage)
`DebugGrant(player, qi)` · `DebugReset(player)` · `DebugSet(player, key, value)` (`orbNow` spawns an
orb). Client: player attribute `HudDevice` = `pc` / `phone` forces a HUD layout.

## Performance budget
~500k triangles / ~500 draw calls per scene; small parts CastShadow off; few shadowed lights in view.
A fully built peak is far over a phone-friendly part count: halls, pagodas and pavilions must be
baked to reused meshes before players arrive (BACKLOG).
