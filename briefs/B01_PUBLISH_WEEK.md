# B01 Publish week

**Goal:** a public release in about a week, with Robux products, then read what players do.
**Spec homes:** [VISION](../docs/design/VISION.md), [ECONOMY](../docs/design/ECONOMY.md),
[MONETIZATION](../docs/design/MONETIZATION.md), [TECH](../docs/design/TECH.md), [FEEL](../docs/design/FEEL.md).

## Steps
1. **Organise** (D18): docs, Rojo 34875, vault folder, git. Owner: GitHub repo + first commit.
2. **Save safety:** session lock (UpdateAsync with a session id and a lease), retries with backoff, a data
   version field and migration hook, structured error logging; a failed load never saves over data.
3. **Phone performance:** bake the Main Hall levels, pagodas, halls and pavilion to reused MeshParts;
   enable streaming sensibly; measure part count, fps and cloud overdraw on the owner's phone.
4. **Products** (D17): owner creates them and sends ids; game passes checked on join, developer products
   through an idempotent `ProcessReceipt`; a small shop screen (mock first, R4); recruit odds shown.
5. **First 5 minutes:** a guide arrow from spawn to the first pads; tune realm 1 to 3 pacing with a
   quick simulation of time to each milestone.
6. **Return hooks:** daily reward, an offline-earnings screen, a realm leaderboard, a settings screen
   with music / SFX / ambience volumes (mocks first).
7. **Store page + analytics:** icon and thumbnails from Studio captures, description, the age
   questionnaire; analytics events for the first session (first pad, first Main Hall level, first
   expansion, first breakthrough, product views and buys).
8. **Owner phone playtest**, fixes, owner publishes.

## Telemetry
Step 7 adds the first-session funnel and product events; every later feature names its event.

## Done when
ROADMAP M2 is ticked, STATE.md says what shipped, and the decisions are in DECISIONS.md.
