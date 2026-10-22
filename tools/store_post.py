"""Store art post-processing (Gladiator recipe, docs/research/2026-10-21_store_icons_thumbnails.md):
real Studio captures of our disciples and halls, then grade, backlight, god rays behind the subject,
qi sparkles and gold title type. Raw captures: docs/art/mocks/store/raw/ (each hero shot has a
`_plate` twin with the subject hidden, which gives the subject mask).

    python tools/store_post.py      # -> docs/art/mocks/store/final/ (3 icons, 3 thumbnails, a board)
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "docs", "art", "mocks", "store", "raw")
OUT = os.path.join(ROOT, "docs", "art", "mocks", "store", "final")
FONTS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")
F_SERIF = os.path.join(FONTS, "cambriab.ttf")
GOLD_HI, GOLD_LO = (255, 232, 150), (222, 140, 36)


def load(name):
    return Image.open(os.path.join(RAW, name)).convert("RGB")


def crop_c(im, cx, cy, w, h):
    x0 = int(min(max(0, cx - w / 2), im.width - w))
    y0 = int(min(max(0, cy - h / 2), im.height - h))
    return im.crop((x0, y0, x0 + int(w), y0 + int(h)))


def arr(im):
    return np.asarray(im, np.float32)


def img(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def subject_mask(frame, plate, thr=26, grow=3, soft=2.5):
    """Where the frame differs from the plate = the subject (and its aura)."""
    d = np.abs(arr(frame) - arr(plate)).max(axis=2)
    m = Image.fromarray(((d > thr) * 255).astype(np.uint8), "L")
    m = m.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(grow * 2 + 1))
    return m.filter(ImageFilter.GaussianBlur(soft))


def grade(im, sat=1.15, con=1.08, bri=1.0, warm=(1.04, 1.0, 0.96), vig=0.35):
    im = ImageEnhance.Contrast(ImageEnhance.Color(im).enhance(sat)).enhance(con)
    a = arr(im) * bri
    H, W = a.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.sqrt(((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2)
    a *= (1 - vig * np.clip(d - 0.55, 0, 1) ** 1.6)[..., None]
    a *= np.array(warm, np.float32)
    return img(a)


def add(base, layer_rgb, k=1.0):
    return img(arr(base) + arr(layer_rgb) * k)


def screen(base, layer_rgb, k=1.0):
    a, b = arr(base) / 255, np.clip(arr(layer_rgb) * k / 255, 0, 1)
    return img((1 - (1 - a) * (1 - b)) * 255)


def radial(size, cx, cy, r, col, power=2.0):
    W, H = size
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    g = np.clip(1 - np.hypot(xx - cx, yy - cy) / r, 0, 1) ** power
    return img(g[..., None] * np.array(col, np.float32))


def rays(size, cx, cy, col, n=22, seed=3, length=1.6, width=(0.02, 0.06), alpha=(60, 140), blur=6):
    """God rays fanning out from (cx, cy): thin wedges, uneven, blurred."""
    W, H = size
    rng = random.Random(seed)
    L = Image.new("L", size, 0)
    d = ImageDraw.Draw(L)
    R = max(W, H) * length
    for i in range(n):
        a = rng.uniform(0, math.tau)
        w = rng.uniform(*width)
        d.polygon([(cx, cy), (cx + math.cos(a - w) * R, cy + math.sin(a - w) * R),
                   (cx + math.cos(a + w) * R, cy + math.sin(a + w) * R)], fill=rng.randint(*alpha))
    L = L.filter(ImageFilter.GaussianBlur(blur))
    # fade with distance so rays live near the source
    fall = arr(radial(size, cx, cy, max(W, H) * 0.75, (255, 255, 255), 1.1))[..., 0] / 255
    g = arr(L) / 255 * fall
    return img(g[..., None] * np.array(col, np.float32))


def sparkles(size, box, col, n=40, seed=5, rmax=7):
    """Qi motes: soft dots with a bright core, a few four-point glints."""
    W, H = size
    rng = random.Random(seed)
    lay = Image.new("RGB", size, (0, 0, 0))
    glow = Image.new("RGB", size, (0, 0, 0))
    d, dg = ImageDraw.Draw(lay), ImageDraw.Draw(glow)
    x0, y0, x1, y1 = box
    for i in range(n):
        x, y = rng.uniform(x0, x1), rng.uniform(y0, y1)
        r = rng.uniform(1.5, rmax)
        dg.ellipse((x - r * 3, y - r * 3, x + r * 3, y + r * 3), fill=col)
        d.ellipse((x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6), fill=(255, 255, 255))
        if i % 6 == 0:
            L = r * 5
            d.polygon([(x - L, y), (x, y - r * 0.5), (x + L, y), (x, y + r * 0.5)], fill=(255, 250, 230))
            d.polygon([(x, y - L), (x + r * 0.5, y), (x, y + L), (x - r * 0.5, y)], fill=(255, 250, 230))
    glow = glow.filter(ImageFilter.GaussianBlur(rmax * 1.6))
    return add(img(arr(glow) * 0.55), lay.filter(ImageFilter.GaussianBlur(0.8)))


def comp_behind(base, layer, mask, k=1.0):
    """Add a light layer only where the subject is NOT (rays and backlight go behind the figure)."""
    m = 1 - arr(mask)[..., None] / 255
    return img(arr(base) + arr(layer) * m * k)


def rim(base, mask, col, width=6, k=0.9):
    """A thin backlight rim along the subject's silhouette edge."""
    m = arr(mask) / 255
    outer = arr(mask.filter(ImageFilter.GaussianBlur(width))) / 255
    edge = np.clip(m - (arr(mask.filter(ImageFilter.MinFilter(width * 2 + 1))) / 255), 0, 1)
    e = np.clip(edge * 1.2 + (outer - m).clip(0) * 0.0, 0, 1)
    return img(arr(base) + e[..., None] * np.array(col, np.float32) * k)


# ---------------------------------------------------------------- type (ported from Gladiator's gold_text)
def font(size):
    return ImageFont.truetype(F_SERIF, size)


def tracked_w(text, f, track):
    d = ImageDraw.Draw(Image.new("L", (1, 1)))
    return sum(d.textlength(ch, font=f) for ch in text) + track * (len(text) - 1)


