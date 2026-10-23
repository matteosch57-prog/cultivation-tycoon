"""Line the Studio bot (tools/botsim.client.luau) up against tools/sim_check.py, minute by minute.

    python tools/botsim_compare.py BOTLOG.txt [--minutes 35] [--seeds 10]

BOTLOG.txt = the bot's _G.BOT.log lines ("t|kind|what|cost|q=..|r=..|R<realm>|L<life>"), one per line,
plus a last line "WAIT <seconds> <longest>". The sim plays the same player: one session of --minutes,
walk 6 s, orbs every 30 s, no incense blessing (a solo Play has nobody to give one).
"""

import argparse
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sim_check  # noqa: E402
from sim_game import load, DEFAULT_CONFIG  # noqa: E402


def sim_runs(minutes, seeds):
    sim_check.KINDS["bot"] = dict(session=minutes, per_day=1, walk=6, orb_every=30)
    C = load(str(DEFAULT_CONFIG))
    runs = []
    for seed in range(1, seeds + 1):
        ev = []
        sim_check.sim(C, "bot", "gated", 1, seed, (), bless=0, events=ev)
        runs.append(ev)
    return runs


def milestones(ev):
    """(first building s, [breakthrough s], [rebirth s], waiting s, longest wait s, buys)"""
    first, bts, rbs, buys = None, [], [], 0
    waits, longest, run, last = 0, 0, 0, None
    for t, k, v, realm, life in ev:
        if k == "wait":
            waits += 1
            run = run + 1 if last == t - 1 else 1
            last = t
            longest = max(longest, run)
            continue
        buys += 1
        if k == "buildings" and first is None:
            first = t
        if k == "breakthrough":
            bts.append(t)
        if k == "rebirth":
            rbs.append(t)
    return first, bts, rbs, waits, longest, buys


def bot_milestones(lines):
    first, bts, rbs, buys, waits, longest = None, [], [], 0, None, None
    for ln in lines:
        if ln.startswith("WAIT"):
            _, waits, longest = ln.split()
            continue
        f = ln.split("|")
        if len(f) < 3:
            continue
        t, kind, what = int(f[0]), f[1], f[2]
        if kind == "buy" and what.startswith("Pad_") and first is None:
            first = t
        if kind == "breakthrough" and what == "true":
            bts.append(t)
        if kind == "rebirth" and what == "true":
            rbs.append(t)
        if kind in ("buy", "recruit", "breakthrough", "rebirth") and what not in ("chest", "refused", "false"):
            buys += 1
    return first, bts, rbs, int(waits or 0), int(longest or 0), buys


def mmss(s):
    return "-" if s is None else "%d:%02d" % (s // 60, s % 60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("botlog")
    ap.add_argument("--minutes", type=int, default=35)
    ap.add_argument("--seeds", type=int, default=10)
    a = ap.parse_args()
    bot = bot_milestones(Path(a.botlog).read_text().splitlines())
    sims = [milestones(ev) for ev in sim_runs(a.minutes, a.seeds)]
    total = a.minutes * 60
    print("%-28s %-12s %s" % ("", "Studio bot", "sim_check (median of %d seeds, min-max)" % a.seeds))

    def row(name, b, vals, f=mmss):
        vals = [v for v in vals if v is not None]
        s = "%s (%s-%s)" % (f(int(statistics.median(vals))), f(min(vals)), f(max(vals))) if vals else "-"
        print("%-28s %-12s %s" % (name, f(b) if b is not None else "-", s))

    row("first building", bot[0], [s[0] for s in sims])
    for i in range(max(len(bot[1]), max(len(s[1]) for s in sims))):
        row("breakthrough %d" % (i + 1), bot[1][i] if i < len(bot[1]) else None, [s[1][i] if i < len(s[1]) else None for s in sims])
    for i in range(max(len(bot[2]), max(len(s[2]) for s in sims))):
        row("rebirth %d" % (i + 1), bot[2][i] if i < len(bot[2]) else None, [s[2][i] if i < len(s[2]) else None for s in sims])
    pct = lambda w: "%d%%" % round(100 * w / total)  # noqa: E731
    print("%-28s %-12s %s" % ("waiting (share of play)", pct(bot[3]), "%s (%s-%s)" % (
        pct(statistics.median(s[3] for s in sims)), pct(min(s[3] for s in sims)), pct(max(s[3] for s in sims)))))
    row("longest single wait", bot[4], [s[4] for s in sims])
    row("purchases", bot[5], [s[5] for s in sims], f=str)


if __name__ == "__main__":
    main()
