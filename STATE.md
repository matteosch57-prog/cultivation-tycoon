# STATE: what is true right now
> The only status board (R1). Overwrite in place, 80 lines max. History = `git log` (once git exists).

**Phase:** M2 publish week (brief [B01](briefs/B01_PUBLISH_WEEK.md)). M1 playable base is built and
checked in Studio Play (ROADMAP).

## Where things stand
- **Studio:** place 115564708369657 "Cultivation Tycoon". Scripts match `src/`. Place-only edits
  (Lighting, ActiveSky, Showcase island) persist only when Mattéo saves the place.
- **Sync:** Rojo port 34875 is connected from the Studio plugin (scripts in Studio match `src/`).
- **Git:** GitHub `matteosch57-prog/cultivation-tycoon` (private), branch `main`; history = `git log`.
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

## Next action
Phone test after the next publish: `/perf`, walk a full peak, `/clouds`, `/perf` again, send the
`[Perf]` console rows (they close ROADMAP "Phone performance").
