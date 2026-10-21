# Backlog

Known gaps not yet in a brief. Delete a line when it is fixed.

## Performance
- Phone numbers for a full peak and the cloud overdraw A/B (`/perf`, `/clouds`) are not in yet.
- Pad price cards (`Build.client.luau`) rewrite text, colour and scale every 0.15 s: write only on a
  change (R16 rule 4) and add PerfMark "padcards".
- Streaming target radius: at the default every peak stays loaded on a phone (owner call: smaller =
  far peaks pop out).

## Look
- Our own skybox (the Creator Store one is a re-upload that could be moderated).
- Moon gate reads as a white cog wheel (ring corners stick out as teeth) and skewed from some angles.
- Name plaques are blank on every hall and the Sect Gate (visual check 2026-10-21, captures 27/28).
- About half the visible lawn on a full peak is bare earth: `paintGround` paints each part's
  grid-snapped box, bigger than the part (raycast count 49%, captures 27/29).
- Full-size island (r = 90) reads as a table top: the rock body stays ~0.77 x radius (capture 32).
- Kit (`Kit.luau`) is not yet used by the Peak Shrine, Library, Bell Tower, gates and pavilions.
- HUD: the disciples card is a panel (R4 says no panels); the far price card's feature line is ~8 px.
- Incense haze smears the courtyard; the Qi Array orb blows out to a white disc.

## Feel
- The music bed is not picked yet (DECISIONS Q1).

## Docs
- No doc gate script yet (Gladiator's `tools/check_docs.py` is the model).
