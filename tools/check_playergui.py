"""Gate: nothing a script needs may live where the first spawn wipes it (R19, D68).

Why (2026-10-22 live bug): Main sets CharacterAutoLoads = false and calls LoadCharacter once the save
has loaded. In Studio that happens before the client scripts run; on a live server it happens AFTER
them, and every LoadCharacter empties PlayerGui of everything except guis with ResetOnSpawn = false.
The menus' BindableEvents (IndexOpen, ShopOpen, ReincOpen, RecruitFx) and the HudSlots folder lived in
PlayerGui, so live the Index, Shop, Reincarnation and recruit reveal silently never opened, while
every Studio test passed. Studio cannot show this bug; this check can.

Rules, per file under src/:
  A. Whatever is parented to PlayerGui is a ScreenGui / BillboardGui / SurfaceGui made with
     ResetOnSpawn = false. Signals, folders and values go on the Player instead.
  B. A PlayerGui:FindFirstChild / WaitForChild("Name") names a gui some script makes under rule A
     (or one of Roblox's own, ROBLOX_GUIS).

    python tools/check_playergui.py            # exit 1 on any finding
    python tools/check_playergui.py --selftest # positive control: the pre-fix code must fail
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUI_CLASSES = {"ScreenGui", "BillboardGui", "SurfaceGui"}
ROBLOX_GUIS = {"TouchGui", "Chat", "BubbleChat", "Freecam"}

# an expression that IS the PlayerGui (besides a local bound to it)
# ...and ends there (`playerGui.Foo` / `playerGui:Bar()` are something else); same line only
END = r"(?![ \t]*[.:\w(])"
PG_DIRECT = r'(?:\w+:WaitForChild\("PlayerGui"[^)]*\)|\w+:FindFirstChild\("PlayerGui"\)|\w+\.PlayerGui\b|\w+:FindFirstChildOfClass\("PlayerGui"\))'


def strip_comments(src: str) -> str:
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def pg_expr(src: str) -> str:
    names = re.findall(r"\blocal\s+(\w+)\s*=\s*" + PG_DIRECT + END, src)
    alts = [PG_DIRECT] + [rf"\b{re.escape(n)}\b" for n in names]
    return "(?:" + "|".join(alts) + ")"


def check_source(path: str, src: str):
    """-> (findings, gui names this file makes safely, names it looks up)"""
    src = strip_comments(src)
    pg = pg_expr(src)
    findings, safe_names, lookups = [], set(), []

    def line_of(pos):
        return src.count("\n", 0, pos) + 1

    # A: `v.Parent = <PlayerGui>`
    for m in re.finditer(rf"\b(\w+)\.Parent\s*=\s*{pg}{END}", src):
        v = m.group(1)
        cls = re.search(rf"\b{re.escape(v)}\s*=\s*Instance\.new\(\"(\w+)\"\)", src)
        cls = cls.group(1) if cls else None
        where = f"{path}:{line_of(m.start())}"
        if cls not in GUI_CLASSES:
            findings.append(f"{where}: `{v}` ({cls or 'unknown class'}) is parented to PlayerGui; "
                            "the first spawn wipes it. Parent it to the Player.")
            continue
        if not re.search(rf"\b{re.escape(v)}\.ResetOnSpawn\s*=\s*false\b", src):
            findings.append(f"{where}: {cls} `{v}` in PlayerGui without `{v}.ResetOnSpawn = false`; "
                            "the first spawn wipes it.")
            continue
        for n in re.findall(rf"\b{re.escape(v)}\.Name\s*=\s*\"(\w+)\"", src):
            safe_names.add(n)
    # A: `Parent = <PlayerGui>` inside a props table (the class is not knowable here)
    for m in re.finditer(rf"(?<![.\w])Parent\s*=\s*{pg}{END}", src):
        findings.append(f"{path}:{line_of(m.start())}: something is parented to PlayerGui through a props "
                        "table; write `v.Parent = playerGui` after `v.ResetOnSpawn = false` so this check can see it.")
    # B: lookups by name
    for m in re.finditer(rf"{pg}\s*:\s*(?:FindFirstChild|WaitForChild)\(\"(\w+)\"", src):
        lookups.append((f"{path}:{line_of(m.start())}", m.group(1)))
    return findings, safe_names, lookups


def check_tree(files):
    """files: {path: source} -> findings"""
    findings, safe, lookups = [], set(ROBLOX_GUIS), []
    for path, src in sorted(files.items()):
        f, s, l = check_source(path, src)
        findings += f
        safe |= s
        lookups += l
    for where, name in lookups:
        if name not in safe:
            findings.append(f"{where}: looks up PlayerGui.{name}, which no script makes as a gui with "
                            "ResetOnSpawn = false; live it is gone after the first spawn. Look it up on the Player.")
    return findings


def load_tree():
    return {str(p.relative_to(ROOT)).replace("\\", "/"): p.read_text(encoding="utf-8")
            for p in sorted((ROOT / "src").rglob("*.luau"))}


def selftest():
    """Positive control: each pattern of the 2026-10-22 bug must be caught, the fixed forms must pass."""
    bad = {
        "a.luau": 'local playerGui = player:WaitForChild("PlayerGui")\n'
                  'local ev = Instance.new("BindableEvent")\nev.Name = "IndexOpen"\nev.Parent = playerGui\n',
        "b.luau": 'local pg = player:WaitForChild("PlayerGui")\nlocal ev = pg:FindFirstChild("IndexOpen")\n',
        "c.luau": 'local bb = Instance.new("BillboardGui")\nbb.Parent = player:WaitForChild("PlayerGui")\n',
        "d.luau": 'local f = Instance.new("Folder")\nf.Parent = player.PlayerGui\n',
    }
    good = {
        "a.luau": 'local playerGui = player:WaitForChild("PlayerGui")\n'
                  'local ev = Instance.new("BindableEvent")\nev.Name = "IndexOpen"\nev.Parent = player\n'
                  'local g = Instance.new("ScreenGui")\ng.Name = "Hud"\ng.ResetOnSpawn = false\ng.Parent = playerGui\n'
                  'local h = playerGui:FindFirstChild("Hud")\nlocal t = playerGui:FindFirstChild("TouchGui")\n'
                  '-- ev.Parent = playerGui (a comment is ignored)\n'
                  'local hud = player.PlayerGui:FindFirstChild("Hud")\nlocal c = hud:FindFirstChild("Counter", true)\n',
    }
    caught = check_tree(bad)
    missed = [k for k in bad if not any(f.startswith(k + ":") for f in caught)]
    clean = check_tree(good)
    ok = not missed and not clean
    print(f"selftest: {len(caught)} findings on the bad tree (missed: {missed or 'none'}), "
          f"{len(clean)} on the good tree -> {'OK' if ok else 'FAIL'}")
    for f in clean:
        print("  unexpected:", f)
    return ok


def main():
    if "--selftest" in sys.argv:
        sys.exit(0 if selftest() else 1)
    files = load_tree()
    findings = check_tree(files)
    for f in findings:
        print(f)
    print(f"check_playergui: {len(files)} files, {len(findings)} findings")
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
