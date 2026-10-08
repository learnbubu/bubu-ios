"""Mesh skinning for the results moments (owner, 7 Oct 2026: the arms must move, without the joints
showing). Each moment's Bùbù stays ONE image; a grid is laid over it, and each grid point gets a weight
per arm bone: 1 inside the arm, 0 on the body, blended smoothly across the shoulder. Turning a bone
then bends the image, stretching the fur over the shoulder instead of splitting it (as Rive and Spine
do; SpriteKit's SKWarpGeometryGrid does the same in the app).

The arm regions are where the original Bùbù differs from Codex's armless body (as limbs_cut.py); each
bone's pivot is its shoulder. Writes out/rig/skin.json: per moment, the grid size, the layer's box and,
per bone, its pivot and the weights at the grid points.

Separate pieces, not one image (owner, 8 Oct: anything cut from the one picture drags bits of it along).
The STILL layer is Codex's armless body; the ARM layer is the clean arm pieces drawn for rig6, laid over
it. Only the arm layer bends: each arm's weight is 0 at its shoulder root (so the joint never opens) and
eases to 1 towards the hand."""
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


# both arms drawn as one piece: the shoulders (stage px) are pinned, and the hands either swing about the
# middle of them (sweep) or move straight (flawless lifts the stamp, early bird lifts the cup to sip);
# "shift" is the direction moved per unit of the bone's value
SHOULDERS = {"flawless": [(321, 437), (686, 477)], "sweep": [(254, 474), (594, 564)], "earlybird": [(324, 565), (724, 585)]}
SHIFT = {"flawless": [0, -1.6], "earlybird": [0, -1.8]}


# brain gains was drawn small (owner, 8 Oct: match his head to the others'): scaled about his feet
# (stage px), then moved so the feet sit at the new point. 1.25 is as big as fits with the books on top.
SCALE = {"brain": (1.25, (508.5, 987), (508.5, 1000))}


def scaled(k, im):
    if k not in SCALE: return im
    f, (fx, fy), (tx, ty) = SCALE[k]
    fx, fy, tx, ty = fx + PAD, fy + PAD, tx + PAD, ty + PAD
    # PIL's affine maps output -> input
    return np.asarray(Image.fromarray(im).transform(im.shape[1::-1], Image.AFFINE, (1 / f, 0, fx - tx / f, 0, 1 / f, fy - ty / f), Image.BICUBIC))


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


if __name__ == "__main__":
    out = {}
    for k, nb in MOMENTS.items():
        body = scaled(k, np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-body-placed.png")).convert("RGBA")))
        pieces = [scaled(k, np.asarray(Image.open(os.path.join(RIG, n + ".png")).convert("RGBA"))) for n in ARMS[k]]
        arm = Image.new("RGBA", body.shape[1::-1], (0, 0, 0, 0))
        for pc in pieces: arm.alpha_composite(Image.fromarray(pc))
        arm = np.asarray(arm); ba = body[:, :, 3] > 128
        whole = ba | (arm[:, :, 3] > 128)
        ys, xs = np.where(whole); x0, y0, x1, y1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
        gx = np.linspace(x0, x1 - 1, G); gy = np.linspace(y0, y1 - 1, G)
        bones = []
        for pc in pieces:
            bm = pc[:, :, 3] > 128
            # the shoulder: where the piece meets the body, the part of it nearest the body's middle
            over = ndimage.binary_dilation(ba, iterations=4) & bm
            oy, ox = np.where(over)
            by, bx = np.where(ba); c = np.array([bx.mean(), by.mean()])
            d = np.hypot(ox - c[0], oy - c[1]); sel = d <= np.percentile(d, 35)
            piv = np.array([ox[sel].mean(), oy[sel].mean()])
            if k == "kungfu": piv = np.array(json.load(open(os.path.join(RIG, "pivots.json")))["kungfu-limb"]) + PAD
            anchors = [piv]
            if k in SHOULDERS:
                anchors = [np.array(a) + PAD for a in SHOULDERS[k]]; piv = sum(anchors) / len(anchors)
            # weight: 0 round the shoulder root(s), easing to 1 over ~130 px towards the hand; only on this arm
            yy, xx = np.mgrid[:bm.shape[0], :bm.shape[1]]
            dist = np.min([np.hypot(xx - a[0], yy - a[1]) for a in anchors], axis=0)
            u = np.clip((dist - 25) / 130, 0, 1); w = u * u * (3 - 2 * u)
            w = w * ndimage.gaussian_filter(ndimage.binary_dilation(bm, iterations=24).astype(float), 6)
            W = w[np.ix_(gy.astype(int), gx.astype(int))]
            bones.append({"pivot": [float(piv[0]) - PAD, float(piv[1]) - PAD], "w": [round(float(v), 3) for v in W.ravel()]})
            if k in SHIFT: bones[-1]["shift"] = SHIFT[k]
        M = 140; crop = (max(0, x0 - M), max(0, y0 - M), min(whole.shape[1], x1 + M), min(whole.shape[0], y1 + M))
        cx0, cy0, cx1, cy1 = crop
        out[k] = {"layer": "kick" if k == "kungfu" else "bubu", "still": uri(body[cy0:cy1, cx0:cx1]), "arm": uri(arm[cy0:cy1, cx0:cx1]),
                  "at": [int(cx0) - PAD, int(cy0) - PAD], "grid": G,
                  "box": [float(x0 - PAD), float(y0 - PAD), float(x1 - PAD), float(y1 - PAD)], "bones": bones}
        print(k, "bones", [b["pivot"] for b in bones])
    json.dump(out, open(os.path.join(RIG, "skin.json"), "w"))
