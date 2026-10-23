# Backlog

Known gaps not yet in a brief. Delete a line when it is fixed.

## Performance
- Phone numbers for a full peak and the cloud overdraw A/B (`/perf`, `/clouds`) are not in yet.
- Streaming target radius: at the default every peak stays loaded on a phone (owner call: smaller =
  far peaks pop out).

## Look
- Our own skybox (the Creator Store one is a re-upload that could be moderated).

## Cultivators
- Heavenly Emperor maiden robe (Chang'e Amber) reads pale gold, not orange: swap the id in `ROBES`.
- Robes and hair are other creators' catalog items: if one is taken down it goes missing until its id
  is replaced (`ROBES` / `LOOK` in `Cultivators.luau`).
- An uploaded meditation animation (owner uploads, R5) would replace the coded pose and breathing.
- Inner and Core ground sigils are faint at some angles over the light floor.

## Feel
- A full settings page (music, sounds, ambience volumes and more; owner 2026-10-23: "full setting page
  is missing, todo"). Mock first (R4). Today only Roblox's own menu volume.
- The music bed is not picked yet (DECISIONS Q1).
- HUD gift button: the prize picture on its corner (`ui.giftBadge`, 22 px) is hard to read; the name under it carries the prize. Try a bigger figure without the aura.

## Docs
- No doc gate script yet (Gladiator's `tools/check_docs.py` is the model).
