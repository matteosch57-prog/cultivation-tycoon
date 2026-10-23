# Badges (proposal, 2026-10-22)

Roblox badges are free to award and show on the player's profile. Creating them in Creator Hub is
free for 5 a day per game, then 100 Robux each
([DevForum: free badge creations](https://devforum.roblox.com/t/announcing-free-badge-creations/1680515)).
So the list is 10: the first 5 tonight, the other 5 tomorrow, at no cost.

Goal: a short goal between every realm step, so a player always has one in reach.
The game awards them from the server (`BadgeService:AwardBadge`) when the goal is met; the id of
each badge goes in `Config.BADGES` after you create it (0 = not created yet, nothing is awarded).

| # | Name | Description (paste into Creator Hub) | When it is awarded | Icon idea |
|---|---|---|---|---|
| 1 | Sect Founder | Raise the first building of your sect. | First building bought | Your first hall on a jade circle |
| 2 | First Disciple | Welcome your first disciple. | First recruit | An Outer Disciple bowing |
| 3 | Foundation Laid | Break through to Foundation Establishment. | Reach realm 2 | Jade lotus with a "2" seal |
| 4 | Golden Core | Form your Golden Core. | Reach realm 3 (Core Formation) | A golden orb in rays |
| 5 | Loyal Cultivator | Return for 7 days of Daily Blessings. | Day 7 of the login streak | Seven lit lanterns |
| 6 | Elder's Favour | Recruit an Elder or rarer. | First Elder+ disciple | Purple-aura Elder |
| 7 | Nascent Soul | Awaken your Nascent Soul. | Reach realm 4 | A small glowing spirit over a hall |
| 8 | Sect of Friends | Cultivate beside a friend. | Play on a server with a friend | Two disciples back to back |
| 9 | Mahayana | Reach the Great Vehicle. | Reach realm 8 | Main Hall level 5 at dusk |
| 11 | True Immortal | Ascend to True Immortal, the tenth realm. | Reach realm 10 | The grand hall at dusk (was Mahayana's icon) |
| 10 | Reborn | Start a new life through reincarnation. | First reincarnation | A phoenix ring around the qi drop |

**Launch set (owner 2026-10-23, 5 free creations):** Sect Founder and First Disciple (easy), Golden Core and
Loyal Cultivator (medium), True Immortal (super hard). The other five keep id 0 for now.

**Icons (2026-10-23):** `art/badges/<key>.png`, 512 x 512, in the shop icons' glossy-disc language
(gold ring, painted subject, filling the circle Roblox crops to). Generator
`tools/shop_icons/badge_icons.js` (names and descriptions also in `badges.json`); render as its header says.
