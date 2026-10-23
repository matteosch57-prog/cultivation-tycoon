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

- **Endless progression (D63 rebirth, D31, D32, on integration):** Muscle Legends' rebirth (qi price +
  step, back to realm 1 built, +50% qi each, karma each, realms gated by rebirths; checked in Studio
  Play 2026-10-22), the Karma Shop (Heavenly Hands included) and the realm 6 to 10+ looks
  are built and checked in Studio Play (mock save); Spirit Tide and playtime gifts (D30) too. Left:
  Matteo's look at the Karma Shop page with 8 tiles (not captured: it needs a tap).

- **Economy** (ECONOMY; sims `tools/sim_game.py` + the second opinion's `tools/sim_check.py`): the
  island opens over realms 1 to 4 (D48), new lives start built (D56), rebirth opens only at a realm
  gate (D63, D66), every realm costs x5, gates go on past realm 17, Harmony / rebirth / index / passes
  stay out of prices (D67). Sim, regular player: realm 2 ~5 min, first rebirth ~11 min, realm 12 day 7,
  18 day 21, 24 day 60. Simulated only: real pacing waits for the first live batch.
- **Build flow** (D69, D71, on `integration`): a breakthrough asks for a confirm on its own screen; a
  pad shows a build preview and the step-out teleport is gone. Checked in Studio Play.

- **Shop** (D24, D33; MONETIZATION, SHOP_ITEMS): screen B (Boosts / Qi / Disciples tabs), items
  sold where they act (passes at the peak entrance, pill at the furnace, orbs at the array), a
  Disciple Garden island with the six disciples for sale, a Get Qi offer on a pad out of reach; 3
  passes and 11 products (the 5 Robux Welcome Pouch included, D38) granted through saved receipts. Item ids are in `Config.SHOP_PASSES` / `SHOP_PRODUCTS`. **Owner to do:** a Studio test
  purchase checks the prompt and ProcessReceipt; badge ids in `Config.BADGES` (BADGES.md).

- **Cultivators** (branch `cultivators`, merged into `integration`): disciples are R15 Roblox avatars
  in catalog hanfu, 4 looks x 9 rarities, layered auras, floating idle with faces that blink and watch
  a close player. Checked in Studio Edit (and a Play by Phone performance); design in ART_BIBLE.
  Then the premium pass (D41, branch `characters`, merged): one anime head, rarity ladder of magic
  circles, light orbs, halo, steel jian fans with a rim glow, lotus seat, ornaments, mudra / qi surge /
  bow, a recruit arrival walk, a flying pose. Checked in Studio Play; left: Matteo's own playtest.

- **Visible progression** (D53, D62, on `integration`): buildings recolour by realm (Timber, Red
  Lacquer, Jade, Imperial Gold over realms 1 to 4; later lives top out in White Jade / Void Amethyst /
  Celestial Azure), lanterns and motes grow with lives, the Main Hall grows 8% / 15% in lives 2 / 3,
  a status title over other players' heads; hub ranking wall (Greatest Sects, Richest Qi, This Week,
  global + per country stores), Lives in the player list. Checked in Studio Play (skins, hall,
  wall with sample rows via `Ranks.debugRows`). The Ranks chip opens the Rankings screen (D80:
  Global / Country / Friends, top 100, your row pinned; Go to the wall teleports).
  Bigger boards, a bigger hub and portals to every island and back (D70, checked in Studio Play).

- **Sky Islets** (D42, on `integration`): home island + Fields / Alchemy / Disciples / Summit islets
  opened by bridge pads; no default roads or trees (path and grove pads, optional, Harmony +2% each
  to +20%); 2 workers per farm / mine / furnace / training ground; guide trail routes over bridges.
  Layout script `tools/islet_layout.py`. Checked in Economy's Play; left: phone triangle count.
- **Incense Blessing** (D57): a celadon incense-pot shrine left of the avenue; a visitor's 3 s blessing
  gives both players BLESS_SECONDS of income, once per sect a day, alt-proof. Checked in Studio Play
  with the BlessTest hook (the pot shrine on branch `shrine`). Left: a real 2-player test.
- **Heavenly Altar** (D78, D79, on `integration`): a store arena mesh on a lotus-isle rock 36 up, moon
  gates on the plaza teleport you up, Palm in the Recruit spot on phones, ~30 stud knock with a
  ragdoll; hub island portals got a light column. Checked in Studio Play. Left: Palm on a real phone.

## Next action
Phone test after the next publish: `/perf`, walk a full peak, `/clouds`, `/perf` again, send the
`[Perf]` console rows (they close ROADMAP "Phone performance").
