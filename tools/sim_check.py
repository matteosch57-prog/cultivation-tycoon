"""Second-opinion economy sim (2026-10-22): written from the server code, not from sim_game.py.

Why a second sim: sim_game.py rebirths only when a realm gate blocks it, but the HUD chip turns gold
and wobbles (and the red dot lights) the moment qi >= the rebirth price (Hud.client rebirthChip,
Dots.luau). This sim plays the rebirth the way the HUD asks for it, adds the sources sim_game.py skips
(Daily Blessing streak with its Immortal / Celestial days, the Shop free gift, Incense Blessing, the
starter chest, Welcome Pouch, Robux disciples) and prices recruits with the x10 button.
Since D66 the server opens a rebirth only when the next realm waits for one, so every policy now obeys
that gate (default `gated`); `--pre-d66` replays the old qi-price-only rule.

    python tools/sim_check.py                          # the standard table
    python tools/sim_check.py --kind regular --policy eager --days 30 --trace
    python tools/sim_check.py --set REBIRTH_PRICE_STEP=... --set REBIRTH_BONUS=...

Every rule names the code it copies (Main.server.luau unless said).
"""

import argparse
import math
import random
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sim_game import load, DEFAULT_CONFIG  # noqa: E402  (the Config.luau parser only)

# Config.STREAK (D58) is a table of tables the parser skips: copied here, checked against Config by hand
STREAK = [dict(qi=300, summons=1), dict(rarity="Immortal", again=3), dict(qi=600, summons=2), dict(qi=900),
          dict(summons=3), dict(qi=1800), dict(rarity="Celestial", again=3)]
# Config.MISSION_RANKS (Sect Missions, 2026-10-25) is a table of tables too: copied, checked by hand.
# Each rank: rewards at cumulative stars (qi = s of away income, summons, pill = s of 2x, rarity); the last ranks up.
MISSION_RANKS = [
    [(2, dict(qi=60)), (4, dict(summons=1)), (7, dict(pill=120)), (10, dict(qi=120)), (13, dict(summons=2, rarity="Core Disciple"))],
    [(3, dict(qi=90)), (7, dict(summons=1)), (11, dict(pill=180)), (16, dict(qi=150)), (20, dict(summons=2)), (25, dict(summons=2, rarity="Core Disciple"))],
    [(4, dict(qi=120)), (9, dict(summons=2)), (15, dict(pill=300)), (21, dict(qi=180)), (26, dict(summons=2)), (32, dict(summons=3, rarity="Elder"))],
    [(6, dict(qi=150)), (13, dict(summons=2)), (21, dict(pill=300)), (29, dict(qi=240)), (37, dict(summons=3)), (46, dict(summons=3, rarity="Elder"))],
    [(8, dict(qi=180)), (18, dict(summons=2)), (28, dict(pill=420)), (39, dict(qi=300)), (50, dict(summons=3)), (63, dict(summons=4, rarity="Immortal"))],
    [(11, dict(qi=240)), (25, dict(summons=3)), (40, dict(pill=600)), (55, dict(qi=360)), (71, dict(summons=4)), (89, dict(summons=4, rarity="Elder"))],
    [(16, dict(qi=300)), (36, dict(summons=3)), (58, dict(pill=600)), (80, dict(qi=480)), (104, dict(summons=5)), (131, dict(summons=5, rarity="Immortal"))],
    [(22, dict(qi=360)), (50, dict(summons=4)), (80, dict(pill=900)), (112, dict(qi=600)), (146, dict(summons=5)), (182, dict(summons=6, rarity="Immortal"))],
    [(32, dict(qi=480)), (70, dict(summons=4)), (113, dict(pill=900)), (160, dict(qi=720)), (208, dict(summons=6)), (259, dict(summons=6, rarity="Celestial"))],
    [(40, dict(qi=600)), (88, dict(summons=5)), (140, dict(pill=1200)), (196, dict(qi=900)), (256, dict(summons=6)), (319, dict(summons=8, rarity="Celestial"))],
]
MISSION_DAILY_CHEST = dict(qi=300, summons=2)
# --missions: an independent stand-in for the missions themselves: stars come at STAR_RATE per second of
# play (not the qisim's real mission draws), the 3 dailies (2 stars each) are done in the day's first
# session after DAILY_AFTER s, then the daily chest.
STAR_RATE = 1.3 / 60
DAILY_AFTER = 600
SLOT_PADS = ("quarters1", "quarters2")  # fallback when Config has no SLOT_PADS

