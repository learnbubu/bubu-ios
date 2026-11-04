"""Cut a part the owner's way, from his recordings' principles rather than his shapes (the owner, 4 Nov 2026: "follow how we made
things from the recording. Things will be different shapes etc but the same principles apply"). See lessons/LESSONS.md.

- The whole part is drawn, hidden parts included: the caller gives its full mask (what the drawing shows, plus what a Codex
  picture or a rule says is under the parts in front).
- Its first points are its extremes in its own frame (lessons 1, 4): the ends and sides along its main line, not the screen's.
- Points go where the outline really turns: a corner (the tuft's tips, the heel's step) keeps its corner, with broken handles.
- Handles lie along the edge (lesson 1).
- Then, as he does, a point is added only where the shape can't be held without one (lessons 1, 11, 14, 16), at the place it's
  furthest off. It stops as soon as the outline is within `tol` everywhere, so the count stays as small as the shape allows.
- Where the edge shows (`seen`), it must be within `tol` (2 px: he places by eye, a pixel or two); where it's hidden, a looser
  `tol_hidden` will do (hidden parts are generous, not traced).

cut(mask, seen=None, tol=2.0, tol_hidden=8, corner_deg=55, max_points=20) -> ({"raw": control points}, points, how far off)
"""
import math
import cv2
import numpy as np
from scipy.optimize import least_squares


def contour(mask):
    # (the mask smoothed first, as he'd see it: pixel steps and a Codex picture's wobbles aren't turns)
    m = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 2.5) > 0.5
    cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=len)[:, 0, :].astype(float)
    if cv2.contourArea(c.astype(np.float32)) < 0:      # (clockwise on screen, as Studio's shapes go)
        c = c[::-1]
    # (smoothed a touch, so pixel steps aren't read as turns)
    k = 3
    pad = np.r_[c[-k:], c, c[:k]]
    sm = np.array([pad[i:i + 2 * k + 1].mean(0) for i in range(len(c))])
    return sm


def turns(c, step=6):
    """how sharply the outline turns at each point, in degrees, over `step` points either side"""
    n = len(c)
    a, b = c[(np.arange(n) - step) % n], c[(np.arange(n) + step) % n]
    v1, v2 = c - a, b - c
    cos = (v1 * v2).sum(1) / (np.linalg.norm(v1, axis=1) * np.linalg.norm(v2, axis=1) + 1e-9)
    return np.degrees(np.arccos(np.clip(cos, -1, 1)))


def tangent(c, i, side, step=5):
    """the edge's direction at point i, coming in (side -1) or going out (side 1)"""
    n = len(c)
    j = (i + side * step) % n
    d = (c[j] - c[i]) * side
    return d / (np.linalg.norm(d) + 1e-9)


def seg_fit(c, i, j, t0, t3):
    """a cubic from c[i] to c[j] along the edge between them, its handles along t0 and t3, their lengths fitted"""
    n = len(c)
    idx = np.arange(i, j + (n if j <= i else 0) + 1) % n
    pts = c[idx]
    p0, p3 = c[i], c[j]
    chord = np.linalg.norm(p3 - p0) + 1e-9
    s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    u = s / max(s[-1], 1e-9)

    def curve(v, uu):
        p1, p2 = p0 + t0 * v[0], p3 - t3 * v[1]
        q = 1 - uu[:, None]
        return q ** 3 * p0 + 3 * q * q * uu[:, None] * p1 + 3 * q * uu[:, None] ** 2 * p2 + uu[:, None] ** 3 * p3
    r = least_squares(lambda v: (curve(v, u) - pts).ravel(), [chord / 3, chord / 3], bounds=([0.05 * chord, 0.05 * chord], [1.2 * chord, 1.2 * chord]))
    v = r.x
    # (how far off: each edge point to the nearest of many points on the curve)
    dense = curve(v, np.linspace(0, 1, 120))
    err = np.sqrt(((pts[:, None, :] - dense[None]) ** 2).sum(-1)).min(1)
    return v, err, idx


def cut(mask, seen=None, tol=2.0, tol_hidden=8.0, corner_deg=55, max_points=20, extra=()):
    c = contour(mask)
    n = len(c)
    # 1. its extremes in its own frame
    m = c.mean(0)
    _, vecs = np.linalg.eigh(np.cov((c - m).T))
    ax = [vecs[:, 1], vecs[:, 0]]
    keys = set()
    for a in ax:
        pr = (c - m) @ a
        keys |= {int(np.argmax(pr)), int(np.argmin(pr))}
    # 2. its real corners
    tn = turns(c)
    corner = set()
    for i in np.argsort(-tn):
        if tn[i] < corner_deg:
            break
        if all(min(abs(i - k), n - abs(i - k)) > 8 for k in corner):
            corner.add(int(i))
    # (points asked for by the caller: places he'd put one, as the foot's bump)
    for p in extra:
        keys.add(int(np.argmin(((c - p) ** 2).sum(1))))
    keys = sorted(keys | corner)
    # (two key points too close together: keep one)
    kept = []
    for k in keys:
        if not kept or min(abs(k - kept[-1]), n - abs(k - kept[-1])) > 6:
            kept.append(k)
    if len(kept) > 1 and min(abs(kept[0] - kept[-1]), n - abs(kept[0] - kept[-1])) <= 6:
        kept.pop()
    keys = kept
    seen_at = None
    if seen is not None:
        xi, yi = np.clip(c[:, 0].round().astype(int), 0, seen.shape[1] - 1), np.clip(c[:, 1].round().astype(int), 0, seen.shape[0] - 1)
        seen_at = seen[yi, xi] > 0

    def build(keys):
        segs, worst = [], (0, None)
        for a, b in zip(keys, keys[1:] + keys[:1]):
            t0 = tangent(c, a, 1) if a not in corner else tangent(c, a, 1, 3)
            t3 = tangent(c, b, -1) if b not in corner else tangent(c, b, -1, 3)
            if a not in corner:     # (a smooth point's handles lie along one line)
                t_in = tangent(c, a, -1)
                t0 = (t0 + t_in) / (np.linalg.norm(t0 + t_in) + 1e-9)
            if b not in corner:
                t_out = tangent(c, b, 1)
                t3 = (t3 + t_out) / (np.linalg.norm(t3 + t_out) + 1e-9)
            v, err, idx = seg_fit(c, a, b, t0, t3)
            lim = np.where(seen_at[idx], tol, tol_hidden) if seen_at is not None else np.full(len(idx), tol)
            over = err / lim
            k = int(np.argmax(over))
            if over[k] > worst[0] and 3 < k < len(idx) - 4:
                worst = (over[k], int(idx[k]))
            segs.append((a, b, t0, t3, v))
        return segs, worst

    segs, worst = build(keys)
    while worst[0] > 1 and len(keys) < max_points:
        keys = sorted(keys + [worst[1]])
        segs, worst = build(keys)
    raw = [c[segs[0][0]]]
    for a, b, t0, t3, v in segs:
        raw += [c[a] + t0 * v[0], c[b] - t3 * v[1], c[b]]
    return {"raw": np.array(raw)}, len(keys), worst[0]
