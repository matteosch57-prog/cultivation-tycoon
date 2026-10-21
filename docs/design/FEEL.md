# Feel: sound, motion, light

The juice layer (D16). Reference: research on top Roblox clicker/tycoon games (2026-10-21): constant
small rewards, rewards fly to the counter, the most frequent sound is the quietest.

## Buying (src/client/Build.client.luau)
- Each pad: stone disc + jade inlay, green when affordable, red when not; a light beacon (beam, motes,
  pulsing ring) calls the player; beams fade when the camera is close.
- Price card: HUD style (outlined text, no panel): name, feature line, price; "Need X more" when
  standing on a pad you cannot afford.
- Guide trail (`Guide.client.luau`, D22): jade chevrons painted on the ground from the feet to the
  HUD's "Next:" pad, drifting toward it; always in realm 1 until `GUIDE_BUILT` buildings, then only
  after `GUIDE_IDLE` s standing still. Objects, not light (R3).
- Within 18 studs a jade hologram of the building fades in where it will stand.
- Buying: the pad sinks, coins + chime; the building rises bottom to top (Quint out), sparks, a warm
  light flash and a chime when it lands; a temple bell for a Main Hall level.

## Constant motion (src/client/Juice.client.luau)
- "+qi" floats off every earning building every 3 s (staggered).
- Orbs bob and spin; collecting one flies qi drops into the HUD counter, which bounces.
- Toy buttons grow on hover, squish on press, spring back.

## Sound (src/shared/Sfx.luau)
- All Roblox-licensed library audio (no uploads). Pools per sound, random pitch, SoundGroups SFX /
  Music / Ambience. Onsets and loudness measured in Play and trimmed (`from`, `vol`, `to`).
- Frequent sounds (click, toast) are the quietest layer; big ones (gong, thunder) only on rare events.
- Ambience: quiet birds + a positional waterfall loop. Music: 3 candidates, Workspace attribute
  `MusicTrack` switches live; the owner picks by ear.

## Light events
Recruit: a column in the rarity colour on the platform (taller for rarer). Expansion: a big column over
the peak. Pill: gold column around the player. Orb: a flash. Spirit Tide: a pale blue column over the peak and a soft gong.