def gold_text(canvas, text, cx, y, size, max_w=None, track_ratio=0.06, hi=GOLD_HI, lo=GOLD_LO, pool=0):
    """Gold-gradient serif caps, soft shadow, warm rim. (cx, y) = top centre. Returns the ink bbox."""
    W, H = canvas.size
    s = size
    while max_w and s > 20 and tracked_w(text, font(s), s * track_ratio) > max_w:
        s -= 2
    f, tr = font(s), s * track_ratio
    w = tracked_w(text, f, tr)
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    x = cx - w / 2
    for ch in text:
        d.text((x, y), ch, font=f, fill=255)
        x += d.textlength(ch, font=f) + tr
    bb = mask.getbbox()
    c = canvas.convert("RGBA")
    if pool:
        p = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(p).rounded_rectangle([bb[0] - pool, bb[1] - pool * 0.6, bb[2] + pool, bb[3] + pool * 0.6],
                                            radius=pool, fill=(20, 16, 40, 120))
        c.alpha_composite(p.filter(ImageFilter.GaussianBlur(pool * 0.7)))
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.paste(Image.new("RGB", (W, H), (30, 14, 6)), (max(2, s // 30), max(3, s // 18)),
             mask.filter(ImageFilter.GaussianBlur(max(2, s // 16))).point(lambda v: int(v * 0.85)))
    c.alpha_composite(sh)
    gh = max(1, bb[3] - bb[1])
    ramp = np.clip((np.arange(H, dtype=np.float32) - bb[1]) / gh, 0, 1)[:, None]
    grad = np.array(hi, np.float32) * (1 - ramp) + np.array(lo, np.float32) * ramp
    lay = Image.fromarray(np.repeat(grad[:, None, :], W, axis=1).astype(np.uint8), "RGB").convert("RGBA")
    lay.putalpha(mask)
    c.alpha_composite(lay)
    # thin dark inline under the gradient edge reads as an engraved bevel
    edge = mask.filter(ImageFilter.MaxFilter(3))
    ring = Image.fromarray(np.clip(arr(edge) - arr(mask), 0, 255).astype(np.uint8), "L")
    inl = Image.new("RGBA", (W, H), (120, 64, 14, 255)); inl.putalpha(ring)
    c.alpha_composite(inl)
    out = c.convert("RGB")
    g = np.zeros((H, W, 3), np.float32)
    for b, tint in ((0.10, (214, 140, 40)), (0.03, (255, 236, 200))):
        gm = arr(mask.filter(ImageFilter.GaussianBlur(max(1, int(gh * b)))))[..., None] / 255
        g += gm * np.array(tint, np.float32) * 0.30
    return img(arr(out) + g), bb


def save(im, name, size):
    os.makedirs(OUT, exist_ok=True)
    im = im.resize(size, Image.LANCZOS)
    p = os.path.join(OUT, name)
    im.save(p)
    return p


# ---------------------------------------------------------------- the pieces
JADE, GOLD, WHITE_GOLD, RED_GOLD = (110, 235, 190), (255, 196, 80), (255, 240, 200), (255, 150, 60)


def hero_light(frame, plate, cx, cy, col, ray_col, seed=3, glow_r=520, glow_k=0.9, ray_k=1.0):
    """Backlight + god rays behind a disciple, a warm rim on him, qi motes around."""
    m = subject_mask(frame, plate)
    out = grade(frame, sat=1.18, con=1.10)
    out = comp_behind(out, radial(out.size, cx, cy, glow_r, col, 1.6), m, glow_k)
    out = comp_behind(out, rays(out.size, cx, cy, ray_col, n=26, seed=seed), m, ray_k)
    out = rim(out, m, (255, 236, 190), width=4, k=0.55)
    return out, m


def icon_disciple(name, frame_f, col, ray_col, mote, seed):
    fr, pl = load(frame_f), load("hero_plate.jpg")
    # head at about (904, 410) in the 1808 x 833 capture
    out, m = hero_light(fr, pl, 904, 400, col, ray_col, seed=seed, glow_r=470)
    out = crop_c(out, 904, 416, 833, 833)
    out = screen(out, sparkles(out.size, (60, 80, 773, 700), mote, n=26, seed=seed, rmax=6), 0.9)
    out = grade(out, sat=1.04, con=1.02, vig=0.45)
    return save(out, f"icon_{name}.png", (512, 512))


def icon_peak():
    fr = load("peak_wide.jpg")
    out = grade(fr, sat=1.2, con=1.1, warm=(1.06, 1.0, 0.92))
    out = crop_c(out, 905, 420, 833, 833)
    # the island is the subject: light comes from behind it, upper right
    out = add(out, radial(out.size, 560, 230, 520, (255, 220, 150), 1.8), 0.6)
    out = add(out, rays(out.size, 600, 180, (255, 236, 190), n=20, seed=8, alpha=(40, 110)), 0.9)
    out = screen(out, sparkles(out.size, (180, 120, 650, 420), JADE, n=22, seed=2, rmax=5), 0.9)
    out = grade(out, sat=1.0, con=1.04, vig=0.4)
    return save(out, "icon_floating_sect.png", (512, 512))


def label(c, text, cx, y, size, col):
    """Plain serif caps with a soft shadow (the 'before' side of a comparison)."""
    W, H = c.size
    f = font(size)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).text((cx, y), text, font=f, fill=255, anchor="mt")
    cc = c.convert("RGBA")
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    sh.paste(Image.new("RGB", c.size, (10, 10, 20)), (3, 5), m.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.8)))
    cc.alpha_composite(sh)
    lay = Image.new("RGBA", c.size, col + (255,)); lay.putalpha(m)
    cc.alpha_composite(lay)
    return cc.convert("RGB")


def arrow(c, cx, cy, s, col=(255, 226, 140)):
    cc = c.convert("RGBA")
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    pts = [(cx - s, cy - s * 0.32), (cx + s * 0.1, cy - s * 0.32), (cx + s * 0.1, cy - s * 0.75), (cx + s, cy),
           (cx + s * 0.1, cy + s * 0.75), (cx + s * 0.1, cy + s * 0.32), (cx - s, cy + s * 0.32)]
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon([(x + 4, y + 7) for x, y in pts], fill=(20, 10, 30, 150))
    cc.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)))
    d.polygon(pts, fill=col + (255,))
    d.polygon([(x, y) for x, y in pts[:4]] + [(cx + s * 0.1, cy), (cx - s, cy)], fill=(255, 244, 205, 255))
    cc.alpha_composite(lay)
    return cc.convert("RGB")


def thumb_outer_to_primordial():
    pl = load("hero_plate.jpg")
    a = grade(load("hero_outer.jpg"), sat=0.35, con=1.0, bri=0.72, warm=(0.95, 0.98, 1.06), vig=0.5)
    b, _ = hero_light(load("hero_primordial.jpg"), pl, 904, 400, WHITE_GOLD, (255, 246, 220), seed=4, glow_r=560)
    b = screen(b, sparkles(b.size, (500, 120, 1300, 760), JADE, n=40, seed=9, rmax=6), 0.9)
    L, R = crop_c(a, 904, 416, 740, 833), crop_c(b, 904, 416, 740, 833)
    c = Image.new("RGB", (1480, 833))
    c.paste(L, (0, 0)); c.paste(R, (740, 0))
    # a slanted seam
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).polygon([(800, 0), (1480, 0), (1480, 833), (680, 833)], fill=255)
    full = Image.new("RGB", c.size); full.paste(L, (0, 0)); full.paste(R, (740, 0))
    left_only = Image.new("RGB", c.size); left_only.paste(crop_c(a, 904 + 60, 416, 740 + 120, 833).resize((860, 833)), (0, 0))
    c = Image.composite(full, left_only, m.filter(ImageFilter.GaussianBlur(2)))
    c = c.resize((1920, 1080), Image.LANCZOS)
    d = ImageDraw.Draw(c)
    d.line([(1037, 0), (882, 1080)], fill=(255, 240, 200), width=6)
    c = label(c, "OUTER DISCIPLE", 470, 70, 82, (226, 230, 240))
    c, _ = gold_text(c, "PRIMORDIAL", 1430, 52, 118, max_w=900, pool=40)
    c = arrow(c, 960, 560, 92)
    c = grade(c, sat=1.0, con=1.02, vig=0.25)
    return save(c, "thumb_outer_to_primordial.png", (1920, 1080))


def thumb_build_your_sect():
    a = grade(load("peak_bare.jpg"), sat=0.85, con=1.0, bri=0.92, vig=0.4)
    b = grade(load("peak_full.jpg"), sat=1.22, con=1.1, warm=(1.06, 1.0, 0.92), vig=0.3)
    b = add(b, radial(b.size, 1100, 220, 700, (255, 220, 150), 1.8), 0.55)
    b = add(b, rays(b.size, 1150, 120, (255, 236, 190), n=22, seed=6, alpha=(40, 110)), 0.8)
    b = screen(b, sparkles(b.size, (500, 150, 1400, 520), GOLD, n=34, seed=3, rmax=6), 0.9)
    # one island, same camera: the left half still bare, the right half grown into the sect
    A, B = crop_c(a, 904, 416, 1480, 833), crop_c(b, 904, 416, 1480, 833)
    c = A.copy(); c.paste(B.crop((740, 0, 1480, 833)), (740, 0))
    c = c.resize((1920, 1080), Image.LANCZOS)
    ImageDraw.Draw(c).rectangle((957, 0, 963, 1080), fill=(255, 244, 214))
    c = label(c, "DAY 1", 480, 60, 104, (236, 240, 248))
    c, _ = gold_text(c, "DAY 100", 1440, 46, 130, pool=40)
    c = grade(c, sat=1.0, con=1.02, vig=0.22)
    return save(c, "thumb_build_your_sect.png", (1920, 1080))


