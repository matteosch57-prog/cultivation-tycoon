"""Sky Islets layout (D42): islets, lobes, every building, then the neighbour and spacing checks;
then spots for bridges, paths, groves, hire and shop pads. ISLETS / LOBES below mirror
Config.ISLETS / ISLAND_LOBES (edit both). Usage: python tools/islet_layout.py src/shared/Config.luau out.json
Prints the gaps; writes out.json (building spots) and out_extras.json. Copy the numbers into Config by hand."""
import math, re, sys, json

src = open(sys.argv[1], encoding="utf-8").read()
pads = []
for m in re.finditer(r'\{ id = "(\w+)", name = "([^"]+)", cost = (\d+), income = (\d+), unlock = (\d+), req = \{([^}]*)\}, x = (-?[\d.]+), z = (-?[\d.]+)(.*?)\},?\n', src):
    d = re.search(r'district = "(\w+)"', m.group(9))
    pads.append(dict(id=m.group(1), cost=int(m.group(3)), unlock=int(m.group(5)), req=re.findall(r'"(\w+)"', m.group(6)),
                     x=float(m.group(7)), z=float(m.group(8)), district=d.group(1) if d else None))
pads = [p for p in pads if not p["id"].startswith(("bridge_", "path_", "grove_"))]
byid = {p["id"]: p for p in pads}

# islets: x, z, r; bridge = (from islet, pad id)
ISLETS = {
    "heart": dict(x=0, z=0, r=66),
    "fields": dict(x=-124, z=-60, r=54, frm="heart"),
    "dao": dict(x=126, z=-64, r=56, frm="heart"),
    "disciples": dict(x=-100, z=-172, r=44, frm="fields"),
    "summit": dict(x=44, z=-140, r=44, frm="dao"),
}
LOBES = [
    dict(islet="fields", dx=-30, dz=-34, r=28, exp=1),
    dict(islet="disciples", dx=-30, dz=-34, r=24, exp=1),
    dict(islet="dao", dx=28, dz=-44, r=32, exp=2),
    dict(islet="summit", dx=0, dz=-38, r=26, exp=2),
]
SUMMIT = {"pagoda1", "pagoda2", "library", "bell", "moongate"}
def islet_of(p):
    if p["id"] in SUMMIT: return "summit"
    if p["id"].startswith("mainhall") or p["district"] in (None, "heart"): return "heart"
    return p["district"]
def exp_of(p):
    seen, todo, lvl = set(), [p["id"]], 0
    while todo:
        i = todo.pop()
        if i in seen: continue
        seen.add(i)
        if i == "expand1": lvl = max(lvl, 1); continue
        if i == "expand2": lvl = max(lvl, 2); continue
        if i in byid: todo += byid[i]["req"]
    return lvl

SIZE = dict(garden=10, garden2=10, garden3=10, vein1=6, vein2=6, vein3=6, furnace=8, hall=11, quarters1=9, quarters2=11,
            bamboo=11, training=12, bell=7, koi=8, library=15, moongate=9, pagoda1=8, pagoda2=8, array=9, tea1=9, tea2=9,
            firelotus1=8, firelotus2=8, jade1=8, jade2=8, jade3=8, thunder1=8, thunder2=8, spring1=8, spring2=8)

def bridge_dir(name):
    i = ISLETS[name]
    f = ISLETS[i["frm"]]
    dx, dz = f["x"] - i["x"], f["z"] - i["z"]
    d = math.hypot(dx, dz)
    return dx / d, dz / d, d

placed = {}
fixed = {}
# heart: keep today's spots (avenue, gate, lanterns, platform, Main Hall)
for p in pads:
    if islet_of(p) == "heart" and not p["id"].startswith("expand"):
        fixed[p["id"]] = (p["x"], p["z"])

def land_points(name, lvl_max):
    i = ISLETS[name]
    pts = []
    for gx in range(-80, 81, 2):
        for gz in range(-80, 81, 2):
            x, z = i["x"] + gx, i["z"] + gz
            inside = None
            if math.hypot(gx, gz) < i["r"]: inside = 0
            for l in LOBES:
                if l["islet"] == name and math.hypot(gx - l["dx"], gz - l["dz"]) < l["r"]:
                    inside = l["exp"] if inside is None else min(inside, l["exp"])
            if inside is not None and inside <= lvl_max:
                pts.append((x, z, inside))
    return pts

