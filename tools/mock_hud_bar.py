"""Render docs/art/mocks/hud_bar.html (options A/B/C, playing + ready) with Edge headless into
docs/art/mocks/hud_bar_<opt>[_ready].jpg. One render at a time."""
import pathlib
import subprocess

from PIL import Image

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
MOCKS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "art" / "mocks"
W, H = 1808, 938

for opt in "ABC":
    for s, suffix in ((0, ""), (1, "_ready")):
        png = MOCKS / f"_hud_bar_{opt}{suffix}.png"
        url = (MOCKS / "hud_bar.html").as_uri() + f"?opt={opt}&s={s}"
        subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=4000",
                        f"--window-size={W},{H}", f"--screenshot={png}", url], check=True, capture_output=True)
        Image.open(png).convert("RGB").save(MOCKS / f"hud_bar_{opt}{suffix}.jpg", quality=86)
        png.unlink()
        print("wrote", f"hud_bar_{opt}{suffix}.jpg")