def thumb_recruit_legends():
    out, m = hero_light(load("hero_emperor.jpg"), load("hero_plate.jpg"), 904, 380, (255, 205, 110), (255, 226, 160),
                        seed=11, glow_r=640, glow_k=1.0, ray_k=1.1)
    out = screen(out, sparkles(out.size, (300, 60, 1500, 760), GOLD, n=60, seed=12, rmax=7), 0.95)
    out = crop_c(out, 904, 416, 1480, 833).resize((1920, 1080), Image.LANCZOS)
    out, bb = gold_text(out, "RECRUIT", 400, 150, 132, pool=40)
    out, _ = gold_text(out, "LEGENDS", 1520, 150, 132, pool=40)
    out = grade(out, sat=1.0, con=1.02, vig=0.25)
    return save(out, "thumb_recruit_legends.png", (1920, 1080))


def board(icons, thumbs):
    B = Image.new("RGB", (3 * 680 + 40, 520 + 40 + 3 * 0 + 400), (18, 20, 26))
    d = ImageDraw.Draw(B)
    for i, p in enumerate(icons):
        im = Image.open(p).convert("RGB")
        x = 20 + i * 680
        B.paste(im.resize((440, 440), Image.LANCZOS), (x, 20))
        B.paste(im.resize((150, 150), Image.LANCZOS), (x + 460, 20))
        B.paste(im.resize((64, 64), Image.LANCZOS), (x + 460, 190))
    for i, p in enumerate(thumbs):
        im = Image.open(p).convert("RGB")
        B.paste(im.resize((640, 360), Image.LANCZOS), (20 + i * 680, 500))
    B.save(os.path.join(OUT, "board.png"))


# ---------------------------------------------------------------- round 4 (owner picks 2026-10-21)
def sky_mask(im):
    """Background = sky, cloud sea and clouds: blue-dominant or near-white bluish pixels."""
    a = arr(im)
    r, b = a[..., 0], a[..., 2]
    blue = np.clip((b - r - 16) / 30, 0, 1)
    white = np.clip((a.min(axis=2) - 205) / 30, 0, 1) * np.clip((b - r + 12) / 20, 0, 1)
    m = np.maximum(blue, white)
    M = Image.fromarray((m * 255).astype(np.uint8), "L").filter(ImageFilter.MedianFilter(5))
    return M.filter(ImageFilter.GaussianBlur(1.5))


def gradient_map(im, stops):
    """Map luminance onto a colour ramp (dark -> light); keeps the painted clouds' shapes."""
    L = np.clip((arr(im.convert("L")) / 255 - 0.15) / 0.85, 0, 1)
    n = len(stops) - 1
    idx = np.minimum((L * n).astype(int), n - 1)
    t = (L * n - idx)[..., None]
    S = np.array(stops, np.float32)
    return img(S[idx] * (1 - t) + S[idx + 1] * t)


def petal_shape(size, rot, col):
    """One sakura petal: a rounded oval with a notch and a pale centre, drawn 4x then reduced."""
    s = size * 4
    P = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(P)
    d.ellipse((s * 0.22, s * 0.08, s * 0.78, s * 0.92), fill=col + (255,))
    d.polygon([(s * 0.5, s * 0.10), (s * 0.40, 0), (s * 0.60, 0)], fill=(0, 0, 0, 0))
    d.ellipse((s * 0.36, s * 0.22, s * 0.56, s * 0.62), fill=(255, 238, 244, 190))
    P = P.filter(ImageFilter.GaussianBlur(s * 0.02)).rotate(rot, resample=Image.BICUBIC, expand=True)
    return P.resize((max(2, P.width // 4), max(2, P.height // 4)), Image.LANCZOS)


def scatter_petals(c, n, seed, box, size=(9, 20)):
    rng = random.Random(seed)
    cc = c.convert("RGBA")
    for i in range(n):
        x, y = rng.uniform(box[0], box[2]), rng.uniform(box[1], box[3])
        col = rng.choice([(246, 178, 196), (250, 204, 216), (236, 140, 170)])
        p = petal_shape(int(rng.uniform(*size)), rng.uniform(0, 360), col)
        if i % 4 == 0:  # a few near the lens, out of focus
            p = p.resize((p.width * 2, p.height * 2), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3))
        cc.alpha_composite(p, (int(x), int(y)))
    return cc.convert("RGB")


SAKURA = None


def sakura_cutout():
    """The game's own sakura canopy (leaf-card mesh) cut from its sky plate, trunk dropped."""
    fr, pl = load("sakura.jpg"), load("sakura_plate.jpg")
    m = subject_mask(fr, pl, thr=30, grow=1, soft=1.2)
    rgba = fr.convert("RGBA")
    rgba.putalpha(m)
    return rgba.crop((540, 40, 1470, 640))


def corner(c, piece, where, scale, rot=0):
    p = piece.resize((int(piece.width * scale), int(piece.height * scale)), Image.LANCZOS)
    if rot:
        p = p.rotate(rot, resample=Image.BICUBIC, expand=True)
    W, H = c.size
    x, y = {"tl": (-int(p.width * 0.42), -int(p.height * 0.45)), "br": (W - int(p.width * 0.55), H - int(p.height * 0.42))}[where]
    cc = c.convert("RGBA")
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    sh.paste(Image.new("RGB", p.size, (40, 20, 50)), (x + 6, y + 10), p.split()[3].point(lambda v: int(v * 0.35)))
    cc.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    return cc.convert("RGB")


def island_icon(name, stops, seed=1, night=False):
    global SAKURA
    if SAKURA is None:
        SAKURA = sakura_cutout()
    crop = crop_c(load("isl_day.jpg"), 895, 416, 833, 833)  # closer than round 3: the island fills the tile
    if stops:
        base = crop
        if night:
            base = img(arr(ImageEnhance.Brightness(crop).enhance(0.62)) * np.array([0.82, 0.88, 1.12]))
        crop = Image.composite(gradient_map(crop, stops), base, sky_mask(crop))
    out = grade(crop, sat=1.18, con=1.08, warm=(1.0, 1.0, 1.0), vig=0.0)
    glow_col = stops[2] if stops else (255, 226, 160)
    out = add(out, radial(out.size, 560, 230, 460, glow_col, 1.8), 0.25 if night else 0.45)
    if night:
        out = add(out, radial(out.size, 420, 300, 200, (255, 190, 110), 1.5), 0.55)
    out = screen(out, sparkles(out.size, (150, 150, 700, 500), (150, 200, 255) if night else (255, 236, 190), n=18, seed=seed, rmax=4), 0.8)
    out = corner(out, SAKURA, "tl", 0.52, rot=-18)
    out = corner(out, SAKURA, "br", 0.46, rot=160)
    out = scatter_petals(out, 18, seed, (60, 60, 780, 780), size=(12, 22))
    out = grade(out, sat=1.0, con=1.03, vig=0.32)
    return save(out, f"icon_{name}.png", (512, 512))


def cut(frame_f, plate_f="sky_plate.jpg", box=(560, 180, 1250, 833)):
    fr, pl = load(frame_f), load(plate_f)
    m = subject_mask(fr, pl, thr=34, grow=2, soft=2)
    rgba = fr.convert("RGBA")
    rgba.putalpha(m)
    return rgba.crop(box)


def sky_bg():
    bg = crop_c(load("sky_plate.jpg"), 904, 416, 1480, 833).resize((1920, 1080), Image.LANCZOS)
    return grade(bg, sat=1.1, con=1.04, vig=0.2)


def paste_subject(c, rgba, cx, base_y, h, glow=None, seed=1, dull=False):
    s = h / rgba.height
    p = rgba.resize((int(rgba.width * s), int(rgba.height * s)), Image.LANCZOS)
    x, y = int(cx - p.width / 2), int(base_y - p.height)
    if dull:
        rgb = ImageEnhance.Brightness(ImageEnhance.Color(p.convert("RGB")).enhance(0.25)).enhance(0.8)
        p = Image.merge("RGBA", (*rgb.split(), p.split()[3]))
    if glow:
        hx, hy = cx, y + p.height * 0.32
        c = add(c, radial(c.size, hx, hy, p.height * 0.75, glow, 1.6), 0.85)
        c = add(c, rays(c.size, hx, hy, (255, 248, 228), n=24, seed=seed, alpha=(50, 120)), 0.85)
    cc = c.convert("RGBA")
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    if glow:
        halo = Image.new("RGBA", p.size, glow + (0,))
        halo.putalpha(p.split()[3].filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v * 0.8)))
        lay.paste(halo, (x, y), halo)
        cc.alpha_composite(lay)
        lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    return cc.convert("RGB")


