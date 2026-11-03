"""The five-pose jump morphed with Studio's bend keys (owner, 3 Nov 2026: "use the in between feature to morph stuff"). Each pose's
mesh bends into the next pose's shape while the next bends out of this one's and fades in, led by the same body points marked
on every pose. Uses the art and places from the "jump-five" document; writes the document "jump-morph" and its art only.
Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I jump_morph.py
"""
import json
import os
import shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy.interpolate import RBFInterpolator

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/jump-morph"
GROUND, MID, CELLS = 950, 512, 24
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
# the same body points on each pose, in tenths of its picture: ears, head top, sides, chin, nose, belly top, bottom, sides,
# shoulders, elbows, hands, hips, feet
MARKS = {
    "stand": [(1.8, 1), (7.8, 1), (5, .7), (1.3, 3.2), (8.9, 3.2), (5, 4.7), (5, 3), (5, 5.1), (5, 8.6), (2, 6.9), (8.2, 6.9), (2.2, 5), (7.8, 5), (.8, 6.5), (9.2, 6.5), (.7, 7.5), (9.3, 7.5), (2.7, 8.5), (7.3, 8.5), (3, 9.7), (7, 9.7)],
    "crouch": [(2.1, 1), (8, 1), (5, .9), (1.8, 3.2), (8.2, 3.2), (5, 5.7), (5, 3.9), (5, 6), (5, 9), (1.9, 7.2), (8, 7.2), (1.5, 5.2), (8.5, 5.2), (.4, 6.3), (9.6, 6.3), (1, 7.2), (9, 7.2), (1.5, 8.2), (8.5, 8.2), (1.5, 9.6), (8.5, 9.6)],
    "stretch": [(1.6, .8), (7.5, .8), (5, .5), (1.6, 2.4), (8.4, 2.4), (5, 4.1), (5, 2.6), (5, 4.5), (5, 8.4), (2, 6.5), (7.9, 6.5), (2.2, 4.5), (7.7, 4.5), (1.1, 3.8), (8.9, 3.8), (.6, 2.2), (9.4, 2.2), (2.5, 8.5), (7.5, 8.5), (3.4, 9.7), (6.5, 9.7)],
    "apex": [(1.8, 1), (8.3, 1), (5, .7), (1.7, 3), (8.3, 3), (5, 4.8), (5, 3.1), (5, 5.3), (5, 8.9), (2.3, 7), (7.6, 7), (2.2, 5.3), (7.8, 5.3), (1, 4.8), (9, 4.8), (.4, 3.6), (9.6, 3.6), (2, 8.2), (8, 8.2), (3.2, 9.6), (6.8, 9.6)],
    "squash": [(2.6, 1), (7.3, 1), (5, .7), (2.2, 3.2), (7.7, 3.2), (5, 5.1), (5, 3.4), (5, 6), (5, 8.9), (2.5, 7.5), (7.5, 7.5), (2.6, 5.6), (7.4, 5.6), (1, 5.3), (9, 5.3), (.3, 4.4), (9.7, 4.4), (1.8, 8.5), (8.2, 8.5), (1.6, 9.6), (8.4, 9.6)],
}
# the order, and each change from one pose to the next: its start and end
ORDER = ["stand", "crouch", "stretch", "apex", "stretch", "squash", "stand"]
CHANGES = [(120, 250), (400, 490), (520, 640), (780, 880), (900, 980), (1070, 1230)]
HEIGHT = [(400, 0, OUT), (520, -170, SOFT), (700, -225, SOFT), (880, -170, IN), (980, 0, HOLD)]
EASES = {0: (0.42, 0.58), 1: (0.2, 0.8), 2: (0.16, 0.5), 3: (0.6, 0.84), 4: (0.5, 0.9), 5: (0.3, 0.7)}

five = {l["art"][:-4]: l for l in json.load(open(f"{ROOT}/docs/jump-five.json", encoding="utf-8"))["layers"] if l["id"].startswith("L")}
place = {}
for name, l in five.items():
    y0 = GROUND - l["h"] * l["scale"] / 2
    place[name] = {"x": l["x"], "y": y0, "w": l["w"], "h": l["h"], "s": l["scale"]}


def picture_points(name):
    p = place[name]
    return np.array(MARKS[name], float) / 10 * [p["w"], p["h"]]


def doc_points(name):
    p = place[name]
    return (picture_points(name) - [p["w"] / 2, p["h"] / 2]) * p["s"] + [p["x"], p["y"]]


def grid(name):
    p = place[name]
    xs, ys = np.meshgrid(np.linspace(0, p["w"], CELLS + 1), np.linspace(0, p["h"], CELLS + 1))
    return np.dstack([xs, ys]).reshape(-1, 2)


