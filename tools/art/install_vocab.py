"""Puts the Vocabulary room's art (Codex batch "vocab", cut out by process.py into out/final) into the app's asset
catalog. The garden's three pots go on one shared canvas, their pots lined up at the foot, so the seedling, the
leafy plant and the flowering one keep the same pot when drawn at one height (each was cropped to its own plant).
The garden bed's pink fringe (the magenta's, along the soil's foot) is recoloured as soil.
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")
# the most a picture is kept at (px): the tiles and pots show ~70 pt, the panda and the bed larger
LONG = {"vocab-flash": 480, "vocab-match": 520, "vocab-garden": 420, "panda-searching": 600, "vocab-bed": 1100}


def load(n):
    return Image.open(os.path.join(FINAL, n + ".png")).convert("RGBA")


def pot_centre(im):
    """Where the pot's foot is centred: the terracotta in the picture's bottom quarter."""
    a = np.array(im).astype(int)
    h = a.shape[0]
    f = a[int(h * 0.75):]
    r, g, b, al = f[..., 0], f[..., 1], f[..., 2], f[..., 3]
    xs = np.nonzero((al > 200) & (r > 190) & (g > 90) & (g < 185) & (b < 130))[1]
    return (xs.min() + xs.max()) / 2


def garden():
    ims = {n: load(n) for n in ("vocab-seed", "vocab-grow", "vocab-bloom")}
    cs = {n: pot_centre(im) for n, im in ims.items()}
    left = max(cs[n] for n in ims)
    right = max(im.width - cs[n] for n, im in ims.items())
    w, h = int(left + right) + 2, max(im.height for im in ims.values())
    out = {}
    for n, im in ims.items():
        c = Image.new("RGBA", (w, h))
        c.alpha_composite(im, (int(round(left - cs[n])), h - im.height))
        out[n] = c
    return out


def bed():
    im = load("vocab-bed")
    a = np.array(im).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    pink = (al > 0) & (r > 120) & (b > g + 15) & (r > g + 30)
    soil = (al > 250) & ~pink & (r > g) & (g > b) & (r < 170) & (r > 90)
    tone = a[soil][:, :3].mean(axis=0)
    a[pink, :3] = tone
    # the fainter spill left on the soil's and leaves' edges: whatever magenta is over the green, taken out of red and blue
    # (nothing in the picture is meant to be magenta: the flowers are coral, red over blue)
    spill = np.clip(np.minimum(a[..., 0], a[..., 2]) - a[..., 1], 0, None)
    a[..., 0] -= spill
    a[..., 2] -= spill
    print("bed: recoloured", int(pink.sum()), "pink px to soil", tone.round(), "and took spill out of", int((spill > 0).sum()))
    return Image.fromarray(a.astype("uint8"), "RGBA")


def install(name, im):
    im = im.copy()
    k = LONG["vocab-garden" if name in ("vocab-seed", "vocab-grow", "vocab-bloom") else name] / max(im.size)
    if k < 1:
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    d = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"), optimize=True)
    json.dump({"info": {"author": "xcode", "version": 1}, "images": [{"idiom": "universal", "filename": name + ".png"}]},
              open(os.path.join(d, "Contents.json"), "w"), indent=2)
    print(name, im.size)


if __name__ == "__main__":
    for n, im in garden().items():
        install(n, im)
    install("vocab-bed", bed())
    for n in ("vocab-flash", "vocab-match", "panda-searching"):
        install(n, load(n))
