# qisim: the qi sim that runs the game's own code

`tools/sim_game.py` and `tools/sim_check.py` re-type the economy in Python, so they drift from the
game. qisim does not: it runs the real Luau.

- `src/shared/Config.luau` is loaded as it is.
- The economy functions of `src/server/Main.server.luau` (`rate`, `priceRate`, `discipleMult`, `roll`,
  `addDisciple`, `reincarnate`, and the Recruit, Chest, Pill, Gift, Streak, Welcome and Karma handlers)
  are cut out of Main's text by name and run with stubs for the parts that draw or save. Shop's
  `grantProduct` runs the same way.
- What Main does inline (the 1 s income tick, the offline pay at join, the pad offers and their
  prices, a pad buy, the breakthrough, hires, orbs) is mirrored in `world.luau`. Each mirrored line is
  listed in `engine.luau` MIRRORS, and a run stops with an error when one of them is no longer in the
  source. The Shop daily gift, the altar and the shrine payouts are checked the same way.
- An error caught inside the game's code, or a name the stubs don't provide, fails the run.

`player.luau` is the player: the HUD "Next" pick (`Config.guidePick`), the best payback among what
they can afford (measured with the game's `rate()`), walking at `Config.MOVE.walk` between the real
pad positions, orbs, gifts, pill, chest, streak, shop gift, Karma Shop, rebirth (recruiting the qi
above the price first). Profiles come from the 2025 Roblox benchmark (GameAnalytics): `median`
2 x 7 min a day, `engaged` 3 x 15, `hooked` 4 x 26, and `regular` 2 x 30 (the old sims' player).

## Run

Needs [Lune](https://github.com/lune-org/lune/releases) 0.8.9 (one binary). From the repo root:

```
lune run tools/qisim/run.luau <median|engaged|hooked|regular> <days> <seeds> [none|all passes] [altar share]
lune run tools/qisim/replay.luau <save.json> [seeds] [profile]
```

`replay` plays a real save's sessions (`journal.sess`: start and length) with its passes and the
Welcome Pouch, and prints the save next to the sim. A save JSON is the record's `data` table; add
`"simPasses": { "x2": true, "auto": true, "vip": true }` for a player who owns the passes.

Findings and validation: `docs/research/2026-10-23_qisim.md`.
