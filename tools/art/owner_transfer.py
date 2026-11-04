"""The owner's own front parts carried onto another view's drawing (the owner, 4 Nov 2026, on the three-quarter: "we need to make sure
we're following what we learnt from those recordings and apply it to these turns"). Rather than cutting a view's part afresh by rule,
it starts from his finished part, so it keeps what every lesson taught: his point count (11 for the head, 18 for the mouth, 12 for a
leg), where his points sit, his handles, his fuller stroke ends, his round hidden caps.

- His part is read exactly as he left it, every handle as drawn (his tuft's corners are broken handles, so nothing is smoothed).
- It's carried over whole by an affine map (moved, turned, sized and slanted, which keeps a Bézier exactly), first onto where the rough
  cut of the view's part lies, then onto the view's drawing wherever its edge can be seen.
- Then, only for parts the turn changes beyond a slant, each point he placed on the seen edge moves a little (with its handles, which
  keep his angles and lengths) to sit on the drawing; neighbours move together, so nothing goes lumpy. Hidden points stay where his
  shape puts them. Eyes and brows skip this step (lesson 6: he shapes them to look right, so a refit would undo him).

A shape here is {"raw": array of control points}: M p0, then C c1 c2 p for each segment, closing on p0.
"""
import json
import re
import cv2
import numpy as np
from scipy.optimize import least_squares

import lesson_fit as F


def shapes_of(doc, layer_id):
    """a layer's shapes as (fill, {"raw": control points in the composition})"""
    d = json.load(open(f"{F.ROOT}/docs/{doc}.json", encoding="utf-8"))
    l = next(x for x in d["layers"] if x["id"] == layer_id)
    t = open(f"{F.ROOT}/art/{doc}/{l['art']}").read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', t).group(1).split()]
    k = l["w"] / vb[2]
    x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    out = []
    for el in re.findall(r"<path\b[^>]*/>", t):
        dd = re.search(r' d="([^"]+)"', el).group(1)
        if re.search(r"[LlHhVvSsQqTtAa]", dd):
            raise ValueError(f"{l['art']}: more than plain curves")
        tr = re.search(r"translate\(([-\d.]+),([-\d.]+)\)", el)
        tx, ty = (float(tr.group(1)), float(tr.group(2))) if tr else (0, 0)
        p = np.array([float(v) for v in re.findall(r"-?[\d.]+(?:e-?\d+)?", dd)]).reshape(-1, 2) + [tx, ty]
        p = np.stack([x0 + (p[:, 0] - vb[0]) * k, y0 + (p[:, 1] - vb[1]) * k], 1)
        fill = re.search(r'fill="([^"]+)"', el).group(1)
        out.append((fill, {"raw": p}))
    return out


def is_raw(a):
    return isinstance(a, dict)


def sample(a, n=40):
    if not is_raw(a):
        return F.sample(a, n)
    p, pts = a["raw"], []
    ts = np.linspace(0, 1, n, endpoint=False)[:, None]
    for i in range(0, len(p) - 3, 3):
        p0, c1, c2, e = p[i:i + 4]
        u = 1 - ts
        pts.append(u ** 3 * p0 + 3 * u * u * ts * c1 + 3 * u * ts * ts * c2 + ts ** 3 * e)
    return np.concatenate(pts)


def path_d(a):
    if not is_raw(a):
        return F.path_d(a)
    p = a["raw"]
    f = lambda q: f"{q[0]:.2f} {q[1]:.2f}"
    return f"M{f(p[0])} " + " ".join(f"C{f(p[i])} {f(p[i + 1])} {f(p[i + 2])}" for i in range(1, len(p) - 2, 3)) + " Z"


def shifted(a, dx, dy):
    if not is_raw(a):
        return [[x[0] - dx, x[1] - dy, x[2], x[3], x[4]] for x in a]
    return {"raw": a["raw"] - [dx, dy]}


def anchors(a):
    """the on-curve points (one per anchor)"""
    return a["raw"][0:-1:3] if is_raw(a) else np.array([x[:2] for x in a])


def mapped(a, M):
    return {"raw": a["raw"] @ M[:, :2].T + M[:, 2]}


def _chamfer(pts_a, pts_b):
    d = np.sqrt(((pts_a[:, None, :] - pts_b[None, :, :]) ** 2).sum(-1))
    return np.concatenate([d.min(1), d.min(0)])


