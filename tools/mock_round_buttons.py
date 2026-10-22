"""Render docs/art/mocks/2026-10-22_round_buttons.html (Now / A / B / C round-button looks) with Edge
headless into docs/art/mocks/2026-10-22_round_buttons.jpg."""
import pathlib
import subprocess
import tempfile

from PIL import Image

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
MOCKS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "art" / "mocks"
W, H = 1344, 735


def main():
    p = pathlib.Path(tempfile.mkdtemp()) / "board.png"
    url = (MOCKS / "2026-10-22_round_buttons.html").as_uri()
    subprocess.run([EDGE, "--headless", "--disable-gpu", "--hide-scrollbars", "--virtual-time-budget=4000",
                    "--allow-file-access-from-files", f"--window-size={W},{H}", f"--screenshot={p}", url],
                   check=True, capture_output=True)
    out = MOCKS / "2026-10-22_round_buttons.jpg"
    Image.open(p).convert("RGB").save(out, quality=92)
    print(out)


if __name__ == "__main__":
    main()
