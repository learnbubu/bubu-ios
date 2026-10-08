"""Line the clean rig6 arm pieces up with the arms in the original moment art (owner, 8 Oct: "line them up
with the static images"). The target is the original's arm: its dark fur near the piece, plus anything
the armless body hasn't got. Each piece is shifted, scaled and turned to overlap it best (IoU), then saved
to out/rig/fit/<piece>.png in the same placed frame."""
import os

import numpy as np
from PIL import Image
from scipy import ndimage, optimize

from skin import ARMS, RIG


def target(k, piece):
    orig = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-bubu-placed.png")).convert("RGBA"))
    body = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-body-placed.png")).convert("RGBA"))
    near = ndimage.binary_dilation(piece[:, :, 3] > 128, iterations=50)
    oa = orig[:, :, 3] > 128
    dark = orig[:, :, :3].mean(2) < 90
    T = near & oa & (dark | (body[:, :, 3] < 128))
    # what the piece holds (stamp, broom, cup) counts too: wherever the piece is opaque and not fur, and the
    # original is opaque and not the body
    held = (piece[:, :, 3] > 128) & (piece[:, :, :3].mean(2) >= 90)
    T |= ndimage.binary_dilation(held, iterations=10) & oa & (np.abs(orig[:, :, :3].astype(int) - body[:, :, :3]).mean(2) > 40)
    return ndimage.binary_opening(T, iterations=2)


def warp(im, p, c):
    tx, ty, s, r = p
    a = np.deg2rad(r); cs, sn = np.cos(a) / s, np.sin(a) / s
    cx, cy = c
    # output -> input: about the piece's centre c
    A = (cs, sn, cx - cs * (cx + tx) - sn * (cy + ty), -sn, cs, cy + sn * (cx + tx) - cs * (cy + ty))
    return np.asarray(Image.fromarray(im).transform(im.shape[1::-1], Image.AFFINE, A, Image.BICUBIC))


if __name__ == "__main__":
    os.makedirs(os.path.join(RIG, "fit"), exist_ok=True)
    import sys
    only = sys.argv[1:]
    for k, names in ARMS.items():
        if k == "kungfu" or (only and k not in only): continue                       # its leg is cut from the original already
        for n in names:
            pc = np.asarray(Image.open(os.path.join(RIG, n + ".png")).convert("RGBA"))
            T = target(k, pc)
            ys, xs = np.where(pc[:, :, 3] > 128); c = (xs.mean(), ys.mean())
            sm = 4                                         # work at 1/4 size
            Ts = T[::sm, ::sm]
            small = np.ascontiguousarray(pc[::sm, ::sm]); cs_ = (c[0] / sm, c[1] / sm)
            def cost(p):
                m = warp(small, (p[0] / sm, p[1] / sm, p[2], p[3]), cs_)[:, :, 3] > 128
                return -(m & Ts).sum() / max(1, (m | Ts).sum())
            best = None
            # early bird's sides are dark fur too, so its arms would stretch over them: hold its scale near 1
            sb = (0.95, 1.05) if k == "earlybird" else (0.6, 1.3)
            for s0 in ((1.0,) if k == "earlybird" else (0.85, 1.0)):
                for r0 in (-8, 0, 8):
                    res = optimize.minimize(cost, [0, 0, s0, r0], method="Powell",
                                            bounds=[(-120, 120), (-120, 120), sb, (-30, 30)], options={"xtol": 0.5, "ftol": 1e-4})
                    if best is None or res.fun < best.fun: best = res
            p = best.x
            Image.fromarray(warp(pc, p, c)).save(os.path.join(RIG, "fit", n + ".png"))
            print(n, "IoU before %.3f after %.3f" % (-cost([0, 0, 1, 0]), -best.fun), "move", np.round(p, 2))
