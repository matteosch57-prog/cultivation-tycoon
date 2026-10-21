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

## Feel
- The music bed is not picked yet (DECISIONS Q1).

## Docs
- No doc gate script yet (Gladiator's `tools/check_docs.py` is the model).
- HUD toasts still print amounts as words ("+3.6K Qi", "Gift +720 Qi", Qi pack and orb toasts in
  `Hud.client`): switch them to `Toy.amount` with the qi / karma icon (owner rule: every amount shows
  its currency icon). Rebase first; several threads edit Hud.client.
