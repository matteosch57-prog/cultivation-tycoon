# Data: saves, memory and what we learn about players

Audit of 2026-10-22, checked against what went wrong in Heavenly RNG and Gladiator RNG.

## Saves (DataStore)
One record per player (`u<userId>` in `Config.DATASTORE`), written by `src/server/SaveStore.luau`.

| Past incident (other game) | What happened there | Here |
|---|---|---|
| Heavenly 2026-06-19 outage | 12 ordered-board writes per player per minute filled the request queue; nobody could join | No ordered stores, no leaderboards. Autosave waits for `SAVE_MIN_BUDGET` and staggers players |
| Heavenly 2026-06-24 throttle | a save after every action hit the experience-wide write cap | Saves only on a 60 s timer, plus leave, close, receipts and a new life. One save in flight per player |
| Heavenly 2026-07-12 MemoryStore at 97% | a list capped on read, never on write, filled the universe quota | No MemoryStore and no MessagingService |
| Heavenly hot keys | every member saved into 3 shared keys | Every key is one player's own |
| Gladiator R5 | a failed load must not let the player play unsaved | Fail closed: a failed load asks the player to rejoin |
| Overwrites across servers | a slow old server overwrote a newer save | Session lock with a lease; a save lands only while this session holds the lock |
| Robux granted twice | a retried receipt paid again | PurchaseIds kept in the save (`RECEIPTS_KEPT`), granted then saved |
| Field retyped by a release | old servers broke on the new type | Additive `backfill` only; never retype a stored field (`DATA_VERSION` + `migrate`) |

Record size: about 3 KB plus the journal, which is capped at about 8 KB. Every list in the save is
capped (disciples `DISCIPLE_CAP`, receipts `RECEIPTS_KEPT`, journal below).

**Monitoring already live:** `ServerHealth` prints `[SRVHEALTH]`/`[DSMON]` every 30 s and sends the
events `ServerHealth` and `DataStorePressure`; `SaveIssue` counts failed loads.

## Server memory
Measured in Studio Play on 2026-10-22: one peak goes from 33,356 workspace instances (empty) to 46,197
(every building). After 7 empty-to-full rebuild cycles the instance count came back exactly, and the
Lua heap fell back to 6.3 MB after garbage collection: no leak. Every per-player table (sessions,
friends, Guard, Shop, Altar, Journal) is cleared at leave, and a leaving player's peak is cleared.
Studio cannot measure phone memory: use `/perf` on a phone (PerfLog).

## What we learn about players
Two layers.

**1. Roblox Analytics (totals across players, ~24 h lag).** Catalogue: `Telemetry.EVENTS`, with the
question each event answers. Onboarding funnel (`Telemetry.FUNNEL`), economy sources and sinks per
item, realm progression, and these custom events: FunnelTime, SessionEnd, LeaveState, Build, Recruit,
Feature (pill, orb, gift, hands), IdleChest, Shop, DiscipleBought, KarmaShop, Reincarnate, AltarRound,
Social, ServerHealth, DataStorePressure, SaveIssue.
- **Build** (2026-10-22): which building, realm, minutes played. Shows build order and skipped buildings.
- **LeaveState** (2026-10-22): minutes since the last buy, pads affordable at leave, AFK share. Splits
  "left at a wall" (nothing affordable, long since a buy) from "left lost" (things to buy) and "idled".
- Roblox rules: only CustomField01..03 are read; at most 8,000 field combinations per event and 100
  event names; never a UserId or client text in a field.

**2. The journal (per player, in their own save).** `src/server/Journal.luau`, `data.journal`:
- `first[code]` = minutes played the first time, `count[code]` = how many times (lifetime).
- `log` = every action in order, but only in the first two hours of play (at most 250 lines). This is
  the new-player story: what they did, in what order, and the last thing before they left.
- `sess` = the last 30 sessions: start time, length, AFK seconds, buildings owned.
- Codes: `buy:<pad|hire_x|recruit|breakthrough>`, `get:<offline|chest|welcome|altarWin|...>`, and every
  analytics event as `<Event>:<first field>` (`Recruit:Rare`, `Shop:prompt:x2`, `Feature:pill`,
  `KarmaShop:seat`, `FunnelTime:Main Hall`), plus `join` and `leave`. Codes come only from server
  names, never from client text.

**Reading it:** `tools/journal_report.luau` (paste into the Studio command bar in Edit, API access on).
It is read only (ListKeysAsync and GetAsync). `USER_ID = 0` prints a summary over up to 300 saves:
next-day and week returns, median session and AFK share, every action with the share of players who
did it and when, and what one-session players did last before leaving. `USER_ID = <id>` prints one
player's sessions and action log.

## Not logged (on purpose or not yet)
- Which menus a player opens, apart from the shop: these live in the client UI scripts.
- Chat text, or anything personal.
