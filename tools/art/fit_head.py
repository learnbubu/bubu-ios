"""Locks a cast drawing's head size (the owner, 23 Oct 2026: "head is a bit small. really need to lock in sizes"): the
head (hair, face, ears) measured as a share of the figure's whole height, and scaled about the chin until it's the
target, Xiaoyu's 48% (the approved model; the studio avatar's is 50%). Codex draws the figure, this fixes the one size
it keeps drifting on, as add_sparkle fixes the eyes.

The head is found as one piece: from the face, through skin, cheeks, eyes, mouth, nose and hair, stopping at the
backdrop and anything else (clothes, what they hold). The chin is where that piece narrows into the neck.

    python fit_head.py <png> [target, default 0.48]
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

MAGENTA = (255, 0, 255)


def backdrop(a):
    return (a[..., 0] > 200) & (a[..., 2] > 200) & (a[..., 1] < 80)


def head_mask(a):
    """The head: one connected piece of face colours and hair, flooded from the middle of the face."""
    h, w = a.shape[:2]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    skin = (r > 225) & (g > 160) & (g < 215) & (b > 120) & (b < 190) & (r - b > 40)
    cheek = (r > 225) & (g > 140) & (g < 200) & (b > 110) & (b < 180) & (r - g > 45)
    dark = (r < 120) & (g < 110) & (b < 110)                          # hair, eyes, brows
    mouth = (r > 180) & (g < 140) & (b < 140) & (r - g > 70)
    m = (skin | cheek | dark | mouth) & ~backdrop(a)
    # start on the face: the first skin pixel down the middle, in the top half
    cx = w // 2
    sy = next(y for y in range(int(h * 0.15), int(h * 0.6)) if skin[y, cx])
    seen = np.zeros_like(m)
    q = deque([(sy, cx)])
    seen[sy, cx] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                q.append((ny, nx))
    return seen


def measure(a):
    """(figure top, figure bottom, chin row, head mask)."""
    fig = ~backdrop(a)
    rows = np.nonzero(fig.any(1))[0]
    top, bottom = rows.min(), rows.max()
    head = head_mask(a)
    span = np.array([(np.ptp(np.nonzero(head[y])[0]) if head[y].any() else 0) for y in range(a.shape[0])])
    peak = int(np.argmax(span))
    chin = next(y for y in range(peak, a.shape[0]) if span[y] < span[peak] * 0.45)
    head[chin:] = False
    return top, bottom, chin, head


def scale_head(img, s):
    """The head scaled by s about its chin, over the rest (the old head is inside the new one)."""
    a = np.array(img).astype(int)
    top, bottom, chin, head = measure(a)
    xs = np.nonzero(head.any(0))[0]
    cx = (xs.min() + xs.max()) / 2
    piece = Image.fromarray(np.dstack([a.astype("uint8"), (head * 255).astype("uint8")]), "RGBA").crop((0, 0, img.width, chin))
    big = piece.resize((round(piece.width * s), round(piece.height * s)), Image.LANCZOS)
    out = img.convert("RGBA")
    out.alpha_composite(big, (round(cx - cx * s), round(chin - chin * s)))
    return out.convert("RGB")


def share(img):
    top, bottom, chin, _ = measure(np.array(img).astype(int))
    return (chin - top) / (bottom - top), top, bottom, chin


def fit(path, target=0.48):
    im = Image.open(path).convert("RGB")
    first, top, bottom, chin = share(im)
    print(f"{path}: head {first:.0%} of the height", end="")
    # worked on with plenty of room above (the head grows up), a few small steps, each measured again, until on target
    pad = im.height // 3
    work = Image.new("RGB", (im.width, im.height + pad), MAGENTA)
    work.paste(im, (0, pad))
    # one exact scaling from the first measurement (measuring again after pasting a bigger head over the old one is
    # unreliable: stepping on that way stacked copies of the head)
    _, top, bottom, chin = share(work)
    hh, H = chin - top, bottom - top
    scale = target * (H - hh) / (hh * (1 - target))
    if abs(scale - 1) < 0.01:
        print(", already on target"); return
    work = scale_head(work, scale)
    a = np.array(work).astype(int)
    bottom = int(np.nonzero((~backdrop(a)).any(1))[0].max())
    # back into the job's canvas: the figure at its old height from the foot, shrunk to fit if it now reaches the top
    a = np.array(work).astype(int)
    rows = np.nonzero((~backdrop(a)).any(1))[0]
    cols = np.nonzero((~backdrop(a)).any(0))[0]
    fig = work.crop((cols.min(), rows.min(), cols.max() + 1, rows.max() + 1))
    margin = 30
    k = min(1.0, (bottom - pad - margin) / fig.height, (im.width - 2 * margin) / fig.width)
    if k < 1:
        fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
    out = Image.new("RGB", im.size, MAGENTA)
    foot = bottom - pad                       # the feet stay where they were
    out.paste(fig, (round(cols.min() + (cols.max() + 1 - cols.min() - fig.width) / 2), foot + 1 - fig.height))
    out.save(path)
    print(f", scaled {scale:.3f} to {target:.0%}{' (the figure shrunk a little to fit the canvas)' if k < 1 else ''}")


if __name__ == "__main__":
    fit(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 0.48)
