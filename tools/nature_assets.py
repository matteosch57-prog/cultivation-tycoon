"""Leaf-card tree assets (owner 2026-10-21, plan A; research 2026-10-21_nature).

Premium stylized trees on Roblox are leaf cards: a canopy mesh made of many small quads, each
showing a painted cluster of leaves with see-through edges, turned outward and given sphere
normals so the whole canopy shades like one soft round mass (DevForum "Ultimate Guide to Stylized
Trees", "Trying to make stylized trees correctly"). This script writes:

  art/meshes/canopy_round.obj   broadleaf canopy (sakura, ginkgo and maple share it)
  art/meshes/canopy_pine.obj    drooping tiers for the fir
  art/textures/leaves_<kind>.png 512 x 512 leaf clusters, alpha edges, colour bled into the
                                 transparent pixels (no dark fringe when mipmapped)
  art/preview/*.json            the same data for a Studio Edit preview (EditableMesh /
                                EditableImage), so nothing is uploaded until the owner picks

Usage: python tools/nature_assets.py
"""

import base64
import json
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "art")
TEX = 512
SS = 2  # supersampling for the painting


# ----------------------------------------------------------------------------------------------
# Textures
def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def rot(points, a, ox, oy, s):
    ca, sa = math.cos(a), math.sin(a)
    return [(ox + (x * ca - y * sa) * s, oy + (x * sa + y * ca) * s) for x, y in points]


def petal_blossom():
    """Five notched petals around a centre; returned as a list of polygons (petal by petal)."""
    polys = []
    for k in range(5):
        a = k * 2 * math.pi / 5
        pts = []
        for i in range(25):
            t = i / 24
            th = -0.55 + 1.1 * t
            r = 0.95 * math.cos(th * 1.3) ** 0.6
            if abs(th) < 0.1:
                r -= 0.1 * (1 - abs(th) / 0.1)  # the notch at the petal tip
            pts.append((math.sin(th) * r * 0.75, r))
        pts.append((0, 0.08))
        polys.append(rot(pts, a, 0, 0, 1))
    return polys


def ginkgo_leaf():
    pts = [(0, 0)]
    for i in range(41):
        th = math.radians(-55 + 110 * i / 40)
        r = 1.0 + 0.025 * math.sin(i * 0.6)
        if abs(th) < math.radians(5):
            r -= 0.12  # the split in the middle of the fan
        pts.append((math.sin(th) * r * 0.85, 0.3 + math.cos(th) * r * 0.75))
    return [pts]


def maple_leaf():
    pts = []
    for i in range(121):
        th = -math.pi + 2 * math.pi * i / 120
        f = ((th + math.pi / 2) * 5 / (2 * math.pi) + 0.5) % 1  # five lobes, pointed tips
        lobe = (1 - abs(f * 2 - 1)) ** 1.8
        r = 0.42 + 0.58 * lobe
        if abs(th + math.pi / 2) < 0.35:
            r *= 0.35  # the notch where the stem joins
        pts.append((math.cos(th) * r, 0.55 + math.sin(th) * r))
    return [pts]


def green_leaf():
    pts = []
    for i in range(31):
        t = i / 30
        w = math.sin(t * math.pi) ** 0.8 * 0.36
        pts.append((w, t))
    for i in range(30, -1, -1):
        t = i / 30
        w = math.sin(t * math.pi) ** 0.8 * 0.36
        pts.append((-w, t))
    return [pts]


def needle_sprig():
    """A stem with short needles both sides: thin quads."""
    polys = [[(-0.035, 0), (0.035, 0), (0.025, 1.2), (-0.025, 1.2)]]
    for i in range(16):
        y = 0.08 + i * 0.07
        ln = 0.5 * (1 - i / 22)
        for side in (-1, 1):
            a = side * math.radians(50 - i * 1.5)
            x2, y2 = math.sin(a) * ln, y + math.cos(a) * ln
            polys.append([(0, y - 0.035), (0, y + 0.035), (x2, y2 + 0.02), (x2, y2 - 0.02)])
    return polys


