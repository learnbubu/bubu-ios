"""Limbs cut from the original sticker art, not Codex's redraw (owner, 7 Oct 2026: the redrawn arms
didn't match): a limb is the part of the original Bùbù layer that isn't in Codex's limbless body
(where the two differ). Codex's body is kept for what the limb was covering. Writes
out/rig/mo-<k>-<limb>-placed.png and the pivot (where the limb meets the body) into pivots.json."""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
RIG = os.path.join(HERE, "out", "rig")
PAD = 128
LIMB = {"flawless": "arms", "kungfu": "limb", "sweep": "limb", "nightowl": "limb", "earlybird": "limb"}

if __name__ == "__main__":
    piv = json.load(open(os.path.join(RIG, "pivots.json")))
    for k, limb in LIMB.items():
        orig = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-bubu-placed.png")).convert("RGBA")).astype(float)
        body = np.asarray(Image.open(os.path.join(RIG, f"mo-{k}-body-placed.png")).convert("RGBA")).astype(float)
        oa, ba = orig[:, :, 3] > 128, body[:, :, 3] > 128
        diff = np.abs(orig[:, :, :3] - body[:, :, :3]).sum(2)
        # the limb: the original where the body has nothing, or where they clearly differ
        m = oa & (~ba | (diff > 90))
        m = ndimage.binary_opening(m, iterations=2)
        lab, n = ndimage.label(m)
        if n:
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            m = np.isin(lab, [i + 1 for i, sz in enumerate(sizes) if sz > 0.15 * sizes.max()])
        m = ndimage.binary_closing(m, iterations=4) & oa
        m = ndimage.binary_dilation(m, iterations=2) & oa      # take in its soft edge
        out = orig.copy(); out[~m, 3] = 0
        Image.fromarray(out.astype("uint8")).save(os.path.join(RIG, f"mo-{k}-{limb}-placed.png"))
        over = m & ba
        ys, xs = np.where(over)
        if len(xs):
            # the joint: the overlap's point nearest the body's middle
            by, bx = np.where(ba); cy, cx = by.mean(), bx.mean()
            d = np.hypot(xs - cx, ys - cy); i = np.argsort(d)[: max(1, len(d) // 10)]
            piv[f"{k}-{limb}"] = [float(xs[i].mean()) - PAD, float(ys[i].mean()) - PAD]
        print(k, limb, int(m.sum()), "px", piv.get(f"{k}-{limb}"))
    json.dump(piv, open(os.path.join(RIG, "pivots.json"), "w"), indent=1)
