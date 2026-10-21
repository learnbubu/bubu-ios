"""Cut an open pocket (out/raw/pk2-<kind>-open.png, drawn whole by Codex) in two along the pocket's top edge, where the
closed pocket (refs/ref-pk2-<kind>.png) starts: out/raw/pk2-<kind>-body.png is everything from that edge down, and
out/raw/pk2-<kind>-flap-inside.png everything above it (the flap folded up). Both on magenta, as Codex's pictures are.

    python split_open.py red [jade gold]
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
# where the crease is on each open picture (measured: the darkest row where the flap meets the back panel)
CREASE = {"red": 250}


def magenta(a):
    return (a[..., 0] > 190) & (a[..., 2] > 190) & (a[..., 1] < 90)


def split(kind):
    ref = np.array(Image.open(os.path.join(HERE, "refs", f"ref-pk2-{kind}.png")).convert("RGB")).astype(int)
    top = CREASE.get(kind) or np.nonzero(~magenta(ref))[0].min()
    a = np.array(Image.open(os.path.join(HERE, "out", "raw", f"pk2-{kind}-open.png")).convert("RGB"))
    body, flap = a.copy(), a.copy()
    body[:top] = (255, 0, 255)
    flap[top:] = (255, 0, 255)
    Image.fromarray(body).save(os.path.join(HERE, "out", "raw", f"pk2-{kind}-body.png"))
    Image.fromarray(flap).save(os.path.join(HERE, "out", "raw", f"pk2-{kind}-flap-inside.png"))
    print(kind, "cut at", top)


if __name__ == "__main__":
    for k in sys.argv[1:] or ["red"]:
        split(k)
