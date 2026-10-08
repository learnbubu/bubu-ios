"""Mesh skinning for the results moments (owner, 7 Oct 2026: the arms must move, without the joints
showing). Each moment's Bùbù stays ONE image; a grid is laid over it, and each grid point gets a weight
per arm bone: 1 inside the arm, 0 on the body, blended smoothly across the shoulder. Turning a bone
then bends the image, stretching the fur over the shoulder instead of splitting it (as Rive and Spine
do; SpriteKit's SKWarpGeometryGrid does the same in the app).

The arm regions are where the original Bùbù differs from Codex's armless body (as limbs_cut.py); each
bone's pivot is its shoulder. Writes out/rig/skin.json: per moment, the grid size, the layer's box and,
per bone, its pivot and the weights at the grid points.

Masked, not bent whole (owner, 8 Oct: the bend still pulled his face): two images per moment. The STILL
layer is Bùbù never bent, with Codex's armless body filling in where the arm was (so nothing is missing
when it swings away); the ARM layer is the arm alone, cut by its mask, fading out a little way into the
shoulder. Only the arm layer goes through the grid; the face always comes from the still layer."""
import base64
import io
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RIG = os.path.join(HERE, "out", "rig")
PAD = 128
G = 49                    # grid points across and down (finer: smoother bends)
MOMENTS = {"flawless": 1, "sweep": 1, "earlybird": 1, "brain": 2, "kungfu": 1}


ARMS = {"flawless": ["m6-flawless-arms-down"], "sweep": ["m6-sweep-arms-broom"], "earlybird": ["m6-earlybird-arms-lap"],
        "brain": ["m6-brain-arm-left", "m6-brain-arm-right"], "kungfu": ["mo-kungfu-limb-placed"]}


# each head (an ellipse over the face and crown, in placed-image px: centre x, y, radius x, y). Nothing
# here may bend: the blend round an arm stops at the head, so only the arm itself moves over his face
HEADS = {"flawless": (688, 368, 245, 195), "sweep": (646, 448, 262, 176), "earlybird": (688, 464, 256, 176),
         "brain": (640, 592, 192, 134), "kungfu": (730, 422, 250, 186)}


def head_keep(k, shape):
    """1 where the head is (softened over ~20 px at its edge), 0 elsewhere."""
    cx, cy, rx, ry = HEADS[k]
    yy, xx = np.mgrid[:shape[0], :shape[1]]
    d = np.hypot((xx - cx) / rx, (yy - cy) / ry)
    return np.clip((1.08 - d) / 0.16, 0, 1)


def arm_mask(k):
    """The arm areas: the clean arm pieces drawn for rig6 (placed over this sticker), where Bùbù is."""
    orig = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-bubu-placed.png")).convert("RGBA"))
    body = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-body-placed.png")).convert("RGBA"))
    oa, ba = orig[:, :, 3] > 128, body[:, :, 3] > 128
    ms = []
    for n in ARMS[k]:
        a = np.asarray(Image.open(os.path.join(RIG, n + ".png")).convert("RGBA"))[:, :, 3] > 128
        ms.append(ndimage.binary_dilation(a, iterations=6) & oa)
    return ms, ba, oa, orig, body


def uri(a):
    b = io.BytesIO(); Image.fromarray(a).save(b, "WEBP", quality=92, method=6)
    return "data:image/webp;base64," + base64.b64encode(b.getvalue()).decode()


def layers(k, masks, orig, body, crop):
    """The still layer (the arm swapped for the armless body) and the arm layer (the arm cut out, fading
    over ~24 px into the shoulder, never into the head)."""
    x0, y0, x1, y1 = crop
    anym = np.zeros(orig.shape[:2], bool)
    keep = head_keep(k, orig.shape[:2])
    for bm in masks: anym |= bm
    # swap in the body where the arm was, plus any of the old arm round it that the body hasn't got (its
    # soft outline, a sleeve root, a cup's rim)
    near = ndimage.binary_dilation(anym, iterations=60) & (keep < 0.5)
    differs = np.abs(orig[:, :, :3].astype(int) - body[:, :, :3]).mean(2) > 70
    swap = ndimage.binary_dilation(anym, iterations=4) | (near & (body[:, :, 3] < 128) & (orig[:, :, 3] > 0)) |         ndimage.binary_opening(near & differs, iterations=2)
    still = orig.copy(); still[swap] = body[swap]
    # the arm layer covers ALL of what was swapped (so at rest he is exactly the original), then fades
    # over ~24 px into the shoulder, never into the head
    fade = np.clip(1 - ndimage.distance_transform_edt(~swap) / 24, 0, 1)
    alpha = np.maximum(fade * (1 - keep), swap)
    arm = orig.copy(); arm[:, :, 3] = (orig[:, :, 3] * alpha).astype(np.uint8)
    return uri(still[y0:y1, x0:x1]), uri(arm[y0:y1, x0:x1])


if __name__ == "__main__":
    out = {}
    for k, nb in MOMENTS.items():
        masks, body, whole, orig, bodyim = arm_mask(k)
        if k == "kungfu": body = whole            # the legless body is a different shape; pivot from pivots.json
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
            u = np.clip(1 - dist_out / 70, 0, 1); w = u * u * (3 - 2 * u)
            w = ndimage.gaussian_filter(w, 6)
            w = np.maximum(w * (1 - head_keep(k, w.shape)), bm.astype(float))   # the head stays put
            gx = np.linspace(x0, x1 - 1, G); gy = np.linspace(y0, y1 - 1, G)
            W = w[np.ix_(gy.astype(int), gx.astype(int))]
            bones.append({"pivot": piv, "w": [round(float(v), 3) for v in W.ravel()]})
        if k == "kungfu":            # the leg turns at the hip (where it joins him, low)
            piv = json.load(open(os.path.join(RIG, "pivots.json")))["kungfu-limb"]; bones[0]["pivot"] = piv
        M = 140; crop = (max(0, x0 - M), max(0, y0 - M), min(whole.shape[1], x1 + M), min(whole.shape[0], y1 + M))
        still, arm = layers(k, masks, orig, bodyim, crop)
        out[k] = {"layer": "kick" if k == "kungfu" else "bubu", "still": still, "arm": arm, "at": [int(crop[0]) - PAD, int(crop[1]) - PAD], "grid": G, "box": [float(x0 - PAD), float(y0 - PAD), float(x1 - PAD), float(y1 - PAD)], "bones": bones}
        print(k, "bones", [b["pivot"] for b in bones])
    json.dump(out, open(os.path.join(RIG, "skin.json"), "w"))
