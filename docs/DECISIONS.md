# Decisions

Append-only log: a decision and its WHY. Open questions at the top; when one is decided it moves into
the log as a D-number.

## Open
- **Q1** Music bed: Guzheng (1), Temple Of Lihangin (2) or Harmonious Cycles (3). The owner picks by
  ear with the Workspace attribute `MusicTrack`.

- **Q3** Realm pacing after the first breakthrough: today realms 2 and 3 go faster than realm 1
  (disciples carry over). Keep (rebirth games shorten runs) or raise the realm cost ratio
  (sweep in `docs/research/2026-10-21_first_session_onboarding.md`). Update: the whole-climb sim
  (`docs/research/2026-10-21_economy_math.md`) shows realms 2 and 3 are short but realm 8+ each take
  ~2.4x the last (realm 10 = a day of play). Branch `economy` restarts the recruit price each realm
  and steps costs x4.5 after realm 5 (late realms ~1.3x the last); the owner keeps or reverts it.

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
