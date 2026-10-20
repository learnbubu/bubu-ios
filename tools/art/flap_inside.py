"""The underside of a pocket's flap, made from its flap (out/raw/pk2-<kind>-flap.png) rather than drawn: Codex drew the
whole pocket under it (the owner's check of 20 Oct 2026). The flap's outline mirrored up about the pocket's top edge,
filled in a darker shade of the flap with a soft fold shadow, and its curved rim in the flap's gold. Lines up by
construction. Writes out/raw/pk2-<kind>-flap-inside.png (on magenta, as Codex's pictures are).

    python flap_inside.py red [jade gold]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))


def magenta(a):
    return (a[..., 0] > 190) & (a[..., 2] > 190) & (a[..., 1] < 90)


def make(kind):
    a = np.array(Image.open(os.path.join(HERE, "out", "raw", f"pk2-{kind}-flap.png")).convert("RGB")).astype(float)
    on = ~magenta(a.astype(int))
    ys, xs = np.nonzero(on)
    top, bot = ys.min(), ys.max()
    # the flap's own colours: its face (the commonest of its non-gold colours) and its gold rim
    px = a[on]
    gold = (px[:, 0] > 200) & (px[:, 1] > 140)
    face = np.median(px[~gold], axis=0)
    rim = np.median(px[gold], axis=0) if gold.any() else np.array([240, 180, 70.0])
    h = bot - top + 1
    shape = on[top:bot + 1][::-1]                      # mirrored: the curved edge now at the top
    out = np.zeros((1024, 1024), bool)
    y0 = top - h + 4                                   # standing up from the top edge, a hair overlapping it
    out[y0:y0 + h] = shape
    mask = Image.fromarray((out * 255).astype("uint8"))
    inner = np.array(mask.filter(ImageFilter.MinFilter(13))) > 127
    img = np.zeros((1024, 1024, 3))
    img[:] = (255, 0, 255)
    yy = np.arange(1024)[:, None].repeat(1024, 1)
    t = np.clip((yy - y0) / h, 0, 1)                   # 0 at the rim, 1 at the fold
    under = face * 0.80
    shade = under[None, None, :] * (1 - 0.22 * t[..., None] ** 1.6)
    img[out] = rim
    img[inner] = shade[inner]
    # a soft lighter band just inside the rim, as on the front
    band = inner & ~(np.array(mask.filter(ImageFilter.MinFilter(25))) > 127)
    img[band] = img[band] * 0.85 + face * 0.15
    Image.fromarray(img.astype("uint8")).save(os.path.join(HERE, "out", "raw", f"pk2-{kind}-flap-inside.png"))
    print(kind, "flap", top, bot, "inside", y0, y0 + h)


if __name__ == "__main__":
    for k in sys.argv[1:] or ["red"]:
        make(k)
