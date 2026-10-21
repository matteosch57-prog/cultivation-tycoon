"""Whole-game economy sim: realms 1 to N over real days of play (sessions + offline), from Config.luau.

tools/sim_pacing.py answers "how fast is the first session". This one answers "what does the whole
climb feel like": it replays every qi source the server has (pads, disciples, pill, orbs, Spirit Tide,
playtime gifts, offline qi capped at OFFLINE_CAP) inside a session schedule, and reports per realm the
play time, the calendar day, and how much of the play was spent waiting with nothing to buy.

No real players exist yet, so the player kinds are a SWEEP (the Gladiator lesson: read the row that
matches the first live batch, never tune to one modelled archetype).

    python tools/sim_economy.py                      # the sweep table, Config as it is
    python tools/sim_economy.py --rarity Celestial=0.12:9 --rarity "Dao Ancestor=0.03:20"
    python tools/sim_economy.py --set REALM_COST_MULT=5 --set REALM_INCOME_MULT=3
    python tools/sim_economy.py --waits              # the longest waits per realm (the frustration)
    python tools/sim_economy.py --passes 2x,vip,orbs # a player who bought the three passes
    Levers beyond Config (--set): RECRUIT_REALM_MULT (recruit price step per realm instead of
    costMult), RECRUIT_RESET=0 (the old rule: +RECRUIT_GROWTH per disciple EVER recruited).

Light on CPU (one process, 1 s ticks while playing, offline in one step): ~10 s for the default sweep.
"""

import argparse
import random
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sim_pacing import CONFIG, load_config  # noqa: E402  (one Config parser for both sims)

import re  # noqa: E402

SRC = CONFIG.read_text(encoding="utf-8")


def extra_keys(cfg):
    def num(key):
        m = re.search(r"^Config\.%s = ([\d.]+(?: \* [\d.]+)?)" % key, SRC, re.M)
        return eval(m.group(1))

    def arr(key):
        return [float(x) for x in re.findall(r"[\d.]+", re.search(r"^Config\.%s = \{([^}]*)\}" % key, SRC, re.M).group(1))]

    for k in ["REALM_COST_LATE", "REALM_COST_LATE_FROM", "OFFLINE_CAP", "TIDE_FIRST", "TIDE_INTERVAL", "TIDE_DURATION", "TIDE_MULT"]:
        cfg[k] = num(k)
    cfg["GIFT_TIMES"], cfg["GIFT_VALUE"] = arr("GIFT_TIMES"), arr("GIFT_VALUE")
    return cfg


# How a player plays inside a session (same meaning as sim_pacing.STYLES).
PLAY = {
    "active": dict(walk=6, orb_every=30, pill=True, recruit=1.0),
    "casual": dict(walk=15, orb_every=120, pill=True, recruit=0.5),
}
# When they play: (minutes per session, sessions per day, label). Days run 24 h; the gaps between
# sessions are offline time (capped by OFFLINE_CAP).
KINDS = {
    "hooked": dict(play="active", session=60, per_day=3),
    "regular": dict(play="active", session=30, per_day=2),
    "casual": dict(play="casual", session=20, per_day=1),
}


