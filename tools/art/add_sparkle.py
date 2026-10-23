"""Puts the white sparkle back in a cast member's eyes (the owner, 23 Oct 2026: "I actually like the eye sparkle ...
just add the white bit back"): finds each eye, a near-black oval in the face, and draws one small tilted
oval catch-light high on its right, as the first draft had. Usage: python add_sparkle.py <png> x0,y0,x1,y1 x0,y0,x1,y1"""
import sys
import numpy as np
from PIL import Image, ImageDraw

path, boxes = sys.argv[1], [tuple(int(v) for v in b.split(",")) for b in sys.argv[2:]]
K = 4
im = Image.open(path).convert("RGBA")
a = np.array(im).astype(int)
dark = (a[..., 0] < 30) & (a[..., 1] < 30) & (a[..., 2] < 30)
big = im.resize((im.width * K, im.height * K), Image.LANCZOS)
d = ImageDraw.Draw(big)
for (x0, y0, x1, y1) in boxes:
    ys, xs = np.nonzero(dark[y0:y1, x0:x1])
    ex0, ex1, ey0, ey1 = xs.min() + x0, xs.max() + x0, ys.min() + y0, ys.max() + y0
    w, h = ex1 - ex0, ey1 - ey0
    print("eye", ex0, ey0, ex1, ey1)
    # one catch-light high on the right, a small oval tilted along the eye's curve, as the owner's pick (the first
    # draft) has
    side = float(__import__("os").environ.get("SIDE", "0.6"))      # across the eye (0 left, 1 right)
    size = float(__import__("os").environ.get("SIZE", "1.35"))
    cx, cy, rx, ry = ex0 + w * side, ey0 + h * 0.29, w * 0.15 * size, w * 0.10 * size
    spot = Image.new("RGBA", (int(rx * 2 * K) + 8, int(rx * 2 * K) + 8))
    ImageDraw.Draw(spot).ellipse((4, 4 + (rx - ry) * K, 4 + rx * 2 * K, 4 + (rx + ry) * K), fill=(255, 255, 255, 255))
    spot = spot.rotate(35 if side >= 0.5 else -35, resample=Image.BICUBIC)
    big.alpha_composite(spot, (int(cx * K - spot.width / 2), int(cy * K - spot.height / 2)))
big.resize(im.size, Image.LANCZOS).convert("RGB").save(path)
print("ok", path)
