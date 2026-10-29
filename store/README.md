# Store art: the picks

The kept icon and thumbnails for the Roblox store page. Upload from here (Creator Hub), nothing else.

- `icons/`: `icon_day.png` (the main one), `icon_night.png`. 512 x 512.
- `thumbnails/`: 1920 x 1080.
  - `day1_day100_high.png`, `day1_day100_wide.png`
  - `burst_<rarity>.png` and `burst_<rarity>_awaken.png` (Heavenly Emperor, Dao Ancestor, Celestial)
  - `flying_<rarity>.png` and `flying_<rarity>_ascend.png`
  - `cine_day_side.png` and `cine_dusk_disciples.png`: cinematic shots (realm 21, 4th life, every pad, 8 top disciples, no HUD)
  - `ad2_*.png` (ad round 2, 2026-10-29, all four in use): Day 1 / Day 100 mixed with the blue cultivator, which had the best
    click rate. `ad2_day1_day100_cultivator` (+ `_notext`), `ad2_day1_day100_bluesky`, `ad2_day1_day100_character`.
    Rebuild: `python tools/store_ads2.py` (needs Caladea Bold or Cambria Bold).

Everything else (research, every round of mocks, raw Studio captures, how to rebuild) is the work behind
these: `docs/research/2026-10-21_store_icons_thumbnails.md` and `docs/art/mocks/store/`.
