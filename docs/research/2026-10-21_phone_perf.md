# Phone performance, first measurement (2026-10-21, B01 step 3)

Rung: Studio **Edit** on the owner's PC (no Play: two other sessions shared Studio). Draw calls and
triangles transfer to a phone; frame times do not (Gladiator RNG D671). The phone numbers come from
`/perf` (PerfLog) on the owner's phone and are not in yet.

## Where the cost is
A full peak (every building, Main Hall level 5), built by the real `Builders` at x = -2000:
- **7,186 parts but only 27 draw calls:** the renderer instances parts that share a shape and a
  material (colour is free). Part count is not the draw call problem.
- **~750k triangles** for one peak (the budget is ~500k for a whole scene). Measured per part, 100 of
  each on an empty sky: **Block 12, Cylinder 96, Ball 432 triangles**, the same through a SpecialMesh,
  at 80 or 300 studs (no distance detail drop for primitives).
- Small parts carry it: 1,264 balls under 1 stud (roof hip joints, curl tips, finials) = ~546k, and
  1,534 cylinders under 2 studs (hip rods, collars) = ~147k. Blocks: 52k.

## The swap (Lowpoly)
One low-poly mesh of each, cloned for every Ball under 2 studs and every Cylinder under 2 studs
across: ball 80 triangles (8 x 6 sphere), cylinder 36 (10 sides). Tested in Edit with EditableMesh
templates built from the same OBJ files (the live game needs uploaded ids: an EditableMesh made on the
server does not replicate).

| Camera | Draw calls | Triangles |
|---|---|---|
| Whole peak from the bridge side, before | 27 | 524k |
| Whole peak, after | 31 | 200k (-62%) |
| Courtyard toward the Main Hall, before | 26 | 226k |
| Courtyard, after | 30 | 138k (-39%) |

With the owner's uploaded meshes (Config ids, loaded through the real `Lowpoly` path): whole peak
**32 draw calls, 150k triangles (-71%)**, courtyard **30 / 75k (-67%)**; uploaded meshes get Roblox's
own distance detail levels, so they beat the EditableMesh test. Capture:
`docs/art/captures/2026-10-21_lowpoly_uploaded.jpg`.

Two rounds, same numbers. 2,810 of the 7,186 parts became MeshParts; clones of one mesh still
instance (+4 draw calls). Look: `docs/art/captures/2026-10-21_lowpoly_before.jpg` vs `_after.jpg`,
same camera on the Main Hall: no visible difference.

## Streaming (research, docs checked 2026-10-21)
- The place already has StreamingEnabled. The default StreamingTargetRadius is 1024 studs, and the
  peaks are 215 from the hub (430 apart at most), so **every peak stays streamed in**: streaming saves
  nothing today. A smaller target radius would drop far peaks on phones (a look change: owner call).
- SLIM / StreamingMesh imposters do not support models changed at runtime (our buildings are all
  built by the server), so far peaks cannot fall back to an imposter.
- Client scripts already use `DescendantAdded` / `FindFirstChild` on `Sect`, which survives
  streaming; any new client code must expect parts to leave and come back.

## Cloud overdraw
Not measurable on a PC (fill rate is a GPU cost of the phone). The cloud sea is 24 soft clouds of 3
particle layers (~35 big live particles each). `/clouds` hides them on the owner's screen so a `/perf`
recording can compare the same view with and without.

Sources: create.roblox.com/docs/performance-optimization/improve (instancing),
/docs/reference/engine/classes/EditableMesh and GenerationService (no replication),
/docs/workspace/streaming and /docs/workspace/streaming/slim.
