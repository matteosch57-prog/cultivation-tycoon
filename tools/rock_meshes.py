"""Write the four low-poly boulders that ring the round ponds (owner 2026-10-22, pick B).

"All water sources are rounds and ugly, use real small rocks for the round shape" (mock:
docs/art/mocks/2026-10-22_pond_rims.html). DevForum rock threads build rocks from rotated parts or
from a rock mesh; a mesh reads as a real stone and one uploaded mesh cloned many times draws
instanced, like the low-poly balls and the tree canopies.

Each rock is an icosahedron split once (80 triangles), its corners pushed in or out by a seeded
random amount (shared corners move together, so the faces stay closed), squashed to sit low, then
fitted to the unit box (-0.5..0.5 on every axis) so a MeshPart's Size is the rock's size. Normals
are per face: the facets catch the light like cut stone.

Usage: python tools/rock_meshes.py
  writes art/meshes/rock_1.obj .. rock_4.obj (the owner uploads them, ids in Config.ROCK_MESH)
  and art/preview/rocks.json (the same data, for a Studio preview through EditableMesh)
"""

import json
import math
import os
import random

ART = os.path.join(os.path.dirname(__file__), "..", "art")
SEEDS = (11, 23, 37, 41)
SQUASH = 0.72  # height / width before the box fit: rocks lie, they do not stand


def icosphere():
    t = (1 + math.sqrt(5)) / 2
    v = [(-1, t, 0), (1, t, 0), (-1, -t, 0), (1, -t, 0), (0, -1, t), (0, 1, t), (0, -1, -t), (0, 1, -t),
         (t, 0, -1), (t, 0, 1), (-t, 0, -1), (-t, 0, 1)]
    v = [tuple(c / math.sqrt(sum(x * x for x in p)) for c in p) for p in v]
    f = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4), (11, 10, 2),
         (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8), (3, 8, 9), (4, 9, 5),
         (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]
    mid = {}

    def m(a, b):
        k = (min(a, b), max(a, b))
        if k not in mid:
            p = [(v[a][i] + v[b][i]) / 2 for i in range(3)]
            n = math.sqrt(sum(c * c for c in p))
            v.append(tuple(c / n for c in p))
            mid[k] = len(v) - 1
        return mid[k]

    out = []
    for a, b, c in f:
        ab, bc, ca = m(a, b), m(b, c), m(c, a)
        out += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    return v, out


def rock(seed):
    rng = random.Random(seed)
    v, f = icosphere()
    v = [(x * s, y * s * SQUASH, z * s) for (x, y, z), s in ((p, rng.uniform(0.78, 1.16)) for p in v)]
    lo = [min(p[i] for p in v) for i in range(3)]
    hi = [max(p[i] for p in v) for i in range(3)]
    v = [tuple((p[i] - (lo[i] + hi[i]) / 2) / (hi[i] - lo[i]) for i in range(3)) for p in v]
    normals = []
    for a, b, c in f:
        u = [v[b][i] - v[a][i] for i in range(3)]
        w = [v[c][i] - v[a][i] for i in range(3)]
        n = (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])
        k = math.sqrt(sum(x * x for x in n)) or 1
        n = tuple(x / k for x in n)
        centre = [sum(v[j][i] for j in (a, b, c)) for i in range(3)]
        if sum(n[i] * centre[i] for i in range(3)) < 0:  # wind every face outward
            n = tuple(-x for x in n)
        normals.append(n)
    faces = []
    for (a, b, c), n in zip(f, normals):
        u = [v[b][i] - v[a][i] for i in range(3)]
        w = [v[c][i] - v[a][i] for i in range(3)]
        cr = (u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0])
        faces.append((a, b, c) if sum(cr[i] * n[i] for i in range(3)) > 0 else (a, c, b))
    return v, normals, faces


def main():
    os.makedirs(os.path.join(ART, "meshes"), exist_ok=True)
    os.makedirs(os.path.join(ART, "preview"), exist_ok=True)
    preview = []
    for k, seed in enumerate(SEEDS, 1):
        v, n, f = rock(seed)
        name = f"rock_{k}.obj"
        lines = [f"# {name}: {len(f)} triangles, unit box centred on the origin (tools/rock_meshes.py)"]
        lines += [f"v {x:.5f} {y:.5f} {z:.5f}" for x, y, z in v]
        lines += [f"vn {x:.5f} {y:.5f} {z:.5f}" for x, y, z in n]
        lines += [f"f {a + 1}//{i + 1} {b + 1}//{i + 1} {c + 1}//{i + 1}" for i, (a, b, c) in enumerate(f)]
        with open(os.path.join(ART, "meshes", name), "w", newline="\n") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"art/meshes/{name}: {len(f)} triangles")
        preview.append({"v": [[round(c, 5) for c in p] for p in v], "f": [list(t) for t in f]})
    with open(os.path.join(ART, "preview", "rocks.json"), "w", newline="\n") as fh:
        json.dump(preview, fh, separators=(",", ":"))
    print("art/preview/rocks.json")


if __name__ == "__main__":
    main()
