# What pushes players to progress: audit against tycoon research (2026-10-22)

Owner ask: "Based on research of tycoon games, check if we have enough to push people to progress."
Sources: `2026-10-21_tycoon_study.md` (Roblox retention doc: D1 = core loop and first 5 minutes, D7 =
short and long goals, D30 = updates; DevForum session and first-join threads; Grow a Garden, Steal a
Brainrot, Sell Lemons, the Tycoon 2 games), `2026-10-21_playing_together.md`,
`2026-10-22_visible_progression.md`, DevForum daily-streak threads
([consecutive daily rewards](https://devforum.roblox.com/t/consecutive-daily-rewards/289149),
[7-day streak + playtime gifts resource](https://devforum.roblox.com/t/time-rewards-system-roblox-daily-rewards-playtime-gifts-gui-7-day-streak-6-timed-gifts/4849901)).
Checked against `origin/integration` code.

## What we already have
| Push | What it is | Where |
|---|---|---|
| Next step always visible | HUD "Next" pad, pad previews, guide trail, first-time tips | Hud, Guide, D50 |
| Growing, prettier base | island opens over 4 realms (D48), skins by realm, lights by life (D53) | Config.REALM_PADS, Skin |
| Long goal + reset loop | realms, breakthrough, reincarnation, Past Lives, Karma Shop | D29 to D32, D40 |
| Collection with rare pulls | 9 disciple rarities, x10 / x50 recruits, recruit reveal | D41, D52 |
| Come back | idle chest (offline pays half, D39), daily playtime gift ladder (D49) | IdleChest, Hud |
| Shared moments | Spirit Tide (D30), Heavenly Altar rounds | Main, Altar |
| Social | friends bonus (D35), group gift, status title over heads (D53) | Friends, StatusTitle |
| Spend | shop, passes, Welcome Pouch (D38) | Shop |

## Gaps, ranked (impact for the cost)
1. **No ranking anywhere.** The player list shows Realm only; no board of the best sects. Rankings
   are the oldest status push in simulators, and our peaks already stand side by side, so a board at
   the hub (best realm, then lives) gives the skins and titles an audience. Needs an OrderedDataStore
   (ServerHealth already budgets GetSorted). Also add Lives to leaderstats.
2. **No disciple index.** `Pulled` is tracked but never shown as a book to fill. RNG and pet games
   push collection with an index and a reward per completed row (here: per rarity first pulled), which
   turns every recruit into progress even when it is not an upgrade.
3. **No login streak.** D49 rewards staying today, nothing rewards coming back tomorrow. A 7-day
   ladder that pauses instead of resetting on a missed day (the 2026 DevForum resource's choice) fits
   "calm" and lifts D1 / D7.
4. **No milestones or badges.** No BadgeService at all. Roblox badges are free, show on the profile and
   give short goals between realms (first breakthrough, first Elder, first life, realm 10).
5. **Bless a sect** (visit another peak, both gain a little), from the tycoon study, still not built:
   the one social reason to walk to a neighbour.

Already covered and not gaps: the base growing slowly (D48), visible status (D53), shared timed
events, daily playtime gifts, offline return.
