# Backlog

Known gaps not yet in a brief. Delete a line when it is fixed.

## Performance
- Phone numbers for a full peak and the cloud overdraw A/B (`/perf`, `/clouds`) are not in yet.
- Streaming target radius: at the default every peak stays loaded on a phone (owner call: smaller =
  far peaks pop out).

## Look
- Our own skybox (the Creator Store one is a re-upload that could be moderated).
- Pad price cards are not AlwaysOnTop: Studio captures could not show AlwaysOnTop billboards.
- Moon gate arc reads skewed from some angles.

## Cultivators
- Heavenly Emperor maiden robe (Chang'e Amber) reads pale gold, not orange: swap the id in `ROBES`.
- Robes and hair are other creators' catalog items: if one is taken down it goes missing until its id
  is replaced (`ROBES` / `LOOK` in `Cultivators.luau`).
- An uploaded meditation animation (owner uploads, R5) would replace the coded pose and breathing.
- Inner and Core ground sigils are faint at some angles over the light floor.

## Feel
- The music bed is not picked yet (DECISIONS Q1).

## Docs
- No doc gate script yet (Gladiator's `tools/check_docs.py` is the model).
