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


# --- the premium set: two layers a realm (A outer turning one way, B inner the other), as WC3 aura
# models split one aura into parts on flat planes, plus shared glow, rune sprites and a light column --
def petals(g, n, r, ln, wd, t):
    for i in range(n):
        a = i / n * math.tau
        x, y = pol(r, a)
        # an oval pointing out: drawn as a rotated polygon of 24 points
        pts = []
        for k in range(24):
            u = k / 24 * math.tau
            px, py = math.sin(u) * wd * S / 2, -math.cos(u) * ln * S / 2
            pts.append((x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a)))
        g.poly(pts, t)


def thorns(g, n, r, h, t):
    half = math.pi / n * 0.55
    for i in range(n):
        a = (i + 0.5) / n * math.tau
        g.line(pol(r, a - half), pol(r + h, a), t)
        g.line(pol(r + h, a), pol(r, a + half), t)


REALMS = {}


def realm(n):
    def deco(f):
        REALMS[n] = f
        return f
    return deco


@realm(2)
def r2():  # Qi Condensation: the neon rings (reference middle)
    a, b = Art(), Art()
    for r, t in ((0.47, 16), (0.43, 6), (0.39, 10)):
        a.ring(r, t)
    for r, t in ((0.28, 7), (0.23, 12), (0.16, 6)):
        b.ring(r, t)
    return a, b


@realm(3)
def r3():  # Foundation: the square held by four seals
    a, b = Art(), Art()
    a.ring(0.47, 14); a.ring(0.43, 5); a.star(4, 1, 0.43, 10); a.circles(4, 0.43, 0.04, 7)
    b.ring(0.24, 8); b.star(4, 1, 0.24, 7, 1 / 8); b.ring(0.1, 8)
    return a, b


@realm(4)
def r4():  # Core Formation: the hexagram in a rune band
    a, b = Art(), Art()
    a.ring(0.47, 14); a.ring(0.39, 7); a.rune_ring(18, 0.43, 0.04, 5, seed=4)
    b.star(6, 2, 0.36, 11); b.ring(0.36, 6); b.circles(6, 0.36, 0.03, 6); b.ring(0.15, 8)
    return a, b


@realm(5)
def r5():  # Nascent Soul: the lotus round the pentagram
    a, b = Art(), Art()
    a.ring(0.48, 12); petals(a, 12, 0.39, 0.16, 0.07, 7); a.ring(0.3, 6)
    b.star(5, 2, 0.27, 11); b.ring(0.27, 6); b.circles(5, 0.27, 0.035, 6); b.ring(0.1, 8)
    return a, b


@realm(6)
def r6():  # Soul Transformation: the circle chain round runes (reference left)
    a, b = Art(), Art()
    a.ring(0.47, 12); a.ring(0.38, 8); a.circles(12, 0.425, 0.045, 6, 0.5 / 12)
    b.rune_ring(20, 0.33, 0.035, 5, seed=6); b.ring(0.29, 6); b.star(8, 3, 0.27, 7); b.ring(0.11, 8)
    return a, b


@realm(7)
def r7():  # Void Refinement: thorns round two squares turning apart
    a, b = Art(), Art()
    a.ring(0.4, 12); thorns(a, 16, 0.4, 0.08, 8); a.star(4, 1, 0.4, 9); a.rune_ring(16, 0.34, 0.03, 4, seed=7)
    b.star(4, 1, 0.4, 9, 1 / 8); b.ring(0.18, 8); b.circles(8, 0.18, 0.025, 5)
    return a, b


@realm(8)
def r8():  # Body Integration: the star with rune tablets (reference right)
    a, b = Art(), Art()
    rng = random.Random(8)
    for i in range(4):
        a.tablet(i / 4 * math.tau, 0.24, 0.4, 0.08, 7, rng)
    a.ring(0.47, 6); a.rune_ring(16, 0.44, 0.03, 4, seed=81)
    b.star(8, 3, 0.3, 9, 1 / 16); b.star(4, 1, 0.2, 7); b.star(4, 1, 0.2, 7, 1 / 8); b.ring(0.11, 8)
    return a, b


@realm(9)
def r9():  # Mahayana: eight tablets, the great lotus
    a, b = Art(), Art()
    rng = random.Random(9)
    for i in range(8):
        a.tablet(i / 8 * math.tau, 0.3, 0.42, 0.06, 6, rng)
    a.ring(0.3, 9); a.ring(0.47, 5)
    petals(b, 16, 0.2, 0.12, 0.05, 6); b.star(8, 3, 0.25, 7, 1 / 16); b.ring(0.1, 9)
    return a, b


@realm(10)
def r10():  # True Immortal and up: everything, doubled rune bands
    a, b = Art(), Art()
    rng = random.Random(10)
    a.ring(0.48, 14); a.rune_ring(24, 0.445, 0.032, 4, seed=10); a.ring(0.41, 6)
    a.circles(16, 0.375, 0.03, 5, 0.5 / 16)
    for i in range(4):
        a.tablet((i + 0.5) / 4 * math.tau, 0.2, 0.34, 0.07, 6, rng)
    b.star(12, 5, 0.28, 8); b.ring(0.28, 6); b.rune_ring(12, 0.2, 0.035, 4, seed=101); b.ring(0.12, 9); b.star(6, 2, 0.11, 6)
    return a, b