def edge_dist(name, x, z, lvl):
    # distance to the edge of the land of exp level <= lvl
    i = ISLETS[name]
    best = i["r"] - math.hypot(x - i["x"], z - i["z"])
    for l in LOBES:
        if l["islet"] == name and l["exp"] <= lvl:
            best = max(best, l["r"] - math.hypot(x - i["x"] - l["dx"], z - i["z"] - l["dz"]))
    return best

# keep the roads clear (Builders islandPath): landing -> hub (35% in) -> each outgoing bridge foot
def seg_dist(px, pz, ax, az, bx, bz):
    vx, vz = bx - ax, bz - az
    t = max(0, min(1, ((px - ax) * vx + (pz - az) * vz) / (vx * vx + vz * vz)))
    return math.hypot(px - ax - vx * t, pz - az - vz * t)
def roads(name):
    i = ISLETS[name]
    segs = []
    hub = (i["x"], i["z"])
    if "frm" in i:
        f = ISLETS[i["frm"]]
        dx, dz = f["x"] - i["x"], f["z"] - i["z"]
        d = math.hypot(dx, dz)
        land = (i["x"] + dx / d * i["r"], i["z"] + dz / d * i["r"])
        hub = (i["x"] + (land[0] - i["x"]) * 0.35, i["z"] + (land[1] - i["z"]) * 0.35)
        segs.append((land, hub))
    for k, j in ISLETS.items():
        if j.get("frm") == name:
            dx, dz = j["x"] - i["x"], j["z"] - i["z"]
            d = math.hypot(dx, dz)
            foot = (i["x"] + dx / d * i["r"], i["z"] + dz / d * i["r"])
            segs.append((hub, foot))
    return segs
def corridor(name, x, z, s=0):
    return any(seg_dist(x, z, a[0], a[1], b[0], b[1]) < s + 3.5 for a, b in roads(name))
def corridor_out(name, x, z, s=0):
    return False

for name in ("fields", "dao", "disciples", "summit"):
    group = [p for p in pads if islet_of(p) == name and p["id"] != "pagoda2"]
    group.sort(key=lambda p: -SIZE.get(p["id"], 8))
    here = []
    for p in group:
        lvl = exp_of(p)
        s = SIZE.get(p["id"], 8)
        best, bp = -1e9, None
        for x, z, lv in land_points(name, lvl):
            e = edge_dist(name, x, z, lvl) - s - 3
            if e < 0 or corridor(name, x, z, s):
                continue
            gap = min([math.hypot(x - qx, z - qz) - s - qs for qx, qz, qs in here] + [e * 2.2])
            # base pads prefer the base disc; lobe pads prefer their lobe
            score = gap + (6 if lv == lvl else 0)
            if score > best:
                best, bp = score, (x, z)
        if bp is None:
            print("NO SPOT", p["id"]); continue
        here.append((bp[0], bp[1], s))
        placed[p["id"]] = bp

# relax: push overlapping buildings apart, keep them on their land and off the roads
import random
random.seed(3)
for it in range(400):
    moved = False
    for name in ("fields", "dao", "disciples", "summit"):
        ids = [k for k in placed if islet_of(byid[k]) == name]
        for a in ids:
            ax, az = placed[a]; sa = SIZE.get(a, 8); lvl = exp_of(byid[a])
            fx = fz = 0
            for b in ids:
                if b == a: continue
                bx, bz = placed[b]; sb = SIZE.get(b, 8)
                d = math.hypot(ax - bx, az - bz) or 0.01
                over = sa + sb + 5 - d
                if over > 0:
                    fx += (ax - bx) / d * over; fz += (az - bz) / d * over
            if fx or fz:
                nx, nz = ax + fx * 0.3, az + fz * 0.3
                if edge_dist(name, nx, nz, lvl) - sa - 2 >= 0 and not corridor(name, nx, nz, sa):
                    placed[a] = (round(nx, 1), round(nz, 1)); moved = True
                else:
                    # try sliding sideways
                    for ang in range(0, 360, 30):
                        tx, tz = ax + math.cos(math.radians(ang)) * 1.5, az + math.sin(math.radians(ang)) * 1.5
                        if edge_dist(name, tx, tz, lvl) - sa - 2 >= 0 and not corridor(name, tx, tz, sa):
                            cur = min([math.hypot(ax - placed[b][0], az - placed[b][1]) - sa - SIZE.get(b, 8) for b in ids if b != a])
                            new = min([math.hypot(tx - placed[b][0], tz - placed[b][1]) - sa - SIZE.get(b, 8) for b in ids if b != a])
                            if new > cur:
                                placed[a] = (round(tx, 1), round(tz, 1)); moved = True; break
    if not moved: break
