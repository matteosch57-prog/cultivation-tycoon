"""Render docs/art/mocks/altar_arena.html (Heavenly Altar review, owner 2026-10-23) with Edge headless:
altar_arena_A|B|C.jpg (the three altars from the plaza) and altar_phone_<arena>_<btn>.jpg (749 x 381
phone HUD on the altar, Palm button 1 or 2). WebGL runs on SwiftShader, so one render at a time."""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
MOCKS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "art" / "mocks"


def shot(query, w, h, out):
    p = pathlib.Path(tempfile.mkdtemp()) / "shot.png"
    url = (MOCKS / "altar_arena.html").as_uri() + f"?{query}&w={w}&h={h}"
    subprocess.run([EDGE, "--headless=new", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
                    "--hide-scrollbars", "--virtual-time-budget=15000", "--force-device-scale-factor=2",
                    "--allow-file-access-from-files", f"--window-size={w},{h}", f"--screenshot={p}", url],
                   check=True, capture_output=True)
    Image.open(p).convert("RGB").save(MOCKS / out, quality=90)
    print(out)


def main():
    only = sys.argv[1:]
    jobs = [(f"arena={a}&view=hero", 1000, 560, f"altar_arena_{a}.jpg") for a in "ABC"]
    jobs += [(f"arena={a}&view=phone&btn={b}", 749, 381, f"altar_phone_{a}{b}.jpg") for a in "ABC" for b in "12"]
    for q, w, h, out in jobs:
        if not only or any(o in out for o in only):
            shot(q, w, h, out)


if __name__ == "__main__":
    main()