KINDS = {
    # base (deep, inside the cluster), tip (lit), edge (outline), shape, count, size
    "sakura": dict(deep="DE7C98", lit="FFEAF0", edge="B04D6C", centre="F7C95E", shape=petal_blossom, n=40, size=(0.13, 0.17)),
    "ginkgo": dict(deep="D4951A", lit="FFEC94", edge="A86E0C", shape=ginkgo_leaf, n=38, size=(0.14, 0.19)),
    "maple": dict(deep="C2412E", lit="FFAA6E", edge="8E2A20", shape=maple_leaf, n=36, size=(0.14, 0.19)),
    "green": dict(deep="3D7A45", lit="B7DE7E", edge="2C5A33", shape=green_leaf, n=44, size=(0.14, 0.2)),
    "pine": dict(deep="2B5A43", lit="A9D98F", edge="1D4031", shape=needle_sprig, n=42, size=(0.22, 0.3)),
}


def paint(kind, seed):
    spec = KINDS[kind]
    rng = random.Random(seed)
    W = TEX * SS
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    deep, lit, edge = hexc(spec["deep"]), hexc(spec["lit"]), hexc(spec["edge"])
    # a twig under the leaves
    twig = (92, 62, 48, 255)
    cx = cy = W / 2
    for _ in range(3):
        a = rng.uniform(0, 2 * math.pi)
        d.line([(cx, cy), (cx + math.cos(a) * W * 0.3, cy + math.sin(a) * W * 0.3)], fill=twig, width=int(W * 0.008))
    # leaves back to front: those painted later sit on top and are lighter (toward the light,
    # up and left), so the cluster carries its own little gradient
    items = []
    for _ in range(spec["n"]):
        r = W * 0.38 * math.sqrt(rng.random())
        a = rng.uniform(0, 2 * math.pi)
        x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        light = 0.5 + 0.5 * ((cx - x) + (cy - y)) / (W * 0.76)  # up-left is lit
        items.append((light + rng.uniform(-0.15, 0.15), x, y))
    items.sort()
    for light, x, y in items:
        t = max(0.0, min(1.0, light))
        fill = lerp(deep, lit, t * 0.85 + 0.1)
        s = W * rng.uniform(*spec["size"])
        ang = math.atan2(y - cy, x - cx) + math.pi / 2 + rng.uniform(-0.5, 0.5)
        for poly in spec["shape"]():
            pts = rot(poly, ang + math.pi, x, y, s)
            d.polygon(pts, fill=fill + (255,))  # no outline: outlines read as noise at a distance
        if kind == "sakura":
            c = hexc(spec["centre"])
            rr = s * 0.09
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=c + (255,))
        elif kind in ("maple", "green"):
            # a light midrib from the stem
            tip = rot([(0, 0.9)], ang + math.pi, x, y, s)[0]
            d.line([(x, y), tip], fill=lerp(fill, (255, 255, 255), 0.25) + (255,), width=max(1, int(s * 0.025)))
    img = img.resize((TEX, TEX), Image.LANCZOS)
    return bleed(img)


def bleed(img):
    """Hard alpha (no half-transparent fog) and the leaf colour carried into the transparent
    pixels, so filtering never pulls black into the edges (the "pixelfix" step)."""
    a = np.array(img).astype(np.float32)
    alpha = a[:, :, 3]
    solid = alpha > 110
    a[:, :, 3] = np.where(solid, 255, 0)
    rgb = a[:, :, :3] * solid[:, :, None]
    weight = solid.astype(np.float32)
    acc_rgb, acc_w = rgb.copy(), weight.copy()
    for _ in range(24):
        sr = np.zeros_like(acc_rgb)
        sw = np.zeros_like(acc_w)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sr += np.roll(acc_rgb, (dy, dx), (0, 1))
            sw += np.roll(acc_w, (dy, dx), (0, 1))
        empty = acc_w == 0
        fill = sw > 0
        upd = empty & fill
        acc_rgb[upd] = sr[upd] / sw[upd][:, None]
        acc_w[upd] = 1
    a[:, :, :3] = acc_rgb
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


