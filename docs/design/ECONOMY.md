# Economy and progression

Every number lives in `src/shared/Config.luau`; this file names the keys and explains the shape.

## Qi
- Income per second = (`BASE_RATE` + sum of owned pads' `income`) x `incomeMult(realm)` x disciple bonus
  x 2 while a pill is active. Ticked on the server every second.
- Offline: income keeps flowing while away at `OFFLINE_RATE` of the rate (no tide, pill or friends), capped at `OFFLINE_CAP` seconds (+ Deep Meditation).

## Pads (`Config.PADS`)
- A pad opens once `unlock` buildings are owned (any of them) and its `req` pads are owned. This keeps
  3 to 5 pads open at once so players choose (D11).
- Cost x `costMult(realm)`; income x `incomeMult(realm)`. `costMult` steps by `REALM_COST_MULT` per
  realm up to `REALM_COST_LATE_FROM`, then by `REALM_COST_LATE`: the first realms are quick laps, then
  each realm takes ~2 to 3x the last, and realm 10 is the long goal of one life (D25, research
  2026-10-21_economy_math).
- Buying is a server position check every 0.1 s (`checkPads`), not `.Touched` (D10).
- Feature pads carry a `feature` line shown on the price card.

## The Main Hall
`mainhall1..5`: one building at the back centre, each level replaces the last (hut, sect hall, great
hall, palace with wings, gold celestial palace with towers). Only the highest owned level stands.

## Island layout and expansions (layout A, owner 2026-10-21)
Buildings stand in districts (`district` on each pad): Spirit Fields front left (veins, Lotus Garden,
bamboo, koi), Alchemy and Training on the right (furnace, Qi Array, Training Ground, Moon Gate), the
Disciples' corner back left (Disciple Hall, quarters, bell) and the heart (avenue, plaza, Main Hall, the
summit with the pagodas and library). Each OTHER owned qi building in the same district adds
`DISTRICT_BONUS` to a building's income (`districtMult`; the heart takes no bonus). The base disc keeps
`ISLAND_RADIUS`; `expand1`/`expand2` add the lobes in `ISLAND_LOBES` where their districts grow, and
`ROADS` (plus the plaza ring `ROAD_RING`) lay paths into each district as its land arrives. A
breakthrough takes the lobes back. Mock and study: `docs/art/mocks/island_layout.html`.

## Features
- **Recruiting** (Disciple Hall): costs qi (`recruitCost`: `RECRUIT_BASE` x `costMult` x +`RECRUIT_GROWTH`
  per disciple recruited in this realm, `data.realmRecruits`, which a breakthrough resets), rolls `RARITIES`. The best `maxDisciples`
  work; the rest rest until slots open. The roll is never sold for Robux (RULES R8); the Shop sells
  FIXED rarities behind realm gates and per-player limits, priced to their pacing impact (D28,
  MONETIZATION "Disciples for sale" and "Disciple price ladder"). Bought ones are kept in
  `data.boughtDisciples`, are never trimmed from the list, and survive breakthroughs and reincarnation.
- **Disciple slots:** `MAX_DISCIPLES` + one per owned pad in `SLOT_PADS` + `VIP_SLOTS` with the VIP pass.
- **Pill** (Alchemy Furnace): one brewed every `PILL_INTERVAL`; using it doubles qi/s for `PILL_DURATION`.
- **Qi orbs** (Qi Gathering Array): one every `ORB_INTERVAL`, up to `ORB_MAX`; worth `ORB_VALUE` seconds
  of income.

