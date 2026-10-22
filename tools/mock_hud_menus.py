"""Render docs/art/mocks/hud_menus.html (options A/B/C, phone 844x390) with Edge headless into
docs/art/mocks/hud_menus_<opt>.jpg, one at a time."""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
MOCKS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "art" / "mocks"
W, H = 844, 390
PAGES = {
    "hud_menus": {"A": "A: menus on the left, Shop set apart; timers under the qi",
                  "B": "B: menus on the left, timers on the right",
                  "C": "C: one row of menus at the top left"},
    # calmer phone HUD (owner 2026-10-22: "phone is a bit messy"); "now" is the Play capture
    "hud_phone": {"A": "A: two quiet rails (small buttons, round timers on the right edge)",
                  "B": "B: one dock at the bottom, realm bar up under the qi",
                  "C": "C: Shop + Sect menu on the left, one Rewards button on the right"},
}


def main():
    """python tools/mock_hud_menus.py [page] [opts...]   page = hud_menus (default) | hud_phone"""
    args = sys.argv[1:]
    page = args.pop(0) if args and args[0] in PAGES else "hud_menus"
    TAGS = PAGES[page]
    tmp = pathlib.Path(tempfile.mkdtemp())
    for opt in args or ["A", "B", "C"]:
        p = tmp / f"{opt}.png"
        url = (MOCKS / f"{page}.html").as_uri() + f"?opt={opt}"
        subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=4000",
                        f"--window-size={W},{H}", f"--screenshot={p}", url], check=True, capture_output=True)
        out = MOCKS / f"{page}_{opt}.jpg"
        im = Image.open(p).convert("RGB").crop((0, 0, W, H))
        sheet = Image.new("RGB", (W, H + 34), (20, 16, 26))
        sheet.paste(im, (0, 0))
        ImageDraw.Draw(sheet).text((12, H + 7), TAGS[opt], fill=(255, 255, 255), font=ImageFont.truetype("arialbd.ttf", 18))
        sheet.save(out, quality=90)
        print(out)


if __name__ == "__main__":
    main()