# ----------------------------------------------------------------------------------------------
# Meshes: cards as quads, both faces, sphere normals from their blob's centre
def basis(n, spin):
    n = n / np.linalg.norm(n)
    up = np.array([0.0, 1.0, 0.0]) if abs(n[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(up, n)
    u /= np.linalg.norm(u)
    v = np.cross(n, u)
    c, s = math.cos(spin), math.sin(spin)
    return u * c + v * s, -u * s + v * c, n


def card(mesh, centre, normal, size, spin, shade_normal):
    u, v, n = basis(np.array(normal, dtype=float), spin)
    h = size / 2
    corners = [centre - u * h - v * h, centre + u * h - v * h, centre + u * h + v * h, centre - u * h + v * h]
    uvs = [(0, 1), (1, 1), (1, 0), (0, 0)]
    if random.random() < 0.5:
        uvs = [(1 - x, y) for x, y in uvs]  # mirror half the cards so the clusters don't repeat
    base = len(mesh["v"])
    sn = shade_normal / np.linalg.norm(shade_normal)
    for p, t in zip(corners, uvs):
        mesh["v"].append(tuple(p))
        mesh["vt"].append(t)
        mesh["vn"].append(tuple(sn))
    # both faces; the back face keeps the outward normal so it shades like the front
    mesh["f"].append((base, base + 1, base + 2))
    mesh["f"].append((base, base + 2, base + 3))
    mesh["f"].append((base, base + 2, base + 1))
    mesh["f"].append((base, base + 3, base + 2))


def round_canopy(seed, spread=2.3, tall=1.0, puffs=4):
    """Blobs of cards: one broad mass and puffs on its shoulders. `spread` = how far the puffs
    reach (a sakura spreads wide and flat), `tall` stretches it upward (a ginkgo is an upright oval)."""
    rng = np.random.default_rng(seed)
    random.seed(seed)
    mesh = {"v": [], "vt": [], "vn": [], "f": []}
    blobs = [((0, 0, 0), 3.2, 70)]
    for k in range(puffs):
        a = k * 2 * math.pi / puffs + rng.uniform(-0.4, 0.4)
        blobs.append(((math.cos(a) * spread, rng.uniform(-0.3, 0.9) * tall, math.sin(a) * spread), 2.2, 26))
    blobs.append(((0, 1.9 * tall, 0), 2.0, 22))
    if tall > 1.05:
        blobs.append(((0, 3.6 * tall, 0), 1.6, 18))
    centre_all = np.array([0, 0.3, 0.0])
    for c, r, n in blobs:
        c = np.array(c, dtype=float)
        for _ in range(n):
            d = rng.normal(size=3)
            d[1] *= 0.8 * tall
            d /= np.linalg.norm(d)
            pos = c + d * r * rng.uniform(0.55, 1.0)
            # shade like the whole canopy (one soft mass), face a little off the outward direction
            shade = pos - centre_all
            face = d + rng.normal(size=3) * 0.45
            card(mesh, pos, face, rng.uniform(2.2, 3.0), rng.uniform(0, 2 * math.pi), shade)
    return mesh


def pine_canopy(seed):
    rng = np.random.default_rng(seed)
    random.seed(seed)
    mesh = {"v": [], "vt": [], "vn": [], "f": []}
    tiers = 8  # owner 2026-10-21: "a bit more leafs" on the pine
    for i in range(tiers):
        u = i / (tiers - 1)
        y = u * 9.0
        rad = 4.2 * (1 - u * 0.82)
        n = int(36 * (1 - u * 0.6))
        for k in range(n):
            a = k / n * 2 * math.pi + rng.uniform(-0.2, 0.2)
            out = np.array([math.cos(a), 0, math.sin(a)])
            pos = np.array([0, y, 0]) + out * rad * rng.uniform(0.45, 0.95) + np.array([0, rng.uniform(-0.4, 0.4), 0])
            face = out * 0.6 + np.array([0, 0.75, 0]) + rng.normal(size=3) * 0.2  # tilted up, drooping out
            shade = pos - np.array([0, y - 1.5, 0])
            card(mesh, pos, face, rng.uniform(2.0, 2.6) * (1 - u * 0.35), a, shade)
    return mesh


def centre(mesh):
    """Move the canopy so its bounding box is centred on the origin (Roblox centres an uploaded
    mesh the same way, so the preview and the upload sit alike)."""
    v = np.array(mesh["v"])
    mid = (v.min(0) + v.max(0)) / 2
    mesh["v"] = [tuple(p) for p in (v - mid)]
    return mesh


def write_obj(path, mesh, name):
    lines = [f"# {name}: {len(mesh['f'])} triangles (leaf cards, both faces)"]
    lines += [f"v {x:.4f} {y:.4f} {z:.4f}" for x, y, z in mesh["v"]]
    lines += [f"vt {u:.4f} {v:.4f}" for u, v in mesh["vt"]]
    lines += [f"vn {x:.4f} {y:.4f} {z:.4f}" for x, y, z in mesh["vn"]]
    lines += ["f " + " ".join(f"{i + 1}/{i + 1}/{i + 1}" for i in f) for f in mesh["f"]]
    with open(path, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"{path}: {len(mesh['f'])} triangles")


def write_glb(path, mesh):
    """The same canopy as binary glTF: asphalt (Open Cloud) uploads .glb but not .obj."""
    import struct

    v, vt, vn, f = mesh["v"], mesh["vt"], mesh["vn"], mesh["f"]
    pos = b"".join(struct.pack("<3f", *x) for x in v)
    nor = b"".join(struct.pack("<3f", *(np.array(x) / np.linalg.norm(x))) for x in vn)
    uv = b"".join(struct.pack("<2f", u, 1 - w) for u, w in vt)  # glTF puts the uv origin top-left
    idx = b"".join(struct.pack("<3I", *t) for t in f)
    data = pos + nor + uv + idx
    mn = [float(min(x[i] for x in v)) for i in range(3)]
    mx = [float(max(x[i] for x in v)) for i in range(3)]
    off = [0, len(pos), len(pos) + len(nor), len(pos) + len(nor) + len(uv)]
    lens = [len(pos), len(nor), len(uv), len(idx)]
    gltf = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0, "name": os.path.splitext(os.path.basename(path))[0]}],
        "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3}]}],
        "buffers": [{"byteLength": len(data)}],
        "bufferViews": [{"buffer": 0, "byteOffset": off[i], "byteLength": lens[i], "target": 34963 if i == 3 else 34962} for i in range(4)],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(v), "type": "VEC3", "min": mn, "max": mx},
            {"bufferView": 1, "componentType": 5126, "count": len(vn), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(vt), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5125, "count": len(f) * 3, "type": "SCALAR"},
        ],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    data += b"\x00" * ((4 - len(data) % 4) % 4)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(data)))
        fh.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        fh.write(struct.pack("<II", len(data), 0x004E4942) + data)


