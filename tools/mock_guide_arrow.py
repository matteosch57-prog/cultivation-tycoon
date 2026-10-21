"""Guide arrow mocks (B01 step 5, RULES R4): three options painted over a real Studio capture.

    python tools/mock_guide_arrow.py   -> docs/art/mocks/guide_A.jpg, guide_B.jpg, guide_C.jpg
"""

import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "art" / "captures" / "13_pad_beacons_green.jpg"
OUT = ROOT / "docs" / "art" / "mocks"
JADE = (111, 214, 170)
JADE_DARK = (34, 92, 74)
GOLD = (255, 214, 92)
INK = (40, 30, 40)
FONT = "C:/Windows/Fonts/arialbd.ttf"

FEET = (872, 705)  # the player's feet in the capture
PAD = (296, 516)  # the West Wall pad (the HUD goal in the capture)


def bezier(t):
    # a gentle curve from the feet to the pad (the path a player would walk)
    c = (640, 690)
    x = (1 - t) ** 2 * FEET[0] + 2 * (1 - t) * t * c[0] + t ** 2 * PAD[0]
    y = (1 - t) ** 2 * FEET[1] + 2 * (1 - t) * t * c[1] + t ** 2 * PAD[1]
    return x, y


def label(img, title, lines):
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(FONT, 40)
    f2 = ImageFont.truetype(FONT, 26)
    y = 20
    d.text((24, y), title, font=f1, fill="white", stroke_width=4, stroke_fill=INK)
    y += 52
    for ln in lines:
        d.text((24, y), ln, font=f2, fill="white", stroke_width=3, stroke_fill=INK)
        y += 34


def chevron(d, x, y, ang, s, fill, outline):
    # a flat chevron lying on the ground, squashed vertically for perspective
    pts = [(-0.5, -0.6), (0.0, -0.6), (0.5, 0), (0.0, 0.6), (-0.5, 0.6), (0.0, 0)]
    out = []
    for px, py in pts:
        rx = px * math.cos(ang) - py * math.sin(ang)
        ry = px * math.sin(ang) + py * math.cos(ang)
        out.append((x + rx * s, y + ry * s * 0.55))
    d.polygon(out, fill=fill, outline=outline, width=max(2, int(s / 9)))


def option_a():
    img = Image.open(SRC).convert("RGB")
    d = ImageDraw.Draw(img)
    n = 9
    for i in range(1, n):
        t = i / n
        x, y = bezier(t)
        x2, y2 = bezier(t + 0.01)
        ang = math.atan2((y2 - y) / 0.55, x2 - x)
        s = 92 - 50 * t  # farther = smaller
        chevron(d, x + 3, y + 4, ang, s, JADE_DARK, JADE_DARK)
        chevron(d, x, y, ang, s, JADE, (235, 255, 245))
    label(img, "A  Jade trail on the ground", [
        "Painted chevrons from your feet to the next pad.",
        "Not a light (R3): plain jade, they drift forward slowly.",
        "Shown for the first 5 buildings, then only after 20 s idle.",
    ])
    return img


def option_b():
    img = Image.open(SRC).convert("RGB")
    glow = Image.new("RGB", img.size, (0, 0, 0))
    g = ImageDraw.Draw(glow)
    # the spirit wisp, a third of the way along, with a fading dotted trail behind it
    wx, wy = bezier(0.42)
    wy -= 70
    g.ellipse((wx - 70, wy - 70, wx + 70, wy + 70), fill=(80, 170, 135))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img = ImageChops.add(img, glow)
    d = ImageDraw.Draw(img)
    for i in range(1, 9):
        t = 0.42 * i / 9
        x, y = bezier(t)
        y -= 70 * (t / 0.42)
        r = 4 + 8 * (t / 0.42)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(200, 255, 230))
    d.ellipse((wx - 26, wy - 26, wx + 26, wy + 26), fill=(235, 255, 245), outline=JADE, width=6)
    # tail
    d.polygon([(wx + 18, wy - 12), (wx + 80, wy - 34), (wx + 22, wy + 14)], fill=(200, 255, 230))
    label(img, "B  Spirit wisp", [
        "A small jade wisp floats ahead of you to the next pad,",
        "waits on it, then flies to the next one when you buy.",
        "A glowing object (R3 ok if it holds a real light).",
    ])
    return img


def option_c():
    img = Image.open(SRC).convert("RGB")
    d = ImageDraw.Draw(img)
    x, y = PAD[0], PAD[1] - 150
    w, h = 64, 90
    body = [(x - w * 0.32, y - h), (x + w * 0.32, y - h), (x + w * 0.32, y - h * 0.15),
            (x + w * 0.7, y - h * 0.15), (x, y + h * 0.45), (x - w * 0.7, y - h * 0.15), (x - w * 0.32, y - h * 0.15)]
    shadow = [(px + 6, py + 6) for px, py in body]
    d.polygon(shadow, fill=(120, 80, 20))
    d.polygon(body, fill=GOLD, outline=INK, width=6)
    d.line([(x - 14, y - h + 10), (x - 14, y - 30)], fill=(255, 245, 200), width=7)
    for k in range(3):  # bounce marks
        d.arc((x - 40 - k * 12, y + h * 0.5 - 10, x + 40 + k * 12, y + h * 0.5 + 18 + k * 6), 200, 340, fill="white", width=3)
    label(img, "C  Gold arrow over the pad", [
        "A big toy arrow bounces above the next pad only.",
        "Nothing on the ground; the HUD compass stays.",
        "Simplest; easy to miss when the pad is behind you.",
    ])
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in (("A", option_a), ("B", option_b), ("C", option_c)):
        fn().save(OUT / ("guide_%s.jpg" % name), quality=88)
        print("wrote", OUT / ("guide_%s.jpg" % name))


if __name__ == "__main__":
    main()
