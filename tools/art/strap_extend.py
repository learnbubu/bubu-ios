"""The three-quarter's near strap carried on under the arm to the backpack (the owner, lesson 12: "think where those lines may lead...
the SL strap needs to go to the backpack under the arm, so needs to make sense if he lifts his arm up"; then "you extend it under
the arm toward the backpack").

His strap is kept point for point where it shows. Only its squared-off bottom end, which is hidden under the arm at rest, is replaced:
the band turns there and runs on up and back, at its own width, to a round end inside the backpack's bottom. All of the new part is
under the arm at rest, so nothing he drew changes on screen. It's written as a new file, so his edit stays on disk.
The backpack is carried down behind the arm to meet it in puppet_quarter.py.

Save Studio first, then run this, then reload Studio without saving.
From tools/art: ../sfx/.venv/Scripts/python -I strap_extend.py
"""
import json
import math
import os
import sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402
import owner_transfer as T  # noqa: E402

DOC, LID = "puppet-views", "qStrapL"
ROOT = F.ROOT
path = f"{ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
L = next(l for l in doc["layers"] if l["id"] == LID)
fill, his = T.shapes_of(DOC, LID)[0]
P = his["raw"]
n = (len(P) - 1) // 3
# each anchor as (in handle, point, out handle), as he left them
A = [[P[(3 * i - 1) % (len(P) - 1)], P[3 * i], P[3 * i + 1]] for i in range(n)]
# his points round the strap: 0, 1, 2 the squared bottom end (0 and 1 under the arm, 2 the visible corner at the bottom), 3 and 4 up
# the right side, 5 the top, 6 and 7 down the left side
assert n == 8 and math.dist(A[0][1], (379, 799)) < 6, "the strap isn't the one lesson 12 recorded: look before running this"


def smooth(p, prev, nxt, k=1 / 3):
    """a point with handles along the line through its neighbours"""
    p, prev, nxt = np.array(p, float), np.array(prev, float), np.array(nxt, float)
    d = (nxt - prev) / np.linalg.norm(nxt - prev)
    return [p - d * np.linalg.norm(p - prev) * k, p, p + d * np.linalg.norm(nxt - p) * k]


# the new end: from the left side's lower point, the band's upper edge turns back at the corner, runs up and back to a round end
# inside the backpack's bottom, and its lower edge comes back to his visible bottom corner. Every new point is inside the arm at rest.
corner, top_, tip, low = (398, 776), (346, 748), (322, 774), (348, 802)
pts = [A[7][1], corner, top_, tip, low, A[2][1]]
new = [smooth(pts[k], pts[k - 1], pts[k + 1]) for k in range(1, 5)]
# (the round end: its handles across the band, a half circle's)
r = math.dist(top_, low) / 2
new[2] = [np.array(tip) + [0.3 * r, -0.55 * r * 1.1], np.array(tip, float), np.array(tip) + [0.3 * r, 0.55 * r * 1.1]]
A2 = [A[7], *new, *A[2:7]]   # (his 2..6 kept, then his 7 closes back round)
A2 = A2[1:] + A2[:1]
raw = [A2[0][1]]
for i in range(len(A2)):
    a, b = A2[i], A2[(i + 1) % len(A2)]
    raw += [a[2], b[0], b[1]]
raw = np.array(raw)
shape = {"raw": raw}

# check: every new point is under the arm at rest
arm = T.sample(T.shapes_of(DOC, "qArmL")[0][1])
import cv2  # noqa: E402
inside = lambda p: cv2.pointPolygonTest(arm.astype(np.float32), (float(p[0]), float(p[1])), False) > 0
assert all(inside(p) for p in (corner, top_, tip, low)), "a new point would show at rest"

# written as a new file in the layer's own box (grown to fit), so nothing he sees moves
pts_all = T.sample(shape)
x0, y0 = np.floor(pts_all.min(0)) - 2
x1, y1 = np.ceil(pts_all.max(0)) + 2
w, h = x1 - x0, y1 - y0
art = "StrapL-3-4--claude-to-pack.svg"
open(f"{ROOT}/art/{DOC}/{art}", "w").write(
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.0f} {h:.0f}">\n'
    f'<path d="{T.path_d(T.shifted(shape, x0, y0))}" fill="{fill}"/></svg>')
L.update({"art": art, "w": float(w), "h": float(h), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2)})
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"{LID}: his 8 points, the bottom end now runs on to the backpack ({len(A2)} points); written {art}")
