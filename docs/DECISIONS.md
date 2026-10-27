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
  Update (owner 2026-10-22: "way more explicit with the reward, attractive, click it opens a juicy page
  with all timed rewards, make them interesting"; pick C of `docs/art/mocks/timed_gift_*.jpg`): the
  gifts also pay `GIFT_PILL` s of 2x qi and a `GIFT_RARITY` disciple (Elder at 45 min, Immortal at 2 h);
  the HUD button shows the next prize in its own words and colour; a tap opens the Free Gifts page
  (`Gifts.client.luau`: the last gift as a hero card, the rest in a list), where the claim happens.
  Simmed (`tools/sim_game.py`, gift pills + disciples modelled): lives end on the same days as before.
  The Shop's free gift dot (`DOT_SHOP_FIRST`) now lights after 2 min of play (was 10).
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
- **D54** HUD menus = mock B (owner pick, `docs/art/mocks/hud_menus_*.jpg`): left column = what you
  open (Shop gold, Disciples, Karma), right stack under the next goal = what ticks (gift with its next
  reward always shown, pill, altar row via `PlayerGui.HudSlots`); one dark button face, gold only for
  the Shop and a ready gift or pill; a karma counter beside qi once the player has karma or a past life.
- **D53** Building skins follow the realm, lives add what a reset cannot take (owner picked A over B
  and C, then "A is better still", mocks `docs/art/mocks/2026-10-22_skins_*.jpg`, research
  `docs/research/2026-10-22_visible_progression.md`). Every building is recoloured after it is built
  (`Skin.luau`): Timber, Red Lacquer (the art), Jade, Imperial Gold over realms 1 to 4 (the realms
  the island opens over); from realm 4 a 2nd / 3rd / 4th+ life builds in White Jade / Void Amethyst /
  Celestial Azure (`SKIN_LIFE_TOP`). Lives add real stone lanterns round the Main Hall
  (`SKIN_LANTERNS`) and motes over big buildings scale with realm step + lives (`skinLevel`). A title
  over every head shows the realm in its colour and, from life 2, "Nth Life · grade"
  (`StatusTitle.client`). Why: the owner found realms and reincarnation worthless without a visible
  change ("like social status"); a material ladder reads from the next peak like Clash of Clans walls.
- **D55** Phone calm pass = mock A (owner pick): two quiet rails; left = Shop, Disciples, Karma,
  Friends (small, numbers only); right edge = round timers (gift with its reward, pill, altar); one
  Friends button replaces the friends card and the group chip; smaller Recruit seal.
- **D56** Every new life starts with its landing realm built (owner pick 2026-10-22; sim: minutes 6
  to 16 rebuilt the same 16 realm-1 buildings slower, first new land at minute 19). Life 2 now breaks
  through in about a minute and buys new land at about minute 10. The Old Foundations Karma node did
  exactly this, so it is gone.
- **D57** Incense Blessing (owner pick A of three, mock `docs/art/mocks/neighbour_visits.html`; research
  `2026-10-22_neighbour_visits.md`): the reason to visit a neighbour. Every peak has an incense shrine
  by its entrance; a visitor holds its prompt 3 s and both get BLESS_SECONDS of their own offline-rate
  income (the Adopt Me trick-or-treat shape: both sides gain, once a day per house). Once per visitor
  and sect a UTC day, 5 given and 5 received a day at most, never your own; the owner's share needs a
  giver with a 7-day-old account and 10 min played (alts feed nobody). Today's sticks stay lit; the
  plaque counts every blessing ever (`blessTotal`, a status number for the coming sect board). Never
  required, never prompted for (FarmVille's "spam your friends" backlash).
  The shrine: a celadon incense pot (free Creator Store mesh of asset 98661629860539, rebuilt from its
  id) full of sticks on a stone pedestal, two stone lanterns, a low gilt plaque with the count in jade
  round digits (owner pick 2 of `docs/art/mocks/shrine_candidates.jpg`, after a plinth-and-pot and a
  kit pavilion were both "ugly"; capture `docs/art/captures/bless_shrine_pot_play.jpg`).
- **D58** Daily Blessing + badges (owner list 2026-10-22 #3 and #4; streak mock A, "make it more
  attractive", "elder d7 is super late, should be day 2 at least. I'd say even one tier more day
  2"): a 7-day ladder claimed once per UTC day that pauses on a missed day and loops after day 7
  (`Config.STREAK`, an Immortal on day 2 and a Celestial on day 7, each once per save, owner's
  choice over the Celestial shop sale; numbers checked by the economy pass, pace unchanged). 10 badges (`docs/design/BADGES.md`, `Config.BADGES`, `Badges.luau`), awarded
  from the save so a badge created later still reaches everyone who met it.
- **D59** Red dots (owner 2026-10-22): one ruby-gem look (`Toy.dot`); every dot leads to a dot inside
  and clears when followed; the server lights them where state changes (`Dots.luau`); the Shop's dot
  leads to a free Daily Gift (300 s of income, once a UTC day).
- **D60** Disciple index (owner list 2026-10-22 #2; picked B of `docs/art/mocks/disciple_index_{A,B,C}.png`
  "with the C stars system. Max 5 stars each, giving a qi boost, low but good to get. Some summons at
  each step"). One entry per rarity and look (9 x 4); a star at each of `INDEX_STARS` pulls of it,
  `INDEX_STAR_BONUS` income per star (forever; kept out of the price income), `INDEX_STEP_SUMMONS` free
  summons every `INDEX_STEP_STARS` stars (numbers from the economy pass: 0.005 a star sped the climb up
  by 2-3 days). Every disciple counts, from any source. Each disciple now keeps the look it was rolled
  with (`data.discLooks`, a list parallel to `data.disciples`, written only in `addDisciple`), so the
  figure on its seat is its index entry; an old save fills looks from list order and starts its book
  with the disciples it has. Why B over A: nine entries fill in a day; PS99-style variants multiply the
  book without a new rarity. Captures `docs/art/captures/disciple_index_play.jpg`, `..._reveal_play.jpg`.
- **D61** Button feel (owner 2026-10-22: "when clicking on stuff we want a nice animation and sound +
  reactivity and haptics"; picked C + X of `docs/art/mocks/button_feel.html`). Every toy button goes
  through `Toy.feel`: on touch (not release) the click sound and a phone buzz (`Haptic.luau`, one
  Roblox `HapticEffect` per kind, UIClick / UINotification), the face squashes wide onto its shadow,
  release wobbles it tall then settles (C, Jelly). Claim moments call `Toy.reward(button)` (X, Burst:
  pop, white blink, ring, gold motes, chime, double buzz): group gift Claim, chest Collect, Shop
  Daily Gift; the streak Claim can call it too. Why: top simulators answer on press with sound,
  squash and spring; HapticEffect is fully released on iPhone, Android and pads since Sept 2025.
  Tested in Play (Shop button 57x57 -> 61x49 -> 56x58 -> 57x57, no errors).
- **D62** Hub rankings (owner 2026-10-22: "C but way more premium", statues and podiums "horrible",
  "3 different rankings: biggest qi/s, weekly playtime", "a country ranking filter", then "OK, make
  the lights better"; research `docs/research/2026-10-22_progression_pushes.md`, mocks
  `docs/art/mocks/2026-10-22_rank_*.jpg`). Three boards on a wall at the hub (RankBoard): Greatest
  Sects (realms climbed in every life, lives as tie-break) in a painted gate, Richest Qi (best qi/s
  ever) and This Week (play time, new store each Monday UTC) on roofed steles, top 10 with head
  shots, guardian lions, bronze ding braziers and pagoda lanterns with real light (free Creator
  Store meshes rebuilt from ids, no inserted scripts). Each board has a global and a per-country
  OrderedDataStore (Ranks.luau, batched writes, reads every RANK_REFRESH s); Lives joins Realm in
  the player list. Why: rankings are the cheapest status push and give the skins (D53) an audience.
- **D65** HUD travel and purchase moments (owner 2026-10-22: two teleports at the top of the HUD, "MY BASE"
  and "RANKINGS"; a confirm animation on every Robux buy, the recruit reveal for disciples; "Both A",
  mock `docs/art/mocks/2026-10-22_teleport_and_buy.html`). Base (hall icon) and Ranks (new trophy icon,
  cell 30 of the icon sheet) are round chips either side of the qi counter, as Grow a Garden puts its
  travel buttons top centre; a jade wipe hides the jump, the server picks the spot (`Teleport`,
  `TELEPORT_COOLDOWN`, the peak spawn or `TELEPORT_RANK_FRONT` studs in front of the ranking wall).
  Every bought disciple plays the recruit reveal; passes, qi packs and the pill play "Spotlight"
  (BuyMoment.client: veil, gold rays, Toy.reward burst, name, then it flies to the counter or the pill
  chip; `BUY_MOMENT`). Same pass: rails 14 px apart (owner: "super close"), a small X on the disciple
  card, and the Sect Gift card points to the game page for both the like and the group (owner: no
  in-game group link; he puts the community link on the game page).
- **D64** Every shop product is on sale at every realm (owner 2026-10-22: "open all products to any
  level, who cares if someone pays to rush the game"): the `minRealm` gates of Celestial, Dao Ancestor,
  Heavenly Emperor and Primordial (D28) are gone; the gate code stays for any future item.
- **D63** Rebirth = Muscle Legends' rebirth, copied as it is (owner 2026-10-22: "let's just do like
  other games, don't reinvent the wheel"; "I asked you to copy the successful games"). Replaces D29,
  D37, D40's gate, landing and Past Lives: a rebirth costs qi (a price that rises the same step each
  rebirth), resets qi, buildings and realm (realm 1 built, D56), keeps every disciple, adds +5% qi per
  rebirth and pays a growing karma amount; rebirth counts open the deeper realms. Why: the custom
  record-depth rule made every life exactly one realm deeper and lives longer each time, the half
  landing caused the free-repeat exploit, and Past Lives reached x372K by life 14
  (`sim_game.py`); research of 11 Roblox games `docs/research/2026-10-22_rebirth_standard.md`.
  Economy sim (`sim_game.py` b18f691): the realm table binds (first rebirth ~11 to 15 min), +50% a
  rebirth instead of their literal +5% (+5% made every life longer: 46 to 99 min), the boost stays out
  of the price income (the price floor and breakthrough scale with income, so it would do nothing there).
- **D66** Economy second opinion (2026-10-22, `docs/research/2026-10-22_economy_second_opinion.md`,
  checked with `tools/sim_game.py`): a rebirth opens only when the next breakthrough waits for one
  (`Config.rebirthOpen`: every required pad built and fewer rebirths than `rebirthsFor(realm + 1)`);
  with the qi price alone the chip went gold 20 to 90 s after every rebirth and a min-maxer skipped the
  gate table on day 1. Late realms cost x5 like the early ones (x10 stalled a regular player at realm
  14 from day 21), and the gates go on past realm 17 (`rebirthsFor` continues the table's steps).
- **D67** Harmony is left out of the price income (`priceRate`), like the rebirth boost and the index
  (owner 2026-10-22 "make the corrections", `docs/research/2026-10-22_economy_second_opinion.md`):
  inside it the D44 floor and the D48 breakthrough rose with every path and grove, so decor's +20%
  mostly paid for itself. `tools/sim_check.py` / `sim_game.py` (`HARMONY_IN_PRICE` = the old rule):
  pace unchanged for a regular player over 30 days; decor now pays what its card says.
- **D68** The live menus bug (2026-10-22, owner: "make sure it never happens again and log it"): live,
  the Index, Shop, Reincarnation and the recruit reveal never opened and the Friends row left the rail,
  while every Studio Play worked. Cause: their BindableEvents and the `HudSlots` folder were parented
  to PlayerGui; `Main` loads the character itself (`CharacterAutoLoads = false`) after the save loads,
  which on a live server is after the client scripts ran, and that first spawn empties PlayerGui of
  everything but guis with `ResetOnSpawn = false`. Fixed in 6ab3311 (signals on the Player). Guard:
  rule R19 and `tools/check_playergui.py` (fails on anything else parented to PlayerGui and on a
  PlayerGui lookup by a name no script makes as a kept gui; `--selftest` is its positive control, and
  it reports all 17 bug sites on the pre-fix tree de60f19, 0 after). Run it before every merge into
  `integration` and before a publish. In Studio, reset the character once in Play to see this class of bug.
- **D69** Breakthrough confirm screen (owner 2026-10-22: "Breakthrough should make a small screen
  appear with what it does + a confirm button"; picked B of `docs/art/mocks/2026-10-22_breakthrough_confirm.html`,
  "Before and after", the Anime Defenders / Bee Swarm upgrade screen). Stepping on the gold
  Breakthrough pad (or Heavenly Hands on it) no longer pays: the server offers the screen (Notify
  `breakthroughAsk`, the price), once per step on. It shows this realm and the next as seals, the
  income boost (`incomeMult` ratio), the new buildings of the next realm, the rebirth gate when the
  next realm is one (`REBIRTH_REALMS`), "qi + buildings reset" and "disciples, karma, rebirths kept",
  and one Break through button with its qi price (`Breakthrough.client.luau`). Only its Confirm
  (`Breakthrough` remote, Guard budget) breaks through, within `BREAKTHROUGH_ASK_SECONDS` of the
  offer; the server checks the pad, the price and the rebirth gate again. Why: a step on the pad reset
  qi and every building with no warning. Checked in Studio Play (mock save, realm 4 to 5, one pad step):
  `docs/art/captures/2026-10-22_breakthrough_confirm_play.jpg`.
- **D70** Readable ranking wall and quick travel (owner 2026-10-22: "ranks could be bigger, hard to
  read"; "central space can be slightly bigger, with quick TP to other islands, too long to walk").
  Ranking wall (`RankBoard.luau`): gate 22 -> 29 studs, Greatest Sects 15.6 x 14, steles 10 x 12.5,
  rows and text sized from each face (about twice the old text); braziers, lions and lanterns moved
  so nothing overlaps (the lanterns stood on a bridge post). `TELEPORT_RANK_FRONT` 13 -> 9: from 13
  the follow camera sat inside the cauldron and the altar. Every HUD teleport but Base turns the
  camera the way the server faced you (Hud `teleportTo`). Hub: `HUB_RADIUS` 36 -> 44. Portals
  (`Portals.luau`): one beside each bridge mouth on the hub (its plaque = the owner's sect, dark while
  the peak is unclaimed) and a "Sect Hub" one on every island, left of the bridge head clear of the VIP
  pad and the shrine. The client sees the step (tag `Portal`) and sends its `Where` on
  `Remotes.Teleport`; the server checks you stand on that portal and picks the landing (R9).
  Checked in Studio Play (mock save, both directions, overlap sweep):
  `docs/art/captures/2026-10-22_rank_boards_bigger.jpg`, `docs/art/captures/2026-10-22_hub_portals.jpg`.
- **D71** Build preview and a still buyer (owner 2026-10-22: the preview should work for every
  buildable and look better; building teleported the avatar and swung the camera). Owner picks from
  Studio captures (`docs/art/mocks/build_preview/`): B "white spirit", the classic tycoon hologram, a
  pale glowing copy whole in its final place (the jade glass in pieces barely read on paths); and
  "stand still": the server's step-out teleport is gone (it fired whenever you stood inside the new
  thing's box, so paths, groves and bridges threw you several studs), pieces that land on the buyer
  stay passable on their client until they step out. Pads stay where they are.
  Found in the Studio test: built models stream `Atomic` now; with streaming on, a Default model
  arrived as ~10% of its parts (Thatched Hut 47 of 483), so a preview held only those, the build-in
  swirled only those and the rest popped in colliding and shoved the buyer about a stud.
- **D72** Landscape only on phones (owner 2026-10-22: "Force horizontal view"). The place had
  `StarterGui.ScreenOrientation = Sensor`, so a phone held upright played in portrait.
  `default.project.json` now sets `LandscapeSensor` (the phone still flips between its two landscape
  sides; `$ignoreUnknownInstances` keeps the place's StarterGui children), and `Launch.client` sets
  `PlayerGui.ScreenOrientation` and re-asserts it for 5 s: StarterGui is only copied at join and the
  load can reset it (Heavenly RNG's bug). The launch screen waits up to 1.5 s for a landscape viewport
  before sizing itself. Studio Play: HUD rails, top bar, realm bar, Recruit seal and jump button clean
  at 693x359, 751x389, 823x426. The turn itself is only provable on a real phone.
- **D73** Round buttons (owner picked B Dome from `docs/art/mocks/2026-10-22_round_buttons.jpg`): circle
  buttons get `Toy.dome`, all other buttons keep `Toy.glass`.
- **D74** Next step at the bottom centre, Rebirth seal on the realm bar (owner 2026-10-22: "the arrow
  on next step in middle bottom? and the bar + rebirth thing remock", picked mock A of
  `docs/art/mocks/hud_bar_all.jpg`: "A better, but slightly smaller or pushed down"). The next goal
  (turning arrow, pad name, qi price) left the top right for one line over the realm bar; the realm
  name sits over the bar; Rebirth is a round purple seal (karma orb, dome light) locked on the bar's
  right end, its label on the lower rim, gold and wobbling once the price is held. The bar always
  shows the hall count (the next step says Breakthrough). The right stack starts under the top bar.
  Checked in Studio Play (fresh save): no overlaps, no Hud errors.
- **D75** Three shop changes (owner picks 2026-10-23). (1) **Tide Bell**, a repeatable developer
  product (Bee Swarm Simulator's Night Bell, copied as is): it starts a Spirit Tide for the whole
  server now, everyone sees "<name> rang the Tide Bell!" with the countdown; refused while a tide
  runs or the Heavenly Altar is open or warning; the tide schedule never moves, and a tide that lands
  in another adds its time instead of restarting it. (2) **Sect Starter Pack**, 75 Robux once per
  player: an Immortal + 1 hour of income + 10 min of 2x in one product (`grantProduct` handles each
  field of an item), offered once on the card "B night jade" the first time a `feature` building is
  bought 5 min or more after the Welcome card; a "Once" tile in Boosts until bought; no fake discount.
  (3) **Disciples without buy limits** ("let people buy the disciples as much as they want"): `limit`
  dropped from the six disciple products; the prompt is refused when the newcomer could not stay
  (a full sect of stronger ones) or `DISCIPLE_CAP` bought ones are already held, which bounds the
  list and the save. Whether bought disciples count in `priceRate` stays the owner's open decision.
  Sims (`sim_game.py`, `sim_check.py`) unchanged: both items are bought, not simulated.
  Design: MONETIZATION "Tide Bell", "Sect Starter Pack"; list: SHOP_ITEMS.
- **D76** Flying Swords (owner 2026-10-23: "we need some real better sword, so we can sell 3 levels,
  the trail and aura getting better"; "aura only on sword"; picked "Hover ride, faster each level"
  over real flight, which would skip the light stairs and locked isles). PS99's hoverboards copied
  as is: three passes (Jade Jian, Heavenly Sword, Celestial Crystal Sword), a HUD button to ride the
  picked one at 1.5x / 1.75x / 2x walk speed hovering a stud over the ground with normal walking
  physics, off near pads (never buys), on the altar, on death and on a speed check. Looks = the
  Studio mock v9 on the sword only; the Creator Store blades ship as dumped data, not as place edits
  (Ctrl+S is Matteo's). Design: MONETIZATION "Flying Swords"; list: SHOP_ITEMS.
- **D76 v2** The Flying Swords fly (owner 2026-10-23 after trying the hover ride: "i cant fly with
  them? When i jump they got removed? this is bad, study similar games?"; the Roblox cultivation games
  fly on a key, Adopt Me's flying pets fly with the move keys, none drops you on a jump). Adopt Me's
  flight copied: camera-relative, rise / sink keys and a phone down arrow, hover when idle, jump
  rises. Progression kept server side: a ceiling, the map bound, the rider's closed islets; pads and
  the altar still land it. Design: MONETIZATION "Flying Swords".
- **D77** Paid random items (owner pick 2026-10-23, pre-launch audit): qi is sold for Robux and buys
  random recruits, so Roblox counts qi recruits as paid random items. Where
  `ArePaidRandomItemsRestricted` is true (or the check fails: fail closed) the items that sell qi (Qi
  packs, Starter Pack) are not sold; recruits, free summons and every other item stay. Rejected:
  locking qi recruits there (cuts the core loop) and launching without a check. Design: MONETIZATION
  "Rules for any new product".
- **D78** Heavenly Altar review (owner 2026-10-23: "Make a higher more premium place, place the punch
  button better, and make sure it pushes enough"; research: Roblox's own doc places a custom action
  button beside Jump, Slap Battles ragdolls on a hit). Mocks docs/art/mocks/altar_arena_all.jpg and
  altar_phone_buttons.jpg (`tools/mock_altar_arena.py`); owner picked B and 1. The altar is a Lei Tai,
  the square duel stage (red lacquer apron, timber deck, jade and gold seal, banners on the 4 corner
  posts, which never collide so every edge is a ring-out), `ALTAR_HEIGHT` 28 (was 15), half side
  `ALTAR_RADIUS` 11; the Spirit Springs moved out to `ALTAR_SPRING_X` and throw a higher arc; the
  altar row's trail leads to the nearest spring. Palm Strike on a phone takes the Recruit seal's spot
  left of Jump while you stand on the altar (Player attribute `AltarPalm` hides the seal). The knock
  drives ~24 studs (`ALTAR_PUSH_SPEED`, `ALTAR_PUSH_TIME`) with an `ALTAR_RAGDOLL` tumble, a thump and
  a camera kick; the striker gets a smaller kick. Flying Swords stay off over the deck and springs.
- **D79** The altar's look, redone (owner 2026-10-23 on D78's Lei Tai: "It's so ugly.... use the bottom
  of the disciple island, but the top needs an existing asset, try to find a nice open arena"). Three
  free Creator Store arenas staged on an island base in Studio Edit
  (docs/art/mocks/altar_store_arenas.jpg); owner picked A, "Ancient Chinese Arena" (asset 17609048910),
  on the lotus isles' rock islet rather than the peak island's underside ("horrible"), preview
  docs/art/mocks/altar_arena_isle_preview.jpg. The mesh is rebuilt by id (`Config.ALTAR_ARENA`, no
  inserted scripts) and only draws; an invisible slab is the deck, so props, stairs and poles never
  block a push. Stepping off the deck onto the islet's grass counts as out. Springs moved to
  `ALTAR_SPRING_X` 24, clear of the islet. D78's push, Palm spot and sword rule stay. The deck braziers
  went (owner: they read like stools); the hold timer is the HUD beads, a gold light warms the deck
  for 6 s on a win. Then (owner): the deck 36 up (`ALTAR_HEIGHT`), a jade sigil with a small light
  under each corner pole's foot (they stand past the islet's rim: magic holds them), warm lamps at the
  pole tops; two moon gates (owner pick C, docs/art/mocks/altar_tp_pads.jpg) replace the Spirit Springs
  (their arc could not reach 36 up): stepping into a gate's glowing door teleports you onto the deck
  (Teleport "altarGate", checked on the server). The gates then moved in to `ALTAR_SPRING_X` 15 (owner: "more
  to the center"), and the hub's island portals took mock B's look: a light column with gold arrows
  climbing it (`Portals.pad` opts.column; the islands' portals back to the hub are unchanged).
- **D80** Rankings screen and lighter ranking saves (audit 2026-10-23; owner pick C, mock
  `docs/art/mocks/ranks_C.jpg`; "Richest Qi ignores short boosts"). The Ranks chip opens a screen
  (`Ranks.client`): the wall's three boards as tabs, Global / your country / Friends, the top 100 with
  head shots and your own row pinned ("100+" past the list); "Go to the wall" is the old teleport.
  Lists come on demand from `Remotes.Rankings` (`Ranks.fetch`, Guard `Rankings`); the unused
  `Rank_*` Workspace attributes are gone. Friends = up to `RANK_FRIENDS` friends, one GetAsync each on
  the global store, cached `RANK_REFRESH` s. Saves: one per player per `RANK_WRITE_GAP` s (and on
  leave) instead of every 60 s (6 writes per player per minute, over Roblox's 5). Richest Qi ranks
  `data.peakSteady` (rate without pill, Spirit Tide, friends) in a new store `RanksQi2`: the old field
  counted them and a stored counter is never redefined. Why: the audit found country boards written
  but never shown and a write rate the budget could not hold with a full server.
- **D82** Pads you wait for (owner 2026-10-24: "no choice ever, and no frustration at all ever";
  picked Plan 1 of `docs/research/2026-10-24_core_loop_after_10.md`, then "your numbers" on the sim
  page). Each open pad costs `PAD_SECONDS[realm]` s of the pad income (`Main padRate`: the away rate
  without the 2x Qi pass, Welcome Pouch, Robux disciples or the rebirth boost; free disciples count)
  x the rebirth boost the realm needs, spread +-`PAD_SPREAD` by catalogue cost (`Config.padPrice`,
  `Main pricePads`). Prices are set when pads open and again after every buy (build, hire,
  breakthrough, rebirth), so a recruit, orbs or a pill shorten the wait you are in. Realm 1 builds the
  disciple core first (Meditation Platform, Disciple Bridge, Disciple Hall, Alchemy Bridge, Qi Array).
  A breakthrough keeps `PAD_KEEP` (platform, Lotus Isles, hall, quarters, bridges, array). A red pad's
  card says how long until you can afford it at your income now. Felt waits (qisim
  `tools/qisim/waits.luau`, orbs and pills in; `tools/sim_check.py` agrees): realm 1 ~10 s, 2-3 ~30 s,
  4-7 1-4 min, 8-10 14-25 min. Cost: a 3 x 15 min a day player reaches realm 9 around day 34 (was 4).
  Replaces the D44 price floor (`PRICE_FLOOR_S`, kept for the older sims).
- **D83** Recruit tutorial and a trail that never cuts (owner 2026-10-24: "the meditation center
  should be also in the first things, when you unlock recruit small tutorial with a free recruit +
  walk to the meditation center to see it"; "arrows ... cut at bridges, it shouldnt be. keep them
  active always during tutorial"). `Config.GUIDE_PRIORITY` is now D82's realm 1 core in order
  (platform, Fields Bridge, Disciple Bridge, hall, Alchemy Bridge, array): the first open one leads
  the HUD "Next" and the trail, which stays on until the core stands. The first Disciple Hall of a
  save that never recruited comes with `FREE_RECRUITS` (1) free recruit: the Recruit seal reads
  "Free", a tip points at it, and after the reveal a tip over the Meditation Platform leads the trail
  there until the player stands within `SEE_DISCIPLE_RANGE`. The trail now follows the whole route,
  bridge after bridge, from wherever the feet are (on a bridge too). Copies the standard first-egg
  tutorial (Pet Simulator 99, Bee Swarm Simulator's free first bee). qisim (engaged / median, 30 days,
  3 seeds) moves nothing past noise: realm 2 at 2.8 min (was 2.6), every later mark within 2%.
- **D84 Incense button (owner 2026-10-24, pick A of docs/art/mocks/2026-10-24_incense_button_ABC.jpg):**
  a round button in the HUD's right stack (src/client/Incense.client.luau) with the incense left today on
  an ember count badge (Pet Simulator 99 / Bee Swarm item counts). One tap teleports you in front of the
  nearest neighbour's shrine you can still bless (Teleport "shrine", Bless.target); the 3 s hold there
  stays (D57 keeps the visit, like Adopt Me's trick-or-treat buckets). Shown only while another sect is
  on the server; gold when a shrine is free; no incense left = the countdown to the UTC reset.
- **D85 Auto Build (owner 2026-10-25: "long term isn't so interesting once you build the same things
  50 times"; owner pick C of docs/art/mocks/2026-10-25_auto_build.jpg, from the first breakthrough):**
  Mega Mansion Tycoon's "Auto Build" pass ("build your house as you can afford each purchase"), free
  here and only for buildings the save has built before, in any life (`data.everBuilt`, seeded for old
  saves from what they own and the required pads below their best realm). The server buys one marked pad
  (`Auto` attribute) every `AUTO_BUILD_GAP` s while the owner is in the game, in the HUD "Next" order;
  never the breakthrough, the rebirth, the idle chest or hires (qisim: auto hiring starved the pads a
  realm needs, realm 7 -> 5 by day 7). `AUTO_BUILD_FROM` "breakthrough" = from life 1's first
  breakthrough (realm 2 rebuilds realm 1 by itself), "rebirth" = from life 2. Look: a gold beam and an
  "Auto in 0:13" line on the pad card, a gold light column + toast when it builds, a round gold hand in
  the HUD's right stack (count of buildings waiting, tap = on / off, kept in the save). Sims (qisim 4
  profiles x 14 days x 5 seeds, sim_game, sim_check): rebirth 1 0.3-0.8 min sooner, sim_game casual
  life 2 at 8.3 min (was 11.2) and rebirth 2 30 min (was 42); late lives and the end realm unchanged.
- **D86 Sect Styles (owner 2026-10-25: "Rebirth changing the vibe YES A"; research
  `docs/research/2026-10-25_rebirth_new_looks.md`, mocks `docs/art/mocks/2026-10-25_sect_style_*.png`):**
  every rebirth 1 to 10, then 15 and 20, unlocks a whole-sect look (`Config.SECT_STYLES`, Build Your
  Backrooms biomes + Clash of Clans levels): recolour, ornaments on every kit roof ridge and one
  ambience emitter over the peak (`SectStyle.luau`). The new one is worn at once ("New style!"), the
  Rebirth screen names the next one, and the Sect Styles page (Rebirth screen) wears any unlocked one
  or Classic (the D53 ladder). The overhead title shows the style. Why: from rebirth 3 every rebuild
  looked the same. Next: a Relic Hall that never resets, filled by mission progress (owner, mock first).
- **D87 Relic Terrace (owner pick B 2026-10-26; mocks `docs/art/mocks/2026-10-26_relic_*.png`):** a
  small isle bridged off the peak's west rim with ten plinths under a "Relics" gate (`RelicHall.luau`).
  Finishing Sect Missions rank N earns `Config.MISSION_RELICS[N]`, shown in colour for good with a gold
  burst and a "New relic!" toast; the rest stand as dark silhouettes (Animal Crossing museum stands).
  Never resets. Why: something that keeps growing across rebirths.
  Updates 2026-10-27: relics 1-3 and 5-9 are free Creator Store models (owner took the picks on
  `docs/art/mocks/2026-10-26_relic_candidates.png`), scripts stripped, in `assets/relics/RelicN.rbxm` ->
  Rojo `ServerStorage.RelicModels` (a missing file falls back to the part build); Jade Seal and Dragon Pearl
  stay part builds. The isle moved behind the peak (peak frame (-37, -110), bridged from the Fields islet's
  back rim) because at (-98, 69) it stood on the route between two peaks. Its lawn wears the Sect Style
  ground (`RelicHall.ground`). Unclaimed peaks build no isle (~685 parts each). Telemetry: `Relic visit`
  (first walk onto it per session), `Style unlock | wear`. A stray `workspace.Showcase` preview saved in the
  place is destroyed at boot (Main). Sect Styles got icons (sheet cell 40 + one per style, cells 45-57) and
  links from the Karma Shop and Settings.
- **D85b Heavenly Hands = full Auto Build (owner 2026-10-26: "then the karmic shop is useless no?"):**
  with Hands bought (Karma Shop, 5 karma), Auto Build also takes buildings never built before (Mega
  Mansion Tycoon's whole-house Auto Build); the Hands tap button stays. qisim median / engaged 14 days x
  5 seeds: identical (the sims already counted Hands as no walking).
- **D88 First 10 minutes (owner 2026-10-26: "this is what we should aim to do better", Roblox's new-user
  first-session curve 79% 1 min / 38% 5 min / 21% 10 min; journal study `tools/first5_report.luau`, 700
  first sessions, `docs/art/mocks/2026-10-26_first5/`):** players quit mid buying streak (5-9 s after a
  buy), not at a wall; the first breakthrough loses the most (22% within 60 s). Fixed: the quick-start
  welcome (25d0da3) had stamped `welcomed` before the tips read it, so new saves since 2026-10-24 got no
  free first recruit, no first-time tips, no starter chest. Owner picks: (1) "A and B": a gold Rebirth pad
  at the breakthrough spot in a rebirth gate realm (trail + HUD Next lead to it, standing on it opens the
  Rebirth screen, never auto built), and the first `REBIRTH_TIP_TIMES` rebirths open the screen by
  themselves once the price is held; (2) "A": one card at a time (`Shared.Screens`: free summons, the
  breakthrough and auto Rebirth screens wait for any open card) and a new save's first Daily Blessing
  waits for the first breakthrough + `STREAK_NEW_AFTER` s (`STREAK_NEW_LATEST` s at most). qisim
  onesitslow / median / engaged: realm 2 and rebirth 1 0.1-0.6 min sooner, long game unchanged.
