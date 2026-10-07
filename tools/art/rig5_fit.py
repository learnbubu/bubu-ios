"""Fits the rig5 set to Bùbù (owner, 7 Oct 2026): each new head lined up with rig-head by its
outline (the cream face and ears together), each new torso with rig4-torso-arms by its belly.
Writes the places into out/rig/rig5.json (left, top, width on panda-idle's canvas), which
rig_layout reads."""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

from rig_layout import compose, HERE

RIG = os.path.join(HERE, "out", "rig")
HEADS = ["sad", "wince", "wow", "grin", "think", "look-down", "wink", "proud", "sleepy"]
TORSOS = ["hips", "cheer-fists", "scratch", "hug"]


def face_box(a):
    """The head's outline without the ears: the biggest cream area."""
    cream = (a[:, :, 3] > 200) & (a[:, :, 0] > 215) & (a[:, :, 1] > 205) & (a[:, :, 2] > 170)
    lab, n = ndimage.label(cream)
    big = 1 + int(np.argmax(ndimage.sum(cream, lab, range(1, n + 1))))
    ys, xs = np.where(lab == big)
    return xs.min(), ys.min(), xs.max(), ys.max()


def belly_box(a):
    return face_box(a)          # the belly is the torso's biggest cream area


def fit(name, ref_names, box):
    ref = np.array(compose(ref_names, pad=0))
    rx0, ry0, rx1, ry1 = box(ref)
    im = Image.open(os.path.join(RIG, name + ".png")).convert("RGBA")
    x0, y0, x1, y1 = box(np.array(im))
    s = (rx1 - rx0) / (x1 - x0)
    return [round(rx0 - x0 * s, 1), round(ry0 - y0 * s, 1), round(im.width * s, 1)]


if __name__ == "__main__":
    out = {}
    for h in HEADS:
        out[f"rig5-head-{h}"] = fit(f"rig5-head-{h}", ["rig-head"], face_box)
    for t in TORSOS:
        out[f"rig5-torso-{t}"] = fit(f"rig5-torso-{t}", ["rig4-torso-arms"], belly_box)
    json.dump(out, open(os.path.join(RIG, "rig5.json"), "w"), indent=1)
    for k, v in out.items(): print(k, v)
