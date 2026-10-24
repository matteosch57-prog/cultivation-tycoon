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
        expr = {"true": "True", "false": "False"}.get(expr, expr)
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
            isl = re.search(r'islet = "(\w+)"', line)
            kd = re.search(r'kind = "(\w+)"', line)
            st = re.search(r'seats = (\d+)', line)  # a slot pad's seats (Config.maxDisciples)
            kl = re.search(r'karma = (\d+)', line)  # the karma node level an isle pad needs
            pads.append(dict(id=m.group(1), cost=int(m.group(2)), income=int(m.group(3)), unlock=int(m.group(4)),
                             req=re.findall(r'"(\w+)"', m.group(5)), district=d.group(1) if d else None,
                             islet=isl.group(1) if isl else None, kind=kd.group(1) if kd else None,
                             seats=int(st.group(1)) if st else 1, karma=int(kl.group(1)) if kl else 1))
    # Sky Islets (D42): a pad on an islet needs that islet's bridge (Config.isletOf / isletOpen)
    islets = {}
    for line in block("ISLETS"):
        m = re.match(r'\s*(\w+) = \{.*?(?:bridge = "(\w+)")?\s*\},?$', line)
        if m:
            islets[m.group(1)] = m.group(2)
    for p in pads:
        name = p["islet"] or (p["district"] if p["district"] in islets else "heart")
        b = islets.get(name)
        if b and b != p["id"] and b not in p["req"]:
            p["req"].append(b)
    rar = [(float(w), float(b)) for w, b in re.findall(r"weight = ([\d.]+), bonus = ([\d.]+)", "\n".join(block("RARITIES")))]
    env["RARITY_NAMES"] = re.findall(r'name = "([^"]+)", weight', "\n".join(block("RARITIES")))
    dao = {}
    for line in block("DAO"):
        m = re.search(r'key = "(\w+)".*?costs = \{([^}]*)\}', line)
        if m:
            dao[m.group(1)] = [int(x) for x in re.findall(r"\d+", m.group(2))]
    workers = re.findall(r"^\s*(\w+) = \{ name", "\n".join(block("WORKERS")), re.M)
    env.update(PADS=pads, RARITIES=rar, DAO=dao, WORKER_PADS=workers)
    # pity (2026-10-23, Anime Defenders): Config.PITY = { { rarity = "Celestial", at = 1000 }, ... } -> {tier index: at}
    m = re.search(r"^Config\.PITY = \{(.*)\}$", src, re.M)
    if m:
        env["PITY"] = {env["RARITY_NAMES"].index(n): int(a) for n, a in re.findall(r'rarity = "([^"]+)", at = (\d+)', m.group(1))}
    # D63 rebirth (Muscle Legends): Config.REBIRTH_REALMS = { [realm] = rebirths needed, ... }
    m = re.search(r"^Config\.REBIRTH_REALMS = \{([^}]*)\}", src, re.M)
    if m:
        env["REBIRTH_REALMS"] = {int(a): int(b) for a, b in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", m.group(1))}
    # D48: Config.REALM_PADS (pads that first open in realm r) -> REALM_OF; BREAKTHROUGH_SECONDS -> BT_S
    rp = [re.findall(r'"(\w+)"', line) for line in block("REALM_PADS") if "{" in line]
    if rp:
        env["REALM_OF"] = {p["id"]: len(rp) for p in pads}
        for r, ids in enumerate(rp, 1):
            for i in ids:
                env["REALM_OF"][i] = r
        for p in pads:  # Config.DECOR_FROM_REALM: paths and groves wait for it
            if p["kind"] in ("path", "grove"):
                env["REALM_OF"][p["id"]] = max(env["REALM_OF"][p["id"]], int(env.get("DECOR_FROM_REALM", 1)))
    # Config.STREAK (Daily Blessing, D58): a table of tables the flat parser skips -> the sim's STREAK form
    if "STREAK" not in env or not isinstance(env.get("STREAK"), list) or (env["STREAK"] and not isinstance(env["STREAK"][0], dict)):
        st_ = []
        for line in block("STREAK"):
            if "{" not in line:
                continue
            e = {}
            q = re.search(r"qiSec = (\d+)", line)
            if q:
                e["qi_s"] = int(q.group(1))
            sm = re.search(r"^\s*\{[^{]*?summons = (\d+)", line)
            if sm:
                e["summons"] = int(sm.group(1))
            r = re.search(r'rarity = "([^"]+)"', line)
            if r:
                e["disciple"] = r.group(1)
                a = re.search(r"again = \{ summons = (\d+)", line)
                e["else_summons"] = int(a.group(1)) if a else 3
            st_.append(e)
        if st_:
            env["STREAK"] = st_
    # once-a-day qi: the Shop's free Daily Gift (SHOP_FREE_SECONDS); blessings are added per kind
    env.setdefault("DAILY_QI_S", env.get("SHOP_FREE_SECONDS", 0))
    if "BREAKTHROUGH_SECONDS" in env:
        env["BT_S"] = env["BREAKTHROUGH_SECONDS"]
    for k, v in dict(HARMONY_STEP=0, HARMONY_MAX=0, WALK_SCALE=1, DISTRICT_BONUS=0, FRIEND_STEP=0, FRIEND_MAX=0, GROUP_BONUS=0, WELCOME_QI=0, PASS_QI_MULT=2,
                     VIP_SLOTS=1, DAO_PILL_SECONDS=30, DAO_OFFLINE_SECONDS=7200, DAO_ECHO=0.1,
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
DAO_ORDER = ["hands", "isles", "foundation", "elixir", "meditation", "sworn", "seat", "echo"]  # sworn: gone in D44 (skipped)  # cheapest comfort first


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
    pad_seats = {p["id"]: p.get("seats", 1) for p in C["PADS"]}  # a slot pad's seats (Config.maxDisciples)
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
        m = C["REALM_COST_MULT"] ** (min(r, lf) - 1) * C["REALM_COST_LATE"] ** max(0, r - lf)
        # PRICE_PL_EXP (proposal lever): prices follow the Past Lives multiplier ^ this, so a rich soul
        # still has to choose what to build first
        if C.get("PRICE_PL_EXP"):
            m *= (C["PAST_LIVES_MULT"] ** max(0, S["soul"] - (C["REINC_REALM"] - 1))) ** C["PRICE_PL_EXP"]
        return m

    def max_disc():
        return C["MAX_DISCIPLES"] + vip + lvl("seat") + sum(int(pad_seats.get(p, 1)) for p in C["SLOT_PADS"] if p in S["owned"])

    def dmult(price=False):
        seated = sorted(S["disciples"], reverse=True)[:max_disc()]
        # DISCIPLE_STAR_BONUS (stars on the disciple, owner 2026-10-22): a seated disciple's bonus x
        # (1 + this x its own index entry's stars); outside the price income unless DISCIPLE_STAR_IN_PRICE
        per = C.get("DISCIPLE_STAR_BONUS", 0)
        if not per or (price and not C.get("DISCIPLE_STAR_IN_PRICE")):
            return 1 + sum(seated)
        return 1 + sum(d * (1 + per * star_of(getattr(d, "key", None))) for d in seated)

    def dist(i):
        p = pads[i]
        if not p["district"] or p["district"] == "heart" or p["income"] <= 0:
            return 1
        return 1 + C["DISTRICT_BONUS"] * sum(1 for j in S["owned"] if j != i and pads[j]["district"] == p["district"] and pads[j]["income"] > 0)

    def base():  # rate(s, away) without the live-only multipliers
        b = C["BASE_RATE"] + sum(pads[i]["income"] * (1 + C["WORKER_BONUS"] * S["workers"].get(i, 0)) * dist(i) for i in S["owned"])
        past = C["PAST_LIVES_MULT"] ** max(0, S["soul"] - (C["REINC_REALM"] - 1))
        if "REBIRTH_BONUS" in C:  # D63: +REBIRTH_BONUS a rebirth, adding up (rebirths = life - 1)
            past = 1 + C["REBIRTH_BONUS"] * (S["life"] - 1)
            if C.get("REBIRTH_POW"):  # lever: multiplicative instead (x REBIRTH_POW a rebirth)
                past = C["REBIRTH_POW"] ** (S["life"] - 1)
        # Harmony (Config.harmonyMult): every owned path or grove, capped
        harm = 1 + min(C["HARMONY_STEP"] * sum(1 for i in S["owned"] if pads[i].get("kind") in ("path", "grove")), C["HARMONY_MAX"])
        return b * C["REALM_INCOME_MULT"] ** (S["realm"] - 1) * dmult() * x2 * past * harm * idx_mult()

    # INDEX_STARS (disciple index lever): pulls of one rarity x look give stars at these counts;
    # each star adds INDEX_STAR_BONUS income (outside the price income); every INDEX_STEP_STARS stars
    # pays INDEX_STEP_SUMMONS free summons
    idx = {"pulls": {}, "stars": 0, "paid_steps": 0}
    out["index"] = idx

    def idx_mult():
        return 1 + C.get("INDEX_STAR_BONUS", 0) * idx["stars"]

    def star_of(key):  # Config.indexStars: the stars of one entry
        n = idx["pulls"].get(key, 0)
        return sum(1 for at in C.get("INDEX_STARS", []) if n >= at)

    class Disc(float):  # a disciple's bonus that remembers its index entry (rarity, look)
        key = None

    def idx_record(i):
        if not C.get("INDEX_STARS"):
            return None
        key = (i, rng.randrange(int(C.get("INDEX_LOOKS", 4))))
        n = idx["pulls"].get(key, 0) + 1
        idx["pulls"][key] = n
        if n in C["INDEX_STARS"]:
            idx["stars"] += 1
            steps = idx["stars"] // int(C.get("INDEX_STEP_STARS", 10))
            while idx["paid_steps"] < steps:
                idx["paid_steps"] += 1
                for _ in range(int(C.get("INDEX_STEP_SUMMONS", 0))):
                    S["disciples"].append(roll())
                S["disciples"].sort(reverse=True)
                del S["disciples"][C["DISCIPLE_CAP"] + vip:]
        return key

    def price_base():  # Main priceRate: base() without the paid 2x pass, the index, rebirth and Harmony boosts
        rb = 1
        if C.get("REBIRTH_OUT_OF_PRICE", True) and "REBIRTH_BONUS" in C:  # D63: the rebirth boost is left out of prices (Main priceRate)
            rb = C["REBIRTH_POW"] ** (S["life"] - 1) if C.get("REBIRTH_POW") else 1 + C["REBIRTH_BONUS"] * (S["life"] - 1)
        harm = 1 + min(C["HARMONY_STEP"] * sum(1 for i in S["owned"] if pads[i].get("kind") in ("path", "grove")), C["HARMONY_MAX"])
        if not C.get("HARMONY_IN_PRICE"):  # D67: Harmony is left out of prices (Main priceRate)
            rb *= harm
        return base() / (x2 * idx_mult() * rb) * dmult(True) / dmult()

    pity = {}  # PITY (Main roll): {tier index: rolls since that tier or better}

    def roll():  # Main roll: the weights, then pity (Config.PITY), then Shiny (SHINY_CHANCE x SHINY_MULT)
        x = rng.uniform(0, sum(w for w, _ in C["RARITIES"]))
        pick = 0
        for i, (w, b) in enumerate(C["RARITIES"]):
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
        b = C["RARITIES"][pick][1]
        if C.get("SHINY_CHANCE") and rng.random() < C["SHINY_CHANCE"]:
            b *= C.get("SHINY_MULT", 1)
        d = Disc(b)
        d.key = idx_record(pick)
        return d

    # REALM_PADS (proposal lever, owner 2026-10-22 "unlock more with the realms"): realm r offers only
    # the first REALM_PADS[r] pads of the ladder (sorted by unlock, then list order); the rest wait
    order = sorted(range(len(C["PADS"])), key=lambda i: (C["PADS"][i]["unlock"], i))
    rank = {C["PADS"][i]["id"]: k for k, i in enumerate(order)}

    def in_realm(p, r=None):
        r = S["realm"] if r is None else r
        if C.get("REALM_OF"):  # REALM_OF = {pad id: first realm it is offered} (explicit map)
            return C["REALM_OF"].get(p["id"], 1) <= r
        rp = C.get("REALM_PADS")
        if not rp:
            return True
        return rank[p["id"]] < rp[min(r, len(rp)) - 1]

    def open_pads():
        n = len(S["owned"])
        return [p for p in C["PADS"] if p["id"] not in S["owned"] and n >= p["unlock"] and in_realm(p)
                and all(r in S["owned"] for r in p["req"]) and (p.get("kind") != "isle" or lvl("isles") >= p.get("karma", 1))]

    def needed(p):  # Config.neededForBreakthrough: paths and groves are optional when DECOR_OPTIONAL
        return p.get("kind") != "isle" and not (C.get("DECOR_OPTIONAL") and p.get("kind") in ("path", "grove"))

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
        # LAND_HALF (proposal lever): a new life starts at half the deepest realm, fully built
        share = C.get("LAND_HALF") or C.get("REINC_LAND_SHARE")  # Config.REINC_LAND_SHARE (D40)
        land = max(1, int(S["soul"] * share)) if share else 1
        S.update(realm=land, qi=0.0, workers={}, realm_recruits=0, pill_ready=False, pill_t=0.0, boost=0.0)
        S["owned"] = {p["id"] for p in C["PADS"] if in_realm(p, land)} if C.get("LAND_BUILT", True) else set()  # D56: always built
        if "SWORN_BASE" in C:  # before D44 only the sworn ones followed; now every disciple does
            S["disciples"] = sorted(S["disciples"], reverse=True)[:int(C["SWORN_BASE"]) + lvl("sworn")]
        for k in DAO_ORDER:  # spend karma: cheapest comfort first, one level at a time
            costs = C["DAO"].get(k)
            while costs and lvl(k) < len(costs) and S["karma"] >= costs[lvl(k)]:
                S["karma"] -= costs[lvl(k)]
                S["dao"][k] = lvl(k) + 1
        life_start_play, life_start_day = played, day

    def rebirths_for(realm):  # Config.rebirthsFor: the table, then +ceil(i/2) every odd realm past it (D66)
        tab = C.get("REBIRTH_REALMS", {})
        need = max([n for r, n in tab.items() if realm >= r] or [0])
        if tab and not C.get("REBIRTH_GATES_END"):
            last = max(tab)
            n, i = tab[last], 9
            for r in range(last + 2, realm + 1, 2):
                n += -(-i // 2)
                i += 1
                need = n
        return need

    def rebirth(day):  # D63: back to realm 1 built, keep disciples, karma = KARMA + STEP x rebirths
        nonlocal life_start_play, life_start_day
        n = S["life"] - 1
        gain = int((C["REBIRTH_KARMA"] + C["REBIRTH_KARMA_STEP"] * n) * (1 + C["DAO_ECHO"] * lvl("echo")))
        out["lives"].append(dict(life=S["life"], realm=S["realm"], play_s=played - life_start_play, day=day,
                                 karma=gain, past=1 + C["REBIRTH_BONUS"] * (n + 1)))
        led_sink["reset loss"] = led_sink.get("reset loss", 0) + S["qi"]
        out["lives"][-1]["src"], out["lives"][-1]["sink"] = dict(life_src), dict(life_sink)
        life_src.clear()
        life_sink.clear()
        S["karma"] += gain
        S["soul"] = max(S["soul"], S["realm"])
        S["life"] += 1
        land = max(1, int(S["soul"] * C["REBIRTH_LAND_SHARE"])) if C.get("REBIRTH_LAND_SHARE") else 1  # lever
        S.update(realm=land, qi=0.0, workers={}, realm_recruits=0, pill_ready=False, pill_t=0.0, boost=0.0)
        S.pop("bt_frozen", None)
        S["owned"] = {p["id"] for p in C["PADS"] if in_realm(p, land)}
        for k in DAO_ORDER:
            costs = C["DAO"].get(k)
            while costs and lvl(k) < len(costs) and S["karma"] >= costs[lvl(k)]:
                S["karma"] -= costs[lvl(k)]
                S["dao"][k] = lvl(k) + 1
        life_start_play, life_start_day = played, day

    if C["WELCOME_QI"]:
        src("welcome", C["WELCOME_QI"])
    def starter_chest():  # the starter idle chest: qi + free summons, filled when the platform is built
        if C.get("CHEST_STARTER_QI") and not S.get("starter_chest"):
            S["starter_chest"] = True
            src("starter chest", C["CHEST_STARTER_QI"])
            for _ in range(int(C.get("CHEST_STARTER_SUMMONS", 0))):
                S["disciples"].append(roll())
            S["disciples"].sort(reverse=True)
    session_gap = 24 * 3600 / K["per_day"] - K["session"] * 60
    rar_bonus = {n: b for n, b in zip(C.get("RARITY_NAMES", []), [b for _, b in C["RARITIES"]])}
    streak_once = set()
    for day in range(days):
        # STREAK (login streak, proposal lever): day d's reward on the first join of the day; a list of
        # dicts {qi_s, summons, disciple (rarity name, once per save; repeats give `else_summons`)}
        if C.get("DAILY_QI_S"):  # DAILY_QI_S (lever): seconds of income paid once a day (free shop gift, blessings)
            src("daily extras", base() * C["DAILY_QI_S"])
        if C.get("STREAK"):
            r = C["STREAK"][day % len(C["STREAK"])]
            if r.get("qi_s"):
                src("login streak", base() * r["qi_s"])
            summons = r.get("summons", 0)
            if r.get("disciple"):
                if r["disciple"] not in streak_once:
                    streak_once.add(r["disciple"])
                    S["disciples"].append(rar_bonus[r["disciple"]])
                else:
                    summons += r.get("else_summons", 3)
            for _ in range(summons):
                S["disciples"].append(roll())
            S["disciples"].sort(reverse=True)
            del S["disciples"][C["DISCIPLE_CAP"] + vip:]
        for _ in range(K["per_day"]):
            if played:
                away = min(session_gap, C["OFFLINE_CAP"] + C["DAO_OFFLINE_SECONDS"] * lvl("meditation"))
                src("offline", base() * away * C.get("OFFLINE_RATE", 1))  # Main onJoin: x OFFLINE_RATE
                if C.get("CHEST_SUMMON_EVERY") and "platform" in S["owned"]:  # idle chest (stands with the platform): a free summon per CHEST_SUMMON_EVERY s away
                    for _ in range(min(int(away // C["CHEST_SUMMON_EVERY"]), int(C.get("CHEST_SUMMON_MAX", 99)))):
                        S["disciples"].append(roll())
                        S["disciples"].sort(reverse=True)
                        del S["disciples"][C["DISCIPLE_CAP"] + vip:]
                        led_src["free summons"] = led_src.get("free summons", 0)
            tide_phase = rng.uniform(0, C["TIDE_INTERVAL"])
            walking = None
            # GIFT_DAILY (D49): the ladder counts play time over the whole day and restarts each day
            if not C.get("GIFT_DAILY") or S.get("gift_day") != day:
                S.update(gift_day=day, gift_i=0, gift_play=0)
            gift_i = S["gift_i"]
            walk = 0 if lvl("hands") else st["walk"] * C["WALK_SCALE"]  # WALK_SCALE: islets' longer walks
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
                S["gift_play"] = S.get("gift_play", 0) + 1
                if gift_i < len(C["GIFT_TIMES"]) and S["gift_play"] >= C["GIFT_TIMES"][gift_i]:
                    src("playtime gifts", b * C["GIFT_VALUE"][gift_i])
                    for _ in range(int((C.get("GIFT_SUMMONS") or [0] * 99)[gift_i])):  # free summons on some gifts
                        S["disciples"].append(roll())
                        S["disciples"].sort(reverse=True)
                        del S["disciples"][C["DISCIPLE_CAP"] + vip:]
                    S["boost"] += (C.get("GIFT_PILL") or [0] * 99)[gift_i]  # a 2x qi pill (Main ClaimGift: boostUntil +)
                    gr = (C.get("GIFT_RARITY") or [""] * 99)[gift_i]
                    if gr:  # a disciple of that rarity, every day it is reached (addDisciple, never turned away)
                        S["disciples"].append(rar_bonus[gr])
                        S["disciples"].sort(reverse=True)
                        del S["disciples"][C["DISCIPLE_CAP"] + vip:]
                    gift_i += 1
                    S["gift_i"] = gift_i
                if altar_win is not None and "ALTAR_INTERVAL" in C and (s + tide_phase - (C["ALTAR_FIRST"] - C["TIDE_FIRST"])) % C["ALTAR_INTERVAL"] < 1:
                    won = rng.random() < altar_win
                    src("heavenly altar", b * (C["ALTAR_WIN_SECONDS"] if won else C["ALTAR_JOIN_SECONDS"]))

                # spend: breakthrough / reincarnation, else the cheapest thing on offer
                choices = open_pads()
                # DECOR_OPTIONAL: once every required pad is owned the player saves for the breakthrough
                # (they skip the paths and groves still on offer); before that, decor is bought when it is
                # the cheapest thing open, like any pad
                if not any(needed(p) and in_realm(p) and p["id"] not in S["owned"] for p in C["PADS"]):
                    choices = []
                if not choices and "REBIRTH_PRICE" in C:
                    # D63: the next realm needs rebirths (REBIRTH_REALMS); blocked -> rebirth once the qi price is held
                    need = rebirths_for(S["realm"] + 1)
                    if S["life"] - 1 < need:
                        price = C["REBIRTH_PRICE"] + C["REBIRTH_PRICE_STEP"] * (S["life"] - 1)
                        if S["qi"] >= price:
                            sink("rebirth", price)
                            rebirth(day + 1)
                            out["milestones"].setdefault("life %d" % S["life"], played)
                            if len(out["lives"]) >= lives:
                                return out, led_src, led_sink
                        continue
                if not choices:
                    bt = C["BREAKTHROUGH_COST"] * cmult()
                    if C.get("BT_S"):  # BT_S = Config.BREAKTHROUGH_SECONDS (D48): BT_S s of the price income the realm ends on
                        S.setdefault("bt_frozen", price_base() * C["BT_S"])
                        bt = S["bt_frozen"]
                    if S["qi"] >= bt:
                        sink("breakthrough", bt)
                        realm_done(day + 1)
                        carry = S["qi"] if C.get("CARRY_QI") else 0.0  # CARRY_QI: proposal lever (server wipes it)
                        led_sink["reset loss"] = led_sink.get("reset loss", 0) + S["qi"] - carry
                        life_sink["reset loss"] = life_sink.get("reset loss", 0) + S["qi"] - carry
                        S["realm"] += 1
                        S.pop("bt_frozen", None)
                        keep = S["owned"] if C.get("KEEP_ON_BT") else set()  # KEEP_ON_BT: buildings stay (only a new life resets)
                        kw = S["workers"] if C.get("KEEP_ON_BT") else {}
                        S.update(qi=carry, owned=keep, workers=kw, realm_recruits=0, pill_ready=False, pill_t=0.0, boost=0.0)
                        realm_start = played
                        out["milestones"].setdefault("realm %d" % S["realm"], played)
                        if "REBIRTH_PRICE" not in C and S["realm"] >= max(C["REINC_REALM"], S["soul"] + 1) and S["life"] <= lives:
                            reincarnate(day + 1)
                            out["milestones"].setdefault("life %d" % S["life"], played)
                            if len(out["lives"]) >= lives:
                                return out, led_src, led_sink
                    continue
                target = min(choices, key=lambda p: p["cost"])
                # PRICE_FLOOR_S (proposal lever): a building costs at least this many seconds of income
                # PRICE_FLOOR_FROM_LIFE: the first life(s) stay fast (D25 "first realms fast"), the floor starts later
                floor = price_base() * C.get("PRICE_FLOOR_S", 0) if S["life"] >= C.get("PRICE_FLOOR_FROM_LIFE", 1) else 0
                tcost = max(target["cost"] * cmult(), floor)
                hire = hires()
                # RECRUIT_POW (proposal lever): each recruit in a realm costs x RECRUIT_POW the last (else +GROWTH, linear)
                n_r = S["realm_recruits"]

                def single(k):
                    return C["RECRUIT_BASE"] * cmult() * (C["RECRUIT_POW"] ** k if C.get("RECRUIT_POW") else 1 + k * C["RECRUIT_GROWTH"])
                # RECRUIT_BATCH (D52 lever): the player presses xN; BATCH_RULE prices it
                #   "sum": the next N single prices (Config.recruitBatchCost today), step N
                #   "flat": N x the current single price, step BATCH_STEP(N) (1, "sqrt" or N)
                nb = int(C.get("RECRUIT_BATCH", 1))
                if C.get("BATCH_RULE", "sum") == "sum":
                    rc, step = sum(single(n_r + i) for i in range(nb)), nb
                else:
                    rc = nb * single(n_r)
                    bs = C.get("BATCH_STEP", "sqrt")
                    step = 1 if bs == "one" else (math.ceil(nb ** 0.5) if bs == "sqrt" else nb)
                if "hall" in S["owned"] and rc <= st["recruit"] * tcost * nb and S["qi"] >= rc:
                    sink("recruits", rc)
                    S["realm_recruits"] += step
                    for _ in range(nb):
                        S["disciples"].append(roll())
                    S["disciples"].sort(reverse=True)
                    del S["disciples"][C["DISCIPLE_CAP"] + vip:]
                    out["rolls"] = out.get("rolls", 0) + nb
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
                        # choice metrics: how many open pads could be paid right now, how long since the last buy
                        out.setdefault("kind_buys", []).append(dict(kind=target.get("kind"), id=target["id"], secs=tcost / base(), realm=S["realm"], life=S["life"]))
                        afford = sum(1 for p in choices if max(p["cost"] * cmult(), floor) <= S["qi"])
                        out.setdefault("buys", []).append(dict(life=S["life"], realm=S["realm"], afford=afford, open=len(choices),
                                                               wait=played - out.get("last_buy", played)))
                        out["last_buy"] = played
                        sink("buildings", tcost)
                        S["owned"].add(target["id"])
                        if target["id"] == "platform":
                            starter_chest()
                        if len(choices) == 1:  # that was the realm's last building: how many recruits does a minute buy now?
                            budget, n, k = base() * 60, S["realm_recruits"], 0
                            while k < 500:
                                rck = C["RECRUIT_BASE"] * cmult() * (C.get("RECRUIT_POW", 0) and C["RECRUIT_POW"] ** (n + k) or (1 + (n + k) * C["RECRUIT_GROWTH"]))
                                if rck > budget:
                                    break
                                budget -= rck
                                k += 1
                            out.setdefault("spam", []).append(dict(life=S["life"], realm=S["realm"], per_min=k))
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
