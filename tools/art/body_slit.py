"""A pocket's open body with a thin slit, not a deep hollow (the owner, 20 Oct 2026: "looks like a deep thick inside").
Codex drew the open top as a big dark crescent dipping down to where the flap's edge was; a hongbao is flat paper, so
lifting the flap shows the front panel running up to the top edge and only a thin dark slit above it. Each column's
dark hollow is painted over with the front's own red from just under it, up to the slit.

    python body_slit.py red [jade gold]      (reads out/raw/pk2-<kind>-body.png, keeps the original as _superseded)
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SLIT = 24          # the slit's depth under the pocket's top, in the 1024 canvas


def make(kind):
    path = os.path.join(HERE, "out", "raw", f"pk2-{kind}-body.png")
    keep = os.path.join(HERE, "out", "raw", "_superseded", f"pk2-{kind}-body-hollow.png")
    if not os.path.exists(keep):
        os.makedirs(os.path.dirname(keep), exist_ok=True)
        shutil.copy(path, keep)
    a = np.array(Image.open(keep).convert("RGB")).astype(float)
    mag = (a[..., 0] > 190) & (a[..., 2] > 190) & (a[..., 1] < 90)
    ys, xs = np.nonzero(~mag)
    top, x0, x1 = ys.min(), xs.min(), xs.max()
    lum = a.mean(axis=2)
    # the hollow: the dark inside, well below the front's own brightness
    front = np.median(lum[top + 260:top + 300, x0 + 40:x1 - 40])
    dark = (lum < front * 0.72) & ~mag
    dark[:top + 6] = False
    dark[top + 200:] = False
    dark = np.array(Image.fromarray((dark * 255).astype("uint8")).filter(ImageFilter.MaxFilter(5))) > 127
    out = a.copy()
    for x in range(x0, x1 + 1):
        col = np.nonzero(dark[:, x])[0]
        if len(col) == 0: continue
        lo = col.max() + 4                              # the first row of front under the hollow
        src = a[lo:lo + 10, x].mean(axis=0)
        y_from = top + SLIT
        if lo <= y_from: continue
        out[y_from:lo, x] = src
    # the slit: a thin dark band just under the top rim, and a fine light edge on the front's top
    inside = np.median(a[dark], axis=0) if dark.any() else np.array([120, 12, 12.0])
    for x in range(x0, x1 + 1):
        col = np.nonzero(dark[:, x])[0]
        if len(col) == 0: continue
        s = max(top + 6, col.min())
        out[s:top + SLIT, x] = inside
        out[top + SLIT, x] = out[top + SLIT, x] * 0.6 + np.array([255, 190, 150]) * 0.4
    # soften the seam between the fill and the front under it
    im = Image.fromarray(out.astype("uint8"))
    blur = np.array(im.filter(ImageFilter.GaussianBlur(9))).astype(float)
    band = np.zeros_like(dark)
    for x in range(x0, x1 + 1):
        col = np.nonzero(dark[:, x])[0]
        if len(col): band[col.max() - 14:col.max() + 18, x] = True
    out[band] = blur[band]
    Image.fromarray(out.astype("uint8")).save(path)
    print(kind, "top", top, "front lum", round(front))


if __name__ == "__main__":
    for k in sys.argv[1:] or ["red"]:
        make(k)
