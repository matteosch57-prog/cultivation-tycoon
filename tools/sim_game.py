"""The whole game's qi, simulated: every source and sink the server has, over real days and lives.

Owner, 2026-10-21: "check all the game codes for all Qi sources and sinks, make a full simulation now.
Sims will be our single most important thing to a good game. Pace."

Every rule below names the server code it copies (src/server/Main.server.luau unless said). Numbers come
from a Config.luau (default: src/shared/Config.luau; --config points at another, e.g. a merge preview).
Player kinds are a sweep, not a guess (no live players yet): read the row that matches the first batch.

SOURCES (all qi that enters a save)
  live income   rate(s) every second while playing: (BASE_RATE + pads x workers x districtMult) x
                incomeMult(realm) x disciples x pill x tide x 2x pass x Past Lives x friends x group
  offline       on join: rate(s, away) x min(time away, OFFLINE_CAP + Deep Meditation)   (no tide/pill/friends)
  qi orbs       Qi Gathering Array: one per ORB_INTERVAL (max ORB_MAX), each = rate(s) x ORB_VALUE
  gifts         playtime gifts: GIFT_TIMES[i] s into a session pay rate(s, away) x GIFT_VALUE[i]
  welcome       the Heavenly Gift: WELCOME_QI once per save (D36)
  altar         Heavenly Altar (branch altar): a winner ALTAR_WIN_SECONDS (solo ALTAR_SOLO_SECONDS), a
                fighter ALTAR_JOIN_SECONDS, of rate(s, away)
  qi packs      Robux (Shop.luau): rate(s, away) x seconds
MULTIPLIERS (inside rate): pill (Furnace, PILL_DURATION + Elixir), Spirit Tide, 2x Qi pass, Past Lives,
  friends here (FRIEND_STEP each, live only), group (GROUP_BONUS, when GROUP_ID > 0), disciples
  (best maxDisciples seats; VIP + Disciple Seat), districts (DISTRICT_BONUS), workers (WORKER_BONUS)
SINKS
  pads          buyPad: cost x costMult(realm)          workers   workerCost(pad, n, realm)
  recruits      recruitCost(realm, realmRecruits)      breakthrough  BREAKTHROUGH_COST x costMult(realm)
  reset loss    qi left over is set to 0 by a breakthrough and by a reincarnation (not a purchase:
                qi the player earned and never got to spend)

    python tools/sim_game.py                         # the standard report (all player kinds)
    python tools/sim_game.py --config PATH --days 30
    python tools/sim_game.py --kind regular --trace  # one run, every life and realm
"""

import argparse
import math
import random
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = ROOT / "src" / "shared" / "Config.luau"


# --------------------------------------------------------------------------------------------
# Config.luau -> python (only what the economy reads)
def load(path):
    src = Path(path).read_text(encoding="utf-8")
    env = {}

    def val(expr):
        expr = expr.split("--")[0].strip()
        expr = re.sub(r"Config\.(\w+)", lambda m: repr(env[m.group(1)]), expr)
        return eval(expr, {"math": math})

    for m in re.finditer(r"^Config\.(\w+) = ([^{\n]+)$", src, re.M):
        try:
            env[m.group(1)] = val(m.group(2))
        except Exception:
            pass
    for m in re.finditer(r"^Config\.(\w+) = \{([^{}\n]*)\}", src, re.M):  # flat lists of numbers/names
        items = [x.strip() for x in m.group(2).split(",") if x.strip()]
        try:
            env[m.group(1)] = [float(x) for x in items]
        except ValueError:
            env[m.group(1)] = [x.strip('"') for x in items]

    def block(name):
        m = re.search(r"^Config\.%s = \{\n(.*?)\n\}" % name, src, re.M | re.S)
        return m.group(1).splitlines() if m else []

    pads = []
    for line in block("PADS"):
        m = re.match(r'\s*\{ id = "(\w+)".*?cost = (\d+), income = (\d+), unlock = (\d+), req = \{([^}]*)\}', line)
        if m:
            d = re.search(r'district = "(\w+)"', line)
            pads.append(dict(id=m.group(1), cost=int(m.group(2)), income=int(m.group(3)), unlock=int(m.group(4)),
                             req=re.findall(r'"(\w+)"', m.group(5)), district=d.group(1) if d else None))
    rar = [(float(w), float(b)) for w, b in re.findall(r"weight = ([\d.]+), bonus = ([\d.]+)", "\n".join(block("RARITIES")))]
    dao = {}
    for line in block("DAO"):
        m = re.search(r'key = "(\w+)".*?costs = \{([^}]*)\}', line)
        if m:
            dao[m.group(1)] = [int(x) for x in re.findall(r"\d+", m.group(2))]
    workers = re.findall(r"^\s*(\w+) = \{ name", "\n".join(block("WORKERS")), re.M)
    env.update(PADS=pads, RARITIES=rar, DAO=dao, WORKER_PADS=workers)
    for k, v in dict(DISTRICT_BONUS=0, FRIEND_STEP=0, FRIEND_MAX=0, GROUP_BONUS=0, WELCOME_QI=0, PASS_QI_MULT=2,
                     VIP_SLOTS=1, SWORN_BASE=1, DAO_PILL_SECONDS=30, DAO_OFFLINE_SECONDS=7200, DAO_ECHO=0.1,
                     REINC_REALM=10, PAST_LIVES_MULT=3, WORKER_MAX=0, WORKER_BONUS=0, WORKER_COST=[0.5, 1, 2],
                     REALM_COST_LATE=env.get("REALM_COST_MULT", 8), REALM_COST_LATE_FROM=99).items():
        env.setdefault(k, v)
    return env