## Sect workers
A hire pad (`Hire_<id>`, PadKind `hire`) stands beside each owned building in `WORKERS` until it has
`WORKER_MAX` workers. The n-th costs `workerCost` (`WORKER_COST[n]` x the building's cost x `costMult`)
and adds `WORKER_BONUS` x that building's income (`data.workers[id]`). A breakthrough or a new life
sends them home with the buildings. The card shows one dot per worker the building takes; hire pads
are not `Pad_` so the HUD goal and the guide trail still lead to buildings. Looks, spots and tools:
`src/server/Workers.luau`; job loops on the client: `WorkerJobs.client.luau` (through the rig's joints with planted feet and both hands on two-handed tools, D47,
`Rig.luau`, nothing moves off screen). Why: the peak should look worked and alive (research
2026-10-21_workers, owner picked hire pads and straw hats from mock `docs/art/mocks/workers.html`).

## Spirit Tide (server-wide)
Every peak on a server earns `TIDE_MULT` x for `TIDE_DURATION` s, first `TIDE_FIRST` s after the server
starts, then every `TIDE_INTERVAL` s; a toast warns `TIDE_WARN` s before. Workspace attributes `TideNext`
and `TideUntil` (server time) carry the schedule. Offline qi ignores it. Why: a shared moment worth
staying for (research 2026-10-21_tycoon_study, Grow a Garden weather).

## Friends here (D35)
Each Roblox friend on the same server adds `FRIEND_STEP` to the live qi rate, at most `FRIEND_MAX`
friends (`friendsOf` in `Main.server.luau`, checked once at join with `IsFriendsWith`, in memory only;
never in offline qi, gifts or Qi packs, which use the away rate). A player who joins a friend's server
gets the free peak beside the friend's (`freePlot`). The friends card (owner pick mock A,
`docs/art/mocks/friends_A.png`, `src/client/Friends.client.luau`) sits top right under the Next goal:
friends' head shots and "+X% Qi" (player attributes `FriendsHere`, `FriendIds`), or, alone once the
intro is done (owner wants the social card there from the start), "Play with friends +10% Qi each"; an Invite button opens Roblox's
invite prompt. Event `Social` (friends_here at leave, next_door at join, invite).

## Group gift (D35)
A gift button just right of the HUD's qi total, a gold gift box, "+10%" and the qi drop, wobbling slowly (owner: "just show +10% Qi with an attractive icon"; only while `GROUP_ID` is set and the gift is not active) opens the Sect
Gift card, the owner's three steps: 1 Like the game, 2 Join our group (a button: Roblox's own join prompt,
`GroupService:PromptJoinAsync`, D43), 3 Claim. Only the group
is checked and paid: remote `ClaimGroup` re-reads the player's groups (`GetGroupsAsync`; `IsInGroup`
is cached per session), sets `data.groupClaimed`, and `rate` adds `GROUP_BONUS` everywhere while the
player is still a member (checked at each join). Never reward or check a like (no API, against Roblox
rules). Event `Social` group_claim. Why: co-play sessions last ~1.9x longer and Roblox favours co-play in discovery (research
2026-10-21_playing_together); the sim puts 3 friends all the time at realm 10 one day sooner.
Checked in Studio Play (mock save, 2026-10-21): `DebugSet` friend raised the rate 1 to 1.1/s, the away
rate stayed 1, the line read "1 friend here +10% Qi" (`docs/art/captures/friends_here_play.jpg`), no
script errors. Not checked: two real friends (the peak next door, the `Social` events).

## Heavenly Gift (D36)
A save that never joined before (`data.welcomed == false`; stamped at join, a save from before the gift
counts as welcomed) opens on the intro (`src/client/Intro.client.luau`, player attribute `WelcomeQi`):
all in the qi colours (owner: "make it sexier, keep the coloring like the Qi color"): a big qi drop
breathing in premium rays (owner: "make rays premium": every ray fades out to its tips, a wide soft
set and a thin bright set turn against each other, sparkles twinkle on a ring) and halos, HEAVENLY GIFT, +`WELCOME_QI`, a jade GO with a shine sweep.
GO calls `ClaimWelcome`, which pays once and logs economy source `welcome`; the drop bursts, 36 qi
drops explode across the screen and float, then fly one by one into the counter (nearest first, 0.08 s
apart), each with an `orb` ding climbing in pitch ("collect it slowly, sound following it"). Live funnel times read about 0.5 min earlier than the onboarding table
(compare with its 200 qi row). Checked in Studio Play (mock save, 2026-10-21): qi 8 -> 209 on GO, a
second claim refused, no errors (`docs/art/captures/intro_heavenly_gift_play.jpg`, `intro_burst_play.jpg`, `intro_after_go_play.jpg`).

