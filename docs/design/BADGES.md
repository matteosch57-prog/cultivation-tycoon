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
| 10 | Reborn | Start a new life through reincarnation. | First reincarnation | A phoenix ring around the qi drop |

**Icons:** 512 x 512 PNG, Roblox crops them to a circle (keep the subject in the middle 70%).
Made the way the store art is made: hero shots staged in Studio Play, finished with
`tools/store_post.py` (rays, rim light), not flat drawn vectors.