def compare(name, low_f, high_f, high_label, col, seed):
    c = sky_bg()
    dull = ImageEnhance.Brightness(ImageEnhance.Color(c).enhance(0.45)).enhance(0.72)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).polygon([(1010, 0), (1920, 0), (1920, 1080), (890, 1080)], fill=255)
    c = Image.composite(c, dull, m.filter(ImageFilter.GaussianBlur(2)))
    c = paste_subject(c, cut(low_f), 470, 1060, 760, dull=True)
    c = paste_subject(c, cut(high_f), 1440, 1060, 860, glow=col, seed=seed)
    c = screen(c, sparkles(c.size, (1000, 80, 1900, 1000), col, n=46, seed=seed, rmax=7), 0.9)
    ImageDraw.Draw(c).line([(1010, 0), (890, 1080)], fill=(255, 244, 214), width=6)
    c = label(c, "OUTER DISCIPLE", 470, 60, 76, (226, 230, 240))
    c, _ = gold_text(c, high_label, 1440, 44, 116, max_w=820, pool=40)
    c = arrow(c, 950, 560, 84)
    c = grade(c, sat=1.0, con=1.02, vig=0.22)
    return save(c, f"thumb_compare_{name}.png", (1920, 1080))


def day_split(name, f1, f100, cx, cy, zoom):
    w, h = 1480 * zoom, 833 * zoom
    a = grade(load(f1), sat=0.85, con=1.0, bri=0.92, vig=0.35)
    b = grade(load(f100), sat=1.22, con=1.1, warm=(1.06, 1.0, 0.92), vig=0.25)
    b = add(b, radial(b.size, 1150, 200, 700, (255, 220, 150), 1.8), 0.5)
    b = add(b, rays(b.size, 1180, 100, (255, 236, 190), n=22, seed=6, alpha=(40, 100)), 0.7)
    b = screen(b, sparkles(b.size, (900, 120, 1500, 520), GOLD, n=26, seed=3, rmax=6), 0.9)
    A, B = crop_c(a, cx, cy, w, h), crop_c(b, cx, cy, w, h)
    c = A.copy()
    c.paste(B.crop((int(w / 2), 0, int(w), int(h))), (int(w / 2), 0))
    c = c.resize((1920, 1080), Image.LANCZOS)
    ImageDraw.Draw(c).rectangle((957, 0, 963, 1080), fill=(255, 244, 214))
    c = label(c, "DAY 1", 480, 60, 104, (236, 240, 248))
    c, _ = gold_text(c, "DAY 100", 1440, 46, 130, pool=40)
    c = grade(c, sat=1.0, con=1.02, vig=0.2)
    return save(c, f"thumb_day_{name}.png", (1920, 1080))


def sky_single(name, frame_f, col, seed):
    c = paste_subject(sky_bg(), cut(frame_f), 1250, 1150, 1000, glow=col, seed=seed)
    c = screen(c, sparkles(c.size, (700, 60, 1860, 1000), col, n=40, seed=seed, rmax=7), 0.9)
    return save(grade(c, sat=1.0, con=1.02, vig=0.22), f"thumb_sky_{name}.png", (1920, 1080))


def sky_trio():
    c = sky_bg()
    for f, cx, by, h, col, sd in (("sky_lotus_elder.jpg", 400, 900, 560, (200, 130, 255), 7),
                                  ("sky_elder_immortal.jpg", 1520, 860, 600, (255, 210, 90), 8),
                                  ("sky_sword_celestial.jpg", 960, 1130, 840, (120, 230, 240), 9)):
        c = paste_subject(c, cut(f), cx, by, h, glow=col, seed=sd)
    c = screen(c, sparkles(c.size, (40, 40, 1880, 1040), (255, 240, 200), n=50, seed=4, rmax=6), 0.85)
    return save(grade(c, sat=1.0, con=1.02, vig=0.22), "thumb_sky_trio.png", (1920, 1080))


