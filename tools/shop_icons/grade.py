# Shop icon disciples: grade the magenta-keyed Studio cutouts (tools/store_post.py key()) and add a light edge
# and dark halo for contrast; writes disciples.json for draw.js. Cutouts go in tools/shop_icons/cut/.
import os
from PIL import Image, ImageEnhance, ImageFilter
import base64, io, json, numpy as np, sys
src = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {'immortal':'c2_elder_immortal','celestial':'d_sit_celestial','dao':'d_sit_dao','emperor':'d_sit_emperor'}
try: out = json.load(open(os.path.join(os.path.dirname(__file__), 'disciples.json')))
except Exception: out = {}
for k, f in src.items():
    im = Image.open(os.path.join(os.path.dirname(__file__), 'cut', '%s.png') % f); im = im.crop(im.getbbox())
    w, h = im.size
    cx0, cy0, cx1, cy1 = {'elder': (.0, .0, 1, .80)}.get(k, (.17, .14, .83, .80))
    im = im.crop((int(w*cx0), int(h*cy0), int(w*cx1), int(h*cy1))); im = im.crop(im.getbbox())
    a = np.asarray(im.getchannel('A'), np.float32)
    fade = np.clip((im.height - np.arange(im.height)) / (im.height * .14), 0, 1)[:, None]  # soft bottom edge
    a = Image.fromarray((a * fade).astype(np.uint8))
    rgb = ImageEnhance.Contrast(im.convert('RGB')).enhance(1.25)
    rgb = ImageEnhance.Color(rgb).enhance(1.25)
    rgb = ImageEnhance.Sharpness(rgb).enhance(1.6)
    if k == 'elder': rgb = ImageEnhance.Brightness(rgb).enhance(1.35)
    sub = rgb.convert('RGBA'); sub.putalpha(a)
    pad = 14
    canvas = Image.new('RGBA', (sub.width + pad*2, sub.height + pad*2), (0,0,0,0))
    core = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(9))  # body only, no thin swords
    big = Image.new('L', canvas.size, 0); big.paste(core, (pad, pad))
    ring = big.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(4))
    canvas.paste(Image.new('RGBA', canvas.size, (12, 6, 20, 210)), (0,0), ring)
    edge = big.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(.8))
    canvas.paste(Image.new('RGBA', canvas.size, (255, 246, 220, 255)), (0,0), edge)
    canvas.alpha_composite(sub, (pad, pad))
    b = io.BytesIO(); canvas.save(b, 'PNG'); out[k] = {'w': canvas.width, 'h': canvas.height, 'b64': base64.b64encode(b.getvalue()).decode()}
json.dump(out, open(os.path.join(os.path.dirname(__file__), 'disciples.json'), 'w'))
