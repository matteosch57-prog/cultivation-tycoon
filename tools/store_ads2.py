"""Ad creatives round 2 (2026-10-29): Day 1 / Day 100 with the blue Celestial cultivator. Builds on store_post.py."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import store_post as S
from store_post import *
_cal = "/usr/share/fonts/truetype/crosextra/Caladea-Bold.ttf"
if os.path.exists(_cal):
    S.F_SERIF = _cal
S.OUT = os.path.join(S.ROOT, "docs", "art", "mocks", "store", "ads2")
BLUE = (90, 225, 240)
W, H = 1920, 1080

def island(f, cx, cy, scale, seed_xy=(904, 420)):
    """Cut the island out of its capture: the non-sky blob connected to the island centre."""
    im = grade(load(f), sat=1.2, con=1.08, warm=(1.04, 1.0, 0.95), vig=0.0)
    m = Image.fromarray(255 - np.asarray(sky_mask(im)), "L")
    b = m.point(lambda v: 255 if v > 110 else 0).filter(ImageFilter.MedianFilter(5)).copy()
    ImageDraw.floodfill(b, seed_xy, 128)
    keep = Image.fromarray(((np.asarray(b) == 128) * 255).astype(np.uint8), "L")
    keep = keep.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    rgba = im.convert("RGBA"); rgba.putalpha(keep)
    rgba = rgba.crop(keep.point(lambda v: 255 if v > 128 else 0).getbbox())
    rgba = rgba.resize((int(rgba.width * scale), int(rgba.height * scale)), Image.LANCZOS)
    return rgba, int(cx - rgba.width / 2), int(cy - rgba.height / 2)

def paste(c, p, x, y):
    cc = c.convert("RGBA"); lay = Image.new("RGBA", c.size, (0, 0, 0, 0)); lay.paste(p, (x, y), p); cc.alpha_composite(lay); return cc.convert("RGB")

def hero(c, f, cx, base, h, col, seed, loud=True):
    p0 = key(f, box=(380, 30, 1430, 833)); s = h / p0.height
    p = p0.resize((int(p0.width * s), int(p0.height * s)), Image.LANCZOS)
    x, y = int(cx - p.width / 2), int(base - p.height)
    hx, hy = cx, y + p.height * 0.35
    c = add(c, radial(c.size, hx, hy, h * 0.9, col, 1.6), 0.8)
    c = add(c, rays(c.size, hx, hy, mix_white(col, 0.6), n=30, seed=seed, length=1.4, width=(0.008, 0.025), alpha=(60, 160), blur=4), 0.9)
    if loud:
        c = big_aura(c, p, x, y, col, seed)
    halo = Image.new("RGBA", p.size, col + (0,))
    halo.putalpha(p.split()[3].filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.85)))
    c = paste(c, halo, x, y); c = paste(c, p, x, y)
    return c, (x, y, p)

def plain(c, f, cx, base, h):
    p0 = key(f, box=(380, 30, 1430, 833)); s = h / p0.height
    p = p0.resize((int(p0.width * s), int(p0.height * s)), Image.LANCZOS)
    x, y = int(cx - p.width / 2), int(base - p.height)
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((cx - p.width * 0.4, base - 18, cx + p.width * 0.4, base + 14), fill=(20, 30, 20, 110))
    cc = c.convert("RGBA"); cc.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
    return paste(cc.convert("RGB"), p, x, y)

def split_bg(sky_dull=True):
    c = sky_bg()
    dull = ImageEnhance.Brightness(ImageEnhance.Color(c).enhance(0.5)).enhance(0.78)
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).rectangle((960, 0, W, H), fill=255)
    return Image.composite(c, dull, m), m

def A(words=True, name="A"):
    """Day 1 / Day 100 with YOU: plain disciple on a bare island -> blue Celestial over the full sect."""
    c, m = split_bg()
    i1, x1, y1 = island("dd1_wide.jpg", 480, 760, 0.95)
    rgb = ImageEnhance.Brightness(ImageEnhance.Color(i1.convert("RGB")).enhance(0.6)).enhance(0.85)
    i1 = Image.merge("RGBA", (*rgb.split(), i1.split()[3]))
    c = paste(c, i1, x1, y1)
    c = plain(c, "c2_lotus_outer.jpg", 480, 560, 300)
    hi = sky_bg()
    hi = add(hi, radial(hi.size, 1440, 300, 900, (255, 230, 170), 1.8), 0.35)
    i2, x2, y2 = island("dd100_wide.jpg", 1440, 800, 0.95)
    hi = paste(hi, i2, x2, y2)
    hi, (x, y, p) = hero(hi, "c2_lotus_celestial.jpg", 1440, 600, 560, BLUE, 13)
    hi = screen(hi, sparkles(hi.size, (980, 40, 1900, 1040), BLUE, n=60, seed=13, rmax=8), 0.95)
    c = Image.composite(hi, c, m)
    ImageDraw.Draw(c).rectangle((957, 0, 963, H), fill=(255, 244, 214))
    if words:
        c = label(c, "DAY 1", 480, 50, 120, (236, 240, 248))
        c, _ = gold_text(c, "DAY 100", 1440, 36, 150, pool=40)
    else:
        c = arrow(c, 960, 560, 80)
    c = grade(c, sat=1.0, con=1.03, vig=0.2)
    return save(c, f"{name}.png", (W, H))

def C():
    """One bright sky: the bare island small and low-left, the full sect big right, the blue
    Celestial rising between them. Only DAY 1 / DAY 100 as small tags."""
    c = sky_bg()
    c = add(c, radial(c.size, 1250, 380, 1000, (255, 236, 190), 1.8), 0.3)
    i1, x1, y1 = island("dd1_wide.jpg", 300, 870, 0.55)
    c = paste(c, i1, x1, y1)
    c = plain(c, "c2_lotus_outer.jpg", 300, 770, 160)
    i2, x2, y2 = island("dd100_wide.jpg", 1300, 880, 1.15)
    c = paste(c, i2, x2, y2)
    c, _ = hero(c, "c2_lotus_celestial.jpg", 1240, 640, 620, BLUE, 21)
    c = screen(c, sparkles(c.size, (500, 30, 1900, 1000), BLUE, n=70, seed=21, rmax=8), 0.95)
    c = label(c, "DAY 1", 300, 560, 84, (240, 244, 250))
    c, _ = gold_text(c, "DAY 100", 1560, 40, 140, pool=40)
    c = grade(c, sat=1.02, con=1.04, vig=0.22)
    return save(c, "C.png", (W, H))

def D():
    """The cultivator alone, day 1 vs day 100: plain disciple dull left, blue Celestial burst right."""
    c, m = split_bg()
    c = plain(c, "c2_lotus_outer.jpg", 480, 1000, 620)
    hi = sky_bg()
    hi, _ = hero(hi, "c2_lotus_celestial.jpg", 1440, 1020, 820, BLUE, 7)
    hi = screen(hi, sparkles(hi.size, (980, 40, 1900, 1040), BLUE, n=70, seed=7, rmax=8), 0.95)
    c = Image.composite(hi, c, m)
    ImageDraw.Draw(c).rectangle((957, 0, 963, H), fill=(255, 244, 214))
    c = label(c, "DAY 1", 480, 50, 120, (236, 240, 248))
    c, _ = gold_text(c, "DAY 100", 1440, 36, 150, pool=40)
    c = grade(c, sat=1.0, con=1.03, vig=0.2)
    return save(c, "D.png", (W, H))

def _round1_draft():
    fs = [A(), A(False, "B"), C(), D()]
    B_ = Image.new("RGB", (2 * 970, 2 * 550), (18, 20, 26))
    for i, f in enumerate(fs):
        B_.paste(Image.open(f).convert("RGB").resize((960, 540), Image.LANCZOS), ((i % 2) * 970, (i // 2) * 550))
    B_.save(os.path.join(S.OUT, "board.jpg"), quality=88)

def panel(f, cx, pw, ph, top, cw=1100, warm=True, cut_bottom=80):
    """A capture scaled into a pw x ph panel, the island low; the space above filled with the painted
    sky, blended over the capture's own sky."""
    im = load(f)
    im = grade(im, sat=1.22, con=1.1, warm=(1.06, 1.0, 0.92), vig=0.0) if warm else grade(im, sat=0.8, con=1.0, bri=0.9, vig=0.0)
    x0 = int(min(max(0, cx - cw / 2), im.width - cw))
    cap = im.crop((x0, 0, x0 + cw, im.height))
    s = pw / cw
    cap = cap.resize((pw, int(cap.height * s)), Image.LANCZOS)
    y = ph - cap.height + cut_bottom
    sky = crop_c(load("sky_plate.jpg"), 904, 416, 1480 * pw / 1920 * 1.0, 833).resize((pw, ph), Image.LANCZOS)
    sky = grade(sky, sat=1.1, con=1.04, vig=0.0)
    if not warm:
        sky = ImageEnhance.Brightness(ImageEnhance.Color(sky).enhance(0.6)).enhance(0.85)
    c = sky.copy()
    g = np.clip((np.arange(cap.height, dtype=np.float32) - top * s) / 160, 0, 1)
    sm = arr(sky_mask(cap)) / 255
    a = 1 - sm * (1 - g[:, None])  # sky pixels near the top of the capture fade to the painted sky
    a = a * np.clip(np.arange(cap.height, dtype=np.float32) / 220, 0, 1)[:, None]
    m = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(2))
    c.paste(cap, (0, y), m)
    return c, y, s, x0

