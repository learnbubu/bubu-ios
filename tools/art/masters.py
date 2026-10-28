"""The mount masters: the things the hanging pieces hang from, picked by the owner in the art review (28 Oct 2026).

Each master is the keyed, trimmed mount from out/final, copied into masters/ (kept in git, so it never changes), with
its tie point: the bottom of its brass ring, where a cord is tied. The tie point is found as the lowest visible pixel
in the ring's column (the ring hangs under the arm's outer end), unless TIE gives it by hand. masters/masters.json
holds them all for hang.py; masters/check.png shows each master with its tie point marked, to look at.

    python masters.py
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
OUT = os.path.join(HERE, "masters")

# master name -> the picture kept for it (the review's name, in out/final)
MASTERS = {
    "roof-eave": "mount-roof-eave-tie",         # take 2, a red cord tied round its tip (group "rings"; the ring looked fake)
    "bamboo-pole": "mount-bamboo-pole-ring",    # its red loop swapped for a brass ring (group "rings")
    "iron-scroll": "mount-iron-scroll-take2",
    "cloud-bracket": "mount-cloud-bracket",
    "dragon-head": "mount-dragon-head",
    "jade-bracket": "mount-jade-bracket-take2",
    "brass-rod": "mount-brass-rod",
    "stone-corbel": "mount-stone-corbel",
}
# until the ring swaps are made, the pictures they're made from
FALLBACK = {"mount-roof-eave-tie": "mount-roof-eave-ring", "mount-bamboo-pole-ring": "mount-bamboo-pole"}
TIE = {"mount-roof-eave-ring": (403, 240)}   # picture -> (x, y) by hand, where the found one is wrong (the eave's orange woodwork reads as brass)
CORD_END = {"mount-roof-eave-tie"}           # tied with a cord, not a ring: the tie point is the cord's end


def brass(a):
    """Brass and gold pixels: warm, bright, low blue."""
    r, g, b = (a[..., i].astype(int) for i in range(3))
    return (a[..., 3] > 128) & (r > 150) & (g > 100) & (b < 0.6 * g) & (r - b > 90)


def find_cord_end(im):
    """The bottom of a red cord hanging from the mount's outer end (in its right quarter, clear of the eave's woodwork)."""
    a = np.asarray(im)
    r, g, b = (a[..., i].astype(int) for i in range(3))
    m = (a[..., 3] > 128) & (r > 160) & (g < 110) & (b < 110) & (r - g > 90)
    m[:, : a.shape[1] * 3 // 4] = False
    ys, xs = np.nonzero(m)
    if not len(ys):
        return None
    return (int(round(xs[ys >= ys.max() - 2].mean())), int(ys.max()))


def find_tie(im):
    """The bottom middle of the ring: the lowest brass blob in the right half, its lowest row's middle."""
    from scipy import ndimage
    a = np.asarray(im)
    m = brass(a)
    m[:, : a.shape[1] // 2] = False
    lab, k = ndimage.label(m)
    if not k:
        return None
    sizes = ndimage.sum(m, lab, range(1, k + 1))
    best = None
    for j in range(1, k + 1):
        if sizes[j - 1] < 150:
            continue
        ys, xs = np.nonzero(lab == j)
        h, w = ys.max() - ys.min(), xs.max() - xs.min()
        if w > 3 * max(h, 1):          # a long rod, not a ring
            continue
        if best is None or ys.max() > best[1]:
            low = xs[ys >= ys.max() - 2]
            best = (int(round(low.mean())), int(ys.max()))
    return best


def main():
    os.makedirs(OUT, exist_ok=True)
    meta, shots = {}, []
    for name, src in MASTERS.items():
        f = os.path.join(FINAL, src + ".png")
        if not os.path.exists(f):
            f = os.path.join(FINAL, FALLBACK.get(src, src) + ".png")
        im = Image.open(f).convert("RGBA")
        im.save(os.path.join(OUT, name + ".png"))
        pic = os.path.basename(f)[:-4]
        tie = TIE.get(pic) or (find_cord_end(im) if pic in CORD_END else find_tie(im))
        meta[name] = {"file": name + ".png", "from": os.path.basename(f)[:-4], "size": list(im.size), "tie": list(tie) if tie else None}
        shot = Image.new("RGBA", im.size, (246, 241, 228, 255))
        shot.alpha_composite(im)
        if tie:
            d = ImageDraw.Draw(shot)
            d.ellipse((tie[0] - 9, tie[1] - 9, tie[0] + 9, tie[1] + 9), outline=(0, 160, 255), width=4)
        shots.append((name, shot))
        print(f"{name:14} {meta[name]['from']:28} {im.size} tie {tie}")
    json.dump(meta, open(os.path.join(OUT, "masters.json"), "w"), indent=1)
    W = max(s.width for _, s in shots) + 20
    H = max(s.height for _, s in shots) + 40
    sheet = Image.new("RGB", (W * 3, H * 3), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, (n, s) in enumerate(shots):
        x, y = (i % 3) * W, (i // 3) * H
        sheet.paste(s, (x + 10, y + 10))
        d.text((x + 10, y + H - 26), n, fill=(0, 0, 0))
    sheet.save(os.path.join(OUT, "check.png"))


if __name__ == "__main__":
    main()