# --------------------------------------------------------------------------------------------
# Who plays. play = how they act in a session; when = sessions per day x minutes.
PLAY = {
    "active": dict(walk=6, orb_every=30, pill=True, recruit=1.0, workers=True),
    "casual": dict(walk=15, orb_every=120, pill=True, recruit=0.5, workers=True),
}
KINDS = {
    "casual": dict(play="casual", session=20, per_day=1),
    "regular": dict(play="active", session=30, per_day=2),
    "hooked": dict(play="active", session=60, per_day=3),
    "regular+passes": dict(play="active", session=30, per_day=2, passes=("2x", "vip", "orbs")),
    "regular+social": dict(play="active", session=30, per_day=2, friends=2, altar=0.25),
}
DAO_ORDER = ["hands", "foundation", "elixir", "meditation", "sworn", "seat", "echo"]  # cheapest comfort first


def simulate(C, kind, seed, days, lives=99, trace=False):
    rng = random.Random(seed)
    K = KINDS[kind]
    st = PLAY[K["play"]]
    passes = K.get("passes", ())
    friends = min(K.get("friends", 0), C["FRIEND_MAX"])
    altar_win = K.get("altar")  # chance to win a round they fight in (None = never goes)
    pads = {p["id"]: p for p in C["PADS"]}
    x2 = C["PASS_QI_MULT"] if "2x" in passes else 1
    vip = C["VIP_SLOTS"] if "vip" in passes else 0
    auto_orbs = "orbs" in passes

    S = dict(realm=1, qi=0.0, owned=set(), workers={}, disciples=[], realm_recruits=0, soul=0, karma=0,
             dao={}, life=1, pill_t=0.0, pill_ready=False, boost=0.0, orb_t=0.0, orbs=0)
    led_src, led_sink = {}, {}
    out = dict(milestones={}, lives=[], realms=[])
    played = 0
    life_start_play, life_start_day, realm_start = 0, 0, 0

    life_src, life_sink = {}, {}  # this life's ledger (qi grows exponentially, so whole-run totals only show the end)

    def src(k, v):
        led_src[k] = led_src.get(k, 0) + v
        life_src[k] = life_src.get(k, 0) + v
        S["qi"] += v

    def sink(k, v):
        led_sink[k] = led_sink.get(k, 0) + v
        life_sink[k] = life_sink.get(k, 0) + v
        S["qi"] -= v

    def lvl(k):
        return S["dao"].get(k, 0)

    def cmult(r=None):
        r = S["realm"] if r is None else r
        lf = int(C["REALM_COST_LATE_FROM"])
        return C["REALM_COST_MULT"] ** (min(r, lf) - 1) * C["REALM_COST_LATE"] ** max(0, r - lf)

    def max_disc():
        return C["MAX_DISCIPLES"] + vip + lvl("seat") + sum(1 for p in C["SLOT_PADS"] if p in S["owned"])

    def dmult():
        return 1 + sum(sorted(S["disciples"], reverse=True)[:max_disc()])

    def dist(i):
        p = pads[i]
        if not p["district"] or p["district"] == "heart" or p["income"] <= 0:
            return 1
        return 1 + C["DISTRICT_BONUS"] * sum(1 for j in S["owned"] if j != i and pads[j]["district"] == p["district"] and pads[j]["income"] > 0)

    def base():  # rate(s, away) without the live-only multipliers
        b = C["BASE_RATE"] + sum(pads[i]["income"] * (1 + C["WORKER_BONUS"] * S["workers"].get(i, 0)) * dist(i) for i in S["owned"])
        past = C["PAST_LIVES_MULT"] ** max(0, S["soul"] - (C["REINC_REALM"] - 1))
        return b * C["REALM_INCOME_MULT"] ** (S["realm"] - 1) * dmult() * x2 * past

    def roll():
        x = rng.uniform(0, sum(w for w, _ in C["RARITIES"]))
        for w, b in C["RARITIES"]:
            x -= w
            if x <= 0:
                return b
        return C["RARITIES"][0][1]

    def open_pads():
        n = len(S["owned"])
        return [p for p in C["PADS"] if p["id"] not in S["owned"] and n >= p["unlock"] and all(r in S["owned"] for r in p["req"])]

    def hires():
        if not st["workers"]:
            return []
        return [(pads[i]["cost"] * C["WORKER_COST"][S["workers"].get(i, 0)] * cmult(), i) for i in C["WORKER_PADS"]
                if i in S["owned"] and S["workers"].get(i, 0) < C["WORKER_MAX"]]

    def realm_done(day):
        out["realms"].append(dict(life=S["life"], realm=S["realm"], play_s=played - realm_start, day=day))

    def reincarnate(day):
        nonlocal life_start_play, life_start_day
        gain = 0
        if S["realm"] > S["soul"]:  # D37: only a new record depth pays
            gain = int(C["KARMA_GROWTH"] ** (S["realm"] - C["REINC_REALM"]) * (1 + C["DAO_ECHO"] * lvl("echo"))) if "KARMA_GROWTH" in C \
                else int(10 * 10 ** ((S["realm"] - C["REINC_REALM"]) / 3) * (1 + C["DAO_ECHO"] * lvl("echo")))
        out["lives"].append(dict(life=S["life"], realm=S["realm"], play_s=played - life_start_play, day=day,
                                 karma=gain, past=C["PAST_LIVES_MULT"] ** max(0, max(S["soul"], S["realm"]) - (C["REINC_REALM"] - 1))))
        led_sink["reset loss"] = led_sink.get("reset loss", 0) + S["qi"]
        life_sink["reset loss"] = life_sink.get("reset loss", 0) + S["qi"]
        out["lives"][-1]["src"], out["lives"][-1]["sink"] = dict(life_src), dict(life_sink)
        life_src.clear()
        life_sink.clear()
        S["karma"] += gain
        S["soul"] = max(S["soul"], S["realm"])
        S["life"] += 1
        S.update(realm=1, qi=0.0, workers={}, realm_recruits=0, pill_ready=False, pill_t=0.0, boost=0.0)
        S["owned"] = {p["id"] for p in C["PADS"]} if lvl("foundation") else set()
        keep = sorted(S["disciples"], reverse=True)[:C["SWORN_BASE"] + lvl("sworn")]
        S["disciples"] = keep
        for k in DAO_ORDER:  # spend karma: cheapest comfort first, one level at a time
            costs = C["DAO"].get(k)
            while costs and lvl(k) < len(costs) and S["karma"] >= costs[lvl(k)]:
                S["karma"] -= costs[lvl(k)]
                S["dao"][k] = lvl(k) + 1
        life_start_play, life_start_day = played, day

    if C["WELCOME_QI"]:
        src("welcome", C["WELCOME_QI"])
    session_gap = 24 * 3600 / K["per_day"] - K["session"] * 60
    for day in range(days):
        for _ in range(K["per_day"]):
            if played:
                away = min(session_gap, C["OFFLINE_CAP"] + C["DAO_OFFLINE_SECONDS"] * lvl("meditation"))
                src("offline", base() * away * C.get("OFFLINE_RATE", 1))  # OFFLINE_RATE: proposal lever (server pays 1)
            tide_phase = rng.uniform(0, C["TIDE_INTERVAL"])
            gift_i, walking = 0, None
            walk = 0 if lvl("hands") else st["walk"]
            for s in range(int(K["session"] * 60)):
                played += 1
                tp = (s + tide_phase) % C["TIDE_INTERVAL"]
                tide = C["TIDE_MULT"] if tp < C["TIDE_DURATION"] else 1
                pill = 2 if S["boost"] > 0 else 1
                fr = 1 + C["FRIEND_STEP"] * friends
                b = base()
                src("live income", b)
                if pill > 1:
                    src("pill", b * (pill - 1))
                if tide > 1:
                    src("spirit tide", b * pill * (tide - 1))
                if fr > 1:
                    src("friends here", b * pill * tide * (fr - 1))
                r = b * pill * tide * fr
                S["boost"] = max(0, S["boost"] - 1)
                if "furnace" in S["owned"] and not S["pill_ready"]:
                    S["pill_t"] += 1
                    S["pill_ready"] = S["pill_t"] >= C["PILL_INTERVAL"]
                if S["pill_ready"] and st["pill"]:
                    S["pill_ready"], S["pill_t"] = False, 0
                    S["boost"] = C["PILL_DURATION"] + C["DAO_PILL_SECONDS"] * lvl("elixir")
                if "array" in S["owned"]:
                    S["orb_t"] += 1
                    if S["orb_t"] >= C["ORB_INTERVAL"]:
                        S["orb_t"], S["orbs"] = 0, min(C["ORB_MAX"], S["orbs"] + 1)
                if S["orbs"] and (auto_orbs or s % st["orb_every"] == 0):
                    src("qi orbs", S["orbs"] * int(r * C["ORB_VALUE"]))
                    S["orbs"] = 0
                if gift_i < len(C["GIFT_TIMES"]) and s >= C["GIFT_TIMES"][gift_i]:
                    src("playtime gifts", b * C["GIFT_VALUE"][gift_i])
                    gift_i += 1
                if altar_win is not None and "ALTAR_INTERVAL" in C and (s + tide_phase - C["TIDE_INTERVAL"] / 2) % C["ALTAR_INTERVAL"] < 1:
                    won = rng.random() < altar_win
                    src("heavenly altar", b * (C["ALTAR_WIN_SECONDS"] if won else C["ALTAR_JOIN_SECONDS"]))

                # spend: breakthrough / reincarnation, else the cheapest thing on offer
                choices = open_pads()
                if not choices:
                    bt = C["BREAKTHROUGH_COST"] * cmult()
                    if S["qi"] >= bt:
                        sink("breakthrough", bt)
                        realm_done(day + 1)
                        carry = S["qi"] if C.get("CARRY_QI") else 0.0  # CARRY_QI: proposal lever (server wipes it)
                        led_sink["reset loss"] = led_sink.get("reset loss", 0) + S["qi"] - carry
                        life_sink["reset loss"] = life_sink.get("reset loss", 0) + S["qi"] - carry
                        S["realm"] += 1
                        S.update(qi=carry, owned=set(), workers={}, realm_recruits=0, pill_ready=False, pill_t=0.0, boost=0.0)
                        realm_start = played
                        out["milestones"].setdefault("realm %d" % S["realm"], played)
                        if S["realm"] >= max(C["REINC_REALM"], S["soul"] + 1) and S["life"] <= lives:
                            reincarnate(day + 1)
                            out["milestones"].setdefault("life %d" % S["life"], played)
                            if len(out["lives"]) >= lives:
                                return out, led_src, led_sink
                    continue
                target = min(choices, key=lambda p: p["cost"])
                tcost = target["cost"] * cmult()
                hire = hires()
                rc = C["RECRUIT_BASE"] * cmult() * (1 + S["realm_recruits"] * C["RECRUIT_GROWTH"])
                if "hall" in S["owned"] and rc <= st["recruit"] * tcost and S["qi"] >= rc:
                    sink("recruits", rc)
                    S["realm_recruits"] += 1
                    bb = roll()
                    S["disciples"].append(bb)
                    S["disciples"].sort(reverse=True)
                    del S["disciples"][C["DISCIPLE_CAP"] + vip:]
                    continue
                if hire and min(hire)[0] < tcost:
                    wc, wid = min(hire)
                    if S["qi"] >= wc:
                        sink("workers", wc)
                        S["workers"][wid] = S["workers"].get(wid, 0) + 1
                    continue
                if S["qi"] >= tcost:
                    walking = walking if walking is not None else s + walk
                    if s >= walking:
                        walking = None
                        sink("buildings", tcost)
                        S["owned"].add(target["id"])
                        out["milestones"].setdefault(target["id"], played)
    return out, led_src, led_sink


