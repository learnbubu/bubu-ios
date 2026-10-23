"""Puts the white sparkle in a cast member's eyes (the owner, 23 Oct 2026: "I actually like the eye sparkle", and then
"shall we just add it after"): Codex draws the eyes plain, and every drawing gets the same sparkle here, so they all
match. The owner's pick (A): one small tilted oval high on the right of each eye.

The eyes are found by themselves: the two biggest near-black blobs in the top half that sit inside skin (the hair is
dark brown, not black, and isn't surrounded by skin). Or give their boxes.

    python add_sparkle.py <png> [x0,y0,x1,y1 x0,y0,x1,y1]
    SIDE (across the eye, 0 left 1 right, default 0.6) and SIZE (default 1.35) change it.
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw


def find_eyes(a):
    """The two eyes' boxes: near-black blobs in the top 60%, with skin round them, the biggest two."""
    h, w = a.shape[:2]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dark = (r < 30) & (g < 30) & (b < 30)
    skin = (r > 220) & (g > 160) & (g < 215) & (b > 120) & (b < 185) & (r - b > 45)
    top = int(h * 0.6)
    seen = np.zeros_like(dark)
    blobs = []
    for y0 in range(0, top, 2):
        for x0 in range(0, w, 2):
            if not dark[y0, x0] or seen[y0, x0]:
                continue
            q, pts = deque([(y0, x0)]), []
            seen[y0, x0] = True
            while q:
                y, x = q.popleft()
                pts.append((y, x))
                for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < top and 0 <= nx < w and dark[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            if len(pts) < 200:
                continue
            ys, xs = zip(*pts)
            bx = (min(xs), min(ys), max(xs), max(ys))
            # an eye has skin just left and right of it
            m = 6
            left = skin[bx[1]:bx[3], max(0, bx[0] - m):bx[0]].mean() if bx[0] > m else 0
            right = skin[bx[1]:bx[3], bx[2] + 1:bx[2] + 1 + m].mean() if bx[2] + m < w else 0
            if left > 0.3 and right > 0.3:
                blobs.append((len(pts), bx))
    blobs.sort(reverse=True)
    eyes = sorted((bx for _, bx in blobs[:2]), key=lambda bx: bx[0])
    if len(eyes) != 2:
        raise SystemExit(f"found {len(eyes)} eyes, not 2: give their boxes")
    return eyes


def sparkle(path, boxes=None):
    K = 4
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(int)
    eyes = boxes or find_eyes(a)
    side = float(os.environ.get("SIDE", "0.6"))
    size = float(os.environ.get("SIZE", "1.35"))
    big = im.resize((im.width * K, im.height * K), Image.LANCZOS)
    for (ex0, ey0, ex1, ey1) in eyes:
        w, h = ex1 - ex0, ey1 - ey0
        print("eye", ex0, ey0, ex1, ey1)
        # one catch-light high on the right, a small oval tilted along the eye's curve
        cx, cy, rx, ry = ex0 + w * side, ey0 + h * 0.29, w * 0.15 * size, w * 0.10 * size
        spot = Image.new("RGBA", (int(rx * 2 * K) + 8, int(rx * 2 * K) + 8))
        ImageDraw.Draw(spot).ellipse((4, 4 + (rx - ry) * K, 4 + rx * 2 * K, 4 + (rx + ry) * K), fill=(255, 255, 255, 255))
        spot = spot.rotate(35 if side >= 0.5 else -35, resample=Image.BICUBIC)
        big.alpha_composite(spot, (int(cx * K - spot.width / 2), int(cy * K - spot.height / 2)))
    big.resize(im.size, Image.LANCZOS).convert("RGB").save(path)
    print("ok", path)


if __name__ == "__main__":
    given = [tuple(int(v) for v in b.split(",")) for b in sys.argv[2:]]
    sparkle(sys.argv[1], given or None)
