"""Write the two low-poly meshes that replace small Ball and Cylinder parts (B01 step 3).

A Roblox Ball part draws 432 triangles and a Cylinder 96 (measured in Studio, 2026-10-21), and a
full peak has ~1,260 balls and ~1,500 cylinders under 2 studs (roof hip rods and their joints).
These meshes fill the same box as the part (-0.5..0.5 on every axis), the cylinder runs along X
like a Roblox Cylinder part, so a MeshPart of the same Size and CFrame is a drop-in swap.

Usage: python tools/lowpoly_meshes.py   (writes art/meshes/*.obj; the owner uploads them)
"""

import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "meshes")
BALL_SEGMENTS, BALL_RINGS = 8, 6  # 8 * 4 * 2 + 2 * 8 = 80 triangles
CYL_SIDES = 10  # 10 * 2 sides + 2 * 8 caps = 36 triangles


def write_obj(name, verts, normals, faces):
    path = os.path.join(OUT, name)
    lines = [f"# {name}: {len(faces)} triangles, unit box centred on the origin"]
    lines += [f"v {x:.6f} {y:.6f} {z:.6f}" for x, y, z in verts]
    lines += [f"vn {x:.6f} {y:.6f} {z:.6f}" for x, y, z in normals]
    # faces: tuples of (vertex index, normal index), 0-based here, 1-based in OBJ
    lines += ["f " + " ".join(f"{v + 1}//{n + 1}" for v, n in f) for f in faces]
    with open(path, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"{path}: {len(faces)} triangles")
    return len(faces)


def ball():
    verts, normals, faces = [], [], []
    verts.append((0, 0.5, 0))
    normals.append((0, 1, 0))
    for r in range(1, BALL_RINGS):
        phi = math.pi * r / BALL_RINGS
        for s in range(BALL_SEGMENTS):
            th = 2 * math.pi * s / BALL_SEGMENTS
            n = (math.sin(phi) * math.cos(th), math.cos(phi), math.sin(phi) * math.sin(th))
            normals.append(n)
            verts.append(tuple(c * 0.5 for c in n))
    verts.append((0, -0.5, 0))
    normals.append((0, -1, 0))
    bottom = len(verts) - 1

    def ring(r, s):
        return 1 + (r - 1) * BALL_SEGMENTS + s % BALL_SEGMENTS

    for s in range(BALL_SEGMENTS):  # counter-clockwise seen from outside
        a, b = ring(1, s), ring(1, s + 1)
        faces.append(((0, 0), (b, b), (a, a)))
    for r in range(1, BALL_RINGS - 1):
        for s in range(BALL_SEGMENTS):
            a, b = ring(r, s), ring(r, s + 1)
            c, d = ring(r + 1, s), ring(r + 1, s + 1)
            faces.append(((a, a), (b, b), (d, d)))
            faces.append(((a, a), (d, d), (c, c)))
    for s in range(BALL_SEGMENTS):
        a, b = ring(BALL_RINGS - 1, s), ring(BALL_RINGS - 1, s + 1)
        faces.append(((bottom, bottom), (a, a), (b, b)))
    return write_obj("ball_lowpoly.obj", verts, normals, faces)


def cylinder():
    # axis along X (a Roblox Cylinder part's axis), radius 0.5, length 1
    verts, normals, faces = [], [], []
    for x in (-0.5, 0.5):
        for s in range(CYL_SIDES):
            th = 2 * math.pi * s / CYL_SIDES
            verts.append((x, 0.5 * math.cos(th), 0.5 * math.sin(th)))
    for s in range(CYL_SIDES):  # smooth side normals
        th = 2 * math.pi * s / CYL_SIDES
        normals.append((0, math.cos(th), math.sin(th)))
    normals.append((-1, 0, 0))
    normals.append((1, 0, 0))
    nl, nr = CYL_SIDES, CYL_SIDES + 1
    for s in range(CYL_SIDES):
        s1 = (s + 1) % CYL_SIDES
        a, b = s, s1  # left ring
        c, d = CYL_SIDES + s, CYL_SIDES + s1  # right ring
        faces.append(((a, s), (b, s1), (d, s1)))
        faces.append(((a, s), (d, s1), (c, s)))
    for s in range(1, CYL_SIDES - 1):  # caps as fans, facing outward
        faces.append(((0, nl), (s + 1, nl), (s, nl)))
        faces.append(((CYL_SIDES, nr), (CYL_SIDES + s, nr), (CYL_SIDES + s + 1, nr)))
    return write_obj("cylinder_lowpoly.obj", verts, normals, faces)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ball()
    cylinder()
