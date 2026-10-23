"""Player aura textures in the Warcraft 3 aura style, drawn entirely in code (ours to ship).

Owner 2026-10-23: references from Hive Workshop / XGM aura packs (bright neon line art, concentric
rings, a star with rune tablets, a ring of small circles with runes floating up). Those packs are WC3
assets (and some carry Blizzard textures), so we draw our own in that style instead.

Each glyph is white line art on transparent with a soft glow baked in, so one upload serves any realm
colour (ImageLabel.ImageColor3 / ParticleEmitter.Color tint it). Runes are made-up glyphs drawn from
a seeded stroke grammar, like WC3's.

    python tools/aura_textures.py            # the sample sheet (3 realms) + the rune sprite sheet
Output: docs/art/mocks/auras/ (glyph_<realm>.png 1024 px, runes_2x2.png, board_wc3_style.png)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "art", "mocks", "auras")
N = 1024  # final size
SS = 2  # supersample
S = N * SS
C = S / 2


def pol(r, a):
    """canvas point at radius r (0..0.5 of the size) and angle a (radians, 0 = up)"""
    return (C + math.sin(a) * r * S, C - math.cos(a) * r * S)


class Art:
    def __init__(self):
        self.im = Image.new("L", (S, S), 0)
        self.d = ImageDraw.Draw(self.im)

    def w(self, t):
        return max(1, int(t * S / 1000))

    def ring(self, r, t):
        rr = r * S
        self.d.ellipse((C - rr, C - rr, C + rr, C + rr), outline=255, width=self.w(t))

    def line(self, p0, p1, t):
        self.d.line((p0, p1), fill=255, width=self.w(t), joint="curve")
        for p in (p0, p1):  # round caps
            h = self.w(t) / 2
            self.d.ellipse((p[0] - h, p[1] - h, p[0] + h, p[1] + h), fill=255)

    def poly(self, pts, t):
        for i in range(len(pts)):
            self.line(pts[i], pts[(i + 1) % len(pts)], t)

    def star(self, n, k, r, t, turn=0.0):
        for i in range(n):
            self.line(pol(r, (i / n + turn) * math.tau), pol(r, ((i + k) / n + turn) * math.tau), t)

    def circles(self, n, r, rad, t, turn=0.0):
        for i in range(n):
            x, y = pol(r, (i / n + turn) * math.tau)
            rr = rad * S
            self.d.ellipse((x - rr, y - rr, x + rr, y + rr), outline=255, width=self.w(t))

    def ticks(self, n, r0, r1, t):
        for i in range(n):
            a = i / n * math.tau
            self.line(pol(r0, a), pol(r1, a), t)

    def rune(self, cx, cy, size, rng, t, rot=0.0):
        """a made-up rune: 2 to 4 strokes between points of a 3x3 grid, sometimes a ring or a dot"""
        pts = [(-1, -1), (0, -1), (1, -1), (-1, 0), (0, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
        ca, sa = math.cos(rot), math.sin(rot)

        def at(p):
            x, y = p[0] * size / 2, p[1] * size / 2
            return (cx + x * ca - y * sa, cy + x * sa + y * ca)

        spine = rng.choice([(1, 7), (3, 5), (0, 8), (2, 6)])
        self.line(at(pts[spine[0]]), at(pts[spine[1]]), t)
        for _ in range(rng.randint(1, 3)):
            a, b = rng.sample(range(9), 2)
            self.line(at(pts[a]), at(pts[b]), t)
        if rng.random() < 0.35:
            x, y = at(pts[rng.choice([1, 3, 5, 7])])
            rr = size * 0.16
            self.d.ellipse((x - rr, y - rr, x + rr, y + rr), outline=255, width=self.w(t))

    def rune_ring(self, n, r, size, t, seed, face_out=True):
        rng = random.Random(seed)
        for i in range(n):
            a = i / n * math.tau
            x, y = pol(r, a)
            self.rune(x, y, size * S, rng, t, a if face_out else 0)

    def tablet(self, a, r0, r1, wid, t, rng):
        """a rune tablet on an arm (the reference's star arms): a long box with a ring at the tip"""
        ca, sa = math.cos(a), math.sin(a)
        px, py = ca * wid * S / 2, sa * wid * S / 2
        p0, p1 = pol(r0, a), pol(r1, a)
        box = [(p0[0] - px, p0[1] - py), (p1[0] - px, p1[1] - py), (p1[0] + px, p1[1] + py), (p0[0] + px, p0[1] + py)]
        self.poly(box, t)
        tip = pol(r1 + wid * 0.45, a)
        rr = wid * 0.4 * S
        self.d.ellipse((tip[0] - rr, tip[1] - rr, tip[0] + rr, tip[1] + rr), outline=255, width=self.w(t))
        for j in range(3):
            f = 0.25 + j * 0.25
            x, y = pol(r0 + (r1 - r0) * f, a)
            self.rune(x, y, wid * 0.7 * S, rng, t * 0.7, a + math.pi / 2)

    def finish(self, glow=1.0):
        """downsample, then bake the glow: wide soft halo + tight bloom under the crisp line"""
        line = self.im.resize((N, N), Image.LANCZOS)
        a = np.asarray(line, dtype=np.float32) / 255
        wide = np.asarray(line.filter(ImageFilter.GaussianBlur(N / 60)), dtype=np.float32) / 255
        tight = np.asarray(line.filter(ImageFilter.GaussianBlur(N / 220)), dtype=np.float32) / 255
        alpha = np.clip(a + tight * 1.6 * glow + wide * 2.2 * glow, 0, 1)
        img = np.zeros((N, N, 4), dtype=np.uint8)
        img[..., :3] = 255
        img[..., 3] = (alpha * 255).astype(np.uint8)
        return Image.fromarray(img, "RGBA")


# --- the sample realms -----------------------------------------------------------------------------
def glyph_rings():
    """realm 2 sample: the reference's middle one, concentric neon rings, uneven widths"""
    g = Art()
    for r, t in ((0.46, 16), (0.42, 7), (0.37, 11), (0.27, 6), (0.22, 12), (0.15, 7)):
        g.ring(r, t)
    return g.finish(1.1)


def glyph_circle_chain():
    """realm 6 sample: the reference's left one, a band of small circles round runes and a star"""
    g = Art()
    g.ring(0.46, 12)
    g.ring(0.38, 8)
    g.circles(12, 0.42, 0.05, 6, 0.5 / 12)
    g.rune_ring(24, 0.33, 0.035, 5, seed=6)
    g.ring(0.29, 6)
    g.star(8, 3, 0.27, 7)
    g.ring(0.12, 8)
    return g.finish()


def glyph_star_tablets():
    """realm 10 sample: the reference's right one, a star whose arms carry rune tablets"""
    g = Art()
    rng = random.Random(10)
    g.star(8, 3, 0.3, 9, 1 / 16)
    g.star(4, 1, 0.2, 7)
    g.star(4, 1, 0.2, 7, 1 / 8)
    for i in range(4):
        g.tablet(i / 4 * math.tau, 0.24, 0.4, 0.08, 7, rng)
    g.ring(0.11, 8)
    g.ring(0.46, 5)
    g.rune_ring(16, 0.43, 0.035, 4, seed=11)
    return g.finish()


def runes_sheet():
    """the floating rune sprites (reference left): 4 runes in a 2x2 flipbook, white with glow"""
    g = Art()
    rng = random.Random(42)
    for i in range(4):
        cx, cy = (i % 2 + 0.5) * S / 2, (i // 2 + 0.5) * S / 2
        g.rune(cx, cy, S * 0.3, rng, 26)
        rr = S * 0.21
        if i % 2 == 0:
            g.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), outline=255, width=g.w(12))
    return g.finish(0.8)


def tint(img, rgb):
    """the texture tinted and laid on black, as additive light reads in game"""
    r, gc, b = rgb
    a = np.asarray(img, dtype=np.float32)[..., 3:] / 255
    core = np.clip(a * 2.2 - 1.6, 0, 1)  # the crisp line goes to white, the glow keeps the colour
    col = np.array([r, gc, b], dtype=np.float32)
    out = np.minimum(a * 1.5, 1) * col * (1 - core) + core * 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    pieces = [
        ("glyph_2_rings", glyph_rings(), (60, 120, 255)),
        ("glyph_6_circles", glyph_circle_chain(), (230, 235, 60)),
        ("glyph_10_tablets", glyph_star_tablets(), (90, 170, 255)),
        ("runes_2x2", runes_sheet(), (240, 240, 255)),
    ]
    tile = 560
    board = Image.new("RGB", (tile * len(pieces), tile), (0, 0, 0))
    for i, (name, img, rgb) in enumerate(pieces):
        img.save(os.path.join(OUT, name + ".png"))
        board.paste(tint(img, rgb).resize((tile, tile), Image.LANCZOS), (i * tile, 0))
    board.save(os.path.join(OUT, "board_wc3_style.png"))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