# --------------------------------------------------------------------------------------------
def fmt_t(sec):
    return "%.0f min" % (sec / 60) if sec < 5400 else "%.1f h" % (sec / 3600)


def report(C, days, runs):
    lines = []
    for kind in KINDS:
        res = [simulate(C, kind, seed, days) for seed in range(runs)]
        outs = [r[0] for r in res]

        def med_ms(k):
            v = [o["milestones"][k] for o in outs if k in o["milestones"]]
            return statistics.median(v) if len(v) * 2 > runs else None

        lines.append("\n### %s (%s)" % (kind, ", ".join("%s=%s" % kv for kv in KINDS[kind].items())))
        first = [("first building", "path"), ("Main Hall", "mainhall1"), ("Disciple Hall", "hall"), ("realm 2", "realm 2"), ("life 2", "life 2")]
        lines.append("First session, minutes played: " + ", ".join("%s %s" % (n, "%.1f" % (med_ms(k) / 60) if med_ms(k) else "-") for n, k in first))
        lives = {}
        for o in outs:
            for L in o["lives"]:
                lives.setdefault(L["life"], []).append(L)
        lines.append("")
        lines.append("| life | ends at realm | play time in that life | day it ends | karma paid | Past Lives after |")
        lines.append("|---|---|---|---|---|---|")
        for n in sorted(lives)[:14]:
            L = lives[n]
            if len(L) * 2 <= runs:
                break
            m = lambda k: statistics.median(x[k] for x in L)  # noqa: E731
            lines.append("| %d | %d | %s | %d | %d | x%.1f |" % (n, m("realm"), fmt_t(m("play_s")), m("day"), m("karma"), m("past")))
        # shares per life, averaged over lives (each life weighs the same, whatever its size)
        def shares(pick, key):
            acc, n = {}, 0
            for o in outs:
                for L in o["lives"]:
                    if pick(L["life"]) and key in L:
                        tot = sum(L[key].values()) or 1
                        for a, b in L[key].items():
                            acc[a] = acc.get(a, 0) + b / tot
                        n += 1
            return ", ".join("%s %.0f%%" % (a, 100 * b / n) for a, b in sorted(acc.items(), key=lambda x: -x[1]) if b / n >= 0.005) if n else "-"
        last = max(lives) if lives else 1
        lines.append("")
        lines.append("Qi sources, lives 1-4: " + shares(lambda n: n <= 4, "src"))
        lines.append("Qi sources, lives %d-%d: " % (max(5, last - 3), last) + shares(lambda n: n >= max(5, last - 3), "src"))
        lines.append("Qi sinks, lives 1-4: " + shares(lambda n: n <= 4, "sink"))
        lines.append("Qi sinks, lives %d-%d: " % (max(5, last - 3), last) + shares(lambda n: n >= max(5, last - 3), "sink"))
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--kind")
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--set", action="append", default=[], help="KEY=VALUE override")
    a = ap.parse_args()
    C = load(a.config)
    for kv in a.set:
        k, v = kv.split("=")
        C[k] = float(v)
    if a.kind and a.trace:
        o, s, k = simulate(C, a.kind, 1, a.days)
        for r in o["realms"]:
            print("life %2d realm %2d  %8s  day %d" % (r["life"], r["realm"], fmt_t(r["play_s"]), r["day"]))
        return
    if a.kind:
        KINDS_ONLY = {a.kind: KINDS[a.kind]}
        KINDS.clear()
        KINDS.update(KINDS_ONLY)
    print("Config: %s | %d days | median of %d runs" % (a.config, a.days, a.runs))
    print(report(C, a.days, a.runs))


if __name__ == "__main__":
    main()
