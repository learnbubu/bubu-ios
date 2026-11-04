"""Elbows (the owner, 4 Nov 2026, on the first motion test: the wave's arm "looks broken", it should come out from the shoulder and
curve up, as his sketch). Each arm is split into an upper arm and a forearm with the paw, joined at a round elbow: each piece's end at
the elbow a round cap the arm's width, centred on the joint, so the bend reads as one arm (lessons 2-4: round ends, the hidden part
under the other piece, few points). The pieces are cut from the owner's own arm (his fix, lesson 11, and its mirror), so his shape is
kept. Also the ears hinge where they meet the head's outline, not deep inside it (the ear "looks a bit detached").
Works on the test copy, "puppet-test", until the owner OKs it for his master.

From tools/art: ../sfx/.venv/Scripts/python -I puppet_elbow.py   (save Studio first; then run puppet_test_keys or reload)
"""
import json
import math
import os
import re
import sys
import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402

S = F.S
DOC = next((a for a in sys.argv[1:] if not a.startswith("--")), "puppet-test")
EARS_ONLY = "--ears" in sys.argv     # (the hinged elbow lost to bones, 4 Nov 2026: the ears' hinge is kept)
A = f"{F.ROOT}/art/{DOC}/"
path = f"{F.ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
L = {l["id"]: l for l in doc["layers"]}
ELBOW = 0.5          # how far down the arm, shoulder to paw end


def shapes_in_doc(l):
    """each shape of a layer's SVG as (fill, its path's numbers as points in the composition)"""
    t = open(A + l["art"]).read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', t).group(1).split()]
    k = l["w"] / vb[2]
    x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    out = []
    for el in re.findall(r"<path\b[^>]*/>", t):
        d = re.search(r' d="([^"]+)"', el).group(1)
        tr = re.search(r"translate\(([-\d.]+),([-\d.]+)\)", el)
        tx, ty = (float(tr.group(1)), float(tr.group(2))) if tr else (0, 0)
        pts = np.array([float(v) for v in re.findall(r"-?[\d.]+(?:e-?\d+)?", d)]).reshape(-1, 2) + [tx, ty]
        out.append((re.search(r'fill="([^"]+)"', el).group(1), np.c_[x0 + (pts[:, 0] - vb[0]) * k, y0 + (pts[:, 1] - vb[1]) * k]))
    return out


def raster(pts):
    out, cur = [pts[0]], pts[0]
    for i in range(1, len(pts) - 2, 3):
        c1, c2, e = pts[i], pts[i + 1], pts[i + 2]
        for t in np.linspace(0, 1, 24)[1:]:
            u = 1 - t
            out.append(u ** 3 * cur + 3 * u * u * t * c1 + 3 * u * t * t * c2 + t ** 3 * e)
        cur = e
    z = np.zeros((S, S), np.uint8)
    cv2.fillPoly(z, [np.round(np.array(out)).astype(np.int32)], 1)
    return z


def capsule(c, u, n, a, b, r):
    """6 points round a rounded bar along u from a to b (its centre line c + u t), half as wide as r: a round tip at each end"""
    at = lambda t, s: c + u * t + n * s
    ang = lambda d: math.atan2(d[1], d[0])
    side, q = (b - a) / 3, 0.552 * r
    pts = [(at(a, r), ang(u), q, side), (at(b, r), ang(u), side, q), (at(b + r, 0), ang(-n), q, q),
           (at(b, -r), ang(-u), q, side), (at(a, -r), ang(-u), side, q), (at(a - r, 0), ang(n), q, q)]
    return [[p[0], p[1], a_, li, lo] for p, a_, li, lo in pts]


def write(name, shapes):
    """shapes [(fill, anchors)] as a tight SVG: its box, for the layer"""
    allp = np.concatenate([F.sample(a) for _, a in shapes])
    x0, y0 = np.floor(allp.min(0)) - 3
    x1, y1 = np.ceil(allp.max(0)) + 3
    moved = lambda an: [[a[0] - x0, a[1] - y0, a[2], a[3], a[4]] for a in an]
    paths = "\n".join(f'<path d="{F.path_d(moved(a))}" fill="{f}"/>' for f, a in shapes)
    open(A + f"{name}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1 - x0:.0f}" height="{y1 - y0:.0f}" viewBox="0 0 {x1 - x0:.0f} {y1 - y0:.0f}">\n{paths}</svg>')
    return {"art": f"{name}.svg", "w": float(x1 - x0), "h": float(y1 - y0), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2)}


def raw_svg(name, shapes):
    """shapes [(fill, path points)] written as they are (the owner's toe lines, kept exactly)"""
    allp = np.concatenate([p for _, p in shapes])
    x0, y0 = np.floor(allp.min(0)) - 3
    x1, y1 = np.ceil(allp.max(0)) + 3
    return x0, y0, x1, y1


