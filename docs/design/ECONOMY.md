# Economy and progression

Every number lives in `src/shared/Config.luau`; this file names the keys and explains the shape.

## Qi
- Income per second = (`BASE_RATE` + sum of owned pads' `income`) x `incomeMult(realm)` x disciple bonus
  x 2 while a pill is active. Ticked on the server every second.
- Offline: income keeps flowing while away, capped at `OFFLINE_CAP` seconds.

## Pads (`Config.PADS`)
- A pad opens once `unlock` buildings are owned (any of them) and its `req` pads are owned. This keeps
  3 to 5 pads open at once so players choose (D11).
- Cost x `costMult(realm)`; income x `incomeMult(realm)`.
- Buying is a server position check every 0.1 s (`checkPads`), not `.Touched` (D10).
- Feature pads carry a `feature` line shown on the price card.

## The Main Hall
`mainhall1..5`: one building at the back centre, each level replaces the last (hut, sect hall, great
hall, palace with wings, gold celestial palace with towers). Only the highest owned level stands.

## Island expansions
`expand1`, `expand2` grow the island through `ISLAND_RADII`; the outer ring holds the variety buildings
(bamboo grove, training ground, bell tower, koi pond, library, moon gate, pagoda). A breakthrough
shrinks the island back.

## Features
- **Recruiting** (Disciple Hall): costs qi (`recruitCost`), rolls `RARITIES`. The best `maxDisciples`
  work; the rest rest until slots open. Never sold for Robux (RULES R8).
- **Disciple slots:** `MAX_DISCIPLES` + one per owned pad in `SLOT_PADS`.
- **Pill** (Alchemy Furnace): one brewed every `PILL_INTERVAL`; using it doubles qi/s for `PILL_DURATION`.
- **Qi orbs** (Qi Gathering Array): one every `ORB_INTERVAL`, up to `ORB_MAX`; worth `ORB_VALUE` seconds
  of income.

## Realms and breakthrough
All pads owned -> a gold breakthrough pad (`BREAKTHROUGH_COST` x `costMult`). Breaking through: realm + 1,
owned pads, qi and the pill reset; disciples stay. Names in `REALMS`.
