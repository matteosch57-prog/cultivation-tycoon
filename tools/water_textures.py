"""Water textures for scrolling Beams (owner 2026-10-21: "the water sources and the waterfall can be
improved"; kit: memory/Gladiator water research: falling water = a Beam with a scrolling texture,
a basin = flat beam strips over an opaque water part, no Glass, no Terrain water).

  art/textures/water_flow.png    256 x 512, vertical white streaks, tiles top to bottom
  art/textures/water_ripple.png  512 x 512, soft light ripples (caustics), tiles both ways

White on alpha: the Beam's Color tints it. Usage: python tools/water_textures.py
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "textures")


def flow(seed=3):
    rng = random.Random(seed)
    W, H = 256, 512
    a = np.zeros((H, W), np.float32)
    ys = np.arange(H)
    for _ in range(46):
        x = rng.uniform(0, W)
        w = rng.uniform(2, 9)
        strength = rng.uniform(0.25, 0.9)
        # each streak breaks up along its length (sum of sines that tile over H)
        k1, k2 = rng.randint(1, 4), rng.randint(3, 9)
        p1, p2 = rng.uniform(0, 6.28), rng.uniform(0, 6.28)
        along = 0.55 + 0.3 * np.sin(ys / H * 2 * math.pi * k1 + p1) + 0.15 * np.sin(ys / H * 2 * math.pi * k2 + p2)
        for dx in range(-int(w * 2), int(w * 2) + 1):
            col = int(x + dx) % W
            fall = math.exp(-((dx / w) ** 2))
            a[:, col] = np.maximum(a[:, col], strength * fall * np.clip(along, 0, 1))
    a = np.clip(a * 1.1, 0, 1)
    img = Image.fromarray((a * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.2))
    rgba = Image.merge("RGBA", (Image.new("L", (W, H), 255),) * 3 + (img,))
    return rgba


def ripple(seed=5):
    W = 512
    y, x = np.mgrid[0:W, 0:W] / W * 2 * math.pi
    rng = np.random.default_rng(seed)
    v = np.zeros((W, W))
    # a few tiling wave trains crossing; caustic lines are where they pile up
    for _ in range(7):
        kx, ky = rng.integers(1, 5), rng.integers(1, 5)
        ph = rng.uniform(0, 6.28)
        v += np.sin(kx * x + ky * y + ph + 1.5 * np.sin(ky * x - kx * y))
    v = v / 7
    lines = np.exp(-((v - v.mean()) ** 2) / 0.012)
    img = Image.fromarray((np.clip(lines * 0.85, 0, 1) * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.5))
    return Image.merge("RGBA", (Image.new("L", (W, W), 255),) * 3 + (img,))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    flow().save(os.path.join(OUT, "water_flow.png"))
    ripple().save(os.path.join(OUT, "water_ripple.png"))
    print("water_flow.png, water_ripple.png")
