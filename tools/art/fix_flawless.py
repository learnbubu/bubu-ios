"""Flawless's panda was drawn smaller than the other badges': the jade disc above his paw took the top of the picture,
so fitting it to 560 tall shrank him (the owner: "Flawless is smaller than the others"). This lifts the disc off, scales
him up until he alone fills the 560, and sets the disc back behind his raised paw, lower, so it stays inside the picture.

    python fix_flawless.py   (keeps the picture as it was in out/final/achv4-flawless-small.png, and works from that)
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "out", "final", "achv4-flawless-small.png")
DST = os.path.join(HERE, "..", "..", "native", "Bubu", "Resources", "Achievements", "achv-flawless.png")
DISC_SIZE = 135      # across, in the finished picture
TUCK = 0.72          # how much of the disc's height sits above the top of his paw
HIM = 528            # his height in the 560 (the disc takes what's left, clear of his ear)


def main():
    if not os.path.exists(SRC):
        Image.open(DST).convert("RGBA").save(SRC)
    im = Image.open(SRC).convert("RGBA")
    a = np.asarray(im).astype(int)
    r, g, b, al = (a[..., i] for i in range(4))
    # the disc: its greens, joined up, the largest piece (the shadow side and rim are green too)
    green = (al > 0) & (g > r + 8) & (g > 110)
    lab, k = ndimage.label(ndimage.binary_closing(green, iterations=2))
    disc = lab == (1 + int(np.argmax(ndimage.sum(green, lab, range(1, k + 1)))))
    disc = ndimage.binary_fill_holes(disc)
    ys, xs = np.nonzero(disc)
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    dark = (r + g + b) < 200
    lift = disc & ~dark
    # the disc alone (its hole keeps whatever the picture has there), and him alone
    keep = np.asarray(im).copy(); keep[..., 3] = np.where(lift, keep[..., 3], 0)
    disc_pic = Image.fromarray(keep.astype("uint8")).crop(box)
    him = np.asarray(im).copy(); him[..., 3] = np.where(ndimage.binary_dilation(lift, iterations=2) & ~dark, 0, him[..., 3])
    him = Image.fromarray(him.astype("uint8"))
    lab, k = ndimage.label(np.asarray(him)[..., 3] > 30)
    main_piece = lab == (1 + int(np.argmax(ndimage.sum(np.ones_like(lab), lab, range(1, k + 1)))))
    arr = np.asarray(him).copy(); arr[..., 3] = np.where(main_piece, arr[..., 3], 0); him = Image.fromarray(arr)
    hb = him.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()
    him = him.crop(hb)
    s = HIM / him.height
    him = him.resize((round(him.width * s), HIM), Image.LANCZOS)
    # the paw: the highest dark pixels at his right edge (further in, it's his ear)
    m = np.asarray(him); dk = (m[..., 3] > 128) & (m[..., :3].sum(2) < 200)
    half = him.width * 4 // 5
    py = int(np.nonzero(dk[:, half:].sum(1))[0].min())
    row = np.nonzero(dk[py + 12, half:])[0] + half
    px = int(row.mean())
    d = DISC_SIZE
    disc_pic = disc_pic.resize((d, round(disc_pic.height * d / disc_pic.width)), Image.LANCZOS)
    dx, dy = px - d // 2 + 10, py + 560 - HIM - round(disc_pic.height * TUCK)
    dy = max(0, dy)
    # the canvas, his belly in the middle, so he stands on the coin's centre
    belly = int(np.nonzero((m[..., 3] > 128)[HIM * 11 // 14])[0].mean())
    half_w = max(belly, him.width - belly, dx + d - belly) + 2
    out = Image.new("RGBA", (2 * half_w, 560), (0, 0, 0, 0))
    ox = half_w - belly
    out.alpha_composite(disc_pic, (ox + dx, dy))
    out.alpha_composite(him, (ox, 560 - HIM))
    out.save(DST)
    print("him", hb, "scale", round(s, 3), "disc", box, "->", (ox + dx, dy), "size", out.size)


if __name__ == "__main__":
    main()
