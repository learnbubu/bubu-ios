"""Puts each results-moment layer back where it sits in its sticker (Codex re-centred and resized
most of them): for each layer, the size and place where it best matches the finished sticker,
found by masked image matching over a range of sizes. Writes out/rig/mo-<k>-<layer>-placed.png,
each on the sticker's own 1024 canvas, so the layers stack. The nightowl glow is made here
instead (Codex's took pink from the magenta)."""
import os

import numpy as np
from PIL import Image
from scipy.signal import fftconvolve

import process
from add_layers import LAYERS

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, "out", "raw"), os.path.join(HERE, "out", "rig")
N = 256          # matching size


def keyed(path):
    return process.key_full(Image.open(path).convert("RGBA"))


def best_place(full, layer, blob=False):
    """(scale, dx, dy, w, h) in N-pixel units: where the layer best matches the sticker. Blobs by their
    outline against the sticker's outline; everything else by pattern (masked normalised correlation),
    which a small plain patch of the same colour can't fake."""
    F = np.asarray(full.resize((N, N), Image.LANCZOS)).astype(float) / 255
    Fa = (F[:, :, 3] > 0.5).astype(float)
    lb = layer.getbbox(); lay = layer.crop(lb)
    best = (-1e18, None)
    for s in np.linspace(0.3, 1.3, 51):
        w, h = int(lay.width / 1024 * N * s), int(lay.height / 1024 * N * s)
        if w < 6 or h < 6 or w > N or h > N: continue
        L = np.asarray(lay.resize((w, h), Image.LANCZOS)).astype(float) / 255
        a = (L[:, :, 3] > 0.5).astype(float); n = a.sum()
        k = a[::-1, ::-1]
        if blob:
            inter = fftconvolve(Fa, k, mode="valid")
            union = n + Fa.sum() - inter
            score = inter / union
        else:
            score = np.zeros((N - h + 1, N - w + 1))
            for c in range(3):
                Lc = L[:, :, c]; mu = (a * Lc).sum() / n; Lz = a * (Lc - mu)
                f = F[:, :, c] * Fa
                num = fftconvolve(f, Lz[::-1, ::-1], mode="valid")
                sf = fftconvolve(f, k, mode="valid"); sff = fftconvolve(f * f, k, mode="valid")
                var = np.maximum(sff - sf * sf / n, 1e-6)
                score += num / np.sqrt(var * (Lz ** 2).sum() + 1e-9)
            # and it must land on the sticker, not off it
            score -= 2 * (1 - fftconvolve(Fa, k, mode="valid") / n)
        i = np.unravel_index(np.argmax(score), score.shape)
        if score[i] > best[0]:
            best = (score[i], (s, i[1], i[0], w, h))
    return lb, best


def glow():
    y, x = np.mgrid[0:1024, 0:1024]
    return x, y


if __name__ == "__main__":
    for k, layers in LAYERS.items():
        full = keyed(os.path.join(RAW, f"mo-{k}.png")).resize((1024, 1024))
        for name in layers:
            src = os.path.join(RAW, f"mo-{k}-{name}.png")
            if not os.path.exists(src): continue
            layer = keyed(src).resize((1024, 1024))
            if k == "nightowl" and name == "glow":
                continue
            lb, (score, (s, dx, dy, w, h)) = best_place(full, layer, blob=(name == "blob"))
            out = Image.new("RGBA", (1024, 1024))
            sc = 1024 / N
            piece = layer.crop(lb).resize((round(w * sc), round(h * sc)), Image.LANCZOS)
            out.alpha_composite(piece, (round(dx * sc), round(dy * sc)))
            out.save(os.path.join(RIG, f"mo-{k}-{name}-placed.png"))
            print(f"{k:10s} {name:12s} scale {s:.2f}  at {dx * sc:5.0f},{dy * sc:5.0f}  fit {score:.3f}")
    # the nightowl lantern's glow: a soft warm halo where the lantern is in the sticker
    full = np.asarray(keyed(os.path.join(RAW, "mo-nightowl.png")).resize((1024, 1024))).astype(float)
    warm = (full[:, :, 0] > 220) & (full[:, :, 1] > 140) & (full[:, :, 2] < 150) & (full[:, :, 3] > 200)
    ys, xs = np.where(warm)
    cx, cy = np.median(xs), np.median(ys)
    yy, xx = np.mgrid[0:1024, 0:1024]
    r = np.hypot(xx - cx, yy - cy) / 190
    a = np.clip(1 - r, 0, 1) ** 2 * 0.85
    g = np.zeros((1024, 1024, 4)); g[:, :, 0] = 255; g[:, :, 1] = 214; g[:, :, 2] = 120; g[:, :, 3] = a * 255
    Image.fromarray(g.astype("uint8")).save(os.path.join(RIG, "mo-nightowl-glow-placed.png"))
    print("nightowl glow at", int(cx), int(cy))
