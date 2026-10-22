# Playing together and the intro: what this thread did (2026-10-21 to 2026-10-22)

Evidence file (write once). The design itself lives in ECONOMY "Friends here", "Group gift" and
"Heavenly Gift"; the WHY in DECISIONS D35 and D36; numbers in `Config.luau` (`FRIEND_*`, `GROUP_*`,
`WELCOME_QI`). Commit: 8326e06 on `integration` (pushed, origin at 927ce48 or later).

## 1. Research
`docs/research/2026-10-21_playing_together.md`: why tycoon players stay solo (nothing to gain from
others, near-empty servers, calm phone players, fear of being robbed), what makes them play together
(friend bonus, invites, shared moments, visiting), Gladiator RNG lessons (measure every feature,
friends-only referrals, no own chat, no market, nothing social in the first 5 minutes). Ranked ideas:
1 friend bonus + peak next door, 2 invite and referral, 3 bless a sect, 4 sect board. Owner picked 1.

## 2. Built (owner picks in quotes)
- **Friends here (D35, "1 good")**: +`FRIEND_STEP` (10%) live qi per Roblox friend on the server, at most
  `FRIEND_MAX` (3). Not offline, gifts or Qi packs. A joining friend gets the free peak beside theirs
  (`freePlot`). Server: `friendsOf`, `findFriends`, `friendCount` in `Main.server.luau`; attributes
  `FriendsHere`, `FriendIds`. Economy sim: 3 friends always moves realm 10 from day 20 to 19.
- **Friends card (mock A of `docs/art/mocks/friends_*.png`)**: `src/client/Friends.client.luau`, top right
  under Next: head shots and "+X% Qi", or "Play with friends +10% Qi each" when alone (shown once the
  intro is done). Invite opens Roblox's invite prompt (remote `SocialInvite`, telemetry only).
- **Group gift ("like the game, join the group, claim", no group link in game)**: a wobbling gold gift
  button "+10% [qi]" right of the qi total ("put the button on the right of the qi total", "just show
  +10% Qi with an attractive icon") opens the Sect Gift card. Remote `ClaimGroup` re-reads the groups
  (`GetGroupsAsync`), sets `data.groupClaimed`; +`GROUP_BONUS` qi everywhere while a member. The like
  is never checked or paid (no API, against Roblox rules).
- **Heavenly Gift intro (D36, "HEAVENLY GIFT with a nice shiny green GO", then "make it sexier, keep
  the Qi color, make Qi explode and collect it slowly, sound following it", "make rays premium")**:
  `src/client/Intro.client.luau`. A new save (`data.welcomed == false`; old saves count as welcomed)
  sees a qi drop in turning fading rays with sparkles, the title, +200 and a jade GO. Remote
  `ClaimWelcome` pays `WELCOME_QI` once; 36 drops explode, float, then fly in one by one with a
  climbing ding. Economy math check: Main Hall at ~0.5 min instead of 1.1, realms 2 to 5 move under
  a minute.
- **Telemetry**: custom event `Social` (friends_here, next_door, invite, group_claim); economy source
  `welcome`.
- **Studio test hooks** (TECH): `DebugSet(player, "friend", other)`; client attributes `FriendsCard`,
  `IntroGo`.

## 3. Checked (Studio Play, mock save)
Friend bonus rate 1 -> 1.1, away rate unchanged; friends card and group card draw; GO pays 200 once,
a second claim refused; burst and rays captured (`docs/art/captures/friends_*`, `group_*`, `intro_*`).

## 4. Mistakes worth remembering
- A `--` comment put in the middle of a one-line table constructor commented out its end and broke
  the Intro script in the owner's Play (`Expected '}'`). Never put a trailing comment inside a line.
- I read Gladiator RNG's Rojo process (port 34873) as this game's and wrongly said Rojo was down.
  Check the port's owner process before saying a server is down.
- Rotated GuiObjects turn about their own centre and are not clipped; a rotated shine needs care.

## 5. Open items (owner)
- Paste the group id into `Config.GROUP_ID` (0 hides the gift button).
- Two real friend accounts: the peak next door, the friends card with heads, the `Social` events.
- First real tap of GO: watch the burst and listen to the dings in order (only seen through a hook).
- Not built from the research: invite referral rewards (idea 2), Bless a sect (idea 3), sect board (4).
