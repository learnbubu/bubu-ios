"""Blends Bùbù's arms into his body (owner, 6 Oct 2026: odd bits where the lowered arms meet
the shoulders): the arms' black fur is shifted to the body's own black, and each lowered arm's
top fades into the shoulder over a few pixels instead of starting on a hard edge. Run after
rig_straps.py (it reads the mirrored arms). Rewrites out/rig/rig-arm-*.png."""
import os

import numpy as np
from PIL import Image

from rig_layout import compose, HERE

RIG = os.path.join(HERE, "out", "rig")
FADE = 0.12            # the top eighth of a lowered arm fades in


def fur(a):
    m = (a[:, :, 3] > 200) & (a[:, :, :3].sum(2) < 200)
    return np.median(a[m][:, :3], axis=0)


if __name__ == "__main__":
    body = fur(np.array(compose(["rig2-body"], pad=0)).astype(float))
    for n in ("rig-arm-left-down", "rig-arm-right-down", "rig-arm-left-up", "rig-arm-right-up"):
        a = np.array(Image.open(os.path.join(RIG, n + ".png")).convert("RGBA")).astype(float)
        dark = a[:, :, :3].sum(2) < 260
        a[dark, :3] += body - fur(a)            # the fur matches the body's; paw pads and claws keep theirs
        if n.endswith("-down"):
            h = a.shape[0]; ys = np.arange(h)[:, None]
            a[:, :, 3] *= np.clip(ys / (FADE * h), 0, 1) ** 0.7
        Image.fromarray(np.clip(a, 0, 255).astype("uint8")).save(os.path.join(RIG, n + ".png"))
    print("fur", body)
