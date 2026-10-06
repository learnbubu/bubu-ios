"""Trims the rounded arm stubs off the shoulders of the second body (owner, 6 Oct 2026: "weird
armpits" when the arms are up). Above chest level nothing is kept past the line of his sides
below (x 72..343 on the panda-idle canvas), with a soft edge; the lowered arms cover that area,
so one trimmed body does for every pose. Writes out/rig/rig2-body-trim.png on the full canvas."""
import os

import numpy as np
from PIL import Image

from rig_layout import compose, HERE

LEFT, RIGHT, BELOW = 72, 343, 372

if __name__ == "__main__":
    b = np.array(compose(["rig2-body"], pad=0)).astype(float)
    h, w = b.shape[:2]
    x = np.arange(w)[None, :].repeat(h, 0); y = np.arange(h)[:, None].repeat(w, 1)
    # how far inside the side lines, softened over 2 px; only above chest level
    inside = np.clip(np.minimum(x - LEFT, RIGHT - x) / 2 + 0.5, 0, 1)
    keep = np.where(y < BELOW, inside, 1.0)
    b[:, :, 3] *= keep
    Image.fromarray(b.astype("uint8")).crop((0, 0, 420, 643)).save(os.path.join(HERE, "out", "rig", "rig2-body-trim.png"))
    print("ok")
