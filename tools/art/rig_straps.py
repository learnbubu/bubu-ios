"""Bùbù's chest straps as their own layer (owner, 6 Oct 2026), keyed out of rig-body and drawn
over his arms, raised or hanging, so the arms come out from under the straps. Only the two
straps on his chest: not the pack at his side, nor the pack's edge peeking out at his left
shoulder. Also makes the right raised arm the left one mirrored, so both sides match.
Writes out/rig/rig-straps.png (on the panda-idle canvas) and out/rig/rig-arm-right-up.png."""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

from rig_layout import compose, HERE

RIG = os.path.join(HERE, "out", "rig")
SHOULDER = 322     # where a lowered arm starts to hang in front of the strap


def main():
    # the second body when there is one: it has only the straps in red (the pack is its own piece)
    body = next(b for b in ("rig3-body", "rig2-body", "rig-body") if os.path.exists(os.path.join(RIG, b + ".png")))
    b = np.array(compose([body], pad=0)).astype(int)
    r, g, bl, a = b[:, :, 0], b[:, :, 1], b[:, :, 2], b[:, :, 3]
    red = (a > 100) & (r > 140) & (r - g > 50) & (r - bl > 40)
    lab, n = ndimage.label(red)
    keep = np.zeros_like(red)
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(xs) > 2000 and (body != "rig-body" or xs.max() < 345):
            keep |= lab == i
    # take in their soft edges and darker shading
    grow = ndimage.binary_dilation(keep, iterations=2) & (a > 0) & (r > 70) & (r - g > 25)
    out = b.copy()
    out[~grow, 3] = 0
    Image.fromarray(out.astype("uint8")).crop((0, 0, 420, 643)).save(os.path.join(RIG, "rig-straps.png"))
    # each side on its own, whole (over a raised arm) or just over the shoulder (a lowered arm
    # hangs in front of the rest of it)
    full = Image.fromarray(out.astype("uint8")).crop((0, 0, 420, 643))
    fa = np.array(full).astype(float)
    xx = np.arange(fa.shape[1])[None, :]; yy = np.arange(fa.shape[0])[:, None]
    for side, m in (("L", xx < 208), ("R", xx >= 208)):
        one = fa.copy(); one[:, :, 3] *= m
        Image.fromarray(one.astype("uint8")).save(os.path.join(RIG, f"rig-straps-{side}.png"))
        top = one.copy(); top[:, :, 3] *= np.clip((SHOULDER - yy) / 6 + 0.5, 0, 1)
        Image.fromarray(top.astype("uint8")).save(os.path.join(RIG, f"rig-straps-{side}-top.png"))
    down = Image.open(os.path.join(RIG, "rig-arm-right-down.png"))
    down.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(RIG, "rig-arm-left-down.png"))
    up = Image.open(os.path.join(RIG, "rig-arm-left-up.png"))
    up.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(RIG, "rig-arm-right-up.png"))
    print("straps:", int(grow.sum()), "px")


if __name__ == "__main__":
    main()