pos = dict(fixed); pos.update(placed)
pos["pagoda2"] = pos["pagoda1"]

# neighbours: peaks on a ring of PLOT_RADIUS, +Z of each frame faces the hub
def reach_ok(R, plot_count=6):
    shapes = [(i["x"], i["z"], i["r"]) for i in ISLETS.values()]
    shapes += [(ISLETS[l["islet"]]["x"] + l["dx"], ISLETS[l["islet"]]["z"] + l["dz"], l["r"]) for l in LOBES]
    shapes += [(55, 122, 28)]  # shop island
    a = 2 * math.pi / plot_count
    # world of plot 0: centre (R,0), frame looking at hub => +Z points to -X world
    def world(k, x, z):
        ang = k * a
        cx, cz = R * math.cos(ang), R * math.sin(ang)
        fz = (-math.cos(ang), -math.sin(ang))  # +Z toward hub
        fx = (-fz[1], fz[0])
        return cx + fx[0] * x + fz[0] * z, cz + fx[1] * x + fz[1] * z
    worst = 1e9
    for (x0, z0, r0) in shapes:
        p = world(0, x0, z0)
        for (x1, z1, r1) in shapes:
            q = world(1, x1, z1)
            worst = min(worst, math.hypot(p[0] - q[0], p[1] - q[1]) - r0 - r1)
        worst = min(worst, math.hypot(*p) - r0 - 36)  # hub
    return worst

for R in (280,):
    print("PLOT_RADIUS", R, "min gap to a neighbour / hub", round(reach_ok(R), 1))

# spacing report
ids = [k for k in pos if not (k.startswith("mainhall") and k != "mainhall5")]
gaps = []
for a in ids:
    if islet_of(byid[a]) == "heart": continue
    sa = SIZE.get(a, 8)
    g = min(math.hypot(pos[a][0] - pos[b][0], pos[a][1] - pos[b][1]) - sa - SIZE.get(b, 8) for b in ids if b != a)
    gaps.append((round(g, 1), a))
