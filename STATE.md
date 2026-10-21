# STATE: what is true right now
> The only status board (R1). Overwrite in place, 80 lines max. History = `git log` (once git exists).

**Phase:** M2 publish week (brief [B01](briefs/B01_PUBLISH_WEEK.md)). M1 playable base is built and
checked in Studio Play (ROADMAP).

## Where things stand
- **Studio:** place 115564708369657 "Cultivation Tycoon". Scripts match `src/`. Place-only edits
  (Lighting, ActiveSky, Showcase island) persist only when Mattéo saves the place.
- **Sync:** Rojo port 34875 is configured (`start-rojo.bat`); the first connect from the Studio plugin
  has not happened yet. Until then the HTTP fallback in TECH "Sync" was used.
- **Git:** GitHub `matteosch57-prog/cultivation-tycoon` (private), branch `main`; history = `git log`.
- **Open forks:** Q1 music bed.
- **Known risks:** part count of a full peak (BACKLOG "Performance"); the store skybox (ART_BIBLE).

## Next action
Mattéo: connect the Studio Rojo plugin on 34875 (`start-rojo.bat`). Then B01 step 2: save safety.
