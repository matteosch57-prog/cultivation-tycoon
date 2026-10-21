# First session: onboarding research and pacing simulation (2026-10-21)

Evidence for B01 step 5 (first 5 minutes) and the telemetry half of step 7. Numbers in the tables are
outputs of `python tools/sim_pacing.py` on the Config of this date; the live values stay in Config.

## 0. In plain words
- A new player buys their first building about 20 seconds after landing, the Main Hall after about a
  minute, and something new every 20 to 30 seconds for the first 5 minutes. That matches what other
  tycoons do, so the first 5 minutes are not retuned.
- The first breakthrough comes after about 11 minutes for a player who plays actively, and about 20
  minutes for one who mostly waits. The gold breakthrough pad was so cheap that it was bought the
  second it appeared; it now costs a few minutes of income, so it reads as a goal.
- After the first breakthrough the next realms go faster, not slower, because disciples stay and keep
  multiplying income. Whether that is what we want is a question for the owner (Q3 in DECISIONS).
- There are no real players yet, so the simulation sweeps three player styles instead of guessing one.
  The first live batch replaces it: the funnel events below measure the same milestones.

## 1. What other games do (sources)
- **Guide arrow:** the usual build is a client-side Beam from the character's root attachment to the
  target pad, `FaceCamera` on, re-pointed after every purchase to the nearest affordable unbought pad,
  re-scanned about once a second, hidden when nothing qualifies. Roblox ships a "Character Path Beam"
  sample doing exactly this. Variants: scrolling arrow textures on the beam, a 3D arrow part, a bobbing
  arrow over the target.
  devforum.roblox.com/t/how-is-this-follow-the-arrows-system-made/297875 ·
  devforum.roblox.com/t/help-making-leading-arrows-for-a-tycoon/359098 (keep beams client-side) ·
  devforum.roblox.com/t/how-to-make-a-find-nearest-button-tycoon-feature/1980123 ·
  create.roblox.com/docs/samples
- **Example:** Tropical Resort Tycoon 2 has new players "follow the arrow icons" to the first button;
  early prices 40, 120, 250 (search excerpt only).
- **Roblox guidance:** onboarding is the first few minutes; get to the fun fast, keep early levels low,
  end onboarding with short, mid and long goals and a moment of joy; A/B the guide with Experiments.
  create.roblox.com/docs/production/game-design/onboarding
- **Benchmarks:** Roblox's example D1 band is 12.4% (median) to 24.1% (create.roblox.com/docs/production/analytics).
  The 2025 Roblox Benchmark Report (third party) ties D1 to session length: about 4% for 0 to 3 min
  sessions, 8% for 7 to 12, 10% for 13 to 18, double digits past 25 min
  (investgame.net/news/pdf/the-2025-roblox-benchmark-report/). A blog claim (rolearn.dev, no method):
  first placement within 30 s, each second of non-gameplay in the first 5 minutes costs 2 to 3%.
- **Gladiator RNG's own lesson** (its `docs/research/2026-10-21_first_session_rework.md`): the first
  live batch showed where players stopped only because every start step logged; 29% left during one
  step, which no model had predicted. Hence the funnel ships with the feature (its R23).

## 2. The simulation (`tools/sim_pacing.py`)
Reads the pads and keys from Config.luau and replays the server rules once per second. Styles:
active (walks to a pad in 6 s, sweeps orbs every 30 s, uses pills, recruits whenever a roll costs less
than the cheapest open pad), casual (15 s, every 2 min, pills, recruits below half a pad), idle (40 s,
no orbs, no pills, no recruits). Median of 20 runs, minutes since the first join.

| Milestone | active | casual | idle |
|---|---|---|---|
| first building | 0.3 | 0.4 | 0.8 |
| Main Hall (level 1) | 1.1 | 1.4 | 2.9 |
| Disciple Hall | 3.4 | 4.0 | 7.0 |
| first expansion | 7.1 | 6.9 | 10.4 |
| Celestial Palace | 11.0 | 11.0 | 18.6 |
| realm 2 (first breakthrough) | 11.0 | 11.0 | 20.6 |
| realm 3 | 15.1 | 18.4 | 64.2 |
| realm 4 | 22.3 | 31.5 | 174 |

Before this pass the breakthrough cost 45,000: idle reached realm 2 at 18.6 min, i.e. the pad was
bought within seconds of appearing. At 300,000 it takes the idle player about 2 minutes of saving.

**Sweep of the realm ratio** (only cost mult / income mult matters; everything else scales). Realm 3 and
realm 4, minutes, active / idle:

| cost x / income x per realm | realm 3 | realm 4 | idle realm 3 |
|---|---|---|---|
| 8 / 3 (today, ratio 2.7) | 15 | 22 | 64 |
| 12 / 3 or 8 / 2 (ratio 4) | 16 | 28 | 84 |
| 16 / 3 (ratio 5.3) | 17 | 39 | 104 |
| 24 / 3 (ratio 8) | 18 | 69 | 143 |

Why realm 2 is short in every row: disciples carry over, so realm 2 starts at income x3 x disciples
(about x6 for an active player) against costs x8. Rebirth games commonly make each run shorter (a
point from the tycoon study thread); the owner decides (Q3).

## 3. What the funnel measures
See TECH "Telemetry". The onboarding funnel steps are the simulated milestones, so the first live
batch can be read against the table above, and `FunnelTime` gives the minutes played at each step.