## Idle chest (D39)
While away, income runs at `OFFLINE_RATE` of the rate (up to `OFFLINE_CAP` s) and the idle chest on the
peak (`IDLE_CHEST_AT`) collects one free summon per `CHEST_SUMMON_EVERY` s away, at most
`CHEST_SUMMON_MAX` waiting (`data.chestSummons`). On return the server sends `Notify("idleChest", qi,
away, summons)`; `IdleChest.client` plays screen A (the chest bursts, the qi flies into the counter,
summon balls pop out; a tap opens one through `ChestSummon`, the same roll and seating as a recruit,
no qi). Collect opens any left. Event `IdleChest` (hours away, summons waiting, realm). Free summons
don't move the pace (tools/sim_game.py).

## Heavenly Altar (server-wide, king of the hill)
A floating jade altar above the hub cauldron (`src/server/Altar.luau`) opens `ALTAR_FIRST` s after the
server starts, then every `ALTAR_INTERVAL` s, half a tide cycle after each tide; a toast warns
`ALTAR_WARN` s before. Two Spirit Springs on the plaza throw players up while it is open. Stand on it
alone for `ALTAR_HOLD` s to claim it (two or more pause the timer; eight rim braziers light as it
runs). Palm Strike (button above Jump, F) knocks rivals back; a fall locks you out until the round
ends. Winner: `ALTAR_WIN_SECONDS` of their own income (`ALTAR_SOLO_SECONDS` if nobody else came) and
a gold light aura (rim light, halo behind the head, motes; D51) until the next round; everyone else who stood on it: `ALTAR_JOIN_SECONDS`. If nobody holds it
within `ALTAR_WINDOW` s it fades (joiners are still paid). HUD: Workspace attributes `AltarNext`,
`AltarUntil`, `AltarHolder`, `AltarHold`, `AltarCrowd`; player attribute `AltarOut`. Why: the owner's
"something to oppose other players" without stealing (2026-10-21); about +20% live income per round
on average, which moves a regular player's realm 10 by about a day (research 2026-10-21_economy_math).

## Playtime gifts
After `GIFT_TIMES[i]` seconds of play in one session a gift button on the HUD's left column can be
claimed (server `ClaimGift`) for `GIFT_VALUE[i]` seconds of income, counted without tide or pill. The
`GiftIn` player attribute is the seconds left (0 = ready, -1 = all claimed this session). Why: pushes a
first session past the ~8 minute benchmark (research 2026-10-21_tycoon_study). The HUD shows the next
tide under the qi counter (owner picked mock A for both, 2026-10-21).

## Pacing
`python tools/sim_pacing.py` replays these rules from Config and prints the minutes to each milestone
for an active, a casual and an idle player (`--set KEY=VALUE` tries a value first, `--trace` lists
every purchase). `python tools/sim_economy.py` plays the whole climb (realms 1 to 12, real days of
sessions with offline qi, tide, gifts, optional passes) and reports minutes and the day per realm;
`--waits` shows how long players stand with nothing to buy, `--passes 2x,vip,orbs` a paying player,
`--bought 9` a Shop disciple; `simulate(..., reinc=dict(...))` plays several lives of reincarnation.
Evidence: `docs/research/2026-10-21_first_session_onboarding.md` (first session) and
`docs/research/2026-10-21_economy_math.md` (the whole climb, passes, Robux disciples, reincarnation).

## Realms and breakthrough
All pads owned -> a gold breakthrough pad (`BREAKTHROUGH_COST` x `costMult`). Breaking through: realm + 1,
owned pads, qi and the pill reset; disciples stay. Names in `REALMS` (10 names, then "Immortal Realm N").
From `REINC_REALM` a player may reincarnate instead: [REINCARNATION](REINCARNATION.md).