def glow_tex():
    """the light a glyph throws: a soft disc brightest at the rim, as WC3's aura base plane"""
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    r = np.hypot(xx - N / 2, yy - N / 2) / (N / 2)
    rim = np.exp(-((r - 0.9) / 0.08) ** 2)
    body = np.clip(1 - r, 0, 1) ** 1.5 * 0.45
    a = np.clip(rim * 0.8 + body, 0, 1) * (r < 1)
    img = np.zeros((N, N, 4), dtype=np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def column_tex():
    """a vertical light column (realm 9 and up): bright at the base, fading up, soft edges"""
    w, h = 256, 512
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    across = np.exp(-((xx - w / 2) / (w * 0.22)) ** 2)
    up = (yy / h) ** 1.8
    streaks = 0.75 + 0.25 * np.sin(xx / w * math.tau * 5) ** 2
    a = np.clip(across * up * streaks, 0, 1)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def add_light(base, img, rgb, angle=0.0, squash=1.0, scale=1.0, strength=1.0):
    """additive composite of a white texture tinted `rgb` (crisp core to white) onto `base`"""
    t = img.rotate(angle, resample=Image.BICUBIC)
    size = int(base.size[0] * scale)
    t = t.resize((size, max(1, int(size * squash))), Image.LANCZOS)
    a = np.asarray(t, dtype=np.float32)[..., 3] / 255 * strength
    core = np.clip(a * 2.2 - 1.6, 0, 1)
    col = np.array(rgb, dtype=np.float32)
    light = np.minimum(a * 1.5, 1)[..., None] * col * (1 - core[..., None]) + core[..., None] * 255
    out = np.asarray(base, dtype=np.float32).copy()
    h, w = light.shape[:2]
    oy, ox = (out.shape[0] - h) // 2, (out.shape[1] - w) // 2
    out[oy:oy + h, ox:ox + w] += light
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


COLORS = {  # Config.realmColor 2..10 (rarity colours, then the realm tints): approximations for the board
    2: (90, 200, 120), 3: (80, 150, 255), 4: (190, 100, 255), 5: (255, 200, 60), 6: (110, 225, 235),
    7: (180, 120, 255), 8: (255, 150, 90), 9: (255, 215, 120), 10: (255, 120, 200),
}


def frame(n, a_img, b_img, glow, t, size=420, squash=1.0):
    base = Image.new("RGB", (size, size), (8, 8, 14))
    c = COLORS[n]
    pale = tuple(int(v + (255 - v) * 0.5) for v in c)
    pulse = 0.75 + 0.25 * math.sin(t * math.tau)
    base = add_light(base, glow, c, 0, squash, 1.0, 0.55 * pulse)
    base = add_light(base, a_img, c, -14 * t * 6, squash, 1.0)
    base = add_light(base, b_img, pale, 22 * t * 6, squash, 1.0)
    return base


def main():
    os.makedirs(OUT, exist_ok=True)
    glow, col, runes = glow_tex(), column_tex(), runes_sheet()
    glow.save(os.path.join(OUT, "aura_glow.png"))
    col.save(os.path.join(OUT, "aura_column.png"))
    runes.save(os.path.join(OUT, "aura_runes_2x2.png"))
    tiles = []
    gifs = {}
    for n, f in sorted(REALMS.items()):
        a, b = f()
        ai, bi = a.finish(), b.finish()
        ai.save(os.path.join(OUT, f"aura_r{n}_a.png"))
        bi.save(os.path.join(OUT, f"aura_r{n}_b.png"))
        tiles.append(frame(n, ai, bi, glow, 0.15))
        if n in (4, 6, 8, 10):
            gifs[n] = (ai, bi)
    # the board: 9 realms top view, 3 x 3
    T = 420
    board = Image.new("RGB", (T * 3, T * 3), (8, 8, 14))
    for i, t in enumerate(tiles):
        board.paste(t, ((i % 3) * T, (i // 3) * T))
    board.save(os.path.join(OUT, "board_premium_top.png"))
    # a moving preview: 4 realms seen from a player's camera height (squashed), turning and pulsing
    frames = []
    for k in range(24):
        row = Image.new("RGB", (T * 4, int(T * 0.55)), (8, 8, 14))
        for j, (n, (ai, bi)) in enumerate(gifs.items()):
            fr = frame(n, ai, bi, glow, k / 24, T, 0.45)
            row.paste(fr.crop((0, (T - int(T * 0.55)) // 2, T, (T + int(T * 0.55)) // 2)), (j * T, 0))
        frames.append(row)
    frames[0].save(os.path.join(OUT, "preview_premium.gif"), save_all=True, append_images=frames[1:], duration=80, loop=0)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
