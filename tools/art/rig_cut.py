"""Cuts the strap where it pokes out past Bùbù's outline at the shoulders (owner, 6 Oct 2026,
drawing along it: "use the arm, basically outside it should cut"). On a side whose arm is
lowered, the outline is his fur (the body without its red) together with that arm; anything of
the body or its strap outside that outline goes. Applied to every body version (rig_trim.py's)
and the shoulder-only straps. Run after rig_trim.py and rig_blend.py."""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

from rig_layout import compose, HERE

RIG = os.path.join(HERE, "out", "rig")
MID = 208


def alpha(names):
    return np.array(compose(names, pad=0))[:643, :420, 3] > 60


def outline(side):
    """Row by row on that side: above the lowered arm, nothing past the strap's outer edge (the
    rounded shoulder there read as a bump); where the arm is, nothing past the arm's outer edge."""
    b = np.array(compose(["rig2-body"], pad=0))[:643, :420].astype(int)
    r, g, bl, a = b[:, :, 0], b[:, :, 1], b[:, :, 2], b[:, :, 3]
    red = (a > 60) & (r > 110) & (r - g > 40) & (r - bl > 30)
    arm = alpha([f"rig-arm-{'left' if side == 'L' else 'right'}-down"])
    xs = np.arange(420)
    half = xs < MID if side == "L" else xs >= MID
    keep = np.ones((643, 420), bool)
    for y in range(643):
        st = np.where(red[y] & half)[0]
        am = np.where(arm[y] & half)[0]
        if len(am):
            edge = am.min() - 1 if side == "L" else am.max() + 1
            if len(st): edge = min(edge, st.min()) if side == "L" else max(edge, st.max())
        elif len(st):
            edge = st.min() if side == "L" else st.max()
        else:
            continue
        keep[y] = xs >= edge if side == "L" else xs <= edge
    return keep


if __name__ == "__main__":
    xs = np.arange(420)[None, :].repeat(643, 0)
    keep = {}
    for side in ("L", "R"):
        half = xs < MID if side == "L" else xs >= MID
        keep[side] = ~half | outline(side)            # only that side is cut
    # which sides of each body version have a lowered arm
    lowered = {"rig2-body": "LR", "rig2-body-trim-L": "R", "rig2-body-trim-R": "L", "rig2-body-trim": ""}
    for name, sides in lowered.items():
        src = os.path.join(RIG, name + ("-src" if os.path.exists(os.path.join(RIG, name + "-src.png")) else "") + ".png")
        if name == "rig2-body":
            continue        # the full body keeps its own file; its cut copy is rig2-body-cut
        im = np.array(Image.open(src).convert("RGBA")).astype(float)
        for s in sides: im[:, :, 3] *= keep[s]
        Image.fromarray(im.astype("uint8")).save(os.path.join(RIG, name + ".png"))
    full = np.zeros((643, 420, 4)); c = np.array(compose(["rig2-body"], pad=0)).astype(float)[:643, :420]
    full[:] = c; full[:, :, 3] *= keep["L"] & keep["R"]
    Image.fromarray(full.astype("uint8")).save(os.path.join(RIG, "rig2-body-cut.png"))
    for s in ("L", "R"):
        p = os.path.join(RIG, f"rig-straps-{s}-top.png")
        im = np.array(Image.open(p).convert("RGBA")).astype(float); im[:, :, 3] *= keep[s]
        Image.fromarray(im.astype("uint8")).save(p)
    print("ok")
