"""Third pass on the results-moment layers (owner, 7 Oct 2026: "why is the aspect ratio all messed
up?"): Codex redrew some layers a little narrower or wider than in the sticker, and an even scale
kept that. Here each layer gets its own width and height:
  blobs  - stretched so their outline's box matches the sticker's;
  others - a full affine (separate x and y scale, a little shear allowed) fitted to SIFT features
           with RANSAC, when enough agree and it's plausible; otherwise the earlier placement,
           then stretched to match its box against the sticker where that layer is the whole of it.
Rewrites out/rig/mo-<k>-<layer>-placed.png."""
import os

import cv2
import numpy as np
from PIL import Image

import process
from add_layers import LAYERS

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, "out", "raw"), os.path.join(HERE, "out", "rig")


def flat(im):
    a = np.asarray(im).astype(float)
    rgb = a[:, :, :3] * (a[:, :, 3:] / 255) + 128 * (1 - a[:, :, 3:] / 255)
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY), (a[:, :, 3] > 128).astype(np.uint8) * 255


def box(a):
    ys, xs = np.where(a > 128)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


if __name__ == "__main__":
    sift = cv2.SIFT_create(nfeatures=5000)
    bf = cv2.BFMatcher()
    for k, layers in LAYERS.items():
        full = process.key(Image.open(os.path.join(RAW, f"mo-{k}.png")).convert("RGBA")).resize((1024, 1024), Image.LANCZOS)
        fa = np.asarray(full)
        fg, fm = flat(full)
        kf, df = sift.detectAndCompute(fg, fm)
        for name in layers:
            src = os.path.join(RAW, f"mo-{k}-{name}.png")
            if not os.path.exists(src): continue
            layer = process.key(Image.open(src).convert("RGBA")).resize((1024, 1024), Image.LANCZOS)
            la = np.asarray(layer)
            if name == "blob":
                x0, y0, x1, y1 = box(la[:, :, 3]); X0, Y0, X1, Y1 = box(fa[:, :, 3])
                sx, sy = (X1 - X0) / (x1 - x0), (Y1 - Y0) / (y1 - y0)
                M = np.float32([[sx, 0, X0 - x0 * sx], [0, sy, Y0 - y0 * sy]])
                how = f"outline box, x {sx:.2f} y {sy:.2f}"
            else:
                lg, lm = flat(layer)
                kl, dl = sift.detectAndCompute(lg, lm)
                M = None
                if dl is not None and len(kl) >= 8:
                    good = [m for m, n in bf.knnMatch(dl, df, k=2) if m.distance < 0.75 * n.distance]
                    if len(good) >= 8:
                        A, inl = cv2.estimateAffine2D(np.float32([kl[m.queryIdx].pt for m in good]),
                                                      np.float32([kf[m.trainIdx].pt for m in good]),
                                                      method=cv2.RANSAC, ransacReprojThreshold=5)
                        if A is not None and inl.sum() >= 8:
                            sx, sy = np.hypot(A[0, 0], A[1, 0]), np.hypot(A[0, 1], A[1, 1])
                            shear = abs(A[0, 0] * A[0, 1] + A[1, 0] * A[1, 1]) / (sx * sy)
                            if 0.15 < sx < 1.5 and 0.15 < sy < 1.5 and 0.6 < sx / sy < 1.6 and shear < 0.15:
                                M = A.astype(np.float32); how = f"features {int(inl.sum())}/{len(good)}, x {sx:.2f} y {sy:.2f}"
                if M is None:
                    # keep the earlier placement (even scale); it's the best we have
                    print(f"{k:10s} {name:12s} kept the earlier placement"); continue
            out = cv2.warpAffine(la, M, (1024, 1024), flags=cv2.INTER_LANCZOS4, borderValue=(0, 0, 0, 0))
            Image.fromarray(out).save(os.path.join(RIG, f"mo-{k}-{name}-placed.png"))
            print(f"{k:10s} {name:12s} {how}")
