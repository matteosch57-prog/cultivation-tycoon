"""Render docs/art/mocks/loading.html (or tips.html with the first argument `tips`) (options A/B/C, frames 1-3) with Edge headless, one frame at
a time, and stitch each option into docs/art/mocks/loading_<opt>.jpg (three phone frames in a row)."""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
MOCKS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "art" / "mocks"
W, H, GAP = 844, 390, 12
PAGE = "loading.html"


def shot(query, out):
    url = (MOCKS / PAGE).as_uri() + "?" + query
    subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=4000",
                    f"--window-size={W},{H}", f"--screenshot={out}", url], check=True, capture_output=True)


def main():
    global PAGE
    args = sys.argv[1:]
    frames = 3
    if args and args[0] in ("tips", "streak"):  # docs/art/mocks/<page>.html -> <page>_<opt>.jpg
        PAGE, args = args[0] + ".html", args[1:]
        frames = 2 if PAGE == "streak.html" else 3
    opts = args or ["A", "B", "C"]
    tmp = pathlib.Path(tempfile.mkdtemp())
    for opt in opts:
        sheet = Image.new("RGB", (W * frames + GAP * (frames - 1), H), (20, 16, 26))
        for f in range(1, frames + 1):
            p = tmp / f"{opt}{f}.png"
            shot(f"{opt}{f}", p)
            sheet.paste(Image.open(p).convert("RGB").crop((0, 0, W, H)), ((W + GAP) * (f - 1), 0))
        out = MOCKS / f"{PAGE.split('.')[0]}_{opt}.jpg"
        sheet.save(out, quality=90)
        print(out)


if __name__ == "__main__":
    main()
