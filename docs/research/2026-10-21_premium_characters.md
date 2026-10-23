# Premium disciple characters: research and mocks (2026-10-21)

Owner ask: "deep search about these type of characters in those games, animation and faces, something
premium, 3 mocks". Tags: [SRC] a page read, [SNIPPET] a search summary, [KNOWLEDGE] unverified.

## Findings
- No write-up explains how Anime Defenders / Vanguards / ALS / Blox Fruits / GPO build their characters;
  [KNOWLEDGE] unit games use custom anime-proportioned rigs, combat RPGs keep R15 avatars and sell power
  with VFX and custom animation. What reads premium: ONE cohesive style, a strong silhouette (big hair,
  flowing robes), never the stock idle, rarity VFX.
- Faces: FaceControls on a dynamic head can be driven from a client script (blink = LeftEyeClosed /
  RightEyeClosed) [SRC] https://create.roblox.com/docs/reference/engine/classes/FaceControls; NPCs get no
  idle face animation on their own [SRC] https://devforum.roblox.com/t/2579192.
- Animation: since 2025-07-31 an experience can play another creator's animation only if granted
  permission [SRC] https://devforum.roblox.com/t/improving-animation-asset-permissions/3852101; a catalog
  emote's id is not its animation id [SNIPPET]. Client-side procedural motion for static NPCs is the
  documented cheap path [SRC] https://create.roblox.com/docs/performance-optimization/improve.
- Highlight: limit is now 255 on the client; the first on screen costs up to ~1 ms GPU on mobile [SRC]
  https://create.roblox.com/docs/effects/highlighting.
- Catalog finds: "Anime Black" dynamic head (14506610025), Cultivator's Hair set (black 10945619882 /
  11639642608, white 12373799299), cultivator props (sword 10070649892, flute 10070641659, fan
  15197091452, guqin 10070655361), a "Meditation" body bundle 352387, UGC meditation emotes (not usable
  on NPCs without the creator's permission).

## Mocks (Studio Edit captures, `docs/art/mocks/characters_A..C.jpg`)
All three use a new seated pose: hands meet in the lap (meditation mudra) instead of resting on the knees.
- A Anime disciples: one anime head for everyone, the cultivator hair set, a signature prop each.
- B Serene masters: today's heads with eyes closed and a faint smile (FaceControls), a calm look.
- C Radiant immortals: a rarity-coloured rim glow (Highlight) and paper talismans floating around each.