def A2(words=True, name="A"):
    left, y1, s1, x01 = panel("dd1_wide.jpg", 820, 960, H, 420, warm=False)
    left = plain(left, "c2_lotus_outer.jpg", int((870 - x01) * s1), int(y1 + 450 * s1), 250)
    right, y2, s2, x02 = panel("dd100_wide.jpg", 850, 960, H, 420)
    right = add(right, radial(right.size, 480, 330, 700, (255, 230, 170), 1.8), 0.3)
    right, _ = hero(right, "c2_lotus_celestial.jpg", 480, int(y2 + 260 * s2), 470, BLUE, 13)
    right = screen(right, sparkles(right.size, (20, 40, 940, 1040), BLUE, n=50, seed=13, rmax=8), 0.95)
    c = Image.new("RGB", (W, H)); c.paste(left, (0, 0)); c.paste(right, (960, 0))
    ImageDraw.Draw(c).rectangle((957, 0, 963, H), fill=(255, 244, 214))
    if words:
        c = label(c, "DAY 1", 480, 46, 124, (236, 240, 248))
        c, _ = gold_text(c, "DAY 100", 1440, 32, 156, pool=40)
    else:
        c = arrow(c, 960, 560, 80)
    c = grade(c, sat=1.0, con=1.03, vig=0.2)
    return save(c, f"{name}.png", (W, H))

