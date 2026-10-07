"""Second pass for the props layers_fit.py couldn't place: SIFT features in the prop matched to the
finished sticker, and a similarity transform (scale, turn, move) fitted to them with RANSAC. Only
replaces a placement when enough features agree. Writes out/rig/mo-<k>-<layer>-placed.png."""
import os

import cv2
import numpy as np
from PIL import Image

import process
from add_layers import LAYERS

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, "out", "raw"), os.path.join(HERE, "out", "rig")


def flat(im):
    """RGBA over mid grey, as grey-scale for features; and the alpha as a mask."""
    a = np.asarray(im).astype(float)
    rgb = a[:, :, :3] * (a[:, :, 3:] / 255) + 128 * (1 - a[:, :, 3:] / 255)
    g = cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY)
    return g, (a[:, :, 3] > 128).astype(np.uint8) * 255


if __name__ == "__main__":
    sift = cv2.SIFT_create(nfeatures=4000)
    bf = cv2.BFMatcher()
    for k, layers in LAYERS.items():
        full = process.key_full(Image.open(os.path.join(RAW, f"mo-{k}.png")).convert("RGBA")).resize((1024, 1024))
        fg, fm = flat(full)
        kf, df = sift.detectAndCompute(fg, fm)
        for name in layers:
            if name in ("blob", "bubu", "glow"): continue
            src = os.path.join(RAW, f"mo-{k}-{name}.png")
            if not os.path.exists(src): continue
            layer = process.key_full(Image.open(src).convert("RGBA")).resize((1024, 1024))
            lg, lm = flat(layer)
            kl, dl = sift.detectAndCompute(lg, lm)
            if dl is None or df is None or len(kl) < 6:
                print(f"{k:10s} {name:12s} too few features"); continue
            good = [m for m, n in bf.knnMatch(dl, df, k=2) if m.distance < 0.75 * n.distance]
            if len(good) < 6:
                print(f"{k:10s} {name:12s} {len(good)} matches, kept"); continue
            src_pts = np.float32([kl[m.queryIdx].pt for m in good])
            dst_pts = np.float32([kf[m.trainIdx].pt for m in good])
            M, inl = cv2.estimateAffinePartial2D(src_pts, dst_pts, method=cv2.RANSAC, ransacReprojThreshold=6)
            n_in = int(inl.sum()) if inl is not None else 0
            if M is None or n_in < 6:
                print(f"{k:10s} {name:12s} {n_in} agree, kept"); continue
            s = float(np.hypot(M[0, 0], M[1, 0])); turn = np.degrees(np.arctan2(M[1, 0], M[0, 0]))
            if not (0.2 < s < 1.4) or abs(turn) > 15:
                print(f"{k:10s} {name:12s} implausible (scale {s:.2f}, turn {turn:.0f}), kept"); continue
            out = cv2.warpAffine(np.asarray(layer), M, (1024, 1024), flags=cv2.INTER_LANCZOS4, borderValue=(0, 0, 0, 0))
            Image.fromarray(out).save(os.path.join(RIG, f"mo-{k}-{name}-placed.png"))
            print(f"{k:10s} {name:12s} scale {s:.2f}  turn {np.degrees(np.arctan2(M[1, 0], M[0, 0])):5.1f}°  {n_in}/{len(good)} agree")