KINDS = {
    "casual": dict(session=20, per_day=1, walk=15, orb_every=120),
    "regular": dict(session=30, per_day=2, walk=6, orb_every=30),
    "hooked": dict(session=60, per_day=3, walk=6, orb_every=30),
}


PRE_D66 = False  # --pre-d66: the old rebirth rule (qi price only)
# Pad prices (Plan 1, owner pick 2026-10-24; Config.padPrice / Main pricePads): a pad costs
# PAD_SECONDS[realm] s of the pad income (away rate without paid boosts, Robux disciples or the rebirth
# boost) x rebirthMult(the rebirths that realm needs), spread +-PAD_SPREAD by catalogue cost over the
# open pads, set again after every buy; a breakthrough keeps PAD_KEEP. --old-prices = the D44 floor.
PLAN1 = True


def sim(C, kind="regular", policy="gated", days=30, seed=1, buy=(), bless=1, trace=False, react=20, batch=10, events=None, missions=False):
    slot_seats = {p["id"]: int(p.get("seats", 1)) for p in C["PADS"]}  # a slot pad's seats (Config.maxDisciples)
    """policy: gated = rebirth only when the next realm's gate blocks (sim_game.py's rule);
    eager = rebirth `react` s after qi first holds the price (the gold wobbling chip);
    hybrid = eager until every REBIRTH_REALMS gate is open, then climb (the min-max route)."""
    K = KINDS[kind]
    rng = random.Random(seed)
    P = {p["id"]: p for p in C["PADS"]}
    RO = C["REALM_OF"]
    rar = C["RARITIES"]  # (weight, bonus)
    names = C["RARITY_NAMES"]
    wsum = sum(w for w, _ in rar)
    x2 = 2 if "x2" in buy else 1
    vip = 1 if "vip" in buy else 0
    auto = "auto" in buy
    gates = C.get("REBIRTH_REALMS", {})

    keep = {e.split("=")[0].strip() for e in C["PAD_KEEP"]}
    S = dict(realm=1, qi=0.0, owned=set(), workers={}, disc=[], rr=0, lives=1, karma=0, dao={},
             boost=0, pill_t=0, pill=False, orbs=0, orb_t=0, chest=0,
             welcome=0.0, index={}, steps=0, bought=[], ever=set(), best=1)

    def auto_build(pid):  # Main autoBuildTick (D85): a pad this save built before, once Config.autoBuildOpen
        frm = C.get("AUTO_BUILD_FROM")
        open_ = (frm == "breakthrough" and (S["best"] > 1 or S["lives"] > 1)) or (frm == "rebirth" and S["lives"] > 1)
        return open_ and pid in S["ever"]
    src, sink = {}, {}
    log = dict(realms=[], lives=[], days=[], waits={})
    snap = {}  # --plan1: pad id -> price until the next buy
    clock = dict(play=0, realm_t=0, life_t=0)

    def add(k, v):
        src[k] = src.get(k, 0) + v
        S["qi"] += v

    def pay(k, v):
        sink[k] = sink.get(k, 0) + v
        S["qi"] -= v
        if events is not None:  # tools/botsim_compare.py: every spend, to line up with the Studio bot
            events.append((clock["play"], k, v, S["realm"], S["lives"]))

    def lvl(k):
        return S["dao"].get(k, 0)

    def cmult(r=None):
        r = r or S["realm"]
        lf = C["REALM_COST_LATE_FROM"]
        return C["REALM_COST_MULT"] ** (min(r, lf) - 1) * C["REALM_COST_LATE"] ** max(0, r - lf)

    def seats():  # Config.maxDisciples + Disciple Seat
        return C["MAX_DISCIPLES"] + vip + lvl("seat") + sum(slot_seats.get(i, 1) for i in C.get("SLOT_PADS", SLOT_PADS) if i in S["owned"])

    class Disc(float):  # a disciple's bonus that remembers its index entry (addDisciple: name + look)
        key = None

    def dmult(price=False):  # discipleMult: a working disciple's bonus x Config.discipleStarMult (not in priceRate)
        seated = sorted(S["disc"], reverse=True)[:seats()]
        per = 0 if price else C.get("DISCIPLE_STAR_BONUS", 0)
        return 1 + sum(d * (1 + per * sum(1 for at in C["INDEX_STARS"] if S["index"].get(getattr(d, "key", None), 0) >= at)) for d in seated)

    pity = {}

    def roll():  # Main roll: weights, then Config.PITY, then Shiny; returns (rarity index, shiny)
        x = rng.uniform(0, wsum)
        pick = 0
        for i, (w, b) in enumerate(rar):
            x -= w
            if x <= 0:
                pick = i
                break
        for t, n in C.get("PITY", {}).items():
            pity[t] = pity.get(t, 0) + 1
            if pick < t and pity[t] >= n:
                pick = t
            if pick >= t:
                pity[t] = 0
        return pick, C.get("SHINY_CHANCE", 0) > 0 and rng.random() < C["SHINY_CHANCE"]

    def seat(i, shiny=False):  # addDisciple: keep the strongest DISCIPLE_CAP (bought ones never leave)
        if isinstance(i, tuple):
            i, shiny = i
        # indexAdd: entry = rarity x look (4 looks), stars at INDEX_STARS pulls
        key = (i, rng.randrange(4))
        d = Disc(rar[i][1] * (C.get("SHINY_MULT", 1) if shiny else 1))  # Config.discBonus
        d.key = key
        S["disc"].append(d)
        S["disc"].sort(reverse=True)
        keep = int(C["DISCIPLE_CAP"]) + len(S["bought"])
        del S["disc"][keep:]
        n = S["index"].get(key, 0) + 1
        S["index"][key] = n
        if n in C["INDEX_STARS"]:
            steps = stars() // int(C["INDEX_STEP_STARS"])
            if steps > S["steps"]:
                S["chest"] += (steps - S["steps"]) * int(C["INDEX_STEP_SUMMONS"])
                S["steps"] = steps

    def stars():
        return sum(1 for k, n in S["index"].items() for at in C["INDEX_STARS"] if n >= at)

    def base_income():
        b = C["BASE_RATE"]
        for i in S["owned"]:
            p = P[i]
            if p["income"] <= 0:
                continue
            dm = 1
            if p["district"] and p["district"] != "heart":
                dm += C["DISTRICT_BONUS"] * sum(1 for j in S["owned"] if j != i and P[j]["district"] == p["district"] and P[j]["income"] > 0)
            b += p["income"] * (1 + C["WORKER_BONUS"] * S["workers"].get(i, 0)) * dm
        return b

    def harmony():
        n = sum(1 for i in S["owned"] if P[i]["kind"] in ("path", "grove"))
        return 1 + min(n * C["HARMONY_STEP"], C["HARMONY_MAX"])

    cache = {}

    def recalc():
        price = base_income() * C["REALM_INCOME_MULT"] ** (S["realm"] - 1) * dmult(True)  # priceRate (D67: no Harmony, no disciple stars)
        cache["price"] = price * (harmony() if C.get("HARMONY_IN_PRICE") else 1)
        reb = 1 + C["REBIRTH_BONUS"] * (S["lives"] - 1)  # Config.rebirthMult
        idx = 1 + C["INDEX_STAR_BONUS"] * stars()
        cache["away"] = price * dmult() / dmult(True) * harmony() * reb * idx * x2 * (1 + S["welcome"])  # rate(s, true) (no group)

    def plan1_base():  # the price income: rate(s, true) without the 2x pass, Welcome Pouch, rebirth, Robux disciples
        reb = 1 + C["REBIRTH_BONUS"] * (S["lives"] - 1)
        dm = dmult()
        paid = sum(rar[names.index(n)][1] for n in S["bought"] if n in names)
        return cache["away"] / x2 / (1 + S["welcome"]) / reb / dm * max(1.0, dm - paid)

    def pad_seconds():  # Config.padSeconds
        T = C["PAD_SECONDS"]
        return T[min(S["realm"], len(T)) - 1] * (1 + C["REBIRTH_BONUS"] * gate(S["realm"]))

    def worker_cost(i):  # Config.workerCost (Main refreshPads: priced from the pad income, again after a buy)
        n = S["workers"].get(i, 0)
        if not PLAN1:
            return P[i]["cost"] * C["WORKER_COST"][n] * cmult()
        key = "hire_%s_%d" % (i, n)
        if key not in snap:
            snap[key] = max(P[i]["cost"] * C["WORKER_COST"][n], pad_seconds() * C["WORKER_SECONDS"][n] * plan1_base())
        return snap[key]

    def pad_cost(p):  # Config.padCost
        if PLAN1:
            if p["id"] not in snap:
                ops = sorted(open_pads(), key=lambda q: q["cost"])
                i = next((k for k, q in enumerate(ops) if q["id"] == p["id"]), 0)
                sp, T = C["PAD_SPREAD"], C["PAD_SECONDS"]
                f = (1 - sp) + 2 * sp * i / (len(ops) - 1) if len(ops) > 1 else 1
                if p["id"].startswith("mainhall"):  # the Main Hall: MAINHALL_SECONDS[lv], above the spread
                    f = C["MAINHALL_SECONDS"][int(p["id"][-1]) - 1]
                snap[p["id"]] = max(p["cost"], pad_seconds() * f * plan1_base())
                if p["id"].startswith("mainhall"):  # Main pricePads: above the dearest other open pad
                    top = max((pad_cost(q) for q in ops if not q["id"].startswith("mainhall")), default=0)
                    snap[p["id"]] = max(snap[p["id"]], top * C["MAINHALL_ABOVE"])
            return snap[p["id"]]
        fl = cache["price"] * C["PRICE_FLOOR_S"] if S["lives"] >= C["PRICE_FLOOR_FROM_LIFE"] else 0
        return max(p["cost"] * cmult(), fl)

    def needed(p):
        return p["kind"] != "isle" and not (C.get("DECOR_OPTIONAL") and p["kind"] in ("path", "grove"))

    def open_pads():
        n = len(S["owned"])
        return [p for p in C["PADS"] if p["id"] not in S["owned"] and RO[p["id"]] <= S["realm"]
                and n >= p["unlock"] and all(r in S["owned"] for r in p["req"]) and (p["kind"] != "isle" or lvl("isles") >= p.get("karma", 1))]

    def all_built():
        return not any(needed(p) and RO[p["id"]] <= S["realm"] and p["id"] not in S["owned"] for p in C["PADS"])

    def rebirth_price():
        return C["REBIRTH_PRICE"] + C["REBIRTH_PRICE_STEP"] * (S["lives"] - 1)

    def gate(realm):  # Config.rebirthsFor
        if C.get("GATE_EXTEND", True):  # D66: the table's own rule goes on past it (Config.rebirthsFor)
            i = (realm - 1) // 2
            return 0 if i < 1 else 1 + sum(math.ceil(j / 2) for j in range(2, i + 1))
        return max([n for r, n in gates.items() if realm >= r] or [0])

    def recruit_cost(k):
        return math.floor(C["RECRUIT_BASE"] * cmult() * C["RECRUIT_POW"] ** k)

    def do_rebirth():  # reincarnate
        pay("rebirth", rebirth_price())
        r = S["lives"] - 1
        gain = int((C["REBIRTH_KARMA"] + C["REBIRTH_KARMA_STEP"] * r) * (1 + C["DAO_ECHO"] * lvl("echo")))
        sink["reset loss"] = sink.get("reset loss", 0) + S["qi"]
        log["lives"].append(dict(life=S["lives"], realm=S["realm"], t=clock["play"] - clock["life_t"], at=clock["play"]))
        S["karma"] += gain
        S["lives"] += 1
        S.update(realm=1, qi=0.0, workers={}, rr=0, pill=False, pill_t=0, boost=0)
        snap.clear()
        S["owned"] = {p["id"] for p in C["PADS"] if RO[p["id"]] <= 1}
        S.pop("bt", None)
        for k in ("hands", "isles", "elixir", "meditation", "seat", "echo"):  # karma: cheapest comfort first
            costs = C["DAO"].get(k, [])
            while lvl(k) < len(costs) and S["karma"] >= costs[lvl(k)]:
                S["karma"] -= costs[lvl(k)]
                S["dao"][k] = lvl(k) + 1
        clock["life_t"] = clock["play"]
        clock["realm_t"] = clock["play"]
        recalc()

    for i in buy:  # Robux disciples bought on day 1 (Shop.grantProduct)
        if i in names:
            S["bought"].append(i)
            seat(names.index(i))
        if i == "welcome":
            S["welcome"] += 0.1
            S["bought"].append("Elder")
            seat(names.index("Elder"))
    S["owned"] = set()
    recalc()
    add("welcome gift", C["WELCOME_QI"])
    streak_day, streak_got = 0, set()
    M = dict(rank=0, stars=0.0, paid=0)  # Sect Missions (--missions)

    def mission_pay(r):
        add("sect missions", cache["away"] * r.get("qi", 0))
        for _ in range(int(r.get("summons", 0))):
            seat(roll())
        S["boost"] += r.get("pill", 0)
        if r.get("rarity"):
            seat(names.index(r["rarity"]))
        recalc()

    def mission_stars(n):
        M["stars"] += n
        while True:
            path = MISSION_RANKS[min(M["rank"], len(MISSION_RANKS) - 1)]
            if M["paid"] >= len(path) or M["stars"] < path[M["paid"]][0]:
                break
            at, r = path[M["paid"]]
            M["paid"] += 1
            mission_pay(r)
            if M["paid"] == len(path):
                M["rank"] += 1
                M["stars"] -= at
                M["paid"] = 0
                log.setdefault("ranks", []).append(clock["play"])
    gap = 24 * 3600 / K["per_day"] - K["session"] * 60
    eager_at = None
    for day in range(days):
        for sess in range(K["per_day"]):
            if clock["play"]:
                away = min(gap, C["OFFLINE_CAP"] + C["DAO_OFFLINE_SECONDS"] * lvl("meditation"))
                add("offline", cache["away"] * away * C["OFFLINE_RATE"])
                if "platform" in S["owned"]:  # the idle chest stands with the Meditation Platform
                    S["chest"] = max(S["chest"], min(S["chest"] + int(away // C["CHEST_SUMMON_EVERY"]), int(C["CHEST_SUMMON_MAX"])))
            if sess == 0:  # the playtime gift ladder restarts each UTC day (D49)
                gift_i, gift_play = 0, 0
            if sess == 0:  # Daily Blessing (claimed on the first join of the day), Shop free gift, a blessing
                st = STREAK[streak_day % 7]
                if st.get("rarity") and streak_day % 7 not in streak_got:
                    streak_got.add(streak_day % 7)
                    seat(names.index(st["rarity"]))
                elif st.get("rarity"):
                    S["chest"] += st["again"]
                add("streak", cache["away"] * st.get("qi", 0))
                S["chest"] += st.get("summons", 0)
                streak_day += 1
            while S["chest"] > 0:  # idle chest / gift / index summons are opened at once
                S["chest"] -= 1
                seat(roll())
            recalc()
            tide0 = rng.uniform(0, C["TIDE_INTERVAL"])
            walk_until = None
            bank, last_buy = S["qi"], clock["play"]  # pads paid from the qi a session starts with are not waits
            for s in range(int(K["session"] * 60)):
                clock["play"] += 1
                if sess == 0 and s == 600:  # free Shop gift (DOT_SHOP_FIRST), a blessing given and received
                    add("shop free gift", cache["away"] * C["SHOP_FREE_SECONDS"])
                    add("incense blessing", cache["away"] * C["BLESS_SECONDS"] * bless)
                tide = C["TIDE_MULT"] if (s + tide0) % C["TIDE_INTERVAL"] < C["TIDE_DURATION"] else 1
                pill = 2 if S["boost"] > 0 else 1
                live = cache["away"] * pill * tide  # rate(s): friends / group not modelled
                add("live income", cache["away"])
                if live > cache["away"]:
                    add("pill + tide", live - cache["away"])
                S["boost"] = max(0, S["boost"] - 1)
                if "furnace" in S["owned"] and not S["pill"]:
                    S["pill_t"] += 1
                    S["pill"] = S["pill_t"] >= C["PILL_INTERVAL"]
                if S["pill"]:
                    S["pill"], S["pill_t"] = False, 0
                    S["boost"] = C["PILL_DURATION"] + C["DAO_PILL_SECONDS"] * lvl("elixir")
                if "array" in S["owned"]:
                    S["orb_t"] += 1
                    if S["orb_t"] >= C["ORB_INTERVAL"]:
                        S["orb_t"], S["orbs"] = 0, min(C["ORB_MAX"], S["orbs"] + 1)
                if S["orbs"] and (auto or s % K["orb_every"] == 0):
                    add("qi orbs", S["orbs"] * live * C["ORB_VALUE"])
                    S["orbs"] = 0
                if missions:
                    mission_stars(STAR_RATE)
                    if sess == 0 and s == DAILY_AFTER:
                        mission_stars(6)
                        mission_pay(MISSION_DAILY_CHEST)
                gift_play += 1
                if gift_i < len(C["GIFT_TIMES"]) and gift_play >= C["GIFT_TIMES"][gift_i]:
                    add("playtime gifts", cache["away"] * C["GIFT_VALUE"][gift_i])
                    for _ in range(int(C["GIFT_SUMMONS"][gift_i])):
                        seat(roll())
                    gift_i += 1
                    recalc()

                # --- rebirth (the HUD chip): eager presses it once the price is held
                built = all_built()
                if events is not None:  # waiting: qi under the cheapest thing on offer (botsim's rule)
                    offer = []
                    if built:
                        if S["lives"] - 1 < gate(S["realm"] + 1):
                            offer.append(rebirth_price())
                        else:
                            offer.append(math.floor(cache["price"] * C["BREAKTHROUGH_SECONDS"]))
                    else:
                        offer += [pad_cost(p) for p in open_pads()]
                        if "hall" in S["owned"]:
                            offer.append(sum(recruit_cost(S["rr"] + i) for i in range(batch)))
                        offer += [worker_cost(i) for i in C["WORKER_PADS"]
                                  if i in S["owned"] and S["workers"].get(i, 0) < C["WORKER_MAX"]]
                    if offer and S["qi"] < min(offer):
                        events.append((clock["play"], "wait", 0, S["realm"], S["lives"]))
                eager = policy == "eager" or (policy == "hybrid" and S["lives"] - 1 < gate(S["realm"] + 2))
                # D66: the server opens a rebirth only when the next realm waits for one (Config.rebirthOpen),
                # so a press is refused otherwise: eager / hybrid only model the pre-D66 build (--pre-d66)
                if not PRE_D66 and not (built and S["lives"] - 1 < gate(S["realm"] + 1)):
                    eager = False
                if eager and S["qi"] >= rebirth_price():
                    eager_at = s if eager_at is None else eager_at
                    if s - eager_at >= react:
                        eager_at = None
                        do_rebirth()
                        continue
                else:
                    eager_at = None
                if built:
                    if S["lives"] - 1 < gate(S["realm"] + 1):  # blocked: save for the rebirth
                        if S["qi"] >= rebirth_price():
                            do_rebirth()
                        continue
                    S.setdefault("bt", math.floor(cache["price"] * C["BREAKTHROUGH_SECONDS"]))
                    if S["qi"] >= S["bt"]:
                        pay("breakthrough", S.pop("bt"))
                        sink["reset loss"] = sink.get("reset loss", 0) + S["qi"]
                        log["realms"].append(dict(life=S["lives"], realm=S["realm"], t=clock["play"] - clock["realm_t"], at=clock["play"], day=day))
                        S.update(realm=S["realm"] + 1, qi=0.0, owned=(S["owned"] & keep) if PLAN1 else set(), workers={}, rr=0, pill=False, pill_t=0, boost=0)
                        S["best"] = max(S["best"], S["realm"])
                        snap.clear()
                        clock["realm_t"] = clock["play"]
                        recalc()
                    continue
                choices = open_pads()
                target = min(choices, key=pad_cost)
                tcost = pad_cost(target)
                # recruits: an xN press when it costs no more than the next building (the HUD's seal)
                if "hall" in S["owned"]:
                    b10 = sum(recruit_cost(S["rr"] + i) for i in range(batch))
                    if b10 <= tcost and S["qi"] >= b10:
                        pay("recruits", b10)
                        bank -= b10
                        S["rr"] += batch
                        for _ in range(batch):
                            seat(roll())
                        recalc()
                        continue
                hires = [(worker_cost(i), i) for i in C["WORKER_PADS"]
                         if i in S["owned"] and S["workers"].get(i, 0) < C["WORKER_MAX"]]
                if hires and min(hires)[0] < tcost:
                    wc, wi = min(hires)
                    if S["qi"] >= wc:
                        pay("workers", wc)
                        S["workers"][wi] = S["workers"].get(wi, 0) + 1
                        snap.clear()
                        recalc()
                    continue
                if S["qi"] >= tcost:
                    walk_until = walk_until if walk_until is not None else s + (0 if lvl("hands") or auto_build(target["id"]) else K["walk"])
                    if s >= walk_until:
                        walk_until = None
                        pay("buildings", tcost)
                        S["owned"].add(target["id"])
                        S["ever"].add(target["id"])
                        snap.clear()
                        first = log.setdefault("first", {}).setdefault(S["realm"], S["lives"])
                        wk = (S["realm"], first == S["lives"])
                        if bank <= 0:
                            log["waits"].setdefault(wk, []).append(clock["play"] - last_buy)
                        bank -= tcost
                        last_buy = clock["play"]
                        if target["id"] == "platform" and not S.get("starter_chest"):  # the starter chest comes with it
                            S["starter_chest"] = True
                            add("starter chest", C.get("CHEST_STARTER_QI", 0))
                            for _ in range(int(C.get("CHEST_STARTER_SUMMONS", 0))):
                                seat(roll())
                        recalc()
        log["days"].append(dict(day=day + 1, realm=S["realm"], lives=S["lives"], mult=1 + C["REBIRTH_BONUS"] * (S["lives"] - 1),
                                dmult=dmult(), stars=stars(), deepest=max([S["realm"]] + [x["realm"] for x in log["lives"]])))
    return log, src, sink


def fmt(sec):
    return "%.0f s" % sec if sec < 90 else ("%.0f min" % (sec / 60) if sec < 5400 else "%.1f h" % (sec / 3600))


def share(d):
    t = sum(d.values()) or 1
    return ", ".join("%s %.0f%%" % (k, 100 * v / t) for k, v in sorted(d.items(), key=lambda x: -x[1]) if v / t >= 0.01)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--kind", default="regular")
    ap.add_argument("--policy", default="gated")
    ap.add_argument("--pre-d66", action="store_true", help="the build before D66 (a rebirth needed only the qi price)")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--buy", default="", help="comma list: x2,vip,auto,welcome,Primordial,...")
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--trace", action="store_true")
    ap.add_argument("--batch", type=int, default=10, help="recruits per press (1, 10, 50)")
    ap.add_argument("--set", action="append", default=[])
    ap.add_argument("--missions", action="store_true", help="Sect Missions on (stars at STAR_RATE, dailies, rank path rewards)")
    ap.add_argument("--old-prices", action="store_true", help="the D44 price floor from before 2026-10-24 (see PLAN1 above)")
    a = ap.parse_args()
    C = load(a.config)
    for kv in a.set:
        k, v = kv.split("=", 1)
        C[k] = eval(v)
    buy = tuple(x for x in a.buy.split(",") if x)
    global PRE_D66, PLAN1
    PRE_D66 = a.pre_d66
    PLAN1 = not a.old_prices
    runs = [sim(C, a.kind, a.policy, a.days, seed, buy, batch=a.batch, missions=a.missions) for seed in range(1, a.seeds + 1)]
    log, src, sink = runs[0]
    print("kind=%s policy=%s buy=%s days=%d batch=x%d" % (a.kind, a.policy, ",".join(buy) or "-", a.days, a.batch))
    print("day | realm | deepest | rebirths | rebirth x | disciples x | index stars   (median of %d seeds)" % a.seeds)
    for d in (1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60):
        if d <= a.days:
            rows = [r[0]["days"][d - 1] for r in runs]
            m = lambda k: statistics.median(x[k] for x in rows)  # noqa: E731
            print("%3d | %5d | %7d | %8d | x%.1f | x%.0f | %d" % (d, m("realm"), m("deepest"), m("lives") - 1, m("mult"), m("dmult"), m("stars")))
    print("first rebirth after %s played" % (fmt(log["lives"][0]["t"]) if log["lives"] else "-"))
    if len(log["lives"]) < 60:
        print("lives (seed 1): " + ", ".join("%d:R%d %s" % (L["life"], L["realm"], fmt(L["t"])) for L in log["lives"]))
    waits = {}
    for r in runs:
        for k, v in r[0]["waits"].items():
            waits.setdefault(k, []).extend(v)
    if waits:
        print("waits between pads while playing (all seeds): realm, first life there or replay: typical / slowest 10% / longest")
        for k in sorted(waits):
            v = sorted(waits[k])
            print("  realm %2d %-6s %5d pads  %8s / %8s / %8s" % (k[0], "first" if k[1] else "replay", len(v) // a.seeds, fmt(v[len(v) // 2]), fmt(v[int(len(v) * 0.9)]), fmt(v[-1])))
    if a.missions:
        print("sect mission ranks reached at play time (seed 1): " + ", ".join("r%d %s" % (i + 2, fmt(t)) for i, t in enumerate(log.get("ranks", [])[:12])))
    print("sources: " + share(src))
    print("sinks:   " + share(sink))
    if a.trace:
        for r in log["realms"][:400]:
            print("  life %3d realm %2d -> %2d  %8s  day %d" % (r["life"], r["realm"], r["realm"] + 1, fmt(r["t"]), r["day"] + 1))
        for L in log["lives"][:200]:
            print("  rebirth from life %3d at realm %2d after %s" % (L["life"], L["realm"], fmt(L["t"])))


if __name__ == "__main__":
    main()