gaps.sort()
print("tightest gaps", gaps[:6])
print("median gap", gaps[len(gaps) // 2])
for name in ISLETS:
    if "frm" in ISLETS[name]:
        ux, uz, d = bridge_dir(name)
        print("bridge", name, "span", round(d - ISLETS[name]["r"] - ISLETS[ISLETS[name]["frm"]]["r"], 1))
json.dump(dict(ISLETS=ISLETS, LOBES=LOBES, pos=pos, islet={p["id"]: islet_of(p) for p in pads}), open(sys.argv[2], "w"), indent=1)


# ---- extras: spots for bridges, paths, groves, hire and shop pads (run after the layout) ----
"""Spots for the new pads (bridges, paths, groves), hire pads and shop pads on the islet layout."""
import json, math
d = json.load(open(sys.argv[2]))
I, L, pos, islet = d["ISLETS"], d["LOBES"], d["pos"], d["islet"]
SIZE = dict(garden=10, garden2=10, garden3=10, vein1=6, vein2=6, vein3=6, furnace=8, hall=11, quarters1=9, quarters2=11,
            bamboo=11, training=12, bell=7, koi=8, library=15, moongate=9, pagoda1=8, pagoda2=8, array=9, tea1=9, tea2=9,
            platform=13, gate=8, path=4, lanterns=4)
occupied = []
for k, (x, z) in pos.items():
    if k.startswith("mainhall"):
        continue
    occupied.append((x, z, SIZE.get(k, 8), k))
occupied.append((0, -36, 24, "mainhall"))  # the level 5 hall's wings
for zz in range(10, 60, 6):
    occupied.append((0, zz, 5, "avenue"))

def on_land(name, x, z, margin, lvl=0):
    i = I[name]
    if math.hypot(x - i["x"], z - i["z"]) < i["r"] - margin:
        return True
    return any(l["islet"] == name and l["exp"] <= lvl and math.hypot(x - i["x"] - l["dx"], z - i["z"] - l["dz"]) < l["r"] - margin for l in L)

def free(x, z, s):
    return min([math.hypot(x - ox, z - oz) - os - s for ox, oz, os, _ in occupied] + [99])

def best_near(name, tx, tz, s, maxd=30, lvl=0, want=3):
    best, bp = -1e9, None
    for dx in range(-maxd, maxd + 1, 2):
        for dz in range(-maxd, maxd + 1, 2):
            x, z = tx + dx, tz + dz
            if not on_land(name, x, z, s + 2, lvl):
                continue
            f = free(x, z, s)
            if f < want:
                continue
            score = -math.hypot(dx, dz) + min(f, 8) * 0.5
            if score > best:
                best, bp = score, (x, z)
    return bp

out = {}
def put(key, p, s):
    out[key] = p
    occupied.append((p[0], p[1], s, key))

# bridge pads: on the "from" islet, 7 studs inside its rim, facing the target
for name, i in I.items():
    if "frm" not in i:
        continue
    f = I[i["frm"]]
    dx, dz = i["x"] - f["x"], i["z"] - f["z"]
    dd = math.hypot(dx, dz)
    ux, uz = dx / dd, dz / dd
    p = (round(f["x"] + ux * (f["r"] - 8)), round(f["z"] + uz * (f["r"] - 8)))
    put("bridge_" + name, p, 4)
    out["landing_" + name] = (round(i["x"] - ux * i["r"], 1), round(i["z"] - uz * i["r"], 1))
    out["foot_" + name] = (round(f["x"] + ux * f["r"], 1), round(f["z"] + uz * f["r"], 1))

# paths: the pad sits a few studs inside each landing (heart: the plaza ring, beside the platform)
for name, i in I.items():
    if name == "heart":
        p = best_near("heart", -20, 8, 3)
    else:
        lx, lz = out["landing_" + name]
        p = best_near(name, (lx * 2 + i["x"]) / 3, (lz * 2 + i["z"]) / 3, 3, 20)
    put("path_" + name, p, 3)

# groves: the emptiest spot on each islet's base disc
for name, i in I.items():
    best, bp = -1e9, None
    for gx in range(-70, 71, 2):
        for gz in range(-70, 71, 2):
            x, z = i["x"] + gx, i["z"] + gz
            if not on_land(name, x, z, 9):
                continue
            if name == "heart" and z > 0 and abs(x) < 14:
                continue
            f = free(x, z, 7)
            if f > best:
                best, bp = f, (x, z)
    put("grove_" + name, bp, 7)

# hire pads: beside each worker building, on the side facing its islet's centre
for b in ["garden", "garden2", "garden3", "tea1", "tea2", "vein1", "vein2", "vein3", "furnace", "training"]:
    x, z = pos[b]
    i = I[islet[b]]
    vx, vz = i["x"] - x, i["z"] - z
    vd = math.hypot(vx, vz) or 1
    t = (x + vx / vd * (SIZE.get(b, 8) + 5), z + vz / vd * (SIZE.get(b, 8) + 5))
    lvl = 1 if b in ("garden2", "garden3", "tea1", "tea2") else 0
    p = best_near(islet[b], t[0], t[1], 3, 14, lvl, 2)
    put("hire_" + b, p, 3)

# shop pads beside the building they act on
for key, b in (("pill", "furnace"), ("auto", "array")):
    x, z = pos[b]
    p = best_near(islet[b], x, z, 3, 24, 0, 3)
    put("shop_" + key, p, 3)

for k, v in out.items():
    print(k, v)
json.dump(out, open(sys.argv[2].replace(".json", "_extras.json"), "w"), indent=1)
