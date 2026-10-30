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
    "roof-eave": "mount-roof-eave-flat",        # redrawn in the branches' style (group "mounts2"; the painted one, mount-roof-eave-tie, felt too soft)
    "bamboo-pole": "mount-bamboo-pole-ring",    # its red loop swapped for a brass ring (group "rings")
    "iron-scroll": "mount-iron-scroll-take2",
    "cloud-bracket": "mount-cloud-bracket-flat",   # redrawn in the branches' style (group "mounts2")
    "dragon-head": "mount-dragon-head-flat",       # redrawn in the branches' style (group "mounts2")
    "jade-bracket": "mount-jade-bracket-take2",
    "brass-rod": "mount-brass-rod",
    "stone-corbel": "mount-stone-corbel",
}
# until the ring swaps are made, the pictures they're made from
FALLBACK = {"mount-roof-eave-tie": "mount-roof-eave-ring", "mount-bamboo-pole-ring": "mount-bamboo-pole"}
TIE = {"mount-roof-eave-ring": (403, 240)}   # picture -> (x, y) by hand, where the found one is wrong (the eave's orange woodwork reads as brass)
CORD_END = {"mount-roof-eave-tie", "mount-roof-eave-flat"}           # tied with a cord, not a ring: the tie point is the cord's end


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


def cut_at_knot(im, end):
    """A tied cord's drawn tail, from the knot down to its end, rubbed out: hang.py's rope starts at the knot instead,
    so there's no join on the open cord (the owner: "can see the connection point here, lets cut it higher at the
    knot"). Returns the picture and the new tie point, the knot's bottom middle."""
    a = np.asarray(im).copy()
    r, g, b = (a[..., i].astype(int) for i in range(3))
    m = (a[..., 3] > 0) & (r > 120) & (r - g > 60)
    x, y = end
    cw = m[y - 20, x - 20:x + 20].sum()                       # the tail's width, well above its rounded end
    k = y
    while k > 0 and m[k, x - 20:x + 20].sum() <= cw + 3:     # up the tail until the knot widens it
        k -= 1
    k += 2                                                    # just inside the knot's bottom edge
    a[k:y + 3, x - 20:x + 20][m[k:y + 3, x - 20:x + 20]] = 0
    return Image.fromarray(a), (x, k)


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
        pic = os.path.basename(f)[:-4]
        tie = TIE.get(pic) or (find_cord_end(im) if pic in CORD_END else find_tie(im))
        drop = 0                                  # how much higher the tie point sits than the drawn cord's end
        if tie and pic in CORD_END:
            im, knot = cut_at_knot(im, tie)
            drop, tie = tie[1] - knot[1], knot
        im.save(os.path.join(OUT, name + ".png"))
        # how thick the ring's bottom is at the tie point: the rope wraps over just that band, not up through the hole
        band = 0
        if tie and pic not in CORD_END:
            a = np.asarray(im)[:, tie[0], 3] > 128
            while tie[1] - band >= 0 and a[tie[1] - band]:
                band += 1
        meta[name] = {"file": name + ".png", "from": os.path.basename(f)[:-4], "size": list(im.size), "tie": list(tie) if tie else None,
                      "band": band, "drop": drop}
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
