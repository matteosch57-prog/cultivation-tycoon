"""Store icon + thumbnail mocks, drawn entirely in code (no captures, no uploads).

Look: calm, bright, geometric (pastel sky, lavender shadows, vermilion + gold halls, jade, sakura),
which no cultivation or tycoon icon on Roblox uses (research: docs/research/2026-10-21_store_icons_thumbnails.md).
Every shape is drawn at SS x size and downsampled, so edges stay clean at 150 px.

    python tools/store_art.py            # all 10 icons, 10 thumbnails, both pick boards
    python tools/store_art.py icon 3     # one piece

Output: docs/art/mocks/store/drawn/. Palette = docs/art/ART_BIBLE.md "Palette".
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "art", "mocks", "store", "drawn")
FONT = None
for base in (os.path.expandvars(r"%LOCALAPPDATA%\Roblox\Versions"),):
    if os.path.isdir(base):
        for v in sorted(os.listdir(base)):
            p = os.path.join(base, v, "content", "fonts", "FredokaOne-Regular.ttf")
            if os.path.exists(p):
                FONT = p


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# ART_BIBLE palette + store additions
VERMILION = hexc("B8352B")
VERMILION_HI = hexc("D9493B")
GOLD = hexc("E2B04A")
GOLD_HI = hexc("F6D27A")
GOLD_LO = hexc("A9772C")
TILE = hexc("2E3446")
PLASTER = hexc("F1E8D6")
STONE = hexc("C9C2D6")
STONE_LO = hexc("9D95B3")
JADE = hexc("4FB596")
JADE_HI = hexc("8FE0C2")
JADE_LO = hexc("2F7F6C")
LAWN = hexc("79B65A")
LAWN_HI = hexc("A2D46E")
LAWN_LO = hexc("4F8E45")
EARTH = hexc("B07A55")
ROCK = [hexc("E4C7A8"), hexc("CDA98F"), hexc("A98DA6"), hexc("8A7AA3"), hexc("6E6694")]
SAKURA = hexc("F4B6C2")
SAKURA_HI = hexc("FAD4DC")
SAKURA_LO = hexc("E98FA6")
TRUNK = hexc("5A3A29")
CLOUD = hexc("FFFFFF")
CLOUD_LO = hexc("D9DDF4")
SKY_TOP = hexc("4FA8E8")
SKY_BOT = hexc("BEE6F7")
SKIN = hexc("F2CDA9")
HAIR = hexc("2B2433")


# ---------------------------------------------------------------- canvas helpers
class Canvas:
    def __init__(self, w, h, ss=4, bg=(0, 0, 0, 255)):
        self.ss = ss
        self.w, self.h = w * ss, h * ss
        self.im = Image.new("RGBA", (self.w, self.h), bg)

    def S(self, v):
        return v * self.ss

    def layer(self):
        return Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

    def put(self, lay, blur=0):
        if blur:
            # blur premultiplied, or transparent black bleeds a grey fringe into every soft edge
            a = np.asarray(lay, dtype=np.float32)
            a[..., :3] *= a[..., 3:4] / 255
            pm = Image.merge("RGBA", [Image.fromarray(a[..., i].clip(0, 255).astype(np.uint8)) for i in range(4)])
            pm = np.asarray(pm.filter(ImageFilter.GaussianBlur(blur * self.ss)), dtype=np.float32)
            al = pm[..., 3:4]
            pm[..., :3] = np.where(al > 0, pm[..., :3] * 255 / np.maximum(al, 1), 0)
            lay = Image.fromarray(pm.clip(0, 255).astype(np.uint8), "RGBA")
        self.im.alpha_composite(lay)

    def draw(self):
        lay = self.layer()
        return lay, ImageDraw.Draw(lay)

    def final(self, w, h):
        return self.im.resize((w, h), Image.LANCZOS).convert("RGB")


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def sky(c, top=SKY_TOP, bot=SKY_BOT, horizon=1.0):
    g = Image.new("RGBA", (1, 256))
    for y in range(256):
        t = min(1, (y / 255) / horizon)
        g.putpixel((0, y), mix(top, bot, t ** 1.2))
    c.im.alpha_composite(g.resize((c.w, c.h), Image.BICUBIC))


def glow(c, x, y, r, color, alpha=170, blur=None):
    lay, d = c.draw()
    d.ellipse((c.S(x - r), c.S(y - r), c.S(x + r), c.S(y + r)), fill=color[:3] + (alpha,))
    c.put(lay, blur if blur is not None else r * 0.45)


def sun(c, x, y, r, color=hexc("FFF4D6")):
    glow(c, x, y, r * 3.2, hexc("FFE9B0"), 90)
    glow(c, x, y, r * 1.8, hexc("FFF1C8"), 140)
    lay, d = c.draw()
    d.ellipse((c.S(x - r), c.S(y - r), c.S(x + r), c.S(y + r)), fill=color)
    c.put(lay)


def cloud(c, x, y, w, seed=1, shade=CLOUD_LO, body=CLOUD, flat=True, alpha=255):
    """A soft cumulus: lavender underside, white body, flat bottom."""
    rng = random.Random(seed)
    puffs = []
    n = max(4, int(w / 22))
    for i in range(n):
        t = i / (n - 1)
        px = x - w / 2 + t * w
        r = w * (0.10 + 0.16 * math.sin(math.pi * t)) * rng.uniform(0.8, 1.15)
        puffs.append((px, y - r * 0.55, r))
    for (dx, dy, col) in ((0, w * 0.035, shade), (0, 0, body)):
        lay, d = c.draw()
        for (px, py, r) in puffs:
            d.ellipse((c.S(px - r + dx), c.S(py - r + dy), c.S(px + r + dx), c.S(py + r + dy)), fill=col[:3] + (alpha,))
        if flat:
            d.rectangle((0, c.S(y + (w * 0.035 if col is shade else 0)), c.w, c.h), fill=(0, 0, 0, 0))
        c.put(lay)


def cloud_bank(c, y, seed=3, color=CLOUD, shade=CLOUD_LO, count=9, size=(120, 260), alpha=255):
    rng = random.Random(seed)
    W = c.w / c.ss
    for i in range(count):
        x = rng.uniform(-60, W + 60)
        cloud(c, x, y + rng.uniform(-14, 18), rng.uniform(*size), seed + i, shade, color, flat=False, alpha=alpha)
    lay, d = c.draw()
    d.rectangle((0, c.S(y + 14), c.w, c.h), fill=mix(color, shade, 0.3)[:3] + (alpha,))
    c.put(lay, 6)


def poly(c, pts, fill, blur=0):
    lay, d = c.draw()
    d.polygon([(c.S(x), c.S(y)) for x, y in pts], fill=fill)
    c.put(lay, blur)


def rect(c, x0, y0, x1, y1, fill, r=0):
    lay, d = c.draw()
    if r:
        d.rounded_rectangle((c.S(x0), c.S(y0), c.S(x1), c.S(y1)), radius=c.S(r), fill=fill)
    else:
        d.rectangle((c.S(x0), c.S(y0), c.S(x1), c.S(y1)), fill=fill)
    c.put(lay)


def ellipse(c, x0, y0, x1, y1, fill):
    lay, d = c.draw()
    d.ellipse((c.S(x0), c.S(y0), c.S(x1), c.S(y1)), fill=fill)
    c.put(lay)


def bez(p0, p1, p2, n=24):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


# ---------------------------------------------------------------- the world
def island(c, x, y, r, seed=4, depth=1.25, grass=True, lip=True):
    """Floating peak: lawn ellipse on top, earth band, faceted rock cone underneath. (x, y) = lawn centre."""
    rng = random.Random(seed)
    ry = r * 0.26
    tip = y + r * depth
    # rock facets: a fan of quads between the rim and a jagged tip line
    n = 9
    rim = [(x - r + 2 * r * i / n, y + ry * math.sin(math.acos(max(-1, min(1, -1 + 2 * i / n)))) * 0.9 + r * 0.08) for i in range(n + 1)]
    bottom = []
    for i in range(n + 1):
        t = i / n
        spread = math.sin(math.pi * t) ** 0.8
        bx = x + (t - 0.5) * 2 * r * 0.30
        by = y + r * 0.2 + (tip - y - r * 0.2) * spread * rng.uniform(0.75, 1.0)
        bottom.append((bx, by))
    for i in range(n):
        light = abs((i + 0.5) / n - 0.36)  # lit from the upper left
        col = ROCK[min(len(ROCK) - 1, int(light * 6))]
        poly(c, [rim[i], rim[i + 1], bottom[i + 1], bottom[i]], col)
    # earth band
    ellipse(c, x - r, y - ry + r * 0.07, x + r, y + ry + r * 0.07, EARTH)
    if grass:
        ellipse(c, x - r, y - ry, x + r, y + ry, LAWN)
        ellipse(c, x - r * 0.92, y - ry * 0.95, x + r * 0.84, y + ry * 0.62, LAWN_HI if lip else LAWN)
        ellipse(c, x - r * 0.88, y - ry * 0.86, x + r * 0.88, y + ry * 0.70, LAWN)
    return ry


def waterfall(c, x, y, length, w=6):
    lay, d = c.draw()
    d.rectangle((c.S(x - w / 2), c.S(y), c.S(x + w / 2), c.S(y + length)), fill=hexc("CFEFFF", 230))
    d.rectangle((c.S(x - w / 6), c.S(y), c.S(x + w / 6), c.S(y + length)), fill=hexc("FFFFFF", 255))
    c.put(lay)
    glow(c, x, y + length, w * 2.4, CLOUD, 200)


def roof(c, cx, y_eave, w, h, curl=None, col=GOLD, hi=GOLD_HI, soffit=TILE):
    """Curved hip roof: concave flanks, upturned tips. y_eave = eave line, h = roof height."""
    curl = curl if curl is not None else h * 0.55
    xl, xr = cx - w / 2, cx + w / 2
    ridge_l, ridge_r = cx - w * 0.30, cx + w * 0.30
    top = y_eave - h
    left = bez((xl - w * 0.04, y_eave - curl), (xl + w * 0.12, y_eave - h * 0.05), (ridge_l, top))
    right = bez((ridge_r, top), (xr - w * 0.12, y_eave - h * 0.05), (xr + w * 0.04, y_eave - curl))
    under = bez((xr + w * 0.04, y_eave - curl), (cx, y_eave + h * 0.16), (xl - w * 0.04, y_eave - curl))
    # soffit (dark underside) slightly below
    soff = bez((xr + w * 0.02, y_eave - curl * 0.8), (cx, y_eave + h * 0.34), (xl - w * 0.02, y_eave - curl * 0.8))
    poly(c, soff + [(cx, y_eave - h * 0.2)], soffit)
    poly(c, left + right + under, col)
    # lit top band
    band = bez((ridge_l, top), (cx, top - h * 0.02), (ridge_r, top))
    poly(c, left[len(left) // 2:] + band + right[: len(right) // 2] + [(cx, top + h * 0.28)], hi)
    # ridge
    rect(c, ridge_l - w * 0.02, top - h * 0.10, ridge_r + w * 0.02, top + h * 0.02, GOLD_LO, r=h * 0.04)


def hall(c, cx, base, w, h=None, tiers=2, col_n=None):
    """Main Hall: stone plinth, vermilion colonnade, plaster wall, 1-2 gold roofs. base = ground y."""
    h = h or w * 0.62
    plinth_h = h * 0.12
    rect(c, cx - w * 0.52, base - plinth_h, cx + w * 0.52, base, STONE)
    rect(c, cx - w * 0.52, base - plinth_h * 0.35, cx + w * 0.52, base, STONE_LO)
    # stair
    rect(c, cx - w * 0.09, base - plinth_h, cx + w * 0.09, base, PLASTER)
    body_top = base - plinth_h - h * 0.34
    rect(c, cx - w * 0.42, body_top, cx + w * 0.42, base - plinth_h, PLASTER)
    rect(c, cx - w * 0.42, body_top + h * 0.10, cx + w * 0.42, base - plinth_h, TILE)  # doors / shade
    n = col_n or 6
    for i in range(n + 1):
        x = cx - w * 0.42 + (w * 0.84) * i / n
        rect(c, x - w * 0.022, body_top, x + w * 0.022, base - plinth_h, VERMILION)
        rect(c, x - w * 0.022, body_top, x - w * 0.006, base - plinth_h, VERMILION_HI)
    rect(c, cx - w * 0.44, body_top - h * 0.02, cx + w * 0.44, body_top + h * 0.035, VERMILION)
    rect(c, cx - w * 0.44, body_top + h * 0.035, cx + w * 0.44, body_top + h * 0.05, GOLD)
    roof(c, cx, body_top + h * 0.02, w * 1.12, h * 0.26)
    if tiers >= 2:
        up_base = body_top - h * 0.17
        rect(c, cx - w * 0.26, up_base - h * 0.16, cx + w * 0.26, up_base + h * 0.02, PLASTER)
        for i in range(5):
            x = cx - w * 0.26 + (w * 0.52) * i / 4
            rect(c, x - w * 0.015, up_base - h * 0.16, x + w * 0.015, up_base + h * 0.02, VERMILION)
        roof(c, cx, up_base - h * 0.15, w * 0.78, h * 0.25)
    return body_top


def pagoda(c, cx, base, w, tiers=5, h=None):
    h = h or w * 0.42
    y = base
    for i in range(tiers):
        s = 1 - i * 0.13
        bw = w * 0.56 * s
        rect(c, cx - bw / 2, y - h * 0.62, cx + bw / 2, y, VERMILION)
        rect(c, cx - bw / 2, y - h * 0.62, cx - bw / 2 + bw * 0.18, y, VERMILION_HI)
        rect(c, cx - bw * 0.2, y - h * 0.5, cx + bw * 0.2, y - h * 0.05, TILE)
        roof(c, cx, y - h * 0.58, w * s, h * 0.44)
        y -= h * 0.95
    rect(c, cx - w * 0.025, y - h * 0.7, cx + w * 0.025, y + h * 0.2, GOLD)
    ellipse(c, cx - w * 0.05, y - h * 0.85, cx + w * 0.05, y - h * 0.65, GOLD_HI)
    return y


def sakura(c, x, base, s=1.0, seed=2):
    rng = random.Random(seed)
    poly(c, [(x - 3 * s, base), (x + 3 * s, base), (x + 2 * s, base - 30 * s), (x + 9 * s, base - 46 * s), (x - 1 * s, base - 36 * s), (x - 2 * s, base - 30 * s)], TRUNK)
    blobs = [(x + rng.uniform(-26, 26) * s, base - rng.uniform(40, 66) * s, rng.uniform(13, 21) * s) for _ in range(9)]
    for col, dy in ((SAKURA_LO, 5), (SAKURA, 0), (SAKURA_HI, -5)):
        lay, d = c.draw()
        for (bx, by, r) in blobs:
            rr = r * (0.62 if col is SAKURA_HI else 1)
            d.ellipse((c.S(bx - rr), c.S(by - rr + dy * s), c.S(bx + rr), c.S(by + rr + dy * s)), fill=col)
        c.put(lay)


def pine(c, x, base, s=1.0):
    rect(c, x - 2 * s, base - 10 * s, x + 2 * s, base, TRUNK)
    for i, (w, col) in enumerate(((22, LAWN_LO), (17, hexc("3F7A5C")), (12, hexc("4F8E5F")))):
        y = base - 8 * s - i * 11 * s
        poly(c, [(x - w * s, y), (x + w * s, y), (x, y - 20 * s)], col)


def tent(c, x, base, s=1.0):
    poly(c, [(x - 16 * s, base), (x + 16 * s, base), (x, base - 20 * s)], hexc("E6D3B0"))
    poly(c, [(x, base), (x + 16 * s, base), (x, base - 20 * s)], hexc("CDB48C"))
    poly(c, [(x - 4 * s, base), (x + 4 * s, base), (x, base - 9 * s)], hexc("6B5240"))


def avatar(c, x, base, s=1.0, robe=hexc("F4F1EA"), trim=GOLD, pose="sit", hair=HAIR, face=True, arms_up=False):
    """A Roblox R15-ish blocky avatar. pose 'sit' = cross-legged meditation, 'stand'."""
    S_ = s
    if pose == "sit":
        # crossed legs: a wide flat block
        rect(c, x - 22 * S_, base - 12 * S_, x + 22 * S_, base, robe, r=5 * S_)
        rect(c, x - 22 * S_, base - 4 * S_, x + 22 * S_, base, mix(robe, (90, 80, 120, 255), 0.25), r=3 * S_)
        torso_bot = base - 9 * S_
    else:
        rect(c, x - 11 * S_, base - 30 * S_, x - 1 * S_, base, mix(robe, (60, 50, 90, 255), 0.25), r=2 * S_)
        rect(c, x + 1 * S_, base - 30 * S_, x + 11 * S_, base, mix(robe, (60, 50, 90, 255), 0.25), r=2 * S_)
        torso_bot = base - 26 * S_
    tt = torso_bot - 30 * S_
    rect(c, x - 14 * S_, tt, x + 14 * S_, torso_bot, robe, r=4 * S_)
    poly(c, [(x - 6 * S_, tt), (x + 6 * S_, tt), (x, tt + 14 * S_)], trim)  # collar
    rect(c, x - 14 * S_, torso_bot - 7 * S_, x + 14 * S_, torso_bot - 3 * S_, trim)  # sash
    if arms_up:
        rect(c, x - 26 * S_, tt - 22 * S_, x - 16 * S_, tt + 10 * S_, robe, r=4 * S_)
        rect(c, x + 16 * S_, tt - 22 * S_, x + 26 * S_, tt + 10 * S_, robe, r=4 * S_)
    elif pose == "sit":
        poly(c, [(x - 15 * S_, tt + 2 * S_), (x - 25 * S_, tt + 4 * S_), (x - 22 * S_, torso_bot + 2 * S_), (x - 9 * S_, torso_bot + 1 * S_)], robe)
        poly(c, [(x + 15 * S_, tt + 2 * S_), (x + 25 * S_, tt + 4 * S_), (x + 22 * S_, torso_bot + 2 * S_), (x + 9 * S_, torso_bot + 1 * S_)], robe)
        rect(c, x - 10 * S_, torso_bot - 3 * S_, x + 10 * S_, torso_bot + 3 * S_, SKIN, r=3 * S_)  # hands in lap
    else:
        rect(c, x - 22 * S_, tt + 1 * S_, x - 15 * S_, torso_bot + 4 * S_, robe, r=3 * S_)
        rect(c, x + 15 * S_, tt + 1 * S_, x + 22 * S_, torso_bot + 4 * S_, robe, r=3 * S_)
    # head: the rounded Roblox block
    hy = tt - 2 * S_
    rect(c, x - 3.5 * S_, hy - 3 * S_, x + 3.5 * S_, hy + 2 * S_, SKIN)
    rect(c, x - 11 * S_, hy - 22 * S_, x + 11 * S_, hy - 1 * S_, SKIN, r=6 * S_)
    if hair:
        rect(c, x - 12 * S_, hy - 25 * S_, x + 12 * S_, hy - 15 * S_, hair, r=6 * S_)
        ellipse(c, x - 5 * S_, hy - 33 * S_, x + 5 * S_, hy - 22 * S_, hair)  # top bun
    if face:
        # closed, content eyes (meditation) + a small smile
        lay, d = c.draw()
        wpx = max(1, int(c.S(1.4 * S_)))
        for ex in (-5, 5):
            d.arc((c.S(x + (ex - 2.6) * S_), c.S(hy - 13 * S_), c.S(x + (ex + 2.6) * S_), c.S(hy - 8 * S_)), 200, 340, fill=HAIR, width=wpx)
        d.arc((c.S(x - 3.5 * S_), c.S(hy - 9 * S_), c.S(x + 3.5 * S_), c.S(hy - 4 * S_)), 20, 160, fill=hexc("8A4B4B"), width=wpx)
        c.put(lay)
    return hy - 12 * S_  # face centre y


def aura(c, x, y, r, color, strength=1.0):
    glow(c, x, y, r, color, int(150 * strength))
    glow(c, x, y, r * 0.55, mix(color, (255, 255, 255, 255), 0.4), int(170 * strength))


def orbs(c, x, y, r, color, n=5, size=4, phase=0.0):
    for i in range(n):
        a = phase + i / n * math.tau
        ox, oy = x + math.cos(a) * r, y + math.sin(a) * r * 0.35
        glow(c, ox, oy, size * 2.2, color, 150)
        ellipse(c, ox - size, oy - size, ox + size, oy + size, mix(color, (255, 255, 255, 255), 0.55))


def drop(c, x, y, r, col=JADE, hi=JADE_HI, lo=JADE_LO):
    """The qi drop (the game's currency): round bottom, pointed top."""
    top = (x, y - r * 2.1)
    left = bez(top, (x - r * 0.9, y - r * 0.9), (x - r, y))
    right = bez((x + r, y), (x + r * 0.9, y - r * 0.9), top)
    arc = [(x + r * math.cos(a), y + r * math.sin(a)) for a in (i / 40 * math.pi for i in range(41))]
    shape = left + list(reversed(arc)) + right
    poly(c, [(px + r * 0.06, py + r * 0.1) for px, py in shape], hexc("3A6B8C", 90), blur=r * 0.08)  # shadow
    poly(c, shape, col)
    return shape


def text(c, s, x, y, size, fill=(255, 255, 255, 255), anchor="mm", shadow=0.45):
    """Fredoka (the HUD's face) with a soft shadow; never a thick outline (the cheap tell)."""
    f = ImageFont.truetype(FONT, c.S(size))
    sh = c.layer()
    ImageDraw.Draw(sh).text((c.S(x), c.S(y + size * 0.07)), s, font=f, fill=(30, 40, 90, int(255 * shadow)), anchor=anchor)
    c.put(sh, size * 0.08)
    lay = c.layer()
    ImageDraw.Draw(lay).text((c.S(x), c.S(y)), s, font=f, fill=fill, anchor=anchor)
    c.put(lay)


def sect(c, x, y, r, seed=4, trees=True, depth=1.25, fall=True):
    """A full floating sect: island, main hall, cherry trees, pines, waterfall."""
    ry = island(c, x, y, r, seed, depth)
    if fall:
        waterfall(c, x + r * 0.62, y + ry * 0.55, r * 1.2, w=r * 0.05)
    if trees:
        pine(c, x - r * 0.78, y - ry * 0.2, r / 120)
        sakura(c, x - r * 0.62, y + ry * 0.15, r / 150, seed)
        sakura(c, x + r * 0.66, y + ry * 0.05, r / 160, seed + 3)
    hall(c, x, y + ry * 0.05, r * 1.0)
    return ry


# ---------------------------------------------------------------- the 10 icons (512)
def icon_canvas():
    return Canvas(512, 512, 4)


def i01_lone_peak():
    c = icon_canvas(); sky(c)
    sun(c, 380, 120, 30)
    cloud(c, 90, 150, 150, 3, alpha=235); cloud(c, 440, 210, 120, 5, alpha=220)
    sect(c, 256, 270, 150, 4, depth=1.15)
    cloud_bank(c, 470, 7, count=7, size=(140, 260))
    return c


def i02_golden_hall():
    c = icon_canvas(); sky(c, hexc("3E93E0"), hexc("A9DBF5"))
    sun(c, 410, 92, 30)
    hall(c, 256, 560, 560)
    return c


def i03_qi_drop():
    c = icon_canvas(); sky(c, hexc("CFEFFF"), hexc("EAF7FF"))
    shape = drop(c, 256, 330, 150)
    # the world inside the drop, clipped to it
    inner = Canvas(512, 512, 4)
    sky(inner, hexc("5CC6A7"), hexc("BFF1DF"))
    sun(inner, 330, 200, 22, hexc("FFFFFF"))
    sect(inner, 256, 330, 92, 6, depth=1.0)
    cloud_bank(inner, 440, 9, color=hexc("E9FFF6"), shade=hexc("B8E8D7"), count=6, size=(90, 160))
    m = Image.new("L", (c.w, c.h), 0)
    ImageDraw.Draw(m).polygon([(c.S(x), c.S(y)) for x, y in shape], fill=255)
    lay = c.layer(); lay.paste(inner.im, (0, 0), m)
    c.put(lay)
    # glass: highlight + rim
    hl = c.layer(); ImageDraw.Draw(hl).ellipse((c.S(150), c.S(170), c.S(215), c.S(300)), fill=(255, 255, 255, 120))
    c.put(hl, 10)
    rim = c.layer(); ImageDraw.Draw(rim).line([(c.S(x), c.S(y)) for x, y in shape], fill=(255, 255, 255, 170), width=c.S(5))
    c.put(rim, 1.5)
    return c


def i04_build_moment():
    c = icon_canvas(); sky(c)
    # light column and the rising hall
    glow(c, 256, 250, 190, hexc("FFE7A0"), 150)
    lay, d = c.draw()
    d.polygon([(c.S(170), c.S(470)), (c.S(342), c.S(470)), (c.S(300), 0), (c.S(212), 0)], fill=hexc("FFF4C9", 120))
    c.put(lay, 10)
    hall(c, 256, 330, 300)
    rect(c, 0, 330, 512, 512, LAWN); rect(c, 0, 330, 512, 345, LAWN_HI)
    for i in range(14):
        rng = random.Random(i)
        x, y = rng.uniform(110, 400), rng.uniform(120, 330)
        glow(c, x, y, 8, GOLD_HI, 200); ellipse(c, x - 3, y - 3, x + 3, y + 3, hexc("FFFFFF"))
    ellipse(c, 176, 455, 336, 495, JADE_HI); ellipse(c, 186, 460, 326, 490, JADE)
    avatar(c, 256, 478, 2.2, robe=VERMILION, trim=GOLD, pose="stand", arms_up=True, face=False)
    return c


def i05_pagoda_clouds():
    c = icon_canvas(); sky(c, hexc("F7C99A"), hexc("BFE3F6"), horizon=0.75)
    sun(c, 256, 360, 60, hexc("FFF8E6"))
    pagoda(c, 256, 430, 170, tiers=5, h=70)
    cloud_bank(c, 425, 11, count=8, size=(160, 300))
    return c


def i06_day1_day100():
    a = icon_canvas(); sky(a, hexc("8FC8EC"), hexc("D8EEF8"))
    ry = island(a, 256, 290, 175, 4, 1.15)
    tent(a, 160, 290 - ry * 0.05, 2.2)
    cloud_bank(a, 470, 7, count=6)
    b = icon_canvas(); sky(b)
    sun(b, 430, 100, 26)
    sect(b, 256, 290, 175, 4, depth=1.15)
    cloud_bank(b, 470, 7, count=6)
    m = Image.new("L", (a.w, a.h), 0)
    ImageDraw.Draw(m).rectangle((a.w // 2, 0, a.w, a.h), fill=255)
    a.im.paste(b.im, (0, 0), m)
    rect(a, 254, 0, 258, 512, hexc("FFFFFF", 235))
    return a


def i07_serene_disciple():
    c = icon_canvas(); sky(c, hexc("9ED3F2"), hexc("E3F4FB"))
    aura(c, 256, 250, 220, JADE, 0.9)
    fy = avatar(c, 256, 470, 6.0, robe=hexc("F7F4EC"), trim=GOLD)
    orbs(c, 256, 380, 200, JADE_HI, n=6, size=9, phase=0.4)
    return c


def i08_rare_elder():
    c = icon_canvas(); sky(c, hexc("6FB9EE"), hexc("D3EEFA"))
    glow(c, 256, 210, 210, hexc("FFD36B"), 190)
    # halo: light, not a frame (a soft band, no hard ring edge)
    lay, d = c.draw()
    d.ellipse((c.S(116), c.S(70), c.S(396), c.S(350)), outline=hexc("FFF1C2", 200), width=c.S(16))
    c.put(lay, 6)
    avatar(c, 256, 500, 6.0, robe=hexc("C8322D"), trim=GOLD, hair=hexc("F4F4F4"))
    # beard + crown
    poly(c, [(220, 266), (292, 266), (270, 330), (256, 345), (242, 330)], hexc("F7F7F7"))
    poly(c, [(206, 116), (226, 76), (246, 104), (256, 62), (266, 104), (286, 76), (306, 116)], GOLD)
    orbs(c, 256, 380, 215, hexc("FFD36B"), n=7, size=9, phase=1.1)
    return c


def i09_giant_disciple():
    c = icon_canvas(); sky(c, hexc("7EC4F0"), hexc("DDF1FA"))
    aura(c, 256, 230, 190, JADE, 0.7)
    ry = island(c, 256, 360, 190, 8, 0.75)
    sakura(c, 110, 360 + ry * 0.1, 1.2, 2)
    sakura(c, 405, 360 + ry * 0.05, 1.1, 5)
    avatar(c, 256, 372, 4.6, robe=hexc("6C8ED1"), trim=GOLD)
    orbs(c, 256, 300, 190, JADE_HI, n=6, size=8, phase=0.3)
    cloud_bank(c, 492, 7, count=6)
    return c


def i10_sunset_silhouette():
    c = icon_canvas(); sky(c, hexc("F59B6B"), hexc("FFE0B0"))
    sun(c, 256, 250, 120, hexc("FFF3D9"))
    s = Canvas(512, 512, 4, bg=(0, 0, 0, 0))
    sect(s, 256, 300, 165, 4, depth=1.1)
    sil = s.im.split()[3]
    lay = Image.new("RGBA", (c.w, c.h), hexc("6A3B5E"))
    c.im.paste(lay, (0, 0), sil)
    cloud_bank(c, 480, 5, color=hexc("FFD2B5"), shade=hexc("EBA58E"), count=6)
    return c


ICONS = [i01_lone_peak, i02_golden_hall, i03_qi_drop, i04_build_moment, i05_pagoda_clouds,
         i06_day1_day100, i07_serene_disciple, i08_rare_elder, i09_giant_disciple, i10_sunset_silhouette]


# ---------------------------------------------------------------- the 10 thumbnails (1920 x 1080, drawn at 960 x 540 x 4)
def thumb_canvas():
    return Canvas(960, 540, 4)


TITLE = "Cultivation Tycoon"


def t01_archipelago():
    c = thumb_canvas(); sky(c)
    sun(c, 800, 90, 30)
    for (x, y, r, s) in ((130, 250, 60, 2), (820, 300, 75, 5), (600, 200, 40, 9)):
        island(c, x, y, r, s, 1.1)
    sect(c, 430, 330, 190, 4, depth=1.0)
    cloud_bank(c, 505, 3, count=12)
    text(c, TITLE, 480, 66, 54)
    return c


def t02_day1_day100():
    c = thumb_canvas(); sky(c)
    sun(c, 880, 70, 24)
    ry = island(c, 240, 310, 160, 4, 1.05)
    tent(c, 236, 310 - ry * 0.1, 2.0)
    avatar(c, 290, 310 - ry * 0.05, 1.3, robe=hexc("6C8ED1"), pose="stand", face=False)
    sect(c, 720, 310, 160, 4, depth=1.05)
    cloud_bank(c, 505, 3, count=12)
    text(c, "DAY 1", 240, 66, 52)
    text(c, "DAY 100", 720, 66, 52, fill=GOLD_HI)
    return c


RARITY = [("F2F2F2", "C8C8C8"), ("5AC878", "5AC878"), ("5096FF", "5096FF"), ("BE64FF", "BE64FF"),
          ("FFC83C", "FFC83C"), ("6EE1EB", "6EE1EB"), ("E6323C", "E6323C"), ("FF8C28", "FF8C28"), ("FFFFFF", "FF6EDC")]


def t03_rarity_ladder():
    c = thumb_canvas(); sky(c, hexc("6DB8EC"), hexc("D9F0FA"))
    rect(c, 0, 420, 960, 540, LAWN); rect(c, 0, 420, 960, 430, LAWN_HI)
    for i, (robe, au) in enumerate(RARITY):
        x = 64 + i * 104
        k = (i + 1) / len(RARITY)
        aura(c, x, 340, 34 + 44 * k, hexc(au), 0.35 + 0.65 * k)
        avatar(c, x, 440, 2.3, robe=hexc(robe), trim=GOLD if i >= 4 else hexc("D9D2C2"))
        if i >= 4:
            orbs(c, x, 360, 46 + i * 2, hexc(au), n=i - 1, size=3.5)
    text(c, TITLE, 480, 66, 54)
    return c


def t04_build_moment():
    c = thumb_canvas(); sky(c)
    glow(c, 560, 260, 280, hexc("FFE7A0"), 140)
    lay, d = c.draw()
    d.polygon([(c.S(400), c.S(450)), (c.S(720), c.S(450)), (c.S(650), 0), (c.S(470), 0)], fill=hexc("FFF4C9", 110))
    c.put(lay, 14)
    hall(c, 560, 380, 440)
    rect(c, 0, 380, 960, 540, LAWN); rect(c, 0, 380, 960, 392, LAWN_HI)
    for i in range(30):
        rng = random.Random(i)
        x, y = rng.uniform(330, 790), rng.uniform(60, 380)
        glow(c, x, y, 7, GOLD_HI, 200); ellipse(c, x - 2.5, y - 2.5, x + 2.5, y + 2.5, hexc("FFFFFF"))
    ellipse(c, 130, 470, 330, 515, JADE_HI); ellipse(c, 142, 476, 318, 509, JADE)
    avatar(c, 230, 495, 2.8, robe=VERMILION, pose="stand", arms_up=True, face=False)
    return c


def t05_pagoda_dawn():
    c = thumb_canvas(); sky(c, hexc("F6BE92"), hexc("C4E6F7"), horizon=0.7)
    sun(c, 640, 330, 70, hexc("FFF8E6"))
    pagoda(c, 170, 440, 170, tiers=6, h=64)
    pagoda(c, 820, 430, 90, tiers=4, h=36)
    cloud_bank(c, 405, 11, count=14, size=(180, 340))
    text(c, TITLE, 480, 66, 54)
    return c


def t06_qi_rain():
    c = thumb_canvas(); sky(c, hexc("5BB3EA"), hexc("D6F0FA"))
    sect(c, 480, 340, 210, 4, depth=0.95)
    rng = random.Random(4)
    for i in range(16):
        x, y, r = rng.uniform(80, 880), rng.uniform(40, 230), rng.uniform(10, 20)
        drop(c, x, y + r * 1.4, r)
        ellipse(c, x - r * 0.45, y + r * 0.4, x - r * 0.1, y + r * 1.1, hexc("FFFFFF", 150))
    cloud_bank(c, 505, 3, count=12)
    return c


def t07_neighbours():
    c = thumb_canvas(); sky(c)
    pts = [(170, 300, 120, 4), (480, 230, 140, 6), (790, 310, 120, 8)]
    lay, d = c.draw()
    for (a, b) in ((0, 1), (1, 2)):
        x0, y0 = pts[a][0] + pts[a][2] * 0.7, pts[a][1]
        x1, y1 = pts[b][0] - pts[b][2] * 0.7, pts[b][1]
        line = bez((x0, y0), ((x0 + x1) / 2, max(y0, y1) + 40), (x1, y1))
        d.line([(c.S(x), c.S(y)) for x, y in line], fill=hexc("8A5A3C"), width=c.S(7))
    c.put(lay)
    for i, (x, y, r, s) in enumerate(pts):
        ry = sect(c, x, y, r, s, depth=1.0, fall=(i == 1))
        avatar(c, x - r * 0.45, y + ry * 0.4, 0.9, robe=hexc(["5096FF", "E6323C", "5AC878"][i]), pose="stand", arms_up=True, face=False)
    cloud_bank(c, 505, 3, count=12)
    text(c, TITLE, 480, 60, 54)
    return c


def t08_breakthrough():
    c = thumb_canvas(); sky(c, hexc("3D8FDB"), hexc("BFE4F6"))
    lay, d = c.draw()
    d.polygon([(c.S(420), c.S(330)), (c.S(540), c.S(330)), (c.S(600), 0), (c.S(360), 0)], fill=hexc("FFF6D8", 170))
    c.put(lay, 12)
    glow(c, 480, 150, 120, hexc("FFF1C2"), 200)
    sect(c, 480, 380, 200, 4, depth=0.8)
    aura(c, 480, 205, 70, hexc("FFD36B"), 1.0)
    avatar(c, 480, 262, 2.2, robe=hexc("F7F4EC"), trim=GOLD)
    cloud_bank(c, 505, 3, count=12)
    text(c, "BREAK THROUGH", 480, 60, 50)
    return c


def t09_stairway():
    c = thumb_canvas(); sky(c, hexc("5FB3EC"), hexc("E2F4FB"))
    sun(c, 480, 110, 40)
    hall(c, 480, 200, 250)
    # the stair: a narrowing trapezoid of steps
    for i in range(22):
        t0, t1 = i / 22, (i + 1) / 22
        y0, y1 = 540 - t0 * 365, 540 - t1 * 365
        w0, w1 = 260 - t0 * 200, 260 - t1 * 200
        poly(c, [(480 - w0, y0), (480 + w0, y0), (480 + w1, y1), (480 - w1, y1)], PLASTER if i % 2 == 0 else STONE)
    cloud_bank(c, 470, 9, count=12, size=(150, 260), alpha=235)
    avatar(c, 480, 525, 1.2, robe=VERMILION, pose="stand", face=False)
    return c


def t10_lantern_night():
    c = thumb_canvas(); sky(c, hexc("1D2A55"), hexc("5B5C9A"))
    for i in range(70):
        rng = random.Random(i)
        x, y = rng.uniform(0, 960), rng.uniform(0, 260)
        ellipse(c, x - 1, y - 1, x + 1, y + 1, hexc("FFFFFF", 200))
    ellipse(c, 780, 60, 850, 130, hexc("FFF6E0"))
    glow(c, 815, 95, 80, hexc("FFF6E0"), 70)
    sect(c, 480, 350, 220, 4, depth=0.9)
    shade = c.layer(); ImageDraw.Draw(shade).rectangle((0, 0, c.w, c.h), fill=(30, 36, 90, 95)); c.put(shade)
    for i in range(40):
        rng = random.Random(100 + i)
        x, y = rng.uniform(140, 820), rng.uniform(60, 330)
        glow(c, x, y, 14, hexc("FFB45A"), 170)
        rect(c, x - 5, y - 7, x + 5, y + 7, hexc("FFD27A"), r=3)
    cloud_bank(c, 505, 3, color=hexc("3B4277"), shade=hexc("2A3060"), count=12)
    text(c, TITLE, 480, 60, 54)
    return c


THUMBS = [t01_archipelago, t02_day1_day100, t03_rarity_ladder, t04_build_moment, t05_pagoda_dawn,
          t06_qi_rain, t07_neighbours, t08_breakthrough, t09_stairway, t10_lantern_night]


# ---------------------------------------------------------------- output + pick boards
def name(fn):
    return fn.__name__


def board_icons(files):
    cell = 300
    B = Image.new("RGB", (5 * (cell + 170) + 20, 2 * (cell + 60) + 20), (18, 20, 26))
    d = ImageDraw.Draw(B)
    f = ImageFont.truetype(FONT, 22)
    for i, p in enumerate(files):
        im = Image.open(p).convert("RGB")
        x, y = 20 + (i % 5) * (cell + 170), 20 + (i // 5) * (cell + 60)
        B.paste(im.resize((cell, cell), Image.LANCZOS), (x, y))
        B.paste(im.resize((150, 150), Image.LANCZOS), (x + cell + 10, y))
        B.paste(im.resize((64, 64), Image.LANCZOS), (x + cell + 10, y + 160))
        d.text((x, y + cell + 8), os.path.basename(p)[5:-4].replace("_", " "), font=f, fill=(230, 230, 230))
    B.save(os.path.join(OUT, "board_icons.png"))


def board_thumbs(files):
    cw, ch = 480, 270
    B = Image.new("RGB", (5 * (cw + 20) + 20, 2 * (ch + 60) + 20), (18, 20, 26))
    d = ImageDraw.Draw(B)
    f = ImageFont.truetype(FONT, 22)
    for i, p in enumerate(files):
        im = Image.open(p).convert("RGB")
        x, y = 20 + (i % 5) * (cw + 20), 20 + (i // 5) * (ch + 60)
        B.paste(im.resize((cw, ch), Image.LANCZOS), (x, y))
        d.text((x, y + ch + 8), os.path.basename(p)[6:-4].replace("_", " "), font=f, fill=(230, 230, 230))
    B.save(os.path.join(OUT, "board_thumbs.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    icons, thumbs = [], []
    for i, fn in enumerate(ICONS, 1):
        p = os.path.join(OUT, f"icon_{name(fn)}.png")
        if not only or (only[0] == "icon" and int(only[1]) == i):
            fn().final(512, 512).save(p)
        icons.append(p)
    for i, fn in enumerate(THUMBS, 1):
        p = os.path.join(OUT, f"thumb_{name(fn)}.png")
        if not only or (only[0] == "thumb" and int(only[1]) == i):
            fn().final(1920, 1080).save(p)
        thumbs.append(p)
    if all(os.path.exists(p) for p in icons):
        board_icons(icons)
    if all(os.path.exists(p) for p in thumbs):
        board_thumbs(thumbs)


if __name__ == "__main__":
    main()
