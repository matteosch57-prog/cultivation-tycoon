# Quit-risk audit, 2026-10-23 (integration at 9f45915, fixes in 9e19692 + e99a020)

Static read of every script (server, client, shared), selene (roblox std: 0 errors), `tools/check_playergui.py`
(0 findings), then a Studio Play on a fresh (mock) save: launch, Heavenly Gift, Daily Blessing day 2 twice,
character reset, a second Play. No script error or `[Tycoon]` warning in the log.

Not testable in Studio: a real rejoin on a stored save (Studio Play is the mock save), purchases, phone taps.

## Fixed (on integration)

| # | What a player would hit | Fix |
|---|---|---|
| 1 | Daily Blessing day 2 / day 7: a DataStore round trip turns the key `2` into the string `"2"`, so after any rejoin `got[2]` was never found and the Immortal / Celestial disciple was paid again every week instead of the 3 summons (checked in Studio: SetAsync then GetAsync gives `string:2`) | keys are strings; old saves converted on load. Play: day 2 again now pays 3 summons |
| 2 | Offline qi, idle-chest summons and the return screen lost when an autosave or a leftover receipt saved during the join's pass-check yield (`last` was stamped "now" before it was read) | `lastSeen` read before the session can save |
| 3 | A receipt retried on the same server returned Granted without a landed save: Robux lost if every later save failed | a re-seen receipt returns Granted only after a save lands |
| 4 | A receipt on join could be paid before the passes were known (half Qi for a 2x owner) | receipts wait for `s.ready` (end of join) |
| 5 | A failed pass check on join cost the owner the pass for the whole session, and buying again only says "already owned" | the failed checks are retried 10 s later, and a "not purchased" pass prompt re-checks ownership |
| 6 | VIP gold arch could stay on a peak after its owner left mid-join | flag set only while the owner is still there |
| 7 | One error in the income loop stopped qi, gifts, pills, orbs and every autosave for the whole server; one in the orb check stopped pad buying for all | each player's tick runs in a pcall |
| 8 | A pad build that errors took the qi and showed no next pads until a rejoin | onBuy in a pcall; next pads offered anyway |
| 9 | One avatar template that errors after creation hung every later disciple / worker of that look forever | post-processing in a pcall; waiters always woken |
| 10 | One worker rig missing a joint errored every frame for all workers | `Rig.chain` returns no reach |
| 11 | Tapping inside a card (a gift row, the realm plates, next to Rebirth's button) fell through to the veil and closed the screen | card bodies are Active (Gifts, Breakthrough, Rebirth, Odds, Index, Friends) |
| 12 | Disciples book: 10 tiles per row is wider than a 667 px phone page, edge columns cut | columns = what the page holds (4 to 10) |
| 13 | Breakthrough X inside the phone top bar | below `TopbarInset` like the other screens |

## Owner's calls (2026-10-23, built in 8475884, checked in Studio Play where marked)

1. A second Welcome Pouch / Starter Pack pays a Qi pack (`overLimit` in SHOP_PRODUCTS), never a second +10%.
2. Welcome / Starter offers count as made only when the card draws (`OfferShown`). Play: offer drew, stamped once.
3. A rejoin after a crash waits out the save lock behind the loading screen (SAVE_LOCK_WAITS 33 x 5 s > SAVE_LEASE; `SaveWait` attribute, Launch says why).
4. The HUD hides under every full screen (Disciples, Gifts, Daily Blessing, Breakthrough, Odds, return chest, Friends card). Play: hidden under Streak, Gifts, Welcome offer; back after closing.
5. A small X on the Heavenly Gift intro; the gift stays for next session. Play: X closes it, the HUD and the rest stop waiting.
6. The Altar knock check adds twice the player's ping (capped 1.5 s).
7. A Tide Bell rung during (or just before) an Altar round rings after it closes. Play: bell outside a round starts the tide.
8. The Daily Blessing waits until no other screen is open.
9. Peaks: the live place is already Max Players 6 (owner).

Not covered by Play: the receipt paths (Studio cannot buy), the crash-rejoin wait (mock save), a laggy phone at the altar.

## Open: smaller bugs, not fixed (need a Studio look or are low risk)

- Free Gifts X may sit over the first gift's Claim on 16:9 phones (667x375): needs a phone capture.
- Return chest: the server fires `idleChest` 3 s after load; a slow phone whose IdleChest script connects later never shows the screen (the qi is paid). Pull via an attribute.
- IdleChest card does not block taps (HUD and world live under it).
- Touch + keyboard devices (iPad with keyboard): HUD flips phone/PC scale whenever Roblox hides the jump button, losing toasts.
- Text at px(8) to px(9) (~8 px on phones): Index rarity ribbons, tile tags.
- Rank board can draw duplicate rows (two redraws across the headshot yield); Ranks keeps per-player tables forever.
- More than 31 Highlights (disciple rims + swords near a full platform): some rims vanish.
- Badges retry a failing award every second once ids are set (ids are 0 today).
- `/perf` only for `game.CreatorId`: if the place is group-owned, the owner can't record on the phone.
- Altar client text says "Hold it 20 s" instead of `Config.ALTAR_HOLD`.
- Place-only asset `rbxassetid://203785492` fails to load ("Asset type does not match"); not in `src`.
- Doc drift: docs/design/SECURITY.md still says the Reincarnate gate is `soulPeak + 1`; the code gates on `Config.rebirthOpen`.