def C2():
    """The proven Day 1 / Day 100 sect split, re-shot into the bright blue painted sky (no figure)."""
    left, *_ = panel("dd1_wide.jpg", 820, 960, H, 300, cw=900, warm=False, cut_bottom=120)
    right, *_ = panel("dd100_wide.jpg", 850, 960, H, 300, cw=900, cut_bottom=120)
    right = add(right, radial(right.size, 480, 260, 700, (255, 226, 160), 1.8), 0.45)
    right = add(right, rays(right.size, 560, 100, (255, 236, 190), n=22, seed=6, alpha=(40, 100)), 0.7)
    right = screen(right, sparkles(right.size, (40, 160, 920, 700), GOLD, n=30, seed=3, rmax=6), 0.9)
    c = Image.new("RGB", (W, H)); c.paste(left, (0, 0)); c.paste(right, (960, 0))
    ImageDraw.Draw(c).rectangle((957, 0, 963, H), fill=(255, 244, 214))
    c = label(c, "DAY 1", 480, 46, 124, (236, 240, 248))
    c, _ = gold_text(c, "DAY 100", 1440, 32, 156, pool=40)
    c = grade(c, sat=1.0, con=1.03, vig=0.2)
    return save(c, "C.png", (W, H))

def main2():
    os.chdir(S.ROOT)
    fs = [A2(), A2(False, "B"), C2(), D()]
    B_ = Image.new("RGB", (2 * 970, 2 * 550), (18, 20, 26))
    for i, f in enumerate(fs):
        B_.paste(Image.open(f).convert("RGB").resize((960, 540), Image.LANCZOS), ((i % 2) * 970, (i // 2) * 550))
    B_.save(os.path.join(S.OUT, "board.jpg"), quality=88)


if __name__ == "__main__":
    main2()
