# Karma Upgrades (2026-10-26, pick A)

Owner: "overall rebirth is not rewarding cause you can't buy shit. We should do a better skill menu".
Before: 6 nodes, first rebirth paid 2 karma, cheapest node 5: a fresh rebirth bought nothing.

## Research
- Pet Simulator 99 Upgrades (bloxodes.com/wiki/pet-simulator-99/upgrades): 10 lines (Coins, Diamonds,
  Drops, Luck, Magnet, Move Faster, Pet Damage, Pet Speed, Tap Damage, XP), 2 to 9 steps each, every step
  a small % (+10% coins, +10% luck, +12.5% walk), price rising steeply step to step. Copied as option A.
- Cookie Clicker heavenly upgrades: a prestige tree, a node opens its children (option B).
- PS99 ranks: a reward track (option C, A + free perk per rebirth). Matteo picked A.

## Built
Karma x10 (rebirth pays 20 + 10 per rebirth; old saves x10 once). Ten lines, Config.DAO: Sect Fortune
+10% qi x10 (out of prices), Heaven's Favor +5% rare weights x5, Disciple Seat x5, Spirit Magnet +25% orb
qi x5, Swift Steps +10% walk x3, Elixir x5, Meditation x4, Soul Echo x5, Heavenly Hands, Floating Isles x2.

## Sims (30 days, before -> after)
sim_check regular: rebirths by day 30 5 -> 6, deepest realm 8 -> 8; lives 2-4: 31/114/90 min -> 24/88/78.
sim_game (casual 1x20 min / regular 2x30 min): each life 10-17% shorter, the realm each life ends at
unchanged; life 14 ends on day 24 -> 22 (casual) and 9 -> 8 (regular).
Full outputs: /mnt/project-files/2026-10-26_karma_upgrades/sim_*.txt

## Follow-ups
- 2026-10-26 22:00, owner: "can you buy stuff at each reinc at least? red dot when it's possible to buy
  smthing? once per session". Config.daoCost + `more`: Sect Fortune goes on past level 10 (+15 karma a
  level; levels 9-10 now 330/400), so a cheapest-first player buys at least one level every rebirth up to
  rebirth 100 (before: none at rebirths 31, 35, 37, nothing left after 38). Dots.luau lights the Karma
  dot once per session for everything affordable (s.karmaDotSeen). Play-tested (27f6809).
- 2026-10-27: KarmaShop telemetry logs endless levels as "11+"; the one-time karma x10 of an old save is
  printed (efbf2d8). Published by the owner 2026-10-27.

## Still open
- Read the live KarmaShop events: which lines players buy first, and in which life.
- qisim (Lune) was never run on the new shop; sim_game and sim_check were.
- Option C (Rebirth Road, a free perk per rebirth) was not built; it could stack on top of A.
