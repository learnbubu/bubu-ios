"""A strap that goes over the shoulder but under the arm lower down (the owner, 4 Nov 2026: "the top of the arm should be under the
strap, but the bottom should be over?"). One layer can't be both, so, as in After Effects or Toon Boom: a copy of his strap above the
arm, masked to leave out the paw. His strap stays as it is, under the arm, so the paw stays in front of it at the bottom.

As the drawing has it (the owner: "look at the ref"): the strap lies over the upper arm all the way down, its own left edge showing
over the arm, and only the paw comes over it at the bottom. So the copy is the whole strap except where the arm is below PAW.
The mask is in the strap's own pixels, so it moves with the chest, and the copy follows his strap's art: it's the same file.

Save Studio first, then run this, then reload Studio without saving.
From tools/art: ../sfx/.venv/Scripts/python -I strap_over.py [strap layer, default qStrapL] [arm layer, default qArmL] [paw top y, default 770] [stop at this height]
"""
import json
import os
import sys
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402
import owner_transfer as T  # noqa: E402

DOC = "puppet-views"
STRAP = sys.argv[1] if len(sys.argv) > 1 else "qStrapL"
ARM = sys.argv[2] if len(sys.argv) > 2 else "qArmL"
HEAD = "qHead"
PAW = int(sys.argv[3]) if len(sys.argv) > 3 else 770   # (the paw, below this, is in front of the strap)
# (and where only the shoulder's top goes under the strap, as in profile, where the arm hangs in front of the strap's run down his side:
# the copy stops at this height)
TOP = int(sys.argv[4]) if len(sys.argv) > 4 else None
S = F.S
path = f"{F.ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
L = {l["id"]: l for l in doc["layers"]}
fill = lambda lid: (lambda m: [cv2.fillPoly(m, [T.sample(a).round().astype(np.int32)], 1) for _, a in T.shapes_of(DOC, lid)[:1]] and m)(np.zeros((S, S), np.uint8))
strap, arm, head = fill(STRAP), fill(ARM), fill(HEAD)
# where the copy shows: all the strap but where the paw is
paw = arm.copy()
paw[:PAW] = 0
keep = (1 - paw).astype(np.uint8)
if TOP is not None:
    keep[TOP:] = 0
region = cv2.dilate(strap, np.ones((9, 9), np.uint8)) & keep
region = cv2.morphologyEx(region, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
cs, _ = cv2.findContours(region, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
cs = [c for c in cs if cv2.contourArea(c) > 200]
s = L[STRAP]
x0, y0 = s["x"] - s["w"] / 2, s["y"] - s["h"] / 2
masks = []
for c in cs:
    c = cv2.approxPolyDP(c, 1.5, True)[:, 0, :]
    # (a mask's handles are positions in the layer, not offsets: straight lines have them on the point)
    masks.append({"pts": [(lambda x, y: {"x": x, "y": y, "ix": x, "iy": y, "ox": x, "oy": y})(float(p[0] - x0), float(p[1] - y0)) for p in c],
                  "feather": 0, "mode": "show", "on": True})
copy = json.loads(json.dumps(s))
copy.update({"id": STRAP + "Over", "name": s["name"].replace(" (3/4)", " over the shoulder (3/4)").replace(" (side)", " over the shoulder (side)"), "keys": {}})
copy.pop("puppet", None)
copy["mask"], copy["masks"] = masks[0], masks[1:]
doc["layers"] = [l for l in doc["layers"] if l["id"] != copy["id"]]
i = next(k for k, l in enumerate(doc["layers"]) if l["id"] == ARM)
doc["layers"].insert(i, copy)        # (top first: just above the arm)
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"{copy['id']}: his strap's art ({s['art']}) above {ARM}, {len(masks)} mask path(s), {sum(len(m['pts']) for m in masks)} points")
