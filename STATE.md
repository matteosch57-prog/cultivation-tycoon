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
- **Known risks:** part count of a full peak (BACKLOG "Performance"); the store skybox (ART_BIBLE).

- **B01 step 2 save safety:** built and checked in Studio (mock store tests + a real Play join/leave
  on the `_studio` store); not committed yet.

- **B01 step 3 phone performance** (branch `phone-perf`): measured in Studio Edit, a full peak is ~750k
  triangles in ~30 draw calls; `Lowpoly` swaps small balls / cylinders for two shared low-poly meshes
  (-62% triangles, same look, D20). Off until the two meshes are uploaded. `/perf` and `/clouds`
  (owner only) log the phone numbers.

## Next action
Mattéo: upload `art/meshes/ball_lowpoly.obj` and `cylinder_lowpoly.obj` (Studio Asset Manager), put
their ids in `Config.LOWPOLY_BALL` / `LOWPOLY_CYLINDER`, then on the phone: `/perf`, walk a full peak,
`/clouds`, `/perf` again, and send the console rows.
