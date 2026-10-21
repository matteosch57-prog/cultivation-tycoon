"""Time to each early milestone, simulated from src/shared/Config.luau (B01 step 5).

Reads the pad list and the economy keys straight from Config.luau (the one home for numbers), replays
the server's rules (Main.server.luau: rate, refreshPads unlock/req, recruit, pill, orbs) once per
second, and prints the minute each milestone lands for a sweep of player styles. No real players exist
yet, so the styles are a sweep, not a guess at one archetype: read the row that matches the batch.

    python tools/sim_pacing.py            # the sweep table
    python tools/sim_pacing.py --trace    # every purchase of the "active" style, realm 1
"""

import argparse
import random
import re
import statistics
from pathlib import Path

CONFIG = Path(__file__).resolve().parent.parent / "src" / "shared" / "Config.luau"


def load_config():
    src = CONFIG.read_text(encoding="utf-8")

    def num(key):
        m = re.search(r"^Config\.%s = ([\d.]+(?: \* [\d.]+)?)" % key, src, re.M)
        if not m:
            raise SystemExit("Config.%s not found" % key)
        return eval(m.group(1))  # a literal or "a * b" from our own file

    pads = []
    for line in src.splitlines():
        m = re.match(r"\s*\{ id = \"(\w+)\".*?cost = (\d+), income = (\d+), unlock = (\d+), req = \{([^}]*)\}", line)
        if m:
            pads.append({
                "id": m.group(1),
                "cost": int(m.group(2)),
                "income": int(m.group(3)),
                "unlock": int(m.group(4)),
                "req": re.findall(r"\"(\w+)\"", m.group(5)),
            })
    rarities = [(float(w), float(b)) for w, b in re.findall(r"weight = ([\d.]+), bonus = ([\d.]+)", src)]
    slot_pads = re.findall(r"\"(\w+)\"", re.search(r"^Config\.SLOT_PADS = \{([^}]*)\}", src, re.M).group(1))
    keys = ["BASE_RATE", "REALM_INCOME_MULT", "REALM_COST_MULT", "BREAKTHROUGH_COST", "PILL_INTERVAL",
            "PILL_DURATION", "ORB_INTERVAL", "ORB_MAX", "ORB_VALUE", "MAX_DISCIPLES", "RECRUIT_BASE",
            "RECRUIT_GROWTH"]
    cfg = {k: num(k) for k in keys}
    cfg.update(pads=pads, rarities=rarities, slot_pads=slot_pads)
    return cfg


# A style = how a player behaves. walk = seconds from "can afford" to standing on the pad;
# orb_every = how often they sweep the orbs (None = never); recruit = recruit while the roll costs
# less than this share of the cheapest open pad (0 = never recruits).
STYLES = {
    "active": dict(walk=6, orb_every=30, pill=True, recruit=1.0),
    "casual": dict(walk=15, orb_every=120, pill=True, recruit=0.5),
    "idle": dict(walk=40, orb_every=None, pill=False, recruit=0.0),
}

MILESTONES = ["first pad", "mainhall1", "platform", "mainhall2", "hall", "furnace", "array",
              "expand1", "mainhall5", "realm 2", "realm 3", "realm 4"]


