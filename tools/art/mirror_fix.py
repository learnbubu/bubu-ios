"""The owner fixed one of a pair (an eye, a brow...): his fix mirrored about the face's middle onto the other, nudged a pixel or two
onto that side's drawing, never refitted (lesson 6: he shapes parts to look right, so a refit would undo him). It writes the other
layer's new SVG and points that layer at it. Save Studio first, then reload it without saving afterwards.

From tools/art: ../sfx/.venv/Scripts/python -I mirror_fix.py <fixed layer> <other layer> [doc]
"""
import json
import os
import re
import sys
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402

src, dst = sys.argv[1], sys.argv[2]
DOC = sys.argv[3] if len(sys.argv) > 3 else "bubu-puppet-front"
MID = 626.5                      # the drawing's middle: the eyes, brows, cheeks and patches pair about it
A = f"{F.ROOT}/art/{DOC}/"
path = f"{F.ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
L = {l["id"]: l for l in doc["layers"]}


def shapes_in_doc(l):
    """each shape of a layer's SVG as (fill, its path's numbers as points in the composition)"""
    t = open(A + l["art"]).read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', t).group(1).split()]
    k = l["w"] / vb[2]
    x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    out = []
    for el in re.findall(r"<path\b[^>]*/>", t):
        d = re.search(r' d="([^"]+)"', el).group(1)
        if re.search(r"[LlHhVvSsQqTtAa]", d):
            sys.exit(f"{l['art']} has more than plain curves: mirror it by hand")
        tr = re.search(r"translate\(([-\d.]+),([-\d.]+)\)", el)
        tx, ty = (float(tr.group(1)), float(tr.group(2))) if tr else (0, 0)
        pts = np.array([float(v) for v in re.findall(r"-?[\d.]+(?:e-?\d+)?", d)]).reshape(-1, 2) + [tx, ty]
        out.append((re.search(r'fill="([^"]+)"', el).group(1), np.c_[x0 + (pts[:, 0] - vb[0]) * k, y0 + (pts[:, 1] - vb[1]) * k]))
    return out


def raster(shapes):
    z = np.zeros((F.S, F.S), np.uint8)
    for _, pts in shapes:
        out, cur = [pts[0]], pts[0]
        for i in range(1, len(pts) - 2, 3):
            c1, c2, e = pts[i], pts[i + 1], pts[i + 2]
            for t in np.linspace(0, 1, 20)[1:]:
                u = 1 - t
                out.append(u ** 3 * cur + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t ** 3 * e)
            cur = e
        cv2.fillPoly(z, [np.round(np.array(out)).astype(np.int32)], 1)
    return z


def drawn_under(l):
    """the drawing's piece of the colour under a layer's middle: what that layer stands for"""
    shapes = shapes_in_doc(l)
    hex_ = shapes[0][0].lstrip("#")
    rgb = np.array([int(hex_[i:i + 2], 16) for i in (0, 2, 4)])
    name = F.NAMES[int(np.argmin(((np.array(list(F.PALETTE.values())) - rgb) ** 2).sum(1)))]
    m = F.colour(name)
    n, cc = cv2.connectedComponents(m)
    mask = raster(shapes)
    ys, xs = np.nonzero(cc * mask)
    labels, counts = np.unique(cc[ys, xs], return_counts=True)
    return (cc == labels[np.argmax(counts)]).astype(np.uint8)


iou = lambda a, b: float((a & b).sum() / max(1, (a | b).sum()))
fixed = shapes_in_doc(L[src])
mirrored = [(f, np.c_[2 * MID - p[:, 0], p[:, 1]]) for f, p in fixed]
target = drawn_under(L[dst])
his = iou(raster(fixed), drawn_under(L[src]))
best = max(((iou(raster([(f, p + [dx, dy]) for f, p in mirrored]), target), dx, dy)
            for dx in np.arange(-6, 6.5, 0.5) for dy in np.arange(-6, 6.5, 0.5)))
print(f"his {src} on its drawing: overlap {his:.3f}; mirrored onto {dst}: {best[0]:.3f} after a nudge of ({best[1]}, {best[2]})")
moved = [(f, p + [best[1], best[2]]) for f, p in mirrored]
allp = np.concatenate([p for _, p in moved])
x0, y0 = np.floor(allp.min(0)) - 3
x1, y1 = np.ceil(allp.max(0)) + 3
w, h = x1 - x0, y1 - y0


def d_of(p):
    q = p - [x0, y0]
    return f"M{q[0, 0]:.2f} {q[0, 1]:.2f} " + " ".join(
        f"C{q[i, 0]:.2f} {q[i, 1]:.2f} {q[i + 1, 0]:.2f} {q[i + 1, 1]:.2f} {q[i + 2, 0]:.2f} {q[i + 2, 1]:.2f}" for i in range(1, len(q) - 2, 3)) + " Z"


name = f"{dst}-mirror.svg"
paths = "\n".join(f'<path d="{d_of(p)}" fill="{f}"/>' for f, p in moved)
open(A + name, "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.0f} {h:.0f}">\n{paths}</svg>')
L[dst].update({"art": name, "w": float(w), "h": float(h), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2)})
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False)
print(f"{dst} now draws {name}: reload Studio (without saving) to see it")