def bend_to(a, b):
    """every grid point of pose a's picture, in its pixels, moved so its body points land on pose b's"""
    move = (doc_points(b) - doc_points(a)) / place[a]["s"]
    return RBFInterpolator(picture_points(a), move, kernel="thin_plate_spline", smoothing=2)(grid(a))


def eased(u, ease):
    x1, x2 = ease
    # a soft S between the change's start and end, sampled: bend keys only go straight between keys
    return u * u * (3 - 2 * u) * (1 - abs(x1 - x2) / 2) + u * abs(x1 - x2) / 2


def key(t, d):
    return {"t": round(t, 1), "d": [round(float(v), 1) for v in d.reshape(-1)]}


os.makedirs(ART, exist_ok=True)
for name in place:
    shutil.copy(f"{ROOT}/art/jump-five/{name}.png", f"{ART}/{name}.png")
zero = {name: np.zeros(((CELLS + 1) ** 2, 2)) for name in place}
layers = []
for i, name in enumerate(ORDER):
    p = place[name]
    keys = []
    if i > 0:
        start, end = CHANGES[i - 1]
        field = bend_to(name, ORDER[i - 1])
        for k in range(7):
            u = k / 6
            keys.append(key(start + (end - start) * u, field * (1 - eased(u, EASES[i - 1]))))
    if i < len(CHANGES):
        start, end = CHANGES[i]
        field = bend_to(name, ORDER[i + 1])
        for k in range(7):
            u = k / 6
            keys.append(key(start + (end - start) * u, field * eased(u, EASES[i])))
    else:
        # home: a little overshoot past standing, then he breathes
        tall = np.zeros_like(zero[name])
        tall[:, 1] = -(p["h"] - grid(name)[:, 1])
        for t, v in ((1230, 0), (1320, 0.025), (1420, 0), (1700, 0.012), (2000, 0)):
            keys.append(key(t, tall * v))
    if i == 0:
        opacity = [{"t": 0, "v": 1, "ease": HOLD}, {"t": CHANGES[0][1], "v": 0, "ease": HOLD}]
    else:
        start, end = CHANGES[i - 1]
        d = end - start
        opacity = [{"t": 0, "v": 0, "ease": HOLD}, {"t": start + d * 0.42, "v": 0, "ease": LINE}, {"t": start + d * 0.58, "v": 1, "ease": HOLD}]
        if i < len(CHANGES):
            opacity.append({"t": CHANGES[i][1], "v": 0, "ease": HOLD})
    layers.append({
        "id": f"L{i + 1}", "name": f"{i + 1} {name}", "art": f"{name}.png", "w": p["w"], "h": p["h"], "x": p["x"], "y": p["y"], "scale": p["s"],
        "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": p["x"], "y": p["y"]},
        "keys": {"opacity": opacity, "y": [{"t": t, "v": p["y"] + v, "ease": e} for t, v, e in HEIGHT]},
        "deform": {"cols": CELLS, "rows": CELLS, "keys": keys}, "loop": 0, "blink": 0,
    })
layers.reverse()
puff = Image.new("RGBA", (200, 200))
ImageDraw.Draw(puff).ellipse((6, 6, 194, 194), fill=(255, 250, 235, 170))
puff.save(f"{ART}/puff.png")
for j, (dx, dy, size) in enumerate(((-300, -30, 0.5), (300, -30, 0.5), (-210, -70, 0.34), (210, -70, 0.34), (-390, -55, 0.24), (390, -55, 0.24))):
    x0, y0, x1, y1 = MID + dx * 0.45, GROUND - 25, MID + dx, GROUND + dy
    layers.append({
        "id": f"P{j + 1}", "name": f"puff {j + 1}", "art": "puff.png", "w": 200, "h": 200, "x": x0, "y": y0, "scale": size,
        "rotation": 0, "flipX": False, "opacity": 0, "visible": True, "locked": False, "pivot": {"x": x0, "y": y0},
        "keys": {
            "x": [{"t": 980, "v": x0, "ease": OUT}, {"t": 1310, "v": x1, "ease": HOLD}],
            "y": [{"t": 980, "v": y0, "ease": OUT}, {"t": 1310, "v": y1, "ease": HOLD}],
            "scale": [{"t": 980, "v": size * 0.3, "ease": OUT}, {"t": 1110, "v": size, "ease": IN}, {"t": 1310, "v": 0, "ease": HOLD}],
            "opacity": [{"t": 0, "v": 0, "ease": HOLD}, {"t": 980, "v": 1, "ease": HOLD}, {"t": 1310, "v": 0, "ease": HOLD}],
        },
        "loop": 0, "blink": 0,
    })
doc = {"id": "jump-morph", "name": "Jump Morph", "width": 1024, "height": 1024, "duration": 2000, "loop": True, "layers": layers, "bones": []}
json.dump(doc, open(f"{ROOT}/docs/jump-morph.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "jump-morph" not in project["docs"]:
    project["docs"].append("jump-morph")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
