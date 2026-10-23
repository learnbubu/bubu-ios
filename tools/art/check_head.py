"""Checks a cast drawing's head size (the owner, 23 Oct 2026: "really need to lock in sizes", "say about the face
without the hair", and "I want codex to fix this not you"): the face without its hair, ear to ear, measured against the
body below it (chin to feet), next to the studio avatar's 1.08. Hair (a bun, spikes) doesn't count. It only measures:
if a drawing is off, Codex draws it again (over the bald avatar, refs/ref-cast-base.png).

The face is found as one piece: from its middle, through skin, cheeks, eyes, mouth, nose and hair, stopping at the
backdrop and anything else; the chin is where the skin, ear to ear at its widest, narrows into the neck.

    python check_head.py <png> [target face/body, default the avatar's 1.08]
"""
import sys
from collections import deque

import numpy as np
from PIL import Image

MAGENTA = (255, 0, 255)
# the studio avatar's face, ear to ear, over its body from chin to feet (measured on refs/ref-player-avatar.png)
AVATAR = 1.08


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
    gold = (r > 190) & (g > 130) & (g < 200) & (b < 110) & (r - b > 110)  # earrings (they go with the head)
    m = (skin | cheek | dark | mouth | gold) & ~backdrop(a)
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
    # the chin from the skin alone (long hair hangs past it): where the face, ear to ear at its widest, narrows into
    # the neck
    fs = face_skin(a) & head
    span = np.array([(np.ptp(np.nonzero(fs[y])[0]) if fs[y].any() else 0) for y in range(a.shape[0])])
    peak = int(np.argmax(span))
    chin = next(y for y in range(peak, a.shape[0]) if span[y] < span[peak] * 0.45)
    head[chin:] = False
    return top, bottom, chin, head


def face_skin(a):
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (r > 225) & (g > 140) & (g < 215) & (b > 110) & (b < 190) & (r - b > 40)


def face_size(a):
    """The face without the hair: its width ear to ear, as a share of the body below it (chin to feet). The same for
    every character whatever their hair (the owner: "say about the face without the hair to keep the same")."""
    top, bottom, chin, head = measure(a)
    fs = face_skin(a) & head
    width = max(np.ptp(np.nonzero(fs[y])[0]) for y in np.nonzero(fs.any(1))[0])
    return width / (bottom - chin)


def check(path, target=AVATAR, within=0.05):
    """Is this drawing's face the avatar's size for its body? Prints the size and passes within 5%."""
    size = face_size(np.array(Image.open(path).convert("RGB")).astype(int))
    ok = abs(size / target - 1) <= within
    print(f"{path}: face {size:.2f} of the body (the avatar's {target:.2f}): "
          + ("OK" if ok else f"{'too big' if size > target else 'too small'} by {abs(size / target - 1):.0%}: draw it again"))
    return ok


if __name__ == "__main__":
    sys.exit(0 if check(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else AVATAR) else 1)
