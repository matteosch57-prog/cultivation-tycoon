# Mocks for thread "Keep new players past 10 minutes" (2026-10-26): drawn over the Studio captures in
# docs/art/mocks/2026-10-26_first5/. Run: python tools/mock_first5.py
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

D = "docs/art/mocks/2026-10-26_first5"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
GOLD, INK, JADE, WHITE = (255, 211, 77), (27, 20, 32), (111, 214, 170), (255, 255, 255)


def font(n):
    return ImageFont.truetype(BOLD, n)


def label(img, text, sub=None):
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((16, 14, 16 + 22 * len(text) + 30, 64), 14, fill=(0, 0, 0, 200))
    d.text((32, 22), text, font=font(28), fill=GOLD)
    if sub:
        w = d.textlength(sub, font=font(22))
        d.rounded_rectangle((16, 70, 46 + w, 106), 12, fill=(0, 0, 0, 170))
        d.text((31, 76), sub, font=font(22), fill=WHITE)


def centre_text(d, cx, y, text, f, fill, stroke=0):
    w = d.textlength(text, font=f)
    d.text((cx - w / 2, y), text, font=f, fill=fill, stroke_width=stroke, stroke_fill=INK)


def chevrons(d, pts):
    for (x, y, s) in pts:
        d.polygon([(x - 26 * s, y + 10 * s), (x, y - 12 * s), (x + 26 * s, y + 10 * s), (x + 26 * s, y + 2 * s), (x, y - 20 * s), (x - 26 * s, y + 2 * s)], fill=JADE, outline=(34, 92, 74))


def rebirth_pad(base, cx, cy):
    img = base.convert("RGBA")
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse((cx - 150, cy - 46, cx + 150, cy + 46), fill=(255, 200, 60, 150))
    g.rectangle((cx - 40, cy - 420, cx + 40, cy), fill=(255, 220, 110, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    d.ellipse((cx - 110, cy - 32, cx + 110, cy + 32), fill=(255, 205, 70), outline=(150, 95, 20), width=5)
    d.ellipse((cx - 80, cy - 22, cx + 80, cy + 22), outline=(255, 245, 200), width=4)
    # the pad card
    cw, ch, top = 340, 150, cy - 300
    d.rounded_rectangle((cx - cw / 2, top, cx + cw / 2, top + ch), 22, fill=(27, 20, 32, 235), outline=GOLD, width=4)
    centre_text(d, cx, top + 12, "REBIRTH", font(40), GOLD)
    centre_text(d, cx, top + 62, "+50% qi forever", font(26), WHITE)
    centre_text(d, cx, top + 96, "New Sect Style", font(24), JADE)
    d.polygon([(cx - 14, top + ch), (cx + 14, top + ch), (cx, top + ch + 18)], fill=GOLD)
    return img, d


def mock_realm2():
    base = Image.open(os.path.join(D, "realm2_end_wide.jpg"))
    img, d = rebirth_pad(base, 1000, 520)
    chevrons(d, [(560, 590, 1.0), (680, 568, 0.95), (800, 548, 0.9), (900, 534, 0.85)])
    label(img, "A  Rebirth pad on the peak", "The trail ends at a gold pad; step on it to open the Rebirth screen")
    img.convert("RGB").save(os.path.join(D, "mock_rebirth_A_pad.jpg"), quality=88)


def mock_auto_open():
    base = Image.open(os.path.join(D, "realm2_end_wide.jpg")).convert("RGBA")
    dim = Image.new("RGBA", base.size, (8, 6, 16, 150))
    img = Image.alpha_composite(base, dim)
    d = ImageDraw.Draw(img)
    W, H = img.size
    cw, ch = 620, 380
    x0, y0 = (W - cw) / 2, (H - ch) / 2 + 10
    d.rounded_rectangle((x0, y0, x0 + cw, y0 + ch), 30, fill=(27, 20, 32, 245), outline=GOLD, width=5)
    centre_text(d, W / 2, y0 + 22, "Rebirth ready!", font(48), GOLD)
    centre_text(d, W / 2, y0 + 96, "Start again at realm 1, stronger:", font(26), WHITE)
    rows = [("+50% qi forever", GOLD), ("Your disciples stay", JADE), ("New Sect Style: Snow Lotus", JADE), ("Auto Build rebuilds what you had", JADE)]
    for i, (t, c) in enumerate(rows):
        centre_text(d, W / 2, y0 + 140 + i * 40, t, font(28), c)
    bx, by = W / 2, y0 + ch - 70
    d.rounded_rectangle((bx - 170, by, bx + 170, by + 54), 27, fill=(255, 205, 70), outline=(150, 95, 20), width=4)
    centre_text(d, bx, by + 9, "REBIRTH", font(32), INK)
    d.text((x0 + cw - 50, y0 + 14), "X", font=font(32), fill=(255, 120, 120))
    label(img, "B  Rebirth screen opens by itself", "First 2 rebirths only, the moment it is ready and no pad is left")
    img.convert("RGB").save(os.path.join(D, "mock_rebirth_B_autoopen.jpg"), quality=88)


def timeline():
    W, H = 1600, 760
    img = Image.new("RGB", (W, H), (20, 16, 28))
    d = ImageDraw.Draw(img)
    x0, x1 = 120, 1540

    def X(t):
        return x0 + (x1 - x0) * t / 300

    def row(y, title, events, colour):
        d.text((x0, y - 150), title, font=font(30), fill=colour)
        d.line((x0, y, x1, y), fill=(120, 110, 140), width=4)
        for t in range(0, 301, 60):
            d.line((X(t), y - 8, X(t), y + 8), fill=(160, 150, 180), width=3)
            centre_text(d, X(t), y + 14, f"{t // 60}:00", font(18), (160, 150, 180))
        for i, (t, text, c) in enumerate(events):
            yy = [y - 46, y + 44, y - 92, y + 84][i % 4]
            d.ellipse((X(t) - 9, y - 9, X(t) + 9, y + 9), fill=c)
            centre_text(d, X(t), yy, text, font(19), c)

    RED = (255, 120, 120)
    row(250, "Now (fresh save in Studio)", [
        (11, "free recruit", JADE), (81, "Daily Blessing +57K", RED), (86, "Free summons card", RED),
        (141, "breakthrough over the chest card", RED), (213, "realm 2", GOLD), (275, "trail empty", RED)], WHITE)
    row(580, "Pick A: one card at a time; the day-one Blessing after the first breakthrough", [
        (11, "free recruit", JADE), (90, "realm 1 at its own pace", JADE), (170, "breakthrough", GOLD),
        (215, "Daily Blessing (realm 2 income)", GOLD), (235, "then Free summons", JADE), (285, "Rebirth", GOLD)], GOLD)
    centre_text(d, W / 2, 710, "Live: 22% of players leave within 60 s of their first breakthrough, the worst step in the first 5 minutes", font(22), WHITE)
    img.save(os.path.join(D, "mock_popups_timeline.jpg"), quality=90)


mock_realm2()
mock_auto_open()
timeline()
