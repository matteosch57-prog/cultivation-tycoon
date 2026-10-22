# Decisions

Append-only log: a decision and its WHY. Open questions at the top; when one is decided it moves into
the log as a D-number.

## Open
- **Q1** Music bed: Guzheng (1), Temple Of Lihangin (2) or Harmonious Cycles (3). The owner picks by
  ear with the Workspace attribute `MusicTrack`.

## Log (all 2026-10-21, the first session)
- **D1** Theme: cultivation. Compared against aquarium (an old leader, fading), pet shop (the live
  leader, direct competition), wizard (open but combat-heavy). Cultivation is niche, but the owner
  knows it from Heavenly RNG and it costs the least art.
- **D2** A simple tycoon with no combat: the owner found the fighting side of tycoons pointless.
- **D3** Hooks: disciples rolled with rarity (the RNG skill set, smallest form) plus offline qi.
- **D4** World: 6 floating peaks around a hub, rope bridges; one peak per player.
- **D5** Geometry is hand-built from parts (`Style`), not generated meshes: AI-looking art drove
  downvotes on Heavenly RNG, and generated meshes land in the owner's inventory.
- **D6** Sky: the painted anime-style skybox from the Creator Store; it fits the low-poly style far better
  than the default. Risk accepted (a re-upload that could be moderated); our own sky later.
- **D7** HUD: mock C (panel-less, outlined text, toy buttons). Mocks A and B were "so AI".
- **D8** Buying feel: hologram preview within 18 studs, buildings assemble bottom to top, price cards in
  the HUD style (the first dark-panel cards were "too complex" and sat behind the beam).
- **D9** Clouds: soft particle clouds. Solid-ball cumulus read as plastic; adding mist did not fix it.
- **D10** Walk-on buying is a server position check every 0.1 s: `.Touched` on a thin pad top missed
  most real walks.
- **D11** Choice: a pad opens after a total number of buildings, keeping 3 to 5 open (the one-by-one
  chain was too simple).
- **D12** Features chosen by the owner: qi orbs, pill boost, extra disciple slots (not longer offline).
- **D13** One Main Hall upgraded over 5 levels, island expansions (62 -> 76 -> 90), variety buildings on
  the new land; straight walls removed (they cut across the expanded ground).
- **D14** Ground: terrain lawn as LeafyGrass, tall Grass only in rim meadows (blades everywhere looked
  like an overgrown field); the map raised to y = 2 so terrain surfaces exactly under buildings.
- **D15** Side and corner buildings face the centre of the peak (several faced the void).
- **D16** Juice layer: sound, motion and light on every event, licensed library audio only, the most
  frequent sounds quietest (the owner's reference: a top clicker tycoon's level of feedback).
- **D17** First Robux products: 2x Qi, VIP Sect, Auto-collect orbs, Qi packs, Instant pill
  ([MONETIZATION](design/MONETIZATION.md)).
- **D18** Organised like the other projects: START_HERE/STATE/docs layout, Rojo port 34875
  (Heavenly 34872, Gladiator 34873, Follows 34874), vault folder `8_Roblox_Cultivation_Tycoon`,
  private GitHub repo `matteosch57-prog/cultivation-tycoon` (was Q2).
- **D19** Save safety (B01 step 2): one record per player with a per-join session lock, released on
  leave; a save lands only while it holds the lock. A player whose lock stays held plays without saving
  rather than risk an overwrite (a kick-and-rejoin message is a possible later polish).
- **D20** Phone performance (B01 step 3): measured, the cost of a full peak is triangles (~750k, small
  Ball parts at 432 each), not part count or draw calls (~30, instanced). So instead of baking whole
  buildings into unique meshes (one upload per building and level, no reuse), every small ball and
  cylinder becomes a clone of one low-poly mesh: two uploads, -71% triangles on a whole-peak view (Studio Edit), no
  visible change. Not a generated-art mesh (D5): two geometric primitives written by a script.
- **D21** First session (B01 step 5 and the telemetry half of step 7): the first 5 minutes stay as they
  are (a building every 20 to 30 s, the Main Hall at about a minute, like the tycoons researched);
  `BREAKTHROUGH_COST` 45,000 -> 300,000 so the gold pad is a few minutes' goal, not an instant buy;
  every first-session milestone is an onboarding funnel step with its time, plus session ends, recruit
  results and the qi economy (TECH "Telemetry"). Measured from the first build, as Gladiator RNG learned
  (its R23): the batch shows where players stop, which no model predicts.
