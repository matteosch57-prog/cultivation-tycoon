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
- HUD: the disciples card is a panel (R4 says no panels); the far price card's feature line is ~8 px.

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
- HUD toasts still print amounts as words ("+3.6K Qi", "Gift +720 Qi", Qi pack and orb toasts in
  `Hud.client`): switch them to `Toy.amount` with the qi / karma icon (owner rule: every amount shows
  its currency icon). Rebase first; several threads edit Hud.client.
