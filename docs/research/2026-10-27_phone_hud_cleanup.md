# Phone HUD cleanup (2026-10-27)

Owner asked "isnt UI a bit messy?" looking at the phone HUD (captures in
docs/art/mocks/2026-10-27_missions_phone_*.png).

## What is messy now (phone)
- Left rail wraps into two uneven columns (Shop, Disciples, Karma | Friends, Settings): the band between
  the top bar and 72% of the screen is too short for 5 buttons with captions.
- Captions are mixed: "0/6" under Disciples, "+10%" under Friends, nothing under Shop/Karma/Settings.
- The missions line squeezes in beside the second column, mid-left.
- Top centre: "Teleport" ribbon + "Base", qi, "Ranks" all at different heights.
- Up to 4-5 red dots on screen at once (Friends, Shop, Disciples, Karma, gift), so none stands out.

## How top games do it
- Pet Simulator 99: one tidy column of same-size square buttons on the left, numbers as small badges on
  the button, currencies stacked at the left middle; quests/goals as one strip.
- Grow a Garden: the travel buttons as one row of pills at the top centre (Seeds / Sell / Garden), a short
  left column, currency at the bottom; very few labels, the middle of the screen stays clear.
- General Roblox mobile guidance (creation.dev UI best practices; DevForum "Some advice on UIs"): five or
  fewer always-on elements, combine related buttons instead of stacking many small ones, 44 px minimum
  touch target, status/currency in the top corners, keep clear of the thumbstick (it sits on a higher layer
  and steals taps), the same control in the same place in every menu.

## Mocks (phone only, PC unchanged)
Common to all three: every left button the same size, numbers as a small badge on the button instead of a
caption under it, at most ONE red dot on the HUD at a time (the most useful one), Base and Ranks the same
style at the top.
- A "One column" (Pet Sim 99): Shop, Disciples, Karma, Friends, Settings in one column; missions line to
  its right at the top.
- B "Top row" (Grow a Garden): the five buttons in one row under the Roblox top bar; missions line right
  under that row; the middle-left of the screen is empty.
- C "Fewer buttons": column of Shop, Disciples, Karma only; Friends and Settings become small round icons in
  the Roblox top bar line; missions line beside the column.
