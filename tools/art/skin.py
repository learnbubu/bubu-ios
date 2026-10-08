"""Mesh skinning for the results moments (owner, 7 Oct 2026: the arms must move, without the joints
showing). Each moment's Bùbù stays ONE image; a grid is laid over it, and each grid point gets a weight
per arm bone: 1 inside the arm, 0 on the body, blended smoothly across the shoulder. Turning a bone
then bends the image, stretching the fur over the shoulder instead of splitting it (as Rive and Spine
do; SpriteKit's SKWarpGeometryGrid does the same in the app).

The arm regions are where the original Bùbù differs from Codex's armless body (as limbs_cut.py); each
bone's pivot is its shoulder. Writes out/rig/skin.json: per moment, the grid size, the layer's box and,
per bone, its pivot and the weights at the grid points."""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RIG = os.path.join(HERE, "out", "rig")
PAD = 128
G = 33                    # grid points across and down
MOMENTS = {"flawless": 1, "sweep": 1, "earlybird": 1, "brain": 2}


ARMS = {"flawless": ["m6-flawless-arms-down"], "sweep": ["m6-sweep-arms-broom"], "earlybird": ["m6-earlybird-arms-lap"],
        "brain": ["m6-brain-arm-left", "m6-brain-arm-right"]}


def arm_mask(k):
    """The arm areas: the clean arm pieces drawn for rig6 (placed over this sticker), where Bùbù is."""
    orig = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-bubu-placed.png")).convert("RGBA"))
    body = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-body-placed.png")).convert("RGBA"))
    oa, ba = orig[:, :, 3] > 128, body[:, :, 3] > 128
    ms = []
    for n in ARMS[k]:
        a = np.asarray(Image.open(os.path.join(RIG, n + ".png")).convert("RGBA"))[:, :, 3] > 128
        ms.append(ndimage.binary_dilation(a, iterations=6) & oa)
    return ms, ba, oa


if __name__ == "__main__":
    out = {}
    for k, nb in MOMENTS.items():
        masks, body, whole = arm_mask(k)
        ys, xs = np.where(whole); x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        bones = []
        for bm in masks:
            # the shoulder: where the arm meets the body, the part of it nearest the body's middle
            over = ndimage.binary_dilation(bm, iterations=8) & body & ~bm
            oy, ox = np.where(over)
            by, bx = np.where(body); c = np.array([bx.mean(), by.mean()])
            d = np.hypot(ox - c[0], oy - c[1]); sel = d <= np.percentile(d, 35)
            piv = [float(ox[sel].mean()) - PAD, float(oy[sel].mean()) - PAD]
            # weights: 1 in the arm, easing to 0 over ~40 px into the body round the shoulder
            dist_out = ndimage.distance_transform_edt(~bm)
            w = np.clip(1 - dist_out / 40, 0, 1) ** 1.5
            gx = np.linspace(x0, x1 - 1, G); gy = np.linspace(y0, y1 - 1, G)
            W = w[np.ix_(gy.astype(int), gx.astype(int))]
            bones.append({"pivot": piv, "w": [round(float(v), 3) for v in W.ravel()]})
        out[k] = {"grid": G, "box": [float(x0 - PAD), float(y0 - PAD), float(x1 - PAD), float(y1 - PAD)], "bones": bones}
        print(k, "bones", [b["pivot"] for b in bones])
    json.dump(out, open(os.path.join(RIG, "skin.json"), "w"))
