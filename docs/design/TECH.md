# Tech

## Code layout (Rojo: `default.project.json`, port 34875)
| Place path | Source | Role |
|---|---|---|
| ReplicatedStorage.Shared.Config | `src/shared/Config.luau` | every number, pad list, realm/feature helpers |
| ReplicatedStorage.Shared.Sfx | `src/shared/Sfx.luau` | client sound kit |
| ServerScriptService.Server.Main | `src/server/Main.server.luau` | plots, grounds, qi, pads, features, saving |
| ServerScriptService.Server.Builders | `src/server/Builders.luau` | one function per pad id |
| ServerScriptService.Server.Style | `src/server/Style.luau` | hero-quality geometry (halls, roofs, islands, clouds) |
| ServerScriptService.Server.ServerHealth | `src/server/ServerHealth.luau` | `[SRVHEALTH]` / `[DSMON]` lines, throttle watch, health events |
| ReplicatedStorage.Shared.PerfMark | `src/shared/PerfMark.luau` | frame-job timing for `/perf`, `onScreen` test |
| ServerScriptService.Server.Lowpoly | `src/server/Lowpoly.luau` | small balls / cylinders as clones of one low-poly mesh |
| StarterPlayerScripts.Client.Hud | `src/client/Hud.client.luau` | HUD (mock C), phone/computer layouts |
| StarterPlayerScripts.Client.Build | `src/client/Build.client.luau` | price cards, beacons, previews, build animation |
| ServerScriptService.Server.Telemetry | `src/server/Telemetry.luau` | analytics catalogue, funnel, economy events |
| StarterPlayerScripts.Client.Guide | `src/client/Guide.client.luau` | the guide trail to the next pad |
| StarterPlayerScripts.Client.Juice | `src/client/Juice.client.luau` | floating qi, orbs, fly-to, event sounds and light |
| ServerScriptService.Server.Shop | `src/server/Shop.luau` | passes, products (ProcessReceipt), hub shop pads |
| StarterPlayerScripts.Client.Shop | `src/client/Shop.client.luau` | shop screen (mock B), hub pad cards |
| ReplicatedStorage.Shared.Toy | `src/shared/Toy.luau` | HUD drawing kit (text, toy buttons, icons) for new screens |
| StarterPlayerScripts.Client.PerfLog | `src/client/PerfLog.client.luau` | owner-only `/perf` log and `/clouds` A/B |

Place-only content (not in Rojo): Lighting and `ActiveSky`, `ServerStorage.Sky_Original`, the Edit
`Showcase` island, Terrain decoration. It persists only when the owner saves the place.

## Sync
Normal: `start-rojo.bat` (port 34875), then Connect in the Studio Rojo plugin.
Fallback used before Rojo existed: `python -m http.server 8765` in `src/` and an `execute_luau` that
fetches each file and calls `ScriptEditorService:UpdateSourceAsync` (HTTP requests are enabled).

## Branches and integration merges
- Each thread works on its own branch (`economy`, `shop`, `pads`, `cultivators`, `reincarnation`,
  `perf-health`, ...), usually in its own worktree, and rebases on `origin/integration` before asking
  for a merge. `integration` is the branch Rojo serves from the main checkout
  (`C:\Work\cultivation-tycoon`) and the one Studio tests; `main` only gets `integration` once the
  owner has playtested it.
- One thread at a time owns merges into `integration`. Recipe: `git fetch origin`; check
  `git diff --name-only HEAD...origin/<branch>` against `git status` (another thread's uncommitted
  edits in the main checkout must never be lost); `git merge --no-edit origin/<branch>`; push; tell
  the coordinator the new tip.