def board4(icons, thumbs):
    B = Image.new("RGB", (5 * 420 + 20, 600 + 3 * 330 + 20), (18, 20, 26))
    for i, p in enumerate(icons):
        im = Image.open(p).convert("RGB")
        x = 20 + i * 420
        B.paste(im.resize((400, 400), Image.LANCZOS), (x, 20))
        B.paste(im.resize((150, 150), Image.LANCZOS), (x, 430))
        B.paste(im.resize((64, 64), Image.LANCZOS), (x + 170, 430))
    for i, p in enumerate(thumbs):
        im = Image.open(p).convert("RGB")
        B.paste(im.resize((560, 315), Image.LANCZOS), (20 + (i % 3) * 580, 610 + (i // 3) * 330))
    B.save(os.path.join(OUT, "board_round4.png"))


def round4():
    """Owner picks: island icon x5 (closer, new colours, sakura corners); common-to-rare and
    day 1 / day 100 thumbnails x3 each; a text-free disciple on the painted sky x3."""
    icons = [
        island_icon("island_day", None, 1),
        island_icon("island_sunset", ((70, 30, 60), (238, 112, 72), (255, 214, 150), (255, 246, 222)), 2),
        island_icon("island_blossom", ((60, 40, 110), (196, 120, 196), (255, 190, 214), (255, 244, 248)), 3),
        island_icon("island_jade", ((10, 56, 70), (36, 150, 140), (150, 230, 200), (240, 255, 248)), 4),
        island_icon("island_night", ((10, 14, 46), (40, 50, 130), (120, 150, 230), (226, 236, 255)), 5, night=True),
    ]
    thumbs = [
        compare("lotus", "sky_lotus_outer.jpg", "sky_lotus_celestial.jpg", "CELESTIAL", (120, 230, 240), 1),
        compare("monk", "sky_monk_outer.jpg", "sky_monk_dao.jpg", "DAO ANCESTOR", (255, 90, 80), 2),
        compare("elder", "sky_elder_outer.jpg", "sky_elder_immortal.jpg", "IMMORTAL", (255, 210, 90), 3),
        day_split("mid", "d1_mid.jpg", "d100_mid.jpg", 904, 470, 1.0),
        day_split("high", "d1_high.jpg", "d100_high.jpg", 904, 470, 1.0),
        day_split("close", "d1_mid.jpg", "d100_mid.jpg", 904, 430, 0.86),
        sky_single("sword", "sky_sword_celestial.jpg", (120, 230, 240), 1),
        sky_single("lotus", "sky_lotus_elder.jpg", (200, 130, 255), 2),
        sky_trio(),
    ]
    board4(icons, thumbs)


# ---------------------------------------------------------------- round 5 (owner 2026-10-21: unzoom a bit, better light)
def light_island(out, sun, night=False):
    """Sun from the upper right: rays behind the island, a warm key on the lawn and hall,
    the rock underside sinks into a cool shade so the top reads first."""
    W, H = out.size
    a = arr(out)
    yy = np.mgrid[0:H, 0:W][0].astype(np.float32)
    under = np.clip((yy - H * 0.55) / (H * 0.35), 0, 1)[..., None]  # below the lawn rim
    a = a * (1 - 0.30 * under) + np.array([60, 70, 120], np.float32) * 0.30 * under * 0.6
    out = img(a)
    out = add(out, rays(out.size, W * 0.82, H * 0.08, sun, n=26, seed=21, alpha=(40, 110), blur=5), 0.55 if not night else 0.3)
    out = add(out, radial(out.size, W * 0.82, H * 0.08, W * 0.45, sun, 2.0), 0.32 if not night else 0.2)
    out = add(out, radial(out.size, W * 0.55, H * 0.36, W * 0.30, (255, 214, 150) if not night else (255, 180, 100), 1.7), 0.35)
    return out


ICON_SRC = "dense_wide.jpg"  # round 7: the round 5 camera on the denser staged sect (was peak_wide.jpg)


def island_icon5(name, stops, seed=1, night=False):
    global SAKURA
    if SAKURA is None:
        SAKURA = sakura_cutout()
    crop = crop_c(load(ICON_SRC), 905, 445, 690, 690)  # between round 3 (833) and round 4
    if stops:
        base = crop
        if night:
            # owner: the night island must stay easy to see, so it only takes a light moonlit tint
            base = img(arr(ImageEnhance.Brightness(crop).enhance(0.86)) * np.array([0.90, 0.95, 1.08]))
        sky = sky_mask(crop)
        crop = Image.composite(gradient_map(crop, stops), base, sky)
    out = grade(crop, sat=1.18, con=1.10, warm=(1.0, 1.0, 1.0), vig=0.0)
    sun = (150, 190, 255) if night else (stops[3] if stops else (255, 236, 196))
    out = light_island(out, sun, night)
    if night:
        W, H = out.size
        # a pale moon halo behind the island (sky only) separates its silhouette from the dark sky
        halo = radial(out.size, W * 0.5, H * 0.45, W * 0.62, (120, 150, 230), 1.4)
        out = img(arr(out) + arr(halo) * (arr(sky.resize(out.size))[..., None] / 255) * 0.7)
        # warm lantern light pooled on the lawn and halls
        out = add(out, radial(out.size, W * 0.5, H * 0.36, W * 0.36, (255, 186, 110), 1.6), 0.55)
    out = screen(out, sparkles(out.size, (140, 160, 560, 400), (150, 200, 255) if night else (255, 236, 190), n=16, seed=seed, rmax=4), 0.8)
    out = corner(out, SAKURA, "tl", 0.44, rot=-18)
    out = corner(out, SAKURA, "br", 0.38, rot=160)
    out = scatter_petals(out, 16, seed, (40, 40, 650, 650), size=(10, 18))
    out = grade(out, sat=1.0, con=1.04, vig=0.38)
    return save(out, f"icon5_{name}.png", (512, 512))


def big_aura(c, p, x, y, col, seed=1):
    """A loud rarity aura around a pasted subject p at (x, y): a coloured silhouette bloom,
    rising qi flames, a tilted orbit ring behind the body and a bright core. Additive."""
    W, H = c.size
    a = p.split()[3]
    sil = Image.new("L", c.size, 0)
    sil.paste(a, (x, y))
    out = c
    for grow, blur, k in ((41, 40, 1.0), (21, 16, 0.9), (7, 5, 0.7)):
        m = arr(sil.filter(ImageFilter.MaxFilter(grow)).filter(ImageFilter.GaussianBlur(blur)))[..., None] / 255
        out = img(arr(out) + m * np.array(col, np.float32) * k)
    # rising flames: tall soft streaks from the body upward
    rng = random.Random(seed)
    fl = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(fl)
    bx0, bx1 = x + p.width * 0.15, x + p.width * 0.85
    for i in range(26):
        fx = rng.uniform(bx0, bx1)
        top = y - rng.uniform(80, 340)
        w = rng.uniform(10, 34)
        d.polygon([(fx - w, y + p.height * 0.75), (fx + w, y + p.height * 0.75), (fx + rng.uniform(-30, 30), top)], fill=rng.randint(70, 150))
    fl = fl.filter(ImageFilter.GaussianBlur(14))
    out = img(arr(out) + arr(fl)[..., None] / 255 * np.array(mix_white(col, 0.25), np.float32) * 0.9)
    # orbit ring, tilted, behind: drawn on a layer and masked by the body
    ring = Image.new("L", c.size, 0)
    cx, cy = x + p.width / 2, y + p.height * 0.55
    rw, rh = p.width * 0.75, p.height * 0.22
    ImageDraw.Draw(ring).ellipse((cx - rw, cy - rh, cx + rw, cy + rh), outline=255, width=10)
    ring = ring.filter(ImageFilter.GaussianBlur(4))
    r = arr(ring)[..., None] / 255 * (1 - arr(sil)[..., None] / 255)
    out = img(arr(out) + r * np.array(mix_white(col, 0.5), np.float32) * 1.1)
    # orbiting motes on the ring
    for i in range(9):
        t = i / 9 * math.tau + seed
        ox, oy = cx + math.cos(t) * rw, cy + math.sin(t) * rh
        out = add(out, radial(out.size, ox, oy, 46, col, 1.6), 1.0)
        out = add(out, radial(out.size, ox, oy, 12, (255, 255, 255), 1.2), 1.0)
    return out


def mix_white(col, t):
    return tuple(int(v + (255 - v) * t) for v in col)


def paste_plain(c, rgba, cx, base_y, h, dull=False):
    s = h / rgba.height
    p = rgba.resize((int(rgba.width * s), int(rgba.height * s)), Image.LANCZOS)
    if dull:
        rgb = ImageEnhance.Brightness(ImageEnhance.Color(p.convert("RGB")).enhance(0.25)).enhance(0.8)
        p = Image.merge("RGBA", (*rgb.split(), p.split()[3]))
    x, y = int(cx - p.width / 2), int(base_y - p.height)
    return p, x, y


def compare5(name, low_f, high_f, high_label, col, seed):
    c = sky_bg()
    dull = ImageEnhance.Brightness(ImageEnhance.Color(c).enhance(0.45)).enhance(0.72)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).polygon([(1010, 0), (1920, 0), (1920, 1080), (890, 1080)], fill=255)
    c = Image.composite(c, dull, m.filter(ImageFilter.GaussianBlur(2)))
    c = paste_subject(c, cut(low_f), 470, 1060, 720, dull=True)
    p, x, y = paste_plain(c, cut(high_f), 1440, 1040, 800)
    c = add(c, rays(c.size, 1440, y + p.height * 0.3, (255, 248, 228), n=28, seed=seed, alpha=(50, 130)), 0.9)
    c = big_aura(c, p, x, y, col, seed)
    cc = c.convert("RGBA")
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    c = cc.convert("RGB")
    c = screen(c, sparkles(c.size, (1000, 60, 1900, 1000), col, n=60, seed=seed, rmax=8), 0.95)
    ImageDraw.Draw(c).line([(1010, 0), (890, 1080)], fill=(255, 244, 214), width=6)
    c = label(c, "OUTER DISCIPLE", 470, 60, 76, (226, 230, 240))
    c, _ = gold_text(c, high_label, 1440, 44, 116, max_w=820, pool=40)
    c = arrow(c, 950, 560, 84)
    c = grade(c, sat=1.0, con=1.02, vig=0.22)
    return save(c, f"thumb5_compare_{name}.png", (1920, 1080))


def key(frame_f, box=(520, 60, 1290, 800)):
    """Magenta-screen cutout (Studio shot against a SmoothPlastic 230,0,230 board): clean edges even
    on white robes, which the sky-plate difference mask lost against white cloud."""
    a = arr(load(frame_f))
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.clip((np.minimum(r, b) - g - 22) / 40, 0, 1)  # also keys the bright hot spot of the board
    alpha = 1 - m
    # despill: pull the magenta cast out of edge pixels
    spill = np.clip(np.minimum(r, b) - g, 0, None) * (1 - alpha) * 0.9
    a[..., 0] -= spill * 0.6
    a[..., 2] -= spill * 0.6
    # only board pixels connected to the frame edge are background: pink-lit robe and gold inside the
    # silhouette also read as "magenta" and went see-through (the glow behind washed them out)
    bg = Image.fromarray(((m > 0.5) * 255).astype(np.uint8), "L").copy()  # a copy: floodfill silently skips an array-backed image
    for xy in ((0, 0), (bg.width - 1, 0), (0, bg.height - 1), (bg.width - 1, bg.height - 1)):
        ImageDraw.floodfill(bg, xy, 128)
    outside = (np.asarray(bg) == 128)
    outside = np.asarray(Image.fromarray((outside * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))) > 0
    alpha = np.where(outside | (m > 0.9), alpha, 1.0)  # pure board inside a closed ring (magic circle) is still board
    A = Image.fromarray((alpha * 255).astype(np.uint8), "L").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    rgba = img(a).convert("RGBA")
    rgba.putalpha(A)
    rgba = rgba.crop(box)
    return rgba.crop(rgba.getbbox())


def compare6(name, low_f, high_f, high_label, col, seed):
    c = sky_bg()
    dull = ImageEnhance.Brightness(ImageEnhance.Color(c).enhance(0.45)).enhance(0.72)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).polygon([(1010, 0), (1920, 0), (1920, 1080), (890, 1080)], fill=255)
    ms = m.filter(ImageFilter.GaussianBlur(2))
    c = Image.composite(c, dull, ms)
    c = paste_subject(c, key(low_f), 470, 1000, 640, dull=True)
    # the rare side: everything loud happens on its own half only
    hi = sky_bg()
    p, x, y = paste_plain(hi, key(high_f), 1440, 1000, 720)
    hi = add(hi, rays(hi.size, 1440, y + p.height * 0.3, (255, 248, 228), n=28, seed=seed, alpha=(50, 130)), 0.9)
    hi = big_aura(hi, p, x, y, col, seed)
    hh = hi.convert("RGBA")
    lay = Image.new("RGBA", hi.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    hh.alpha_composite(lay)
    hi = screen(hh.convert("RGB"), sparkles(hi.size, (1000, 60, 1900, 1000), col, n=60, seed=seed, rmax=8), 0.95)
    c = Image.composite(hi, c, ms)
    ImageDraw.Draw(c).line([(1010, 0), (890, 1080)], fill=(255, 244, 214), width=6)
    c = label(c, "OUTER DISCIPLE", 470, 60, 76, (226, 230, 240))
    c, _ = gold_text(c, high_label, 1440, 44, 116, max_w=820, pool=40)
    c = arrow(c, 950, 560, 84)
    c = grade(c, sat=1.0, con=1.02, vig=0.22)
    return save(c, f"thumb6_compare_{name}.png", (1920, 1080))


def day6(name, f1, f100, cx, cy, soft=False):
    a = grade(load(f1), sat=0.85, con=1.0, bri=0.92, vig=0.35)
    b = grade(load(f100), sat=1.22, con=1.1, warm=(1.06, 1.0, 0.92), vig=0.25)
    b = add(b, radial(b.size, 1250, 180, 700, (255, 220, 150), 1.8), 0.5)
    b = add(b, rays(b.size, 1300, 80, (255, 236, 190), n=22, seed=6, alpha=(40, 100)), 0.7)
    b = screen(b, sparkles(b.size, (900, 120, 1500, 520), GOLD, n=26, seed=3, rmax=6), 0.9)
    A, B = crop_c(a, cx, cy, 1480, 833), crop_c(b, cx, cy, 1480, 833)
    m = Image.new("L", A.size, 0)
    if soft:
        # a wide feathered diagonal: the lawn fills in as the eye moves right
        g = np.clip((np.mgrid[0:833, 0:1480][1] - 560 + (np.mgrid[0:833, 0:1480][0] - 416) * 0.35) / 380, 0, 1)
        m = Image.fromarray((g * 255).astype(np.uint8), "L")
    else:
        ImageDraw.Draw(m).rectangle((740, 0, 1480, 833), fill=255)
    c = Image.composite(B, A, m).resize((1920, 1080), Image.LANCZOS)
    if not soft:
        ImageDraw.Draw(c).rectangle((957, 0, 963, 1080), fill=(255, 244, 214))
    c = label(c, "DAY 1", 400 if soft else 480, 60, 104, (236, 240, 248))
    c, _ = gold_text(c, "DAY 100", 1500 if soft else 1440, 46, 130, pool=40)
    c = grade(c, sat=1.0, con=1.02, vig=0.2)
    return save(c, f"thumb6_day_{name}.png", (1920, 1080))


def white_tile(name, frame_f, col, cx=1060):
    """Be a Fish style: the disciple big on plain white, a soft rarity glow and a contact shadow."""
    W, H = 1920, 1080
    c = Image.new("RGB", (W, H), (255, 255, 255))
    p = key(frame_f)
    s = 900 / p.height
    p = p.resize((int(p.width * s), int(p.height * s)), Image.LANCZOS)
    x, y = int(cx - p.width / 2), int(1010 - p.height)
    c = img(arr(c) - (255 - arr(radial(c.size, cx, y + p.height * 0.45, 560, (255, 255, 255), 1.4))) * 0 )
    glow = radial(c.size, cx, y + p.height * 0.45, 600, col, 1.8)
    c = img(arr(c) * (1 - arr(glow) / 255 * 0.0) - (255 - arr(glow)) * 0 + 0)  # keep white ground
    c = img(np.minimum(arr(c), 255 - (255 - np.array(mix_white(col, 0.55), np.float32)) * (arr(radial(c.size, cx, y + p.height * 0.45, 620, (255, 255, 255), 2.0)) / 255)))
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - p.width * 0.42, 1000, cx + p.width * 0.42, 1050), fill=(40, 40, 60, 90))
    cc = c.convert("RGBA")
    cc.alpha_composite(sh.filter(ImageFilter.GaussianBlur(18)))
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    return save(cc.convert("RGB"), f"thumb6_white_{name}.png", (W, H))


