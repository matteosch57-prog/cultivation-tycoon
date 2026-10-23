# Studio bot vs sim_check, first 35 minutes (2026-10-23)

Owner: "make a real sim, use the studio engine". The Studio engine runs in real time only, so it
cannot play days; instead one bot played the real game for 35 min and the fast sim was checked
against it. Tools: `tools/botsim.client.luau` (the bot, run through the MCP in a solo Studio Play on
the mock save; lives outside `src`, never ships), `tools/botsim_compare.py` (the same player in
`tools/sim_check.py`, which gained an optional `events` log for this).

Player: the sim's "regular" rules (policy gated): cheapest pad, recruit x10 when no dearer than it,
a cheaper hire first, 6 s walk per pad, orbs every 30 s, gifts / pill / summons / shop gift claimed,
rebirth when the next realm waits for one, karma nodes cheapest comfort first. No passes, no
blessing (solo). Integration at 82a5a94. Bot times below are minus its 9 s boot offset.

| | Studio bot (1 run) | sim_check (median of 10 seeds, range) |
|---|---|---|
| first building | 0:06 | 0:07 |
| breakthrough to realm 2 | 2:21 | 3:01 (2:30-3:31) |
| rebirth 1 | 6:16 | 8:04 (6:41-9:21) |
| breakthrough (life 2) to 2 / 3 / 4 | 6:25 / 10:27 / 15:48 | 8:29 / 12:12 / 18:52 |
| rebirth 2 | 22:46 | 26:13 (25:07-28:23) |
| realm 4, life 3 | 31:58 | 31:48 (31:27-32:33) |
| waiting (nothing affordable) | 3% | 39% (38-41%) |
| longest single wait | 5 s | 42 s (30-48 s) |

- The engine is 15 to 25% faster than the sim up to rebirth 2, then they meet (the bot kept walking
  6 s per pad after buying Heavenly Hands, which the sim makes instant).
- In the engine the bot almost never waits: it held 10 to 100x the next price most of the time;
  the time between two pads was 7 s for 167 of 253 pads and never above 14 s. The pace of the first
  35 minutes is set by walking pad to pad, not by qi.
- The sim's waiting figure is not trustworthy: it waits 39% of the session in short gaps the engine
  does not have. Its realm and rebirth times are close enough (within a quarter) for planning.
- Same-state income matched: at the bot's 16 realm 1 pads the sim's formula gives the bot's rate once
  the Spirit Tide (x2, on in the bot then) is counted, so the gap is not the rate formula. Not yet
  pinned: which rule makes the sim poorer between buys (candidates: pad order under the price floor,
  gift and shop-gift timing, recruit timing).
- Bot gaps: it picked up only 2 orbs in 35 min (the orb walk needs a look; the sim counts ~20% of qi
  from orbs), so the real game is if anything richer than measured; one run only.
