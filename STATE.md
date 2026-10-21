# STATE: what is true right now
> The only status board (R1). Overwrite in place, 80 lines max. History = `git log` (once git exists).

**Phase:** M2 publish week (brief [B01](briefs/B01_PUBLISH_WEEK.md)). M1 playable base is built and
checked in Studio Play (ROADMAP).

## Where things stand
- **Studio:** place 115564708369657 "Cultivation Tycoon". Scripts match `src/`. Place-only edits
  (Lighting, ActiveSky, Showcase island) persist only when Mattéo saves the place.
- **Sync:** Rojo port 34875 is connected from the Studio plugin (scripts in Studio match `src/`).
- **Git:** GitHub `matteosch57-prog/cultivation-tycoon` (private). Every thread's work is merged on
  `integration` (what Rojo serves and Studio tests); `main` gets it after the owner's playtest. How
  merges work: TECH "Branches and integration merges"; history = `git log`.
- **Open forks:** Q1 music bed.
- **Known risks:** phone numbers not measured yet (BACKLOG "Performance"); the store skybox (ART_BIBLE).

- **B01 step 2 save safety:** in `integration`, extended by D26 (one save in flight, budgeted
  autosave, rejoin message on a failed load, ServerHealth; R17).

- **B01 step 3 phone performance:** in `integration`. `Lowpoly` (D20, uploaded meshes) and the D26
  rules (R16: timed frame jobs, nothing animates off screen). Studio: a full peak with the new
  building Kit is ~192k triangles / 33 draw calls on a whole-peak view; Play 60 fps, every frame job
  under 0.1 ms. Not yet measured on the owner's phone (`/perf`, `/clouds`).

- **Building kit** (`Kit.luau`, ART_BIBLE "The kit"): Main Hall levels 1 to 5, Disciple Hall and
  Quarters are assembled from kit pieces (on `integration`). Full peak measured
  192k triangles / 33 draw calls. Visual check report: `docs/research/2026-10-21_visual_check.md`.

- **Step-on pads** (D27, merged in integration): formation array pads, gathering preview, swirl
  build-in, one colour set (`PadLook`), qi / Robux icon on every pad price; chain-buy cause fixed
  (flying build pieces shoved the avatar). Checked in Studio Play. Left: Matteo's ear test of the 6
  new sounds (Sfx `pad*`, `gather`, `smallBell`) and a look at the price card icon in his Play.

- **Endless progression (D29, D31, on integration):** reincarnation from realm 10, Past Lives,
  karma and the Karma Shop are built and checked in Studio Play (mock save); Spirit Tide and playtime
  gifts (D30) too. Left: per-realm visuals and the two later Karma Shop nodes (ROADMAP M3).

- **Economy** (D25, ECONOMY, research `2026-10-21_economy_math.md`): realms 2 to 5 are ~5 to 10 min
  laps, then each realm ~2 to 3x the last; a regular player (2 x 30 min a day) reaches realm 10 about
  day 7 and finishes it about day 20; recruit price restarts each realm. Sims: `tools/sim_economy.py`
  (whole climb, passes, Robux disciples, reincarnation lives at ~5 to 7 days each with x3).
  Simulated only: real pacing waits for the first live batch (funnel and realm events).

- **Shop** (D24, D28; MONETIZATION, SHOP_ITEMS): screen B (Boosts / Qi / Disciples tabs), a "Sect
  Market" island on every peak with step-on pads, 3 passes and 10 products granted through saved
  receipts. Checked in Studio Play with ids at 0 (items read "Soon"). **Owner to do:** create the 13
  items listed in `docs/design/SHOP_ITEMS.md` (type, name, description, price, icon in
  `art/shop_icons/`) and paste each id into `Config.SHOP_PASSES` / `SHOP_PRODUCTS`; then a Studio
  test purchase checks the prompt and ProcessReceipt.

- **Cultivators** (branch `cultivators`, merged into `integration`): disciples are R15 Roblox avatars
  in catalog hanfu, 4 looks x 9 rarities, layered auras, floating idle with faces that blink and watch
  a close player. Checked in Studio Edit (and a Play by Phone performance); design in ART_BIBLE.

## Next action
Phone test after the next publish: `/perf`, walk a full peak, `/clouds`, `/perf` again, send the
`[Perf]` console rows (they close ROADMAP "Phone performance").
