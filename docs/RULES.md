# Rules: invariants that must never break

Append only. Retire a rule by striking it through, never renumber. Cite by number (R3).

- **R1** Status lives only in [STATE.md](../STATE.md), [ROADMAP](ROADMAP.md) ticks, the active brief and git.
  Every other doc describes design or evidence.
- **R2** One home per fact (START_HERE table). The code wins: a doc that disagrees with the code is
  fixed in the same pass.
- **R3** No fake light in the scene: light comes from the sky or a visible lamp holding a real Light.
  Allowed exceptions (owner request): pad beacons and short event flashes.
- **R4** UI: every new screen or button gets a mock first. The HUD language is mock C (outlined
  Fredoka text, toy buttons, no panels). Never the generated look (accent stripes, framed icons, flat
  uniform cards). Player text is never cut (shrink instead) and never uses a dash inside a sentence.
- **R5** Mattéo commits and pushes, creates every Robux product and its price, uploads assets,
  publishes, and saves place-only edits (Ctrl+S). Never `git commit`/`push` unless he asks in the moment.
- **R6** Terrain: the map stands at world y = 2 (`BASE_Y`); grass cylinders are centred at world y = -4
  (FillCylinder snaps to the 4-stud grid). Ground-touching parts paint the earth under them.
- **R7** Studio sessions save to the `_studio` DataStore only (or nowhere, with `MOCK_DATASTORE` on). A
  Studio-only switch is gated on the flag AND `IsStudio()`, never the flag alone.
- **R8** Robux never buys a random reward. Recruits cost qi; their odds are shown in game.
- **R9** The server decides every purchase, grant and roll; clients only draw and play sounds.
- **R10** Never launch Roblox Studio yourself; no mouse input through the Studio MCP.
- **R11** No uploads to Mattéo's inventory without asking (no throwaway or iteration uploads).
- **R12** Creator Store models: delete every script on insert. Prefer Roblox-licensed library audio.
- **R13** Every new sound: measure its onset and loudness in Play before it ships.
- **R14** Separate project from Heavenly RNG and Gladiator RNG: own docs, vault folder and memory.
  It may port code patterns and cite lessons, never write status into their docs.
- **R15** After two failed attempts at a visual, stop and bring it back to Mattéo.