- **D22** Guide arrow = mock A (owner pick of A / B / C, `docs/art/mocks/guide_A..C.jpg`): a jade
  chevron trail on the ground, the most common tycoon guide and the only one of the three that still
  points the way when the pad is behind the player. Plain objects, so no new light exception (R3).
- **D23** Studio Play uses a mock save by default (`MOCK_DATASTORE`, owner 2026-10-21: "why not using a mock data
  store like my other games"): every Play starts as a new player, so the first session (guide trail, funnel)
  is what a tester sees; the `_studio` store stays for save tests with the flag off. Gate = flag AND `IsStudio()`.
- **D24** Shop = mock B (owner pick of A / B / C, `docs/art/mocks/shop_*_phone.jpg`) plus a world
  shop of purple step-on pads around the hub cauldron (owner ask). The ring is on the hub because
  every peak's ground is already planned for build pads. Prices come from Roblox at runtime, never
  from code, because passes are regionally priced. The 2x Qi pass also doubles offline qi (economy
  check: the three passes together give ~1.5 to 2x pace and skip no content). Design in
  MONETIZATION "How the shop works".
- **D25** Realm pacing (closes Q3; owner: "first realms should be fast, then it should get hard; after
  realm 10 we will offer reincarnation"). Costs x5 per realm through realm 5, then x10
  (`REALM_COST_MULT`, `REALM_COST_LATE`, `REALM_COST_LATE_FROM`); the recruit price's +50% steps
  restart at each breakthrough (`data.realmRecruits`) so recruiting stays a qi sink in every realm and
  the top rarities stay a chase (before, recruits stopped after realm 1). Realm 10 is the long goal:
  ~day 21 for two 30 min sessions a day, ~day 11 with the three passes
  (`docs/research/2026-10-21_economy_math.md`). Reincarnation after realm 10 is not designed yet.
- **D26** Performance and data health normalised on Gladiator RNG's lessons (owner: "make sure game is
  fluid and performant, normalize those techniques"; R16, R17). Frame jobs are timed (PerfMark) and
  the `/perf` log names hitches; cultivators and qi orbs stop moving off screen. Saves: one in flight
  per player, budgeted and staggered autosaves, recursive backfill, and a failed load now asks the
  player to rejoin instead of playing without saving (replaces that part of D19: progress made in
  such a session was silently lost). ServerHealth logs server fps, memory and DataStore budgets.
- **D27** Step-on pads = concept C "Formation" (owner pick of A Jade Seal / B Lotus / C Formation in a
  playable 3D mock, `docs/art/mocks/pads_formation_mock.html`; "C amazing, with nice premium light, text
  clear and easy, normalize colors"). Research (`docs/research/2026-10-21_pad_feel.md`): pad tycoons
  rarely preview the building, so the gathering preview is where this game stands out. Pads are drawn
  by the client from a tagged anchor so build, breakthrough and shop pads share one look and one
  colour set (`PadLook`). The pad's light is the R3 pad-beacon exception.
- **D28** Shop island per player (owner: "each player have a small beautiful island for the shop, with
  some characters, we will sell some too, like immortals"; "2x Qi in front of the access"): replaces
  the hub ring of D24. It sits beside the entrance (the hub-side corner), the only spot clear of the
  largest peak, the neighbours and their bridges. Disciples sold = fixed rarities Elder, Immortal and
  every tier Elder to Primordial (owner pick C, "price accordingly"), with the economy check's
  guard-rails: Celestial and above once per player and gated by realm (3 / 5 / 7 / 9), bought ones
  permanent, rolled ones keep a "first pulled" mark, price ladder in MONETIZATION.
- **D29** Reincarnation after realm 10 (owner: "make people advance infinitely"; "I trust you, build
  those"). A new life starts at realm 1 from `REINC_REALM`. Power = Past Lives: x`PAST_LIVES_MULT`
  qi per realm above 9 reached in a finished life (`soulPeak`, monotonic, so only a new record raises
  it; x3 buys back about one realm of the x10 cost step). Choices = karma per life
  (`Config.karmaFor`, ~the cube root of that life's qi) for a Dao Tree (next round, mock first). The
  `SWORN_BASE` best disciple follows into the new life; the rest reset. Realms 6 to 10 named (Void
  Refinement to True Immortal), then "Immortal Realm N". Landing (realm 1) stays below the gate so
  the reset is never free to repeat (Heavenly RNG lesson). Shop-bought disciples are permanent and
  take no sworn seat. Economy check kept x3 and realm 10: a regular player's later lives take 5 to 7
  days each and stay that length at any depth (x2 walls). Research and pacing:
  `docs/research/2026-10-21_reincarnation_design.md`; system: [REINCARNATION](design/REINCARNATION.md).
- **D30** Spirit Tide and playtime gifts (tycoon study `docs/research/2026-10-21_tycoon_study.md`,
  Grow a Garden's server-wide moments and DevForum session advice; owner picked mock A for both): every
  `TIDE_INTERVAL` all peaks on a server earn `TIDE_MULT` x for `TIDE_DURATION` with a heads-up and a
  countdown line under the qi counter; gift button pays `GIFT_VALUE` seconds of income after
  `GIFT_TIMES` of play in a session. Stealing was left out (breaks "fair and calm").
- **D31** Karma Shop (owner: "have a karma shop"): six capped permanent nodes in `Config.DAO` bought
  with karma ([REINCARNATION](design/REINCARNATION.md)); economy check: all maxed makes lives ~35%
  shorter, going deeper still beats resetting often. The reincarnation screen keeps text to the road,
  one NEXT line, two numbers and buttons (owner: "too much text"); every currency amount shows its
  icon (R18).
- **D32** Realm looks and the last two Karma Shop nodes (ROADMAP M3). Every realm from 6 changes the
  peak (clouds, rocks, second waterfall, storm, halo; [REINCARNATION](design/REINCARNATION.md)), all
  blocks and particle clouds, no fake light (the halo is sunlit gold, the lightning an event flash).
  Rebirth Gate (40 / 100 karma) lands a life at realm 3 / 5, never above 5 so the reset stays below its
  gate; Old Foundations then builds the landing realm. Heavenly Hands (20) builds the HUD "Next" pad
  from anywhere (mock A of `docs/art/mocks/karma_nodes_*.png`, picked by default, owner may switch to
  B or C). Economy check (sim_economy reinc mode, 2026-10-21): the gate resetter earns a flat ~4
  karma/h whatever the landing while going deeper earns 4.5 to 80 karma/h over lives 2 to 6; Hands
  cuts realms 1 to 7 from 93 to 62 min for a slow phone walker and leaves the realm 10 date unchanged.
- **D33** World shop spread out (owner: "everything on one island is crowded af"; picked mock A and
  the screen changes, "all accepted"): each item stands where it acts (2x Qi and VIP at the peak
  entrance, Instant Pill at the furnace, Auto Orbs at the array, the last two only once built), the
  side island keeps only the six disciples along a walk (the owner's D28 "beautiful island with
  characters"), Qi packs leave the world for a quiet Get Qi offer on a pad out of reach. Why: Roblox's
  contextual-purchase guide (complementary and in-play offers, displays that lead to the shop, few
  prompts) and tycoon practice (upgrades beside what they upgrade); no public data compares pads
  with a screen, so the `Shop` event's sources are how we measure it. Research
  `docs/research/2026-10-21_shop_placement.md`; mocks `docs/art/mocks/shop_layout_*.png`.
- **D35** Friends here (owner picked idea 1 of `docs/research/2026-10-21_playing_together.md`, "1
  good"): each Roblox friend on the server adds +10% live qi, at most 3 (+30%), and a friend's peak
  is placed next door. Why: playing together is what Roblox measures and rewards, and this is the
  smallest form that needs no screen and works alone (stealing, trading and guilds left out: "fair and
  calm", scams, and Gladiator RNG's lesson that the first session decides, not the social layer).
  Economy check (`sim_economy.py --set FRIENDS_LIVE_MULT=1.3`): realm 10 day 20 -> 19 for a regular
  player with 3 friends all the time, so the 2x Qi pass keeps its value. Design: ECONOMY "Friends here".
  Then (owner): the friends card on the right with Invite (mock A of `docs/art/mocks/friends_*.png`)
  and a group gift card "Like the game, Join the group, Claim" with no group link in game ("they'd need
  to get out, get in group and relaunch the game so they'd pass by to like eventually"). Only the group
  is checked and paid (+`GROUP_BONUS` qi): a like reward breaks Roblox rules and has no API.
- **D36** Intro = the Heavenly Gift (owner: "HEAVENLY GIFT with a nice shiny green GO button that
  bursts", after mocks `docs/art/mocks/intro_*.png`; "give some Qi rewards so they can do the first
  buildings with no wait"). A new save opens on the title, +`WELCOME_QI` and GO; GO pays once per save
  (`data.welcomed`, old saves count as welcomed) and the qi bursts into the counter. 200 = the first
  four buildings. Economy check (sim_pacing START_QI sweep 100 / 200 / 400): Main Hall ~0.5 min instead
  of 1.1, realms 2 to 5 move under a minute, more than 200 just waits in the counter. One tap and no
  cutscene, after Gladiator RNG's lesson that players leave during non-play.