- Overlap with someone's uncommitted file: copy it to a backup file AND `git stash push -m <unique
  tag> -- <file>` (never a bare `git stash` / `pop`: the stash is shared by every worktree), then merge.
- D-number clash in DECISIONS: keep the one already on `integration`, renumber the newcomer, and fix
  every `Dnn` it cites in code comments and docs (grep only that branch's lines).
- After a merge that touches `Config.luau`, run `python tools/sim_pacing.py --runs 3` (it parses
  Config, so a broken pad line fails loudly) and, for economy keys, `tools/sim_economy.py`.
- Before every merge into `integration` and before a publish: `python tools/check_playergui.py`
  (R19, D68: nothing needed may live where the first spawn wipes it; exit 1 lists the lines).
- A GitHub "remote unpack failed" on push is server-side: retry with backoff (2, 4, 8, 16 s).
- Worktrees left after the first session (2026-10-21), all merged into `integration`, safe to remove
  with `git worktree remove <path>` once their threads are closed: `C:\Work\ct-cultivators`
  (has one untracked mock, `docs/art/mocks/cultivators_all.gif`: keep or copy it first),
  `C:\Work\ct-economy`, `C:\Work\ct-pads`, `C:\Work\cultivation-tycoon-perf`,
  `C:\Work\cultivation-tycoon-reinc`. Their branches stay on origin.

## World layout
Hub at the origin, 6 peaks at `PLOT_RADIUS` (215) around it, all standing at world y = `BASE_Y` (2).
Each peak's `frame` has +Z facing the hub. `buildGrounds(plot, radius)` rebuilds island, terrain,
trees, waterfall, bridge and arch when the island grows or shrinks.

## Step-on pads (D27)
- Server: every pad is an invisible anchor part (`Pad_<id>` on a peak, `ShopPad_<key>` on a shop island)
  tagged `StepPad`, attributes `PadKind` (build / breakthrough / shop), `Title`, `Cost`, `Feature`,
  `OwnerId` (none = anyone). Buying is a position check every 0.1 s (`checkPads`, `PAD_REACH` 2.6);
  after a buy every pad waits until the player stands on none (`s.padHold`). Shop pads prompt only
  after the player was seen off them.
- Client (`Build.client.luau`) draws every tagged pad locally in `workspace.LocalPadFX`: the array,
  beacon, price card, preview and press; colours only from `src/shared/PadLook.luau`. A building's
  preview is a hidden copy under its pad (`Preview`); the client moves its pieces with `BulkMoveTo`.
- Build-in: the client animates a model with a fresh `BuiltAt`; its parts are CanCollide off locally
  while they fly (colliding pieces shoved the avatar onto other pads and bought them).

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
(v0 = the bare data table), then `backfill` (Main) adds every default key the save lacks, nested too;
a stored value is never replaced or retyped.

Ported from Gladiator RNG's DataService (its R5, D26 here):
- **Fail closed:** a failed load, a lock that stays held or a newer record kicks the player with a
  rejoin message (`KICK_TEXT`) and logs `SaveIssue`; nobody plays a session that cannot save.
- **One save in flight per player:** `save(s, release, urgent)`; an autosave is skipped while one is
  in flight, a receipt (`urgent`) and the leave/close save (`release`) wait their turn and write.
- **Budget:** an autosave pass is staggered `SAVE_STAGGER` s per player and waits (up to 10 s) for
  `SAVE_MIN_BUDGET` UpdateAsync budget; leave, close and receipts never wait for budget.
- **Receipts** (Shop): the PurchaseId ring is in the save; PurchaseGranted only after a save landed.
- **Logs:** `warn("[Tycoon][save] <event>")` with constant text (the Error Report groups by string),
  the detail in a `print`.
- **MemoryStore:** not used yet. When something needs it (a cross-server leaderboard cache, a
  queue): every call pcall'd with a DataStore fallback, keys bounded (never one per player that
  grows), an expiration on everything, values under 30 KB, and the quota in mind (64 KB + 1 KB per
  player). Ordered DataStore writes (the realm leaderboard) go through one queue that keeps a budget
  reserve, newest value per key (Gladiator `BoardWrites`).

## Server health (`src/server/ServerHealth.luau`)
Passive (no DataStore calls, every loop pcall'd), ported from Gladiator RNG. Every `HEALTH_SAMPLE` s:
`[SRVHEALTH]` (heartbeat fps, worst frame, memory, instances, players, worst ping) and `[DSMON]`
(the 5 DataStore budgets), `-ALERT` when fps < `HEALTH_LOW_FPS`, ping > `HEALTH_ALERT_PING` or a
budget < `HEALTH_LOW_BUDGET`. The engine's DataStore / MemoryStore throttle warnings are classified
(exp, srv, key, queue, throttled, overlimit). Events: `ServerHealth` (the worst sample of each
`HEALTH_EVENT` s window) and `DataStorePressure` (cooldown per series; suppressed samples
accumulate: throttles sum, budgets keep their lowest). Live consoles print every sample; Studio only
the first one and alerts.

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
  kept | benched), `Feature` (pill | orb, realm), `Shop` (open | prompt | bought | closed, source or
  item key, realm).
- **Economy** (currency `Qi`): sinks per pad id, `recruit`, `breakthrough`; sources summed and sent
  with each autosave and on leave (`income`, `orb`) plus `offline` (TimedReward) on join and Qi
  packs (IAP, sku = pack key).
- **Progression:** `Realm` Complete with the realm left behind, on each breakthrough.

## Studio test hooks (Studio only, ServerStorage)
`DebugGrant(player, qi)` · `DebugReset(player)` · `DebugSet(player, key, value)` (`orbNow` spawns an
orb; `friend`, another player or the same one, counts them as a friend here, D35). Client: player attribute `FriendsCard` = true opens the group card; `IntroGo` = true presses the intro's GO; `LaunchTap` = true taps the launch screen. Client: player attribute `HudDevice` = `pc` / `phone` forces a HUD layout.

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
  fps median and slow 5%, worst frame, draw calls, triangles, instances, memory, quality, and each
  PerfMark job's average/worst ms; a `[Perf] hitch` line for every frame over 50 ms naming the
  jobs that ran before it) and `/clouds` (hides the cloud particles on that screen) for the
  overdraw A/B.

### Rules for new code (R16; Gladiator RNG docs/perf/PERFORMANCE.md, D671)
1. **Small round details go through `Style.P` / `Builders.part`** so they become low-poly meshes; a
   new Ball bigger than `LOWPOLY_MAX` costs 432 triangles: count before adding many.
2. **Nothing per frame for what is not seen.** A client loop that animates checks
   `PerfMark.onScreen(camera, pos, radius)` and distance first, and sleeps otherwise (cultivators,
   qi orbs). Effects switch off by distance (cultivator auras beyond 90 studs).
3. **Time every per-frame or burst job:** `local t0 = PerfMark.begin()` ... `PerfMark.finish("name", t0)`
   (hud, cultivators, guide, orbs, padcards, move, reveal, auras), so `/perf` names it.
4. **Write only on a real change.** Compare with the last value before writing a property, above all
   on BillboardGui / SurfaceGui text and colours (each write redraws the GUI).
5. **Big builds fill an unparented Model and parent it once** (one replication; `buildModel`).
6. **Few big particles, never many layers of transparency over the screen;** a new emitter states
   its Rate x Lifetime (live particles) and how far it shows.
7. **Streaming:** client code finds world parts through `Sect` signals and tags, never a held part
   reference or a client ray against far geometry (it may not be streamed in).
8. **Measure, then change only what the measurement names;** no visual cut without the owner's OK.