def round6():
    fs = [compare6("lotus", "key_lotus_outer.jpg", "key_lotus_celestial.jpg", "CELESTIAL", (90, 225, 240), 1),
          compare6("monk_elder", "key_monk_outer.jpg", "key_elder_immortal.jpg", "IMMORTAL", (255, 200, 60), 3),
          day6("right", "d1_right.jpg", "d100_right.jpg", 904, 416),
          day6("front", "d1_front.jpg", "d100_front.jpg", 904, 416),
          day6("soft", "peak_bare.jpg", "peak_full.jpg", 904, 416, soft=True),
          white_tile("lotus", "key_lotus_celestial.jpg", (90, 225, 240)),
          white_tile("elder", "key_elder_immortal.jpg", (255, 200, 60)),
          white_tile("sword", "key_sword_dao.jpg", (255, 90, 80))]
    B = Image.new("RGB", (3 * 650 + 10, 3 * 370 + 10), (18, 20, 26))
    for i, f in enumerate(fs):
        im = Image.open(f).convert("RGB")
        B.paste(im.resize((640, 360), Image.LANCZOS), (10 + (i % 3) * 650 if i < 2 else 10 + ((i - 2) % 3) * 650, 10 if i < 2 else 10 + (1 + (i - 2) // 3) * 370))
    B.save(os.path.join(OUT, "board_thumbs_round5.png"))


def round7():
    """Owner: less underside, more buildings. Dense staged sect (pagodas, bell tower, halls, gate)."""
    global SAKURA
    if SAKURA is None:
        SAKURA = sakura_cutout()
    icons = []
    for name, src, cy, stops, seed, night in (
        ("day", "dense_b.jpg", 400, None, 1, False),
        ("day_low", "dense_a.jpg", 395, None, 6, False),
        ("sunset", "dense_b.jpg", 400, ((70, 30, 60), (238, 112, 72), (255, 214, 150), (255, 246, 222)), 2, False),
        ("blossom", "dense_b.jpg", 400, ((60, 40, 110), (196, 120, 196), (255, 190, 214), (255, 244, 248)), 3, False),
        ("night", "dense_b.jpg", 400, ((10, 14, 46), (40, 50, 130), (120, 150, 230), (226, 236, 255)), 5, True)):
        crop = crop_c(load(src), 905, 416, 833, 833)  # full height: the whole outline, the underside cut at the frame edge
        if stops:
            base = crop
            if night:
                base = img(arr(ImageEnhance.Brightness(crop).enhance(0.62)) * np.array([0.82, 0.88, 1.12]))
            crop = Image.composite(gradient_map(crop, stops), base, sky_mask(crop))
        out = grade(crop, sat=1.18, con=1.10, warm=(1.0, 1.0, 1.0), vig=0.0)
        out = light_island(out, (150, 190, 255) if night else (stops[3] if stops else (255, 236, 196)), night)
        out = screen(out, sparkles(out.size, (140, 120, 640, 420), (150, 200, 255) if night else (255, 236, 190), n=16, seed=seed, rmax=4), 0.8)
        out = corner(out, SAKURA, "tl", 0.46, rot=-18)
        out = corner(out, SAKURA, "br", 0.40, rot=160)
        out = scatter_petals(out, 16, seed, (40, 40, 740, 740), size=(10, 18))
        out = grade(out, sat=1.0, con=1.04, vig=0.38)
        icons.append(save(out, f"icon7_{name}.png", (512, 512)))
    thumbs = [day6("dense_front", "dense_front1.jpg", "dense_front100.jpg", 904, 400),
              day6("dense_side", "dense_side1.jpg", "dense_side100.jpg", 904, 400)]
    for f in thumbs:
        os.replace(f, f.replace("thumb6_", "thumb7_"))
    thumbs = [f.replace("thumb6_", "thumb7_") for f in thumbs]
    B = Image.new("RGB", (5 * 330 + 10, 330 + 170 + 2 * 0 + 380), (18, 20, 26))
    for i, f in enumerate(icons):
        im = Image.open(f).convert("RGB")
        B.paste(im.resize((320, 320), Image.LANCZOS), (10 + i * 330, 10))
        B.paste(im.resize((150, 150), Image.LANCZOS), (10 + i * 330, 340))
        B.paste(im.resize((64, 64), Image.LANCZOS), (170 + i * 330, 340))
    for i, f in enumerate(thumbs):
        im = Image.open(f).convert("RGB")
        B.paste(im.resize((640, 360), Image.LANCZOS), (10 + i * 660, 510))
    B.save(os.path.join(OUT, "board_round6.png"))


def zoom_blur(im, cx, cy, n=10, amount=0.06):
    """Radial (zoom) blur toward (cx, cy): the background rushes out from the burst."""
    acc = arr(im) * 0
    W, H = im.size
    for i in range(n):
        s = 1 + amount * i / (n - 1)
        big = im.resize((int(W * s), int(H * s)), Image.BILINEAR)
        x0, y0 = int(cx * s - cx), int(cy * s - cy)
        acc += arr(big.crop((x0, y0, x0 + W, y0 + H)))
    return img(acc / n)


def burst(name, frame_f, col, seed):
    """Owner idea: the new characters with a big aura burst, like a mental attack. No text."""
    W, H = 1920, 1080
    p0 = key(frame_f)
    s = 960 / p0.height
    p = p0.resize((int(p0.width * s), int(p0.height * s)), Image.LANCZOS)
    cx, base = 960, 1100
    x, y = int(cx - p.width / 2), int(base - p.height)
    hx, hy = cx, y + p.height * 0.32  # the head: the burst comes from the mind
    c = zoom_blur(sky_bg(), hx, hy, amount=0.10)
    c = img(arr(c) * 0.78)  # the sky dims so the burst is the light
    c = add(c, radial(c.size, hx, hy, 900, col, 1.5), 0.9)
    # shockwave rings expanding from the head, each thinner and fainter
    rings = Image.new("L", c.size, 0)
    d = ImageDraw.Draw(rings)
    for i, (r, w, a) in enumerate(((260, 26, 255), (430, 16, 200), (620, 10, 150), (840, 6, 110))):
        d.ellipse((hx - r * 1.25, hy - r, hx + r * 1.25, hy + r), outline=a, width=w)
    rings = rings.filter(ImageFilter.GaussianBlur(5))
    c = img(arr(c) + arr(rings)[..., None] / 255 * np.array(mix_white(col, 0.45), np.float32) * 0.6)
    c = add(c, rays(c.size, hx, hy, mix_white(col, 0.6), n=40, seed=seed, length=2.0, width=(0.006, 0.02), alpha=(90, 200), blur=3), 1.0)
    c = big_aura(c, p, x, y, col, seed)
    cc = c.convert("RGBA")
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    c = cc.convert("RGB")
    c = add(c, radial(c.size, hx, hy, 130, (255, 255, 255), 1.4), 0.55)
    c = screen(c, sparkles(c.size, (100, 40, 1820, 1040), col, n=90, seed=seed, rmax=8), 0.95)
    c = grade(c, sat=1.05, con=1.06, vig=0.35)
    return save(c, f"thumb9_burst_{name}.png", (W, H))


def round9():
    fs = [compare6("lotus_v2", "c2_lotus_outer.jpg", "c2_lotus_celestial.jpg", "CELESTIAL", (90, 225, 240), 1),
          compare6("monk_elder_v2", "c2_monk_outer.jpg", "c2_elder_immortal.jpg", "IMMORTAL", (255, 200, 60), 3),
          burst("emperor", "c2_sword_emperor.jpg", (255, 150, 50), 11),
          burst("dao", "c2_monk_dao.jpg", (255, 60, 70), 12),
          burst("celestial", "c2_lotus_celestial.jpg", (90, 225, 240), 13)]
    B = Image.new("RGB", (3 * 650 + 10, 2 * 370 + 10), (18, 20, 26))
    for i, f in enumerate(fs):
        B.paste(Image.open(f).convert("RGB").resize((640, 360), Image.LANCZOS), (10 + (i % 3 if i < 2 else (i - 2)) * 650, 10 if i < 2 else 380))
    B.save(os.path.join(OUT, "board_characters_round9.png"))


def juice_ladder():
    """Owner 2026-10-22: the kept day icon at five juice levels, simplest to noisiest.
    1 clean grade only, 2 sun rays, 3 + sakura corners, 4 + petals and qi motes,
    5 + a golden qi ring around the island, orbs and a lens flare."""
    global SAKURA
    if SAKURA is None:
        SAKURA = sakura_cutout()
    base = grade(crop_c(load(ICON_SRC), 905, 445, 690, 690), sat=1.18, con=1.10, warm=(1.0, 1.0, 1.0), vig=0.0)
    W, H = base.size
    out = []
    # 1: clean
    l1 = grade(base, sat=1.02, con=1.03, vig=0.30)
    out.append(l1)
    # 2: light only
    l2 = light_island(base, (255, 236, 196))
    out.append(grade(l2, sat=1.0, con=1.04, vig=0.34))
    # 3: + sakura corners
    l3 = corner(corner(l2, SAKURA, "tl", 0.44, rot=-18), SAKURA, "br", 0.38, rot=160)
    out.append(grade(l3, sat=1.0, con=1.04, vig=0.36))
    # 4: + petals and motes
    l4 = screen(l3, sparkles(l3.size, (140, 160, 560, 400), (255, 236, 190), n=16, seed=1, rmax=4), 0.8)
    l4 = scatter_petals(l4, 16, 1, (40, 40, 650, 650), size=(10, 18))
    out.append(grade(l4, sat=1.0, con=1.04, vig=0.38))
    # 5: + qi ring, orbs, flare
    ring = Image.new("L", l4.size, 0)
    d = ImageDraw.Draw(ring)
    cx, cy, rw, rh = W * 0.5, H * 0.50, W * 0.47, H * 0.12
    d.ellipse((cx - rw, cy - rh, cx + rw, cy + rh), outline=255, width=9)
    ring = Image.fromarray(np.maximum(arr(ring.filter(ImageFilter.GaussianBlur(4))), arr(ring.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(18))) * 0.7).astype(np.uint8), "L")
    # the near half of the ring passes in front of the island, the far half behind it (masked by sky)
    sky = arr(sky_mask(base)) / 255
    yy = np.mgrid[0:H, 0:W][0]
    front = (yy > cy)[..., None]
    rk = arr(ring)[..., None] / 255 * np.where(front, 1.0, sky[..., None])
    l5 = img(arr(l4) + rk * np.array((255, 214, 120), np.float32) * 1.6)
    l5 = add(l5, radial(l5.size, cx, cy, W * 0.5, (255, 200, 110), 1.8), 0.25)
    for i in range(10):
        t = i / 10 * math.tau + 0.5
        ox, oy = cx + math.cos(t) * rw, cy + math.sin(t) * rh
        if math.sin(t) < 0 and sky[int(oy), int(ox)] < 0.5:
            continue  # this orb is behind the island
        l5 = add(l5, radial(l5.size, ox, oy, 34, (255, 210, 110), 1.6), 1.0)
        l5 = add(l5, radial(l5.size, ox, oy, 9, (255, 255, 255), 1.2), 1.0)
    l5 = add(l5, radial(l5.size, W * 0.82, H * 0.08, 70, (255, 255, 240), 1.2), 0.9)  # the flare core
    for k, f in ((0.62, 22), (0.45, 12), (0.3, 30)):  # flare ghosts along the sun-to-centre line
        fx, fy = W * 0.82 + (cx - W * 0.82) * (1 + k), H * 0.08 + (cy - H * 0.08) * (1 + k)
        l5 = add(l5, radial(l5.size, fx, fy, f, (180, 220, 255), 1.4), 0.5)
    l5 = screen(l5, sparkles(l5.size, (40, 40, 650, 650), (255, 226, 160), n=40, seed=7, rmax=6), 0.9)
    l5 = scatter_petals(l5, 22, 9, (40, 40, 650, 650), size=(12, 24))
    out.append(grade(l5, sat=1.0, con=1.05, vig=0.40))
    files = [save(o, f"icon11_juice{i + 1}.png", (512, 512)) for i, o in enumerate(out)]
    B = Image.new("RGB", (5 * 330 + 10, 330 + 170), (18, 20, 26))
    for i, f in enumerate(files):
        im = Image.open(f).convert("RGB")
        B.paste(im.resize((320, 320), Image.LANCZOS), (10 + i * 330, 10))
        B.paste(im.resize((150, 150), Image.LANCZOS), (10 + i * 330, 340))
        B.paste(im.resize((64, 64), Image.LANCZOS), (170 + i * 330, 340))
    B.save(os.path.join(OUT, "board_icon_juice.png"))
    return files


def hero_sky(name, frame_f, col, seed, word=None, flying=False):
    """Owner 2026-10-22: burst and flying read busy; the painted sky only behind, one figure big,
    a soft glow in its colour and a few motes. Optional one short gold word in the free half."""
    W, H = 1920, 1080
    p0 = key(frame_f)
    h = 860 if flying else 900
    s = h / p0.height
    p = p0.resize((int(p0.width * s), int(p0.height * s)), Image.LANCZOS)
    cx = 1200 if word else 960
    base = 1000 if flying else 1080
    x, y = int(cx - p.width / 2), int(base - p.height)
    c = sky_bg()
    hx, hy = cx, y + p.height * 0.40
    c = add(c, radial(c.size, hx, hy, 700, col, 1.8), 0.7)
    c = add(c, rays(c.size, hx, hy, mix_white(col, 0.6), n=16, seed=seed, length=1.2, width=(0.01, 0.03), alpha=(40, 90), blur=8), 0.6)
    halo = Image.new("RGBA", p.size, col + (0,))
    halo.putalpha(p.split()[3].filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.85)))
    cc = c.convert("RGBA")
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    lay.paste(halo, (x, y), halo)
    lay.paste(p, (x, y), p)
    cc.alpha_composite(lay)
    c = screen(cc.convert("RGB"), sparkles(c.size, (x - 200, y - 100, x + p.width + 200, y + p.height), col, n=26, seed=seed, rmax=6), 0.85)
    if word:
        c, _ = gold_text(c, word, 520, 420, 150, max_w=760, pool=50)
    c = grade(c, sat=1.02, con=1.04, vig=0.22)
    tag = ("fly" if flying else "burst") + "_" + name + ("_word" if word else "")
    return save(c, f"thumb12_{tag}.png", (W, H))


