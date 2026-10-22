# Player auras by realm and lives (2026-10-22)

Owner ask: "we should give the user auras based on realms and or reincarnation. May you mock that?"

## The game we copy: Super Power Fighting Simulator

Its aura is the standard rank aura of fighting simulators
([wiki](https://super-power-fighting-simulator.fandom.com/wiki/Auras)):

- Nobody buys it. It appears on its own from the second rank (F-Class has none, E-Class is white)
  and evolves at every rank after that.
- Each rank has its own colour, and the shape grows in steps: a plain glow first, then two-tone
  arms and body, then bubbles, lightning and smoke, and at the top galaxies and nebulae.
- Players can turn other players' auras down or off in settings (Low/High, hide others).

## What we already have, and what stays separate

- The status title over every head already shows the realm (in `Config.realmColor`) and, from life 2,
  "Nth Life". The aura reuses that same colour, so the title and the aura say the same thing.
- The altar winner wears a gold rim light (a Highlight plus gold sparkles, D-altar W3). The player
  aura uses no Highlight, so the winner stays unmistakable.
- No paid player aura exists in the Shop. Paid auras belong to disciples (the Elder in the Welcome
  Pouch and the rarity products), so an earned player aura takes no paid value away.
- Realm resets on rebirth (D63). An aura that follows only the realm drops back to nothing every
  rebirth, which is why B and C exist.

## The three mocks (`tools/mock_player_auras.luau`, `src/server/PlayerAura.luau`)

Steps for all: realm or life 1 none, then wisps rising from a ring at the feet, flames up the
body from step 3, twinkling sparks round the body from step 5, every layer larger and denser up to step 9.

- **A Realm aura** (Super Power Fighting Simulator as it is): the aura follows the current realm.
  Gone again after a rebirth until the player climbs back.
- **B Realm aura + life beads**: A, plus one gold bead per rebirth on a halo behind the head,
  kept forever (up to 9).
- **C Life aura**: the aura grows with lives instead of realms (life 2 wisps, and so on), in the
  disciple rarity colour of that life. Never lost, but nothing changes during a life.

Budget: at most 3 particle emitters a player and ~60 live particles at the top step; neon beads only, no Light (R3).