def simulate(cfg, kind, seed, realms=10, days=60, passes=()):
    rng = random.Random(seed)
    k = KINDS[kind]
    st = PLAY[k["play"]]
    pads = {p["id"]: p for p in cfg["pads"]}
    # game passes (branch shop): 2x qi on live AND offline income, VIP +1 slot, orbs fly to you
    x2, vip = (2 if "2x" in passes else 1), (1 if "vip" in passes else 0)
    orb_every = 1 if "orbs" in passes else st["orb_every"]
    realm, qi, owned, disciples, recruited = 1, 0.0, set(), [], 0
    pill_timer, pill_ready, boost = 0.0, False, 0.0
    orb_timer, orbs = 0.0, 0
    played = 0  # seconds of play since the first join
    out = {}  # realm -> dict(play_s, day, wait_s, longest_wait_s, recruits, dmult)
    cur = dict(start=0, wait=0, longest=0, gap=0, recruits=0)

    def max_disc():
        return cfg["MAX_DISCIPLES"] + vip + sum(1 for s in cfg["slot_pads"] if s in owned)

    def dmult():
        return 1 + sum(sorted(disciples, reverse=True)[:max_disc()])

    def base_rate():
        return (cfg["BASE_RATE"] + sum(pads[i]["income"] for i in owned)) * cfg["REALM_INCOME_MULT"] ** (realm - 1) * dmult()

    def cmult():  # Config.costMult
        late_from = int(cfg["REALM_COST_LATE_FROM"])
        return cfg["REALM_COST_MULT"] ** (min(realm, late_from) - 1) * cfg["REALM_COST_LATE"] ** max(0, realm - late_from)

    def open_pads():
        n = len(owned)
        return [p for p in cfg["pads"] if p["id"] not in owned and n >= p["unlock"] and all(r in owned for r in p["req"])]

    def roll():
        x = rng.uniform(0, sum(w for w, _ in cfg["rarities"]))
        for w, b in cfg["rarities"]:
            x -= w
            if x <= 0:
                return b
        return cfg["rarities"][0][1]

    session_gap = 24 * 3600 / k["per_day"] - k["session"] * 60
    for day in range(days):
        for _ in range(k["per_day"]):
            if played:  # offline since the last session
                qi += base_rate() * x2 * min(session_gap, cfg["OFFLINE_CAP"])
            tide_phase = rng.uniform(0, cfg["TIDE_INTERVAL"])  # joins a server mid-cycle
            gift_i, walking = 0, None
            for s in range(int(k["session"] * 60)):
                played += 1
                tp = (s + tide_phase) % cfg["TIDE_INTERVAL"]
                tide = cfg["TIDE_MULT"] if tp < cfg["TIDE_DURATION"] else 1
                r = base_rate() * x2 * (2 if boost > 0 else 1) * tide
                qi += r
                boost = max(0, boost - 1)
                if "furnace" in owned and not pill_ready:
                    pill_timer += 1
                    pill_ready = pill_timer >= cfg["PILL_INTERVAL"]
                if pill_ready and st["pill"]:
                    pill_ready, pill_timer, boost = False, 0, cfg["PILL_DURATION"]
                if "array" in owned:
                    orb_timer += 1
                    if orb_timer >= cfg["ORB_INTERVAL"]:
                        orb_timer, orbs = 0, min(cfg["ORB_MAX"], orbs + 1)
                if orbs and s % orb_every == 0:
                    qi += orbs * int(r * cfg["ORB_VALUE"])
                    orbs = 0
                if gift_i < len(cfg["GIFT_TIMES"]) and s >= cfg["GIFT_TIMES"][gift_i]:
                    qi += base_rate() * cfg["GIFT_VALUE"][gift_i]
                    gift_i += 1

                bought = False
                choices = open_pads()
                if not choices:
                    bt = cfg["BREAKTHROUGH_COST"] * cmult()
                    if qi >= bt:
                        out[realm] = dict(play_s=played - cur["start"], day=day + 1, at_play=played,
                                          wait_s=cur["wait"], longest=max(cur["longest"], cur["gap"]),
                                          recruits=cur["recruits"], dmult=dmult())
                        realm += 1
                        qi, owned, pill_ready, pill_timer, boost = 0.0, set(), False, 0, 0
                        cur = dict(start=played, wait=0, longest=0, gap=0, recruits=0)
                        if realm > realms:
                            return out
                        continue
                    target_cost = bt
                else:
                    target = min(choices, key=lambda p: p["cost"])
                    target_cost = target["cost"] * cmult()
                    n = cur["recruits"] if cfg.get("RECRUIT_RESET", 1) else recruited
                    rm = cfg["RECRUIT_REALM_MULT"] ** (realm - 1) if "RECRUIT_REALM_MULT" in cfg else cmult()
                    rc = cfg["RECRUIT_BASE"] * rm * (1 + n * cfg["RECRUIT_GROWTH"])
                    if "hall" in owned and rc <= st["recruit"] * target_cost and qi >= rc:
                        qi -= rc
                        recruited += 1
                        cur["recruits"] += 1
                        b = roll()
                        if len(disciples) < max_disc() or b > sorted(disciples, reverse=True)[max_disc() - 1]:
                            disciples.append(b)
                            disciples.sort(reverse=True)
                            del disciples[cfg["MAX_DISCIPLES"] + vip + len(cfg["slot_pads"]):]
                        bought = True
                    elif qi >= target_cost:
                        walking = walking or s + st["walk"]
                        if s >= walking:
                            walking = None
                            qi -= target_cost
                            owned.add(target["id"])
                            bought = True
                if bought:
                    cur["longest"] = max(cur["longest"], cur["gap"])
                    cur["gap"] = 0
                elif qi < target_cost:
                    cur["wait"] += 1  # nothing affordable: the player is waiting
                    cur["gap"] += 1
    return out


def fmt_min(s):
    m = s / 60
    return "%.0f" % m if m >= 10 else "%.1f" % m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=6)
    ap.add_argument("--realms", type=int, default=10)
    ap.add_argument("--days", type=int, default=60)
    ap.add_argument("--set", action="append", default=[], help="KEY=VALUE override")
    ap.add_argument("--rarity", action="append", default=[], help='"Name=weight:bonus" adds a rarity')
    ap.add_argument("--passes", default="", help="owned game passes, e.g. 2x,vip,orbs")
    ap.add_argument("--waits", action="store_true", help="print the waiting columns")
    a = ap.parse_args()
    cfg = extra_keys(load_config())
    for kv in a.set:
        key, v = kv.split("=")
        cfg[key] = float(v)
    for r in a.rarity:
        w, b = r.split("=")[1].split(":")
        cfg["rarities"].append((float(w), float(b)))

    print("per realm: play minutes in that realm | day it ends (median of %d runs, '-' = not within %d days)" % (a.runs, a.days))
    if a.waits:
        print("  w = %% of that realm's play with nothing affordable, L = longest wait in minutes, d = disciple mult")
    res = {kd: [simulate(cfg, kd, seed, a.realms, a.days, a.passes.split(",")) for seed in range(a.runs)] for kd in KINDS}
    head = "%-6s" % "realm" + "".join("%26s" % ("%s (%dm x%d/day)" % (kd, KINDS[kd]["session"], KINDS[kd]["per_day"])) for kd in KINDS)
    print(head)
    for rm in range(1, a.realms + 1):
        row = "%-6d" % rm
        for kd in KINDS:
            got = [o[rm] for o in res[kd] if rm in o]
            if len(got) * 2 <= a.runs:
                row += "%26s" % "-"
                continue
            med = lambda f: statistics.median(f(g) for g in got)  # noqa: E731
            cell = "%s min | day %d" % (fmt_min(med(lambda g: g["play_s"])), med(lambda g: g["day"]))
            if a.waits:
                cell = "w%2.0f%% L%s d%.1f " % (100 * med(lambda g: g["wait_s"] / max(1, g["play_s"])),
                                               fmt_min(med(lambda g: g["longest"])), med(lambda g: g["dmult"])) + cell
                row += "%44s" % cell
            else:
                row += "%26s" % cell
        print(row)


if __name__ == "__main__":
    main()