def main():
    for sub in ("meshes", "textures", "preview"):
        os.makedirs(os.path.join(ROOT, sub), exist_ok=True)
    meshes = {
        "canopy_sakura": centre(round_canopy(11, spread=2.9, tall=0.75, puffs=5)),
        "canopy_ginkgo": centre(round_canopy(21, spread=1.8, tall=1.25, puffs=4)),
        "canopy_round": centre(round_canopy(31)),  # maple, and the bushes scaled down
        "canopy_pine": centre(pine_canopy(12)),
    }
    for name, m in meshes.items():
        write_obj(os.path.join(ROOT, "meshes", name + ".obj"), m, name)
        write_glb(os.path.join(ROOT, "meshes", name + ".glb"), m)
        with open(os.path.join(ROOT, "preview", name + ".json"), "w") as fh:
            json.dump({"v": m["v"], "vt": m["vt"], "vn": m["vn"], "f": m["f"]}, fh, separators=(",", ":"))
    sheet = Image.new("RGBA", (TEX * len(KINDS), TEX), (40, 40, 40, 255))
    for i, kind in enumerate(KINDS):
        img = paint(kind, 100 + i)
        img.save(os.path.join(ROOT, "textures", f"leaves_{kind}.png"))
        with open(os.path.join(ROOT, "preview", f"leaves_{kind}.json"), "w") as fh:
            json.dump({"w": TEX, "h": TEX, "rgba": base64.b64encode(img.tobytes()).decode()}, fh)
        sheet.alpha_composite(img, (i * TEX, 0))
        print(f"leaves_{kind}.png")
    sheet.convert("RGB").save(os.path.join(ROOT, "preview", "_leaf_sheet.jpg"), quality=90)


if __name__ == "__main__":
    main()
