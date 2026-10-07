"""Places the split layers (owner, 7 Oct 2026: a body and its moving limb for each moment, and the
lightning-fast Bùbù redrawn) where they sit in their sticker: each matched to the sticker by SIFT
features with one even scale (as layers_affine.py), on the same padded canvas. Writes
out/rig/mo-<k>-<part>-placed.png. Also finds each limb's pivot: the point where it joins the body
(the middle of the limb pixels that overlap the body), saved to out/rig/pivots.json."""
import json
import os

import cv2
import numpy as np
from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, "out", "raw"), os.path.join(HERE, "out", "rig")
PAD = 128
SPLITS = {"flawless": ["body", "arms", "bubu-up"], "kungfu": ["body", "limb"], "sweep": ["body", "limb"],
          "nightowl": ["body", "limb"], "earlybird": ["body", "limb"], "brain": ["body", "limb"], "speedy": ["bubu2"]}


def flat(a):
    rgb = a[:, :, :3] * (a[:, :, 3:] / 255) + 128 * (1 - a[:, :, 3:] / 255)
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY), (a[:, :, 3] > 128).astype(np.uint8) * 255


def load(p):
    return np.asarray(process.key_full(Image.open(p).convert("RGBA")).resize((1024, 1024), Image.LANCZOS))


if __name__ == "__main__":
    sift = cv2.SIFT_create(nfeatures=6000)
    bf = cv2.BFMatcher()
    piv = {}
    for k, parts in SPLITS.items():
        # match against Bùbù's own layer (already placed), which these were all edited from
        ref_raw = load(os.path.join(RAW, f"mo-{k}-bubu.png"))
        kr, dr = sift.detectAndCompute(*flat(ref_raw))
        placed_ref = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-bubu-placed.png")).convert("RGBA"))
        # bubu raw -> placed: re-estimate from features (the placed one is the raw one moved and scaled)
        kp, dp = sift.detectAndCompute(*flat(placed_ref))
        g = [m for m, n in bf.knnMatch(dr, dp, k=2) if m.distance < 0.7 * n.distance]
        Mref, _ = cv2.estimateAffinePartial2D(np.float32([kr[m.queryIdx].pt for m in g]), np.float32([kp[m.trainIdx].pt for m in g]),
                                              method=cv2.RANSAC, ransacReprojThreshold=4)
        body = None
        for part in parts:
            src = os.path.join(RAW, f"mo-{k}-{part}.png")
            if not os.path.exists(src): continue
            lay = load(src)
            kl, dl = sift.detectAndCompute(*flat(lay))
            good = [m for m, n in bf.knnMatch(dl, dr, k=2) if m.distance < 0.75 * n.distance]
            A, inl = cv2.estimateAffinePartial2D(np.float32([kl[m.queryIdx].pt for m in good]), np.float32([kr[m.trainIdx].pt for m in good]),
                                                 method=cv2.RANSAC, ransacReprojThreshold=5)
            s = float(np.hypot(A[0, 0], A[1, 0])) if A is not None else 0
            if A is None or inl.sum() < 8 or not (0.7 < s < 1.4):
                A = np.float32([[1, 0, 0], [0, 1, 0]]); how = "kept in place (the edit kept the canvas)"
            else:
                how = f"features {int(inl.sum())}/{len(good)}, scale {s:.2f}"
            M = (np.vstack([Mref, [0, 0, 1]]) @ np.vstack([A, [0, 0, 1]]))[:2].astype(np.float32)
            out = cv2.warpAffine(lay, M, placed_ref.shape[1::-1], flags=cv2.INTER_LANCZOS4, borderValue=(0, 0, 0, 0))
            name = "bubu" if part == "bubu2" else part
            Image.fromarray(out).save(os.path.join(RIG, f"mo-{k}-{name}-placed.png"))
            if part == "body": body = out
            print(f"{k:10s} {part:8s} {how}")
        # the limb's pivot: where it overlaps the body
        if body is not None:
            for part in ("limb", "arms"):
                p = os.path.join(RIG, f"mo-{k}-{part}-placed.png")
                if not os.path.exists(p): continue
                limb = np.asarray(Image.open(p))
                over = (limb[:, :, 3] > 128) & (body[:, :, 3] > 128)
                ys, xs = np.where(over)
                if len(xs):
                    piv[f"{k}-{part}"] = [float(xs.mean()) - PAD, float(ys.mean()) - PAD]
    json.dump(piv, open(os.path.join(RIG, "pivots.json"), "w"), indent=1)
    print(piv)
