"""Mock: the peak seen from above, realm by realm, when the island opens over realms (owner
2026-10-22: "unlock more with the realms"). Reads Config.luau (PADS x/z, ISLETS, ISLAND_LOBES) and a
pad -> realm map, writes docs/art/mocks/realm_land.html and renders realm_land.png with Edge headless.

    python tools/mock_realm_land.py
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / "src" / "shared" / "Config.luau").read_text(encoding="utf-8")
OUT = ROOT / "docs" / "art" / "mocks" / "realm_land.html"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

R1 = "path vein1 lanterns mainhall1 bridge_fields platform path_heart garden grove_heart vein2 mainhall2 bridge_dao furnace bridge_disciples hall array".split()
R2 = "path_fields grove_fields vein3 firelotus1 gate path_dao mainhall3 path_disciples quarters1 firelotus2 grove_dao expand1 bamboo training".split()
R3 = "garden2 grove_disciples mainhall4 tea1 spring1 koi quarters2 garden3 tea2 expand2 spring2".split()

pads = []
for m in re.finditer(r'\{ id = "(\w+)", name = "([^"]+)".*?x = (-?[\d.]+), z = (-?[\d.]+)(.*?)\},?\n', SRC):
    kind = re.search(r'kind = "(\w+)"', m.group(5))
    pads.append(dict(id=m.group(1), name=m.group(2), x=float(m.group(3)), z=float(m.group(4)), kind=kind.group(1) if kind else None))
realm = {p["id"]: 4 for p in pads}
for r, g in enumerate([R1, R2, R3], 1):
    for i in g:
        realm[i] = r
islets = {m.group(1): (float(m.group(2)), float(m.group(3)), float(m.group(4)), m.group(5))
          for m in re.finditer(r'^\t(\w+) = \{ x = (-?[\d.]+), z = (-?[\d.]+), r = ([\d.]+)(?:, from = "\w+", bridge = "(\w+)")?', SRC, re.M)}
lobes = [(m.group(1), float(m.group(2)), float(m.group(3)), float(m.group(4)), int(m.group(5)))
         for m in re.finditer(r'\{ islet = "(\w+)", x = (-?[\d.]+), z = (-?[\d.]+), r = ([\d.]+), exp = (\d) \}', SRC)]

S, CX, CZ = 0.62, 0, -80  # px per stud, view centre


def panel(r):
    open_ids = {i for i, v in realm.items() if v <= r}
    g = []
    for name, (x, z, rad, bridge) in islets.items():
        live = bridge is None or bridge in open_ids
        g.append('<circle cx="%.0f" cy="%.0f" r="%.0f" fill="%s" stroke="#3d3428" stroke-width="2"/>' % (
            (x - CX) * S, (z - CZ) * S, rad * S, "#7fbf6a" if live else "#c9b48e"))
    for isl, x, z, rad, exp in lobes:
        live = ("expand%d" % exp) in open_ids
        g.append('<circle cx="%.0f" cy="%.0f" r="%.0f" fill="%s" opacity="%s"/>' % (
            (x - CX) * S, (z - CZ) * S, rad * S, "#7fbf6a" if live else "#c9b48e", "1" if live else "0.55"))
    for p in pads:
        if p["id"].startswith("expand"):
            continue
        v = realm[p["id"]]
        if v > r:
            continue
        col = "#e8b23a" if v == r else "#7a3b2e"
        if p["kind"] in ("path", "grove"):
            col = "#2f7d4f" if v < r else "#9be07a"
        g.append('<circle cx="%.0f" cy="%.0f" r="%d" fill="%s" stroke="#1b1420" stroke-width="1.5"/>' % (
            (p["x"] - CX) * S, (p["z"] - CZ) * S, 6 if p["kind"] != "bridge" else 5, col))
    n = sum(1 for v in realm.values() if v <= r)
    new = sum(1 for v in realm.values() if v == r)
    return ('<div class="p"><h2>Realm %d</h2><p>%d of %d buildings (+%d new)</p>'
            '<svg viewBox="-150 -100 300 200" width="420" height="280">%s</svg></div>') % (r, n, len(realm), new, "".join(g))


TODAY = '''<div class="p"><h2>Today</h2><p>all %d in realm 1, ~10 min</p>
<svg viewBox="-150 -100 300 200" width="420" height="280">%s</svg></div>''' % (len(realm), panel(9).split("<svg", 1)[1].split(">", 1)[1].rsplit("</svg>", 1)[0])
html = '''<!doctype html><html><head><meta charset="utf-8"><title>Island by realm</title>
<link href="https://fonts.googleapis.com/css2?family=Fredoka:wght@500;700&display=swap" rel="stylesheet">
<style>body{margin:0;background:#bfe3f5;font-family:Fredoka,sans-serif;color:#1b1420;width:1760px}
.row{display:flex;gap:12px;padding:12px}.p{background:#e9f6fc;border-radius:14px;padding:8px 10px}
h1{margin:12px 16px 0;font-size:28px}h2{margin:0;font-size:22px}p{margin:2px 0 4px;font-size:15px}
.k{margin:0 16px 12px;font-size:15px}.k span{display:inline-block;width:12px;height:12px;border-radius:50%%;margin:0 4px 0 12px;vertical-align:-1px}
</style></head><body><h1>Option A: the island opens over 4 realms (rebuilt each realm)</h1>
<div class="row">%s</div>
<div class="k"><span style="background:#e8b23a"></span>new this realm<span style="background:#7a3b2e"></span>from earlier realms
<span style="background:#9be07a"></span>new path / grove<span style="background:#c9b48e"></span>dry ground: land you can see but not use yet</div>
</body></html>''' % "".join(panel(r) for r in (1, 2, 3, 4))
OUT.write_text(html, encoding="utf-8", newline="\n")
png = OUT.with_suffix(".png")
subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=3000",
                "--window-size=1760,420", "--screenshot=%s" % png, OUT.as_uri()], check=True, capture_output=True)
print(png)
