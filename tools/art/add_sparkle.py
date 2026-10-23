"""Puts the white sparkle back in a cast member's eyes (the owner, 23 Oct 2026: "I actually like the eye sparkle ...
just add the white bit back"): finds each eye, a near-black oval in the face, and draws a round catch-light in its
upper right, a smaller one under it, as the first drafts had. Usage: python add_sparkle.py <png> x0,y0,x1,y1 x0,y0,x1,y1"""
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
    # the big catch-light high on the right, a little one low on the left
    cx, cy, r = ex0 + w * 0.62, ey0 + h * 0.30, w * 0.17
    d.ellipse(((cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K), fill=(255, 255, 255, 255))
    cx, cy, r = ex0 + w * 0.36, ey0 + h * 0.68, w * 0.07
    d.ellipse(((cx - r) * K, (cy - r) * K, (cx + r) * K, (cy + r) * K), fill=(255, 255, 255, 235))
big.resize(im.size, Image.LANCZOS).convert("RGB").save(path)
print("ok", path)
