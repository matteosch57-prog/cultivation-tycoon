# START HERE: Cultivation Tycoon

A calm Roblox tycoon: build your cultivation sect on a floating peak, walk onto pads to raise halls and
towers, recruit disciples, break through realms. Built from code (parts + Luau), developed by AI;
Mattéo operates Studio, playtests, commits, publishes and owns every Robux product.

## Session boot (exactly 3 files, read nothing else)
1. This file.
2. [STATE.md](STATE.md): what is true right now and the single next action.
3. The ONE brief named in STATE.md (in `briefs/`).

Everything else is read on demand from the table below. Skim [docs/RULES.md](docs/RULES.md) once on a
cold start; afterwards cite rules by number.

## Where does a fact go? (one home per fact, R2)
| Kind of fact | Home | How it is updated |
|---|---|---|
| What is true right now, the next action | [STATE.md](STATE.md) | overwrite in place, 80 lines max |
| Milestones and their ticks | [docs/ROADMAP.md](docs/ROADMAP.md) | tick when built + checked |
| Invariants that must never break | [docs/RULES.md](docs/RULES.md) | append; retire by striking |
| A decision and its WHY; open questions | [docs/DECISIONS.md](docs/DECISIONS.md) | append-only; open forks at the top |
| How a system works (current design) | [docs/design/](docs/design/VISION.md) `<SYSTEM>.md` | edit in place |
| A number | `src/shared/Config.luau` (docs name the key) | never hand-copy a number into a doc |
| The look, palette, lighting recipe | [docs/art/ART_BIBLE.md](docs/art/ART_BIBLE.md) | edit in place |
| Captures and mocks | [docs/art/captures/](docs/art/captures/), [docs/art/mocks/](docs/art/mocks/) | add files |
| Evidence: research, playtests, stats | `docs/research/YYYY-MM-DD_topic.md` | write once; newer evidence = new file |
| Known gaps not yet in a brief | [docs/BACKLOG.md](docs/BACKLOG.md) | add; delete the line when fixed |
| A unit of work | `briefs/<ID>_<NAME>.md` | a work order that links the spec |

**Design files:** [VISION](docs/design/VISION.md) · [ECONOMY](docs/design/ECONOMY.md) ·
[FEEL](docs/design/FEEL.md) · [MONETIZATION](docs/design/MONETIZATION.md) · [TECH](docs/design/TECH.md).

## The contract
- **One brief at a time.** When it is done, everything it decided is already in `docs/`, ROADMAP is
  ticked and STATE.md is rewritten.
- **Status lives only in STATE.md, ROADMAP ticks, the active brief and git (R1).**
- **The code wins (R2).** A doc that disagrees with the code is fixed in the same pass.
- **Mattéo commits (R5).** Describe what changed; never commit or push unless he asks in the moment,
  and then stage surgically.
- **Verify it yourself first** (Studio Play through the MCP, captures), then hand Mattéo a short
  playtest script. Never launch Studio yourself (R10).
- **Sync:** `start-rojo.bat` serves `default.project.json` on port **34875**; connect from the Studio
  Rojo plugin ([TECH](docs/design/TECH.md) "Sync").
- Heavenly RNG ([`c:\Work\heavenly-rng`](../heavenly-rng/START_HERE.md)) and Gladiator RNG
  ([`c:\Work\gladiator-rng`](../gladiator-rng/START_HERE.md)) are separate projects: port patterns,
  cite lessons, never write this game's status into their docs (R14).