def _misfit(target, care, behind):
    edge = cv2.Canny(target * 255, 50, 150) & cv2.dilate(behind, np.ones((5, 5), np.uint8)) * 255
    dist = cv2.distanceTransform((edge == 0).astype(np.uint8), cv2.DIST_L2, 5)
    eys, exs = np.nonzero(edge & (care * 255))
    epts = np.stack([exs, eys], 1).astype(float)
    S = F.S

    def of(pts):
        xi, yi = np.clip(pts[:, 0].round().astype(int), 0, S - 1), np.clip(pts[:, 1].round().astype(int), 0, S - 1)
        r1 = np.where(care[yi, xi] > 0, dist[yi, xi], 0)
        if not len(epts):
            return r1
        d2 = np.sqrt(((epts[:, None, :] - pts[None, ::3, :]) ** 2).sum(-1)).min(1)
        return np.concatenate([r1, d2 * 0.5])
    return of, epts


def transfer(own, rough, target, care, behind, refit=True, reach=18, label="", similar=False, hold_k=0.15):
    """his part `own` ({"raw"}) carried onto the view's drawing. `rough` is the rough cut there (any shape), which says roughly where
    the whole part goes, hidden bits included; target/care/behind say where its own edge shows (as lesson_fit's fit). `similar` keeps
    his shape's proportions (moved, turned and sized only): an eye seen further round is smaller, not squashed into a sliver"""
    src = sample(own, 12)
    rough_pts = sample(rough, 12)
    c_s, c_r = src.mean(0), rough_pts.mean(0)
    k0 = np.sqrt(np.cov(rough_pts.T).trace() / np.cov(src.T).trace())

    def M_of(v):
        a, b, c, d, tx, ty = v
        if similar:
            c, d = -b, a
        return np.array([[a, b, c_r[0] + tx - a * c_s[0] - b * c_s[1]], [c, d, c_r[1] + ty - c * c_s[0] - d * c_s[1]]])

    # 1. onto the rough cut, whole (hidden parts included)
    # (his shape kept his: sized and slanted only as much as the view needs, never sheared into something else)
    def skew(v):
        M = M_of(v)[:, :2]
        sv = np.linalg.svd(M, compute_uv=False)
        return np.array([np.log(sv[0] / sv[1]) * 40, min(0, np.linalg.det(M)) * 100])

    # (tried from several turns, the best kept: a strap that slants the other way in this view is a local minimum from straight)
    best = None
    for th in np.radians(np.arange(-60, 61, 15)):
        co, si = np.cos(th) * k0, np.sin(th) * k0
        r = least_squares(lambda v: np.concatenate([_chamfer(src @ M_of(v)[:, :2].T + M_of(v)[:, 2], rough_pts), skew(v)]), [co, -si, si, co, 0, 0])
        if best is None or r.cost < best.cost:
            best = r
    r = best
    # 2. onto the drawing where its edge shows, the rough cut still holding the hidden parts lightly
    of, epts = _misfit(target, care, behind)
    hold = lambda pts: _chamfer(pts[::4], rough_pts[::4]) * hold_k
    full = lambda v: sample(mapped(own, M_of(v)), 30)
    r = least_squares(lambda v: np.concatenate([of(full(v)), hold(full(v)), skew(v)]), r.x, diff_step=1e-3)
    shape = mapped(own, M_of(r.x))
    (a_, b_, _), (c_, d_, _) = M_of(r.x)
    note = f"slant/size {a_:.2f} {b_:.2f} {c_:.2f} {d_:.2f}"
    if refit:
        # 3. his points on the seen edge nudged onto it, handles riding along; neighbours kept moving together
        P = shape["raw"]
        n = (len(P) - 1) // 3
        seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
        on = [i for i in range(n) if seen[min(F.S - 1, max(0, round(P[3 * i, 1]))), min(F.S - 1, max(0, round(P[3 * i, 0])))]]
        if on:
            def moved(v):
                Q = P.copy()
                for k, i in enumerate(on):
                    dxy = v[2 * k:2 * k + 2]
                    idx = [3 * i, 3 * i + 1, (3 * i - 1) % (len(P) - 1)]
                    for j in idx:
                        Q[j] = Q[j] + dxy
                Q[-1] = Q[0]
                return {"raw": Q}
            dv = lambda v: v.reshape(-1, 2)
            smooth = lambda v: np.concatenate([(dv(v)[1:] - dv(v)[:-1]).ravel() * 0.4, dv(v).ravel() * 0.1])
            lo, hi = -reach * np.ones(2 * len(on)), reach * np.ones(2 * len(on))
            r2 = least_squares(lambda v: np.concatenate([of(sample(moved(v), 30)), smooth(v)]), np.zeros(2 * len(on)),
                               bounds=(lo, hi), diff_step=1e-2)
            shape = moved(r2.x)
            note += f", {len(on)} of his {n} points nudged up to {np.abs(r2.x).max():.1f} px"
    err = float(np.mean(of(sample(shape, 30))))
    if label:
        print(f"  {label}: his {(len(shape['raw']) - 1) // 3} points, {note}; off the seen edge {err:.2f} px")
    return shape
