"""The eye marks, one per eye, placed in Bùbù's eye patches the way panda-idle has them: each
mark's centre and width measured against its patch in panda-idle, then applied to the rig head's
patches (rig_layout.EYES). Writes out/rig/rig-glint-<kind>-<side>.png."""
import json
import os

import numpy as np
from scipy import ndimage
from PIL import Image

from rig_layout import compose, L, HERE

IDLE = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets", "panda-idle.imageset", "panda-idle.png")
MID = 208      # Bùbù's middle, in panda-idle's pixels
FACE = (60, 100, 360, 240)


def blobs(a, light):
    """Per side: the eye patch's box and, inside it, the light mark's box."""
    rgb, al = a[:, :, :3].astype(int).sum(2), a[:, :, 3]
    out = {}
    for side, xs in (("L", slice(FACE[0], MID)), ("R", slice(MID, FACE[2]))):
        sub = np.zeros_like(al, dtype=bool); sub[FACE[1]:FACE[3], xs] = True
        dark = sub & (al > 128) & (rgb < 200)
        # the patch: the biggest dark area (not the nose, mouth or brows), its box
        lab, n = ndimage.label(dark)
        big = 1 + int(np.argmax(ndimage.sum(dark, lab, range(1, n + 1))))
        # its holes (the mark inside) count as patch too
        patch = ndimage.binary_fill_holes(lab == big)
        ys, xx = np.where(patch)
        box = (xx.min(), ys.min(), xx.max(), ys.max())
        m = {"patch": box}
        if light:
            inside = patch
            lt = inside & (al > 128) & (rgb > 560)
            ly, lx = np.where(lt)
            m["mark"] = (lx.min(), ly.min(), lx.max(), ly.max())
        out[side] = m
    return out


def main():
    idle = np.array(Image.open(IDLE).convert("RGBA"))
    ref = blobs(idle, True)
    head = np.array(compose(["rig-head"], pad=0))
    hp = blobs(head, False)
    place = {}
    for kind in ("open", "wow"):
        g = Image.open(os.path.join(HERE, "out", "rig", f"rig-glint-{kind}.png")).convert("RGBA")
        w = g.width
        for side in ("L", "R"):
            half = g.crop((0, 0, w // 2, g.height) if side == "L" else (w // 2, 0, w, g.height))
            if kind == "open":
                # both arcs are the same shape: the right one, cleanly, for both eyes (the left
                # half picks up stray light specks that throw its size off)
                half = g.crop((w // 2, 0, w, g.height))
                al = np.array(half)[:, :, 3] > 128
                lab, n = ndimage.label(al)
                big = 1 + int(np.argmax(ndimage.sum(al, lab, range(1, n + 1))))
                ys, xs = np.where(lab == big)
                half = half.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
            else:
                half = half.crop(half.getbbox())
            px0, py0, px1, py1 = ref[side]["patch"]; mx0, my0, mx1, my1 = ref[side]["mark"]
            pw, ph = px1 - px0, py1 - py0
            cx, cy = ((mx0 + mx1) / 2 - px0) / pw, ((my0 + my1) / 2 - py0) / ph
            wr = (mx1 - mx0) / pw
            hx0, hy0, hx1, hy1 = hp[side]["patch"]
            hw, hh = hx1 - hx0, hy1 - hy0
            # the wow marks fill more of the patch than the arcs do
            tw = round(hw * (wr if kind == "open" else 0.62))
            th = round(tw * half.height / half.width)
            ccx, ccy = (hx0 + cx * hw, hy0 + cy * hh) if kind == "open" else (hx0 + hw / 2, hy0 + hh * 0.45)
            name = f"rig-glint-{kind}-{side}"
            half.save(os.path.join(HERE, "out", "rig", name + ".png"))
            place[name] = (round(ccx - tw / 2), round(ccy - th / 2), tw)
    json.dump(place, open(os.path.join(HERE, "out", "rig", "eyes.json"), "w"), indent=1)
    print(place)


if __name__ == "__main__":
    main()
