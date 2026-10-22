"""Cinematic store thumbnails: crop a 1708x785 Studio capture to 16:9, upscale to 1920x1080,
light grade (contrast, warmth, soft vignette). Usage: python cine_post.py <in.jpg> <out.png> [xshift] [yshift] [zoom] [warm]"""
import sys
from PIL import Image, ImageEnhance, ImageFilter, ImageChops
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
xs = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0  # -1..1 of the free width
ys = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
zoom = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0
warm = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0

im = Image.open(src).convert("RGB")
W, H = im.size
h = H / zoom
w = h * 16 / 9
cx = W / 2 + xs * (W - w) / 2
cy = H / 2 + ys * (H - h) / 2
box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
im = im.resize((1920, 1080), Image.LANCZOS, box=box)
im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))
im = ImageEnhance.Contrast(im).enhance(1.08)
im = ImageEnhance.Color(im).enhance(1.08)
a = np.asarray(im).astype(np.float32)
if warm:
    a[..., 0] *= 1 + 0.06 * warm
    a[..., 2] *= 1 - 0.06 * warm
yy, xx = np.mgrid[0:1080, 0:1920]
d = np.sqrt(((xx - 960) / 960) ** 2 + ((yy - 540) / 540) ** 2)
v = 1 - 0.22 * np.clip(d - 0.55, 0, 1) ** 1.5
a *= v[..., None]
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(dst)
print(dst)
