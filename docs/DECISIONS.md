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
- **D37** First reincarnation at realm 2 (owner: "40m is long to hook. 5-10m is good"; he asked to
  "get to the loop FAST"). `REINC_REALM` 2, `PAST_LIVES_MULT` 1.5 (x2 or x3 kept every life under ~1 h
  forever, so it never got hard), karma `KARMA_GROWTH` ^ depth and paid only for a new record depth
  (with the gate at realm 2 and Old Foundations a reset takes minutes, so a repeat must pay nothing).
  The Rebirth Gate node is gone (a landing below realm 2 is realm 1); Old Foundations costs 8 and
  Heavenly Hands 5, because every life replays the early realms. Rhythm (2 x 30 min a day): first new
  life ~10 min, lives 10, 14, 20, 27 ... ~75 min by life 9 (day 6), ~4 h by life 14 (day 16).
  Evidence: `docs/research/2026-10-21_economy_math.md` section 11.
- **D39** Idle pays half (owner, 2026-10-22: "Idle should pay half indeed ... breakthrough,
  reincarnation etc. should always reset Qi"). `OFFLINE_RATE` 0.5: offline was 81% of late qi
  (research 2026-10-22_full_game_sim), now an hour played is worth twice an hour away; regular player
  life 14 moves from day 12 to day 13. Leftover qi stays reset at every breakthrough and reincarnation
  (the carry-over proposal is dropped). An idle chest with free summons and a return screen comes next
  (mock first).
- **D41** Premium disciples = mock A + C (owner pick, `docs/art/mocks/characters_*.jpg`; research
  `docs/research/2026-10-21_premium_characters.md`): one anime dynamic head for every look (one
  cohesive style reads premium), hands in the lap, and a rarity ladder made only of light and glowing
  objects (magic circle, light orbs never solid balls, halo, a fan of spirit swords, lotus seat, crowns).
  Swords are a real steel jian (pick D of five): "fully coloured" swords were rejected, the rarity shows
  as a rim glow and light orbs. A new recruit walks in with Roblox's own R15 walk (no upload); a
  flying pose on a flat sword exists for thumbnails (`Cultivators.build(..., { pose = "fly" })`).
- **D40** Resets make the climb faster (owner: "isn't reincarnation supposed to make the game faster?",
  "how does the game get infinite?", then "whatever research says, of similar games"). Research:
  idle games make the rebuild much faster after a prestige (the multiplier, often auto-buy); Roblox
  rebirth games keep part of the progress plus a permanent multiplier. Sim (2026-10-22): with lives
  starting at realm 1 and x1.5, reaching the old best took 65 to 100% of the last life and lives grew
  ~2x each (a ~20 h wall by life 18). Now a new life lands at `REINC_LAND_SHARE` (half) of the deepest
  realm, fully built, and `PAST_LIVES_MULT` is 2.5: lives stay 10 to 40 min for ~2 weeks, ~1 h by
  life 30 (day 14), ~4 h by life 40 (day 36), no hard wall. Karma still pays only a new record (D37).
  A second layer (Ascension) is the next lever once live data shows where players stop.
- **D34** Less text and a light step (owner, 2026-10-21: "too much text everywhere"; picked mock A of
  `docs/art/mocks/less_text_*.jpg`; "walking speed a bit higher, redo moving and jumping, fit our
  style"). HUD labels are one short word or a number (Shop, 7/7, Use!, a timer), the next goal names
  the pad without "Next:", the realm bar shows a hall icon and n/total, the Rebirth chip a karma orb and
  n/10, the Spirit Tide a wave icon and a timer, the disciples card is a row of disciples in their
  rarity colours (no panel, R4); pad cards show name and price, the 2 to 3 word feature line only up
  close; messages are a few words, every amount with its icon (R18). On a phone the side buttons
  stay between Roblox's top bar and the thumbstick (two columns when tall); while the Shop or
  Reincarnation screen is open the HUD steps aside (toasts stay). Movement (`Config.MOVE`,
  `Movement.client`): faster walk, higher jump with a soft fall, one cloud step in the air with a jade
  ring, Roblox's Ninja run and Levitation jump/fall. Toy buttons keep the first look and their shine becomes a glass cap
  (`Toy.glass`, mock `glass_bars` 3, owner pick out of 10 after "make it slightly more premium"). Recruit reveal (mock
  `recruit_b.gif`, owner: "B with nice sound and auras"): `RecruitReveal.client` flies a qi orb from the
  Recruit button, charges one step per rarity, bursts into the disciple card in an aura that grows
  with rarity (`Config.REVEAL`); the platform column lands at the burst; a tap skips. Disciple icons
  (mocks `disciple_icons` A and `disciple_auras.gif`, owner: "A but ... make a big work on [auras],
  something moving and pretty"): `Toy.disciple` draws a meditating disciple per rarity and `Toy.aura`
  a moving aura that climbs with the rarity (glow, motes, ring, rays, halo, clouds, yin-yang, twin
  rays, rainbow flames), on the HUD disciples row, the Shop tiles and the shop island pads; one
  shared animator moves only the auras on screen. The Recruit button is a round formation seal (mock
  `recruit_button_c.gif`, owner pick C): the qi orb charging through the rarity colours in a turning
  ring, rays and a glow from the aura atlas; still and dim when a recruit is out of reach.
- **D38** Welcome Pouch (owner: "a good fixed bonus as entry door, like an epic disciple and a 10%
  Qi boost", "after a big building after 5-10 minutes"): 5 Robux once, an Elder + 10% Qi forever,
  offered once by a card after a big building between 5 and 10 min of play (MONETIZATION "Welcome
  Pouch"); cheap repeatable qi left out (research `2026-10-22_cheap_buys.md`).
- **D42** Sky Islets (owner pick B of three, mock `docs/art/mocks/peak_layouts.html`; research
  `2026-10-22_space_and_buildables.md`): the peak is a home island (plaza, Main Hall) plus four
  district islets (Fields, Alchemy, Disciples, Summit) in the sky, each opened by a bridge pad; an
  islet not yet bridged shows as dry ground (visible land to grow into, like TPT2). Nothing stands by
  default: no roads, no rim trees. Paths and groves are pads that add a capped Harmony bonus
  (decor pays through a rating, like Retail and Restaurant Tycoon 2). Two workers per building, and
  every farm takes them (owner: "2 farmers on every farming spot"). PLOT_RADIUS 215 -> 280 so the
  islets keep 15 studs from the neighbours. Prices of the new pads: the economy check owns them.
- **D43** Launch = mock A with C's camera dive (owner: "Go A, but the C idea of movement is great
  too"; mocks `docs/art/mocks/loading_*.jpg`, research `docs/research/2026-10-22_launch_flow.md`): a
  ReplicatedFirst screen where the qi drop fills with the real progress, TAP TO ENTER, a camera dive
  onto your peak, then the Heavenly Gift as the reward. The first avatar is made on the peak once it
  is built (`CharacterAutoLoads` off), so no hub stop and no teleport. The group card's Join step
  now opens Roblox's own join prompt (replaces D35's "find the group on the game page").
- **D44** Pace and disciples (owner picks 2026-10-22, research `2026-10-22_choice_and_recruits.md`):
  each recruit in a realm costs `RECRUIT_POW` (1.25) x the last, and a realm pad costs at least
  `PRICE_FLOOR_S` (20) s of income from the second life on (`PRICE_FLOOR_FROM_LIFE`, keeps the first
  life's hook; `Config.padCost`; open pads are repriced as income grows), so
  buying is a choice and recruit spam ends. A new life keeps every disciple; the Sworn Bond node is gone.
- **D45** Round ponds ringed with boulders (owner 2026-10-22: "all water sources are round and ugly,
  use real small rocks for the round shape, make the water fit the round shape"; picked B of the
  mock `docs/art/mocks/2026-10-22_pond_rims.html`): every round pond (resource ponds, koi pond,
  waterfall pool) gets a ring of low-poly boulders (4 meshes from `tools/rock_meshes.py`, ids in
  `Config.ROCK_MESH`, tilted block stones until uploaded) with pebbles in the gaps, its water a
  paler disc under the rocks + the deeper tint in the middle, and ripples cut to the circle
  (Gladiator RNG's round basins, D311 there) instead of a square patch.
- **D46** Koi pond: a red drum bridge spanning rim to rim (curved plank deck, rails following the
  curve, gold-capped posts; owner picked A of `docs/art/mocks/2026-10-22_koi_bridge_*.jpg`; Chinese
  garden bridge research: drum, moon and nine-turn types, the stone moon arch read as a lump) and
  koi from a free Creator Store mesh (owner: "just find a model"; "Fish A" by Karcist, a bare
  MeshPart, no scripts; ids + size in `Config.KOI`), after two part-built koi read as blobs.
- **D47** NPCs move through their own joints (owner picked B of the clips
  `docs/art/mocks/anim_mock_*.mp4`, then asked for both hands on the tools and the walk-in and bow
  redone; research `docs/research/2026-10-22_npc_animation.md`). Workers and disciples keep only the
  root anchored; the client writes joint Transforms (`Rig.luau`), so layered robes, hair and props
  follow (moving each part on its own left sleeves and hair behind). Workers: hips drop into each
  blow with the feet planted (`Rig.leg`), the left hand holds hoe and pick shafts (`Rig.reach`), joints
  ease at their own pace so the arms follow through. Recruit walk-in eases in and out, then bows from
  the hips with a salute. A recruit rebuilds only the seat that changed (seats are kept, so the seat
  order is not the strength order). Why: the owner found the old motion stiff and the full rebuild
  on every recruit weird; joint Transforms are the documented no-upload way.
- **D48** The island opens over the realms (owner pick A of three, research
  `2026-10-22_island_by_realm.md`, mock `docs/art/mocks/realm_land.png`; owner: "tycoons are
  interesting because you get a bigger, more beautiful island slowly"): `Config.REALM_PADS` lists the
  pads that first open in realms 1 to 4 (16, +14, +11, +14), each realm rebuilds everything opened so
  far, a new life lands with its landing realm's pads. The breakthrough costs `BREAKTHROUGH_SECONDS`
  of the price income (buildings x realm x disciples x Past Lives x Harmony; the paid passes are left
  out, so they make goals come sooner instead of raising them; the D44 floor uses it too).
- **D49** Daily playtime gifts (owner 2026-10-22: "always show what's the next reward, reset daily, up to
  2h online"): 8 gifts at 5, 10, 20, 30, 45, 60, 90, 120 min of play TODAY (UTC day, summed over
  sessions, saved as `data.giftDay/giftPlay/giftIdx`), paying `GIFT_VALUE` s of income and
  `GIFT_SUMMONS` free summons (into the idle chest pool). The server publishes GiftIn, GiftNext,
  GiftQi, GiftSummons and GiftResetIn so the HUD always shows the next reward; ClaimGift returns
  `{ qi, summons }`. Simmed: no pace change, ~9% of a regular player's qi.
- **D50** First-time tips = mock A (owner: "Missing small tutorial at: first qi ball to get, first
  pill to use, first idle chest. Small and simple"; mocks `docs/art/mocks/tips_*.jpg`): a cream
  bubble with one line over the orb / chest pad (gold arrow, the jade trail leads there) or beside
  the HUD pill button; once per save (`data.tips`, a save from before them starts with all done).
  The idle chest moves beside the x2 qi pad (owner: "too close to start").
- **D52** x10 / x50 recruits open every orb (owner 2026-10-22: "x10 and x50 should show X balls
  opening, they don't work"; picked A of `docs/art/mocks/recruit_multi_{A,B,C}.mp4`, "give it some juice
  and sound"). A grid hatch (FEEL "x10 / x50"), the Pet Simulator multi-hatch pattern; the stream (B)
  ran ~7 s at x50 and the split orb (C) hid each opening. A press is all or nothing at
  `Config.recruitBatchCost` (the chip shows the total): before, each roll was priced at 1.25x the last
  and the run stopped when qi ran out, so x10 bought 2 or 3 and x50 (~280,000x a single) never ran.
  The selector shows on a press or a hover, qi or not. Batch price and `recruitStep` belong to the
  economy pass.
- **D51** Icons and the altar on screen (owner 2026-10-22: "lots of icons are looking AI af, the like
  thumb for example"; "fight in the middle is too invasive on screen, but it's nice to show it + a
  path to go there, with a HIDE or X button. Crown is ugly, add a light aura better"). Mocks
  `docs/art/mocks/icons_board.jpg` (now vs 3 finishes), `fight_options.jpg`, `aura_options.jpg`;
  owner picks: icons A "sticker" ("but disciples have a better shape already": the disciple icon
  stays the disciple atlas figure), altar A (top right, under the next goal), aura W3.
  Icons: the ~30 box-built icons are replaced by one uploaded sheet of real silhouettes with one
  rule set (ART_BIBLE "Icons"); Robux shows Roblox's own icon. Altar: the ring under the qi counter
  is gone; while a round is open a 46 px altar button sits in the HUD's right stack (PlayerGui
  `HudSlots.Right`, LayoutOrder 3; alone in the top right without it), beads around it = time held,
  seconds under it; a tap points the guide trail at the altar (local attribute `GuideTo`, read by
  `Guide.client`), its X hides it until the next round. Winner: a gold rim light (Highlight) and gold
  sparkles twinkling around the body instead of the part-built crown. Why:
  the box icons were the "AI look" the owner keeps catching; the centre ring covered the view and
  overlapped the counter; a light aura matches the disciples' language.