for side in ("" if EARS_ONLY else "LR"):
    arm = L["arm" + side]
    if arm.get("elbow"):
        print("arm" + side, "already has an elbow")
        continue
    shapes = shapes_in_doc(arm)
    body_fill, body = shapes[0]
    toes = shapes[1:]
    mask = raster(body)
    ys, xs = np.nonzero(mask)
    P = np.array([arm["pivot"]["x"], arm["pivot"]["y"]])
    d = np.hypot(xs - P[0], ys - P[1])
    E = np.array([xs[d.argmax()], ys[d.argmax()]], float)          # the paw's end: furthest from the shoulder
    u = (E - P) / np.linalg.norm(E - P)
    n = np.array([-u[1], u[0]])
    t = (np.c_[xs, ys] - P) @ u
    o = (np.c_[xs, ys] - P) @ n
    Lt = t.max()
    te = Lt * ELBOW
    band = np.abs(t - te) < 4
    lo_, hi_ = o[band].min(), o[band].max()
    r = (hi_ - lo_) / 2
    C = P + u * te + n * (lo_ + hi_) / 2                             # the elbow: the middle of the arm there
    tt = (np.indices((S, S))[::-1].transpose(1, 2, 0) - P) @ u
    disc = np.zeros((S, S), np.uint8)
    cv2.circle(disc, tuple(int(v) for v in C.round()), int(round(r)), 1, -1)
    upper = ((mask & (tt <= te).astype(np.uint8)) | disc)
    fore = ((mask & (tt >= te).astype(np.uint8)) | disc)
    # (each piece's points set out along the arm, then nudged onto its own outline: every edge is its own, even the elbow's cap)
    ts_u = t[(t <= te)]
    up_init = capsule(P + n * (lo_ + hi_) / 2, u, n, ts_u.min() + r, te, r)
    fo_init = capsule(P + n * (lo_ + hi_) / 2, u, n, te, Lt - r, r)
    up, eu = F.fit(up_init, list(range(6)), upper, np.ones((S, S), np.uint8), (1 - upper).astype(np.uint8))
    fo, ef = F.fit(fo_init, list(range(6)), fore, np.ones((S, S), np.uint8), (1 - fore).astype(np.uint8))
    print(f"arm{side}: elbow at ({C[0]:.0f}, {C[1]:.0f}), {2 * r:.0f} wide; upper arm off its outline by {eu:.2f} px, forearm by {ef:.2f} px")
    # the toe lines go with the forearm, as the owner drew them (written straight from his points)
    tx0, ty0, tx1, ty1 = raw_svg(None, [(f, p) for f, p in toes])
    up_place = write(f"arm{side}-upper", [(body_fill, up)])
    allp = np.concatenate([F.sample(fo)] + [p for _, p in toes])
    x0, y0 = np.floor(allp.min(0)) - 3
    x1, y1 = np.ceil(allp.max(0)) + 3
    mv = lambda an: [[a[0] - x0, a[1] - y0, a[2], a[3], a[4]] for a in an]
    tpaths = []
    for f, p in toes:
        q = p - [x0, y0]
        tpaths.append(f'<path d="M{q[0, 0]:.2f} {q[0, 1]:.2f} ' + " ".join(
            f"C{q[i, 0]:.2f} {q[i, 1]:.2f} {q[i + 1, 0]:.2f} {q[i + 1, 1]:.2f} {q[i + 2, 0]:.2f} {q[i + 2, 1]:.2f}" for i in range(1, len(q) - 2, 3)) + f' Z" fill="{f}"/>')
    open(A + f"forearm{side}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1 - x0:.0f}" height="{y1 - y0:.0f}" viewBox="0 0 {x1 - x0:.0f} {y1 - y0:.0f}">\n'
                                              f'<path d="{F.path_d(mv(fo))}" fill="{body_fill}"/>\n' + "\n".join(tpaths) + "</svg>")
    arm.update(up_place)
    arm["elbow"] = True
    fore_layer = json.loads(json.dumps(arm))
    fore_layer.update({"id": "forearm" + side, "name": "forearm" + side, "art": f"forearm{side}.svg", "w": float(x1 - x0), "h": float(y1 - y0),
                       "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2), "pivot": {"x": round(float(C[0]), 1), "y": round(float(C[1]), 1)},
                       "parent": "arm" + side, "keys": {}})
    fore_layer.pop("elbow", None)
    # (just in front of its upper arm: a forearm raised comes in front of the elbow)
    doc["layers"].insert(doc["layers"].index(arm), fore_layer)


# the ears hinge on the head's outline: the middle of where each ear crosses it
head = shapes_in_doc(L["head"])[0][1]
hm = raster(head)
hedge = np.argwhere(cv2.Canny(hm * 255, 50, 150) > 0)[:, ::-1].astype(float)
for side in "LR":
    ear = L["ear" + side]
    em = raster(shapes_in_doc(ear)[0][1])
    ee = cv2.dilate(cv2.Canny(em * 255, 50, 150), np.ones((5, 5), np.uint8))
    cross = np.argwhere((ee > 0) & (cv2.dilate(cv2.Canny(hm * 255, 50, 150), np.ones((5, 5), np.uint8)) > 0))[:, ::-1].astype(float)
    # (two crossings: split by which side of the ear's middle they lie, and take the middle of each)
    ec = np.argwhere(em)[:, ::-1].mean(0)
    hc = np.argwhere(hm)[:, ::-1].mean(0)
    dirn = (hc - ec) / np.linalg.norm(hc - ec)
    perp = np.array([-dirn[1], dirn[0]])
    side_ = (cross - ec) @ perp
    a, b = cross[side_ < 0].mean(0), cross[side_ >= 0].mean(0)
    mid = (a + b) / 2
    pv = hedge[np.argmin(((hedge - mid) ** 2).sum(1))]
    print(f"ear{side}: hinge moved from ({ear['pivot']['x']}, {ear['pivot']['y']}) to the head's edge at ({pv[0]:.0f}, {pv[1]:.0f})")
    ear["pivot"] = {"x": round(float(pv[0]), 1), "y": round(float(pv[1]), 1)}

json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False)
print("written", DOC)