def simulate(cfg, style, seed, until_realm=4, cap_s=12 * 3600, trace=False):
    rng = random.Random(seed)
    st = STYLES[style]
    pads = {p["id"]: p for p in cfg["pads"]}
    realm, qi, owned, disciples, recruited = 1, 0.0, set(), [], 0  # recruited = this realm (D25)
    pill_timer, pill_ready, boost_left = 0.0, False, 0.0
    orb_timer, orbs = 0.0, 0
    walking, hits = None, {}

    def max_disc():
        return cfg["MAX_DISCIPLES"] + sum(1 for s in cfg["slot_pads"] if s in owned)

    def rate(t_boost):
        base = cfg["BASE_RATE"] + sum(pads[i]["income"] for i in owned)
        dm = 1 + sum(b for b in sorted(disciples, reverse=True)[:max_disc()])
        return base * cfg["REALM_INCOME_MULT"] ** (realm - 1) * dm * (2 if t_boost > 0 else 1)

    def open_pads():
        n = len(owned)
        return [p for p in cfg["pads"] if p["id"] not in owned and n >= p["unlock"] and all(r in owned for r in p["req"])]

    def cost_of(p):
        return int(p["cost"] * cfg["REALM_COST_MULT"] ** (realm - 1))

    def roll():
        total = sum(w for w, _ in cfg["rarities"])
        x = rng.uniform(0, total)
        for w, b in cfg["rarities"]:
            x -= w
            if x <= 0:
                return b
        return cfg["rarities"][0][1]

    t = 0
    while t < cap_s:
        t += 1
        r = rate(boost_left)
        qi += r
        boost_left = max(0, boost_left - 1)
        if "furnace" in owned and not pill_ready:
            pill_timer += 1
            if pill_timer >= cfg["PILL_INTERVAL"]:
                pill_ready = True
        if pill_ready and st["pill"]:
            pill_ready, pill_timer, boost_left = False, 0, cfg["PILL_DURATION"]
        if "array" in owned:
            orb_timer += 1
            if orb_timer >= cfg["ORB_INTERVAL"]:
                orb_timer, orbs = 0, min(cfg["ORB_MAX"], orbs + 1)
        if st["orb_every"] and orbs and t % st["orb_every"] == 0:
            qi += orbs * int(rate(boost_left) * cfg["ORB_VALUE"])
            orbs = 0

        choices = open_pads()
        if not choices:  # every pad owned: the breakthrough pad
            bt = int(cfg["BREAKTHROUGH_COST"] * cfg["REALM_COST_MULT"] ** (realm - 1))
            if qi >= bt:
                qi -= bt
                realm += 1
                recruited = 0
                owned, qi, pill_ready, pill_timer, boost_left = set(), 0.0, False, 0, 0
                hits.setdefault("realm %d" % realm, t)
                if realm >= until_realm:
                    break
            continue
        target = min(choices, key=cost_of)
        rc = int(cfg["RECRUIT_BASE"] * cfg["REALM_COST_MULT"] ** (realm - 1) * (1 + recruited * cfg["RECRUIT_GROWTH"]))
        if "hall" in owned and st["recruit"] and rc <= st["recruit"] * cost_of(target) and qi >= rc:
            qi -= rc
            recruited += 1
            b = roll()
            if len(disciples) < max_disc() or b > sorted(disciples, reverse=True)[max_disc() - 1]:
                disciples.append(b)
            continue
        if qi >= cost_of(target):
            if walking is None:
                walking = t + st["walk"]
            if t >= walking:
                walking = None
                qi -= cost_of(target)
                owned.add(target["id"])
                if realm == 1:
                    hits.setdefault("first pad", t)
                    hits.setdefault(target["id"], t)
                if trace and realm == 1:
                    print("  %6.1f min  %-11s cost %6d  rate %7.1f/s" % (t / 60, target["id"], cost_of(target), rate(0)))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--runs", type=int, default=40)
    ap.add_argument("--set", action="append", default=[], help="KEY=VALUE override, e.g. BREAKTHROUGH_COST=90000")
    a = ap.parse_args()
    cfg = load_config()
    for kv in a.set:  # try a value before writing it into Config.luau
        k, v = kv.split("=")
        cfg[k] = float(v)
    if a.trace:
        simulate(cfg, "active", 1, until_realm=2, trace=True)
        return
    print("minutes to each milestone (median of %d runs; '-' = not within 12 h)" % a.runs)
    print("%-11s" % "milestone" + "".join("%10s" % s for s in STYLES))
    runs = {s: [simulate(cfg, s, seed) for seed in range(a.runs)] for s in STYLES}
    for m in MILESTONES:
        row = "%-11s" % m
        for s in STYLES:
            vals = [h[m] for h in runs[s] if m in h]
            row += "%10s" % ("%.1f" % (statistics.median(vals) / 60) if len(vals) * 2 > a.runs else "-")
        print(row)


if __name__ == "__main__":
    main()