def icons5():
    return [
        island_icon5("day", None, 1),
        island_icon5("sunset", ((70, 30, 60), (238, 112, 72), (255, 214, 150), (255, 246, 222)), 2),
        island_icon5("blossom", ((60, 40, 110), (196, 120, 196), (255, 190, 214), (255, 244, 248)), 3),
        island_icon5("jade", ((10, 56, 70), (36, 150, 140), (150, 230, 200), (240, 255, 248)), 4),
        island_icon5("night", ((10, 14, 46), (40, 50, 130), (120, 150, 230), (226, 236, 255)), 5, night=True),
    ]


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["icons5"]:
        fs = icons5()
        B = Image.new("RGB", (5 * 330 + 10, 330 + 170), (18, 20, 26))
        for i, f in enumerate(fs):
            im = Image.open(f).convert("RGB")
            B.paste(im.resize((320, 320), Image.LANCZOS), (10 + i * 330, 10))
            B.paste(im.resize((150, 150), Image.LANCZOS), (10 + i * 330, 340))
            B.paste(im.resize((64, 64), Image.LANCZOS), (170 + i * 330, 340))
        B.save(os.path.join(OUT, "board_icons_round5.png"))
        raise SystemExit
    if sys.argv[1:] == ["round4"]:
        round4()
        raise SystemExit
    icons = [icon_disciple("primordial", "hero_primordial.jpg", (255, 246, 220), (255, 250, 230), JADE, 4),
             icon_disciple("heavenly_emperor", "hero_emperor.jpg", (255, 205, 110), (255, 226, 160), GOLD, 11),
             icon_peak()]
    thumbs = [thumb_outer_to_primordial(), thumb_build_your_sect(), thumb_recruit_legends()]
    board(icons, thumbs)
