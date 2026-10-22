# Playing together: what makes tycoon players play with each other, or alone (2026-10-21)

Evidence file (write once). Proposals only: nothing here is built. Decisions that come out of it go to
DECISIONS.md, numbers to `Config.luau` (the numbers below are provisional, for sizing only).

## 0. In plain words
Roblox says a session with friends lasts about twice as long as a solo one, and since 2025 it pushes
games that bring friends together in discovery. So playing together is worth building. But most tycoon
players play alone, and for simple reasons: their plot is theirs, nothing on another plot changes
anything for them, and in a new game the server is often nearly empty.

The games that make people play together do one of three things. They **pay you for having a friend
in the server** (a small cash bonus per friend). They **make the whole server live the same moment**
(Grow a Garden's weather and weekend events; we already have the Spirit Tide). Or they **let you
touch another player's stuff**: trading, stealing, or visiting.

Our pillar is "fair and calm", so stealing is out, and trading is out too (scams, children, duplicate
bugs; Gladiator RNG's market cost weeks of safety work). What fits us is the gentle version: a
**friend bonus**, **your friend's peak right next to yours**, a **blessing you leave on a neighbour's
peak**, and later a **board of the best sects**. Every one of them must work when you are alone in
the server, because at launch you often will be.

My pick to build first: the friend bonus with the friend's peak next door (section 4, idea 1). It is
the smallest, needs no new screen, and pays exactly the players Roblox rewards us for.

## 1. Why tycoon players stay solo
1. **Nothing to gain from others.** Each plot is a closed loop. Walking to a neighbour's peak changes
   nothing for you. In our game today a visitor can only buy shop items on someone else's peak
   (`Shop.luau`: no owner check on shop pads).
2. **Near-empty servers.** A new game has few players, and Roblox matchmaking has been seen creating
   one-player servers instead of filling existing ones (DevForum bug report, under investigation). Any
   feature that needs a second player is dead weight for most early players.
3. **The audience.** Calm, phone-first players like to go at their own pace. Since January 2026 typed
   chat needs an age check and only works inside an age band, so many players cannot even talk.
4. **Fear of others.** In stealing games (Steal a Brainrot) other players are a threat. Calm tycoon
   players pick calm games for that reason, so any contact we add must be one-way kind: give, never take.
5. **Lesson from Heavenly RNG:** players who arrived through a friend converted best and stayed
   worst, because nothing in the game tied them to each other once they were in (Gladiator RNG
   SOCIAL.md "Goal").

## 2. What makes them play together (precedents)
| Lever | Who does it | How it works | Fits us? |
|---|---|---|---|
| **Friend in the server bonus** | War Tycoon (+10% per friend, max +30%), many tycoons (+5% per friend, max +15%); Gladiator RNG has it (its SOCIAL "Friends here") | passive, server checks Roblox friendship | Yes: no screen, calm |
| **Invite + referral reward** | Roblox's own referral system (`ReferredByPlayerId`, `LaunchData`, Creator Hub banner); Gladiator RNG pays the inviter at the newcomer's 10th win, friends only, capped a month | pay on a real milestone, never on the join | Yes |
| **Party** | Roblox Party (since Dec 2024): up to 6 friends land in one server | players arrive together | Free for us: a 6-peak server fits a full party |
| **Shared server moment** | Grow a Garden weather and the weekend admin events (the Aug 2025 event pushed Roblox to its 47 M concurrent record) | everyone sees the same thing at the same time | Have it: Spirit Tide (D30) |
| **Visit and show off** | Theme Park Tycoon 2 (6 parks per server, visitors walk your park, friends get build rights), Grow a Garden (walk other gardens) | your plot is a stage | Yes: our peaks are already side by side and the realm looks (D32) are visible from next door |
| **Trading** | Pet Simulator 99 Trading Plaza, Grow a Garden (tickets in Aug 2025, a Trade World with booths in Nov 2025) | players swap items | No (scams, kids, dupes; a market is a big safety system) |
| **Stealing / raids** | Steal a Brainrot | other players are a risk | No (breaks "fair and calm", D30) |
| **Guilds / clans** | Pet Simulator 99 clans, Gladiator RNG guilds | weekly group goals | Not now (section 3) |

## 3. Lessons from Gladiator RNG to respect
- **Every feature ships measured (its R23).** Each idea below names the question and the event fields
  that answer it, in the same change.
- **Referrals only between Roblox friends.** Join data can be crafted, so a stranger's id would let an
  alt pay a chosen account. One reward per newcomer, a monthly cap, paid at a real milestone.
- **No chat of our own.** All typed text goes through TextChatService; custom cross-server chats have
  got games deleted. Our social features carry no typed text at all.
- **No market, no direct trade** unless built as a ledger with tickets (its R21). Not worth it here.
- **Do not build a big social system before newcomers survive the first minutes.** Gladiator RNG built
  friends, duo, guilds, a dig and a weekend tournament; then its first ad batch showed 159 new players,
  a 90 s median session and nobody back on day 2. The first session decided everything, not the guild.
  So anything social here stays out of the first 5 minutes (no button, no popup) and is passive.
- **Red dots lead to a dot** and are set where the state changes; "You were blessed" must not become a
  dot hunt.

## 4. Ideas for Cultivation Tycoon, ranked
Each one works with one player in the server.

### 1. Fellow disciples: friend bonus + the friend's peak next door (pick)
- **Bonus:** each Roblox friend on the same server adds +10% to your qi/s, at most +30% (3 friends).
  Server only (`Player:IsFriendsWith`, checked again on join and leave, kept in memory), counted in
  `rate` like the pill, never in offline qi or Qi packs. Shown as one line under the qi counter
  ("Friends here +20%") with their head shots, in the HUD's mock C language.
- **Next door:** `freePlot()` today takes the first free peak. When a friend already owns a peak, take
  the free one beside theirs (the bridge between them becomes "your path"). Zero UI.
- **Why it fits:** the sect theme already says it (fellow disciples cultivate faster together); Parties
  of up to 6 fill exactly our 6 peaks; it is the co-play Roblox ranks for.
- **Size check:** +30% is under the 2x Qi pass, so the pass keeps its value; with the pass it stacks to
  2.6x. Run `tools/sim_economy.py` with a x1.3 income row before choosing the number.
- **Measure:** `Social` event (action `friends_here`, friends bucket 0 / 1 / 2 / 3, session minutes
  bucket). Question: are sessions with a friend longer, and do those players come back more?

### 2. Invite a friend (Roblox referral)
- An "Invite" toy button (mock first, R4) opens `SocialService:PromptGameInvite` with the inviter's id in
  `LaunchData`; Roblox's referral link and banner switched on at publish.
- **The newcomer** gets a small welcome gift at once (a free first recruit or 5 min of income). **The
  inviter** is paid when that newcomer reaches their first breakthrough (a real milestone, about the
  first hour), once per newcomer, friends only, a monthly cap. Port Gladiator's referral code shape
  (`Social.Referral*`), not its screens.
- **Measure:** `Social` actions `invite`, `referral_join`, `referral_paid`, `referral_refused`.

### 3. Bless a sect (the gentle visit; was idea 7 of the tycoon study)
- Each peak gets an incense altar at its entrance (the kit already has incense, `5fb9b03`). A visitor
  who stands at someone else's altar for a few seconds lights it: **both** get ~60 s of their own
  income, the owner sees a toast "Lin blessed your sect", and a lit stick stays in the altar for the
  rest of the session (a visible trace of visits; real lit object, no fake light, R3).
- Limits so it cannot be farmed: once per pair per day, at most 5 blessings given and 5 received a day,
  never between alts in a loop (both sides capped, keyed on the pair and the UTC day).
- **Why:** it turns the 5 other peaks into places worth walking to, works with strangers, takes nothing,
  and gives the realm looks (storm, halo) an audience.
- Needs a mock of the altar and the toast first (R4).
- **Measure:** `Social` actions `bless_given`, `bless_got` (realm bucket). Question: do players walk to
  other peaks, and does a blessed player stay longer?

### 4. The sect board in the hub
- Already planned (ROADMAP M2 "realm leaderboard"). Proposed: a stone stele in the hub with the top
  sects by lives, then realm (both monotonic peaks, so a reset never drops you), plus "Friends" and "This
  server" tabs. OrderedDataStore, written on change only, read on a slow timer (TECH "Data" rules first,
  R17). The top rows show the sect's best disciple in its rarity colour: showing off the collection.
- **Measure:** board opens, and the share of players who climb a row in a week.

### 5. A shared tide goal (later, after data)
- During a Spirit Tide, every build on the server fills one shared bar; when full, every peak gets a
  bonus orb shower. The bar's size scales with the number of active peaks, so one player alone can still
  fill it. Only if the tide data (tycoon study section 3) shows that tides keep players.

### Not proposed
- **Trading or gifting disciples:** paid disciples are fixed and limited per player (D28); a trade path
  would be a way around those limits, and it brings scams and dupes. If ever, a one-way gift of a
  Robux product to a friend, never items between players.
- **Stealing, raids, PvP:** "fair and calm" (D2, D30).
- **Guilds / alliances of sects:** big systems that need many players per server and per day. Revisit
  only once the board shows a steady retained population.
- **Shared peaks** (friends building on one island, Theme Park Tycoon 2 build rights): clashes with one
  save per player and the pad economy.

## 5. Order I would build them in
1. Fellow disciples (idea 1): code only, one HUD line (mock first), no new remote.
2. Invite + referral (idea 2), at publish time so the referral banner is live from day 1.
3. Bless a sect (idea 3), after mocks.
4. The sect board (idea 4), already on the M2 list.
Then read the first live batch before anything bigger.

## Sources
- Roblox, "Join the Party on Roblox" (Dec 2024): Party, co-play sessions ~1.9x longer than solo.
  https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox
- Roblox, discovery that favours retention, co-play and spend (Jun 2026).
  https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox
- GameAnalytics 2025 Roblox benchmark (return frequency grew; the 2025 algorithm update favouring
  friend co-play). https://www.gameanalytics.com/cn/reports/2025-roblox-report
- DevForum, one-player servers instead of filling existing ones (bug report).
  https://devforum.roblox.com/t/roblox-is-creating-1-player-servers-over-filling-existing-ones-harming-interaction/3981365
- Friend bonuses: War Tycoon wiki (cited in Gladiator RNG research 2026-10-03), game pages listing +5%
  per friend, max +15% (Roblox game listings, community). https://war-tycoon-roblox.fandom.com/wiki/Friend_Boosts
- Grow a Garden trading (tickets Aug 2025, Trade World Nov 2025; community guides).
  https://www.sportskeeda.com/roblox-news/grow-garden-trading-update-patch-notes,
  https://beebom.com/grow-a-garden-trading-guide/
- Grow a Garden / Steal a Brainrot weekend admin events and the 47 M record (Tubefilter, Aug 2025).
  https://www.tubefilter.com/2025/08/25/roblox-grow-garden-steal-brainrot-admin-war-record/amp/
- Pet Simulator 99 trading scams (community guides, commercial sites).
  https://www.u7buy.com/blog/ps99-trust-trade-scams-guide
- Theme Park Tycoon 2 (6 parks per server; community pages, low trust).
  https://rowatcher.com/games/31970568/theme-park-tycoon-2
- Steal a Brainrot base lock and social standoff (community).
  https://www.crazygames.com/game/steal-brainrot-online
- Gladiator RNG: `docs/design/SOCIAL.md`, `docs/research/2026-10-03_social_layer.md` (Roblox referral,
  invite, chat and text rules with their sources), `docs/research/2026-10-21_first_session_rework.md`.
- Trust: only the Roblox posts are first party. Game details come from wikis and guides; treat them as
  community-reported.
