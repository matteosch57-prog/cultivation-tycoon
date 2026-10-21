# Tech

## Code layout (Rojo: `default.project.json`, port 34875)
| Place path | Source | Role |
|---|---|---|
| ReplicatedStorage.Shared.Config | `src/shared/Config.luau` | every number, pad list, realm/feature helpers |
| ReplicatedStorage.Shared.Sfx | `src/shared/Sfx.luau` | client sound kit |
| ServerScriptService.Server.Main | `src/server/Main.server.luau` | plots, grounds, qi, pads, features, saving |
| ServerScriptService.Server.Builders | `src/server/Builders.luau` | one function per pad id |
| ServerScriptService.Server.Style | `src/server/Style.luau` | hero-quality geometry (halls, roofs, islands, clouds) |
| ServerScriptService.Server.Lowpoly | `src/server/Lowpoly.luau` | small balls / cylinders as clones of one low-poly mesh |
| StarterPlayerScripts.Client.Hud | `src/client/Hud.client.luau` | HUD (mock C), phone/computer layouts |
| StarterPlayerScripts.Client.Build | `src/client/Build.client.luau` | price cards, beacons, previews, build animation |
| ServerScriptService.Server.Telemetry | `src/server/Telemetry.luau` | analytics catalogue, funnel, economy events |
| StarterPlayerScripts.Client.Guide | `src/client/Guide.client.luau` | the guide trail to the next pad |
| StarterPlayerScripts.Client.Juice | `src/client/Juice.client.luau` | floating qi, orbs, fly-to, event sounds and light |
| StarterPlayerScripts.Client.PerfLog | `src/client/PerfLog.client.luau` | owner-only `/perf` log and `/clouds` A/B |

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
DataStore `CultivationTycoon_v1`. Studio Play with `MOCK_DATASTORE` on (the default; gated on the flag AND
`IsStudio()`) uses no store: every Play is a new player and nothing saves. With it off, Studio uses
`CultivationTycoon_v1_studio`, so tests never touch live saves. Saved on leave, every `AUTOSAVE` s and on close (close waits for every pending save).

`SaveStore.luau` owns the record `{ v, data, lock = { id, t } }`. Each join gets its own session id and
takes the lock on load (UpdateAsync); every save lands only while the record still carries that id,
and leave/close releases it. So a slow save from an old server or an earlier visit can never
overwrite a newer session. A lock not refreshed for `SAVE_LEASE` s (a crashed server) is taken over;
a live one is retried `SAVE_LOCK_WAITS` times, `SAVE_LOCK_WAIT` s apart. Every DataStore call gets
`SAVE_RETRIES` attempts with backoff. Record format = `DATA_VERSION`; `migrate()` lifts older records
(v0 = the bare data table). A record newer than this server, a failed load or a lock that stays held
disables saving for that session. Errors log as `[Tycoon][save] event=<name> user=<id> ...`.

## Telemetry (`src/server/Telemetry.luau`)
`Telemetry.EVENTS` is the catalogue (name, fields, question); `Telemetry.custom` refuses a name not in
it. Fields are built from positional values into `CustomField01..03` only (Roblox ignores any other
key), always bucketed (`minuteBucket`, `builtBucket`, `realmBucket`), never a UserId or free text. A
custom event name is permanent once a published server sends it (100 per experience): add a field
value before a new name. Studio prints `[Tycoon][analytics] ...` instead of sending (Roblox drops
Studio events). One server budget for every event type; events over it are counted and the count
printed once a minute.
- **Onboarding funnel** (`Telemetry.FUNNEL`, once per player, in order): Joined, First building, Main
  Hall, Five buildings, Disciple Hall, First recruit, First expansion, Celestial Palace, Breakthrough.
  `data.funnel` = steps logged, so a return visit never re-logs. `FunnelTime` gives the minutes played
  (`data.playSec`) at each step.
- **Custom:** `SessionEnd` (buildings bucket, session minutes, first | return), `Recruit` (rarity, realm,
  kept | benched), `Feature` (pill | orb, realm).
- **Economy** (currency `Qi`): sinks per pad id, `recruit`, `breakthrough`; sources summed and sent
  with each autosave and on leave (`income`, `orb`) plus `offline` (TimedReward) on join.
- **Progression:** `Realm` Complete with the realm left behind, on each breakthrough.

## Studio test hooks (Studio only, ServerStorage)
`DebugGrant(player, qi)` · `DebugReset(player)` · `DebugSet(player, key, value)` (`orbNow` spawns an
orb). Client: player attribute `HudDevice` = `pc` / `phone` forces a HUD layout.

## Performance
Budget: ~500k triangles / ~500 draw calls per scene; small parts CastShadow off; few shadowed lights
in view. Evidence: [2026-10-21 phone perf](../research/2026-10-21_phone_perf.md).
- **Triangles, not parts, are the cost.** Parts sharing a shape and material draw instanced (a full
  peak: ~7,200 parts, ~30 draw calls). A Ball part is 432 triangles, a Cylinder 96, a Block 12.
- **Lowpoly:** `Style.P` and `Builders.part` ask `Lowpoly.part(shape, size)` for every part. A Ball
  under `LOWPOLY_MAX` studs, or a Cylinder under it across, is a clone of one uploaded mesh
  (`LOWPOLY_BALL` 80 triangles, `LOWPOLY_CYLINDER` 36, axis along X like a Cylinder part; same box, so
  same look). Templates load once at server start with `AssetService:CreateMeshPartAsync`; with no
  id, or a failed load (`[Tycoon][perf] event=lowpoly_load_failed`), plain parts are built. Source
  meshes: `art/meshes/*.obj` from `tools/lowpoly_meshes.py`. A new small round detail costs nothing
  extra as long as it goes through `P` / `part`; a big ball is still 432 triangles.
- **Streaming** is on in the place (target radius = the default 1024, so every peak stays in).
  Server-built models get no SLIM / StreamingMesh imposter. Client code finds world parts through
  `Sect` signals, never a held reference.
- **Measure on the phone:** owner chat `/perf` (10 min, a `[Perf]` row every 10 s in the console:
  fps median and slow 5%, worst frame, draw calls, triangles, instances, memory, quality) and
  `/clouds` (hides the cloud particles on that screen) for the overdraw A/B.
