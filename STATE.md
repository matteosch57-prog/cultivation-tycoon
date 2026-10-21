# STATE: what is true right now
> The only status board (R1). Overwrite in place, 80 lines max. History = `git log` (once git exists).

**Phase:** M2 publish week (brief [B01](briefs/B01_PUBLISH_WEEK.md)). M1 playable base is built and
checked in Studio Play (ROADMAP).

## Where things stand
- **Studio:** place 115564708369657 "Cultivation Tycoon". Scripts match `src/`. Place-only edits
  (Lighting, ActiveSky, Showcase island) persist only when Mattéo saves the place.
- **Sync:** Rojo port 34875 is configured (`start-rojo.bat`); the first connect from the Studio plugin
  has not happened yet. Until then the HTTP fallback in TECH "Sync" was used.
- **Git:** `git init` done, nothing committed. No GitHub repo yet (DECISIONS Q2).
- **Open forks:** Q1 music bed, Q2 GitHub repo.
- **Known risks:** part count of a full peak (BACKLOG "Performance"); the store skybox (ART_BIBLE).

## Next action
Mattéo: create the GitHub repo (or `gh auth login`) and make the first commit; connect Rojo on 34875.
Then B01 day 1: save safety.
