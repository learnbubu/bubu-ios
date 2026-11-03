"""A part cut the owner's way (PUPPET.md, "The owner's method"): a few hand-placed points on the outline's extremes with smooth
handles along the edge, the hidden end a round cap under what covers it, then the points nudged until the edge sits on the drawing.
Toe lines are their own little rounded shapes in the same layer. First test: the right leg and foot (the owner did the head and an arm),
written into the Studio document "cut-lesson" as the layer "Leg_R (Claude)".

From tools/art: ../sfx/.venv/Scripts/python -I lesson_fit.py
"""
import json
import math
import cv2
import numpy as np
from PIL import Image, ImageDraw
from scipy.optimize import least_squares

SRC = "out/raw/rm-rest-a-happy.png"
ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = "cut-lesson"
S = 1254
PALETTE = {"magenta": (255, 0, 255), "cream": (253, 248, 231), "dark": (54, 56, 51), "red": (244, 95, 68), "pink": (247, 183, 185), "grey": (146, 145, 140)}
NAMES = list(PALETTE)
im = np.asarray(Image.open(SRC).convert("RGB").resize((S, S))).astype(float)
label = np.argmin(((im[:, :, None, :] - np.array(list(PALETTE.values()), float)[None, None]) ** 2).sum(-1), -1)
K3 = np.ones((3, 3), np.uint8)


def colour(*names):
    m = np.isin(label, [NAMES.index(n) for n in names]).astype(np.uint8)
    return cv2.morphologyEx(cv2.morphologyEx(m, cv2.MORPH_OPEN, K3), cv2.MORPH_CLOSE, K3)


def segs(anchors):
    """anchors (x, y, angle, in length, out length) round a closed outline: its cubic segments"""
    out = []
    for a, b in zip(anchors, anchors[1:] + anchors[:1]):
        da, db = (math.cos(a[2]), math.sin(a[2])), (math.cos(b[2]), math.sin(b[2]))
        out.append(((a[0], a[1]), (a[0] + da[0] * a[4], a[1] + da[1] * a[4]), (b[0] - db[0] * b[3], b[1] - db[1] * b[3]), (b[0], b[1])))
    return out


def sample(anchors, n=40):
    pts = []
    for p0, p1, p2, p3 in segs(anchors):
        for k in range(n):
            t = k / n
            u = 1 - t
            pts.append([u ** 3 * p0[j] + 3 * u * u * t * p1[j] + 3 * u * t * t * p2[j] + t ** 3 * p3[j] for j in (0, 1)])
    return np.array(pts)


def path_d(anchors):
    s = segs(anchors)
    f = lambda p: f"{p[0]:.2f} {p[1]:.2f}"
    return f"M{f(s[0][0])} " + " ".join(f"C{f(a)} {f(b)} {f(c)}" for _, a, b, c in s) + " Z"


def fit(init, free, target, care):
    """nudge the free anchors until the outline lies on the target's edge wherever the edge can be seen (care)"""
    # (the part's own edge is where it meets the backdrop; where it meets the belly is an overlap, not its outline)
    edge = cv2.Canny(target * 255, 50, 150) & cv2.dilate(colour("magenta"), np.ones((5, 5), np.uint8)) * 255
    dist = cv2.distanceTransform((edge == 0).astype(np.uint8), cv2.DIST_L2, 5)
    eys, exs = np.nonzero(edge & (care * 255))
    epts = np.stack([exs, eys], 1).astype(float)
    base = [list(a) for a in init]

    def build(v):
        an = [list(a) for a in base]
        for k, i in enumerate(free):
            an[i] = list(v[k * 5:k * 5 + 5])
        return an

    def resid(v):
        pts = sample(build(v))
        xi, yi = np.clip(pts[:, 0].round().astype(int), 0, S - 1), np.clip(pts[:, 1].round().astype(int), 0, S - 1)
        seen = care[yi, xi] > 0
        r1 = np.where(seen, dist[yi, xi], 0)
        # and every visible bit of the drawing's edge near the outline (so no part of it is skipped)
        d2 = np.sqrt(((epts[:, None, :] - pts[None, ::3, :]) ** 2).sum(-1)).min(1)
        return np.concatenate([r1, d2 * 0.5])

    v0 = np.concatenate([base[i] for i in free])
    # (each point stays near where it was put, its handles turned no more than ~30 degrees and never flipped back on themselves)
    lo = np.concatenate([[a[0] - 30, a[1] - 30, a[2] - 0.5, 2, 2] for a in (base[i] for i in free)])
    hi = np.concatenate([[a[0] + 30, a[1] + 30, a[2] + 0.5, 160, 160] for a in (base[i] for i in free)])
    r = least_squares(resid, np.clip(v0, lo + 1e-6, hi - 1e-6), bounds=(lo, hi), diff_step=1e-3, max_nfev=4000)
    return build(r.x), float(np.abs(resid(r.x)).mean())


def toe_lines(region):
    """each grey toe line as an 8-point rounded stroke bent along the drawn line, the way the owner cleaned them up: a tip and two
    shoulders at each end, and a point halfway down each side"""
    grey = colour("grey") & region
    shapes = []
    n, cc, stats, _ = cv2.connectedComponentsWithStats(grey)
    for k in range(1, n):
        if stats[k, cv2.CC_STAT_AREA] < 40:
            continue
        ys, xs = np.nonzero(cc == k)
        c = np.array([xs.mean(), ys.mean()])
        _, v = np.linalg.eigh(np.cov(np.stack([xs, ys])))
        ax = v[:, 1]
        nrm = np.array([-ax[1], ax[0]])
        rel = np.stack([xs, ys], 1) - c
        s, o = rel @ ax, rel @ nrm
        bend = np.polyfit(s, o, 2)                       # the line's centre, bent as drawn
        bins = np.linspace(s.min(), s.max(), 8)
        r = float(np.median([(o[(s >= p) & (s < q)].max() - o[(s >= p) & (s < q)].min()) / 2
                             for p, q in zip(bins, bins[1:]) if ((s >= p) & (s < q)).sum() > 2]))
        r = max(r, 2.5)
        at = lambda t: c + ax * t + nrm * np.polyval(bend, t)

        def tn(t):
            d = ax + nrm * np.polyval(np.polyder(bend), t)
            d = d / np.linalg.norm(d)
            return d, np.array([-d[1], d[0]])
        s1, s2, sm = s.min() + r, s.max() - r, (s.min() + s.max()) / 2
        q, side = 0.552 * r, (s2 - s1) / 6
        ang = lambda d: math.atan2(d[1], d[0])
        (t1, n1), (t2, n2), (tm, nm) = tn(s1), tn(s2), tn(sm)
        p1, p2, pm = at(s1), at(s2), at(sm)
        an = [(*(p2 + n2 * r), ang(t2), side, q), (*(p2 + t2 * r), ang(-n2), q, q), (*(p2 - n2 * r), ang(-t2), q, side),
              (*(pm - nm * r), ang(-tm), side, side),
              (*(p1 - n1 * r), ang(-t1), side, q), (*(p1 - t1 * r), ang(n1), q, q), (*(p1 + n1 * r), ang(t1), q, side),
              (*(pm + nm * r), ang(tm), side, side)]
        shapes.append([list(x) for x in an])
    return shapes


# --- the right leg and foot, one shape like the owner's arm and paw ---------------------------------------------------
target = colour("dark", "grey")
cream = colour("cream")
dark = colour("dark")
care = np.zeros((S, S), np.uint8)
care[900:, 640:] = 1                      # his right side, from the hip down: wherever the leg's outline shows
care &= (cream == 0).astype(np.uint8)
# The owner's fix: the leg owns its whole visible outline, right up to where it goes under the belly (the hip), and only then rounds
# over in a cap that rises a little above that point and reaches a little past the inner edge, all hidden.
hip_y = next(y for y in range(860, 1100) if dark[y, 830:880].any() and not cream[y, 830:880].all())
hip_x = int(np.nonzero(dark[hip_y + 2, 830:880])[0].mean()) + 830
gap_y = next(y for y in range(1000, 1150) if colour("magenta")[y, 640:700].any())
inner_x = int(np.nonzero(dark[gap_y + 5, 640:760])[0].min()) + 640
cap_x, cap_y = (inner_x - 8 + hip_x) / 2 - 10, hip_y - 35
side = (inner_x - 8, (hip_y + gap_y) / 2)
init = [(cap_x, cap_y, 0, 45, 45),                      # cap top (hidden)
        (hip_x, hip_y - 8, 1.1, 30, 30),                # the hip: where the outer edge goes under the belly
        (858, 1017, math.pi / 2, 50, 50),               # outer edge
        (849, 1118, math.pi / 2, 30, 20),               # where the foot starts
        (886, 1170, math.pi / 2, 25, 25),               # toe tip
        (850, 1207, math.pi, 30, 50),                   # sole, front
        (725, 1203, math.pi, 50, 25),                   # sole, back
        (681, 1166, -math.pi / 2, 12, 10),              # heel
        (683, 1145, -math.pi / 2, 8, 20),               # heel top: a little step where the leg meets the foot
        (668, 1100, -math.pi / 2 - 0.25, 40, 50),       # inner edge
        (side[0], side[1], -math.pi / 2, 50, 45)]       # cap side (hidden)
leg, err = fit(init, [1, 2, 3, 4, 5, 6, 7, 8, 9], target, care)
toes = toe_lines((np.arange(S)[None, :] > 640) & (np.arange(S)[:, None] > 1100))
print("hip", hip_x, hip_y, "inner", inner_x, "at", gap_y, "| leg: 11 points, off the drawing's edge by", round(err, 2), "px on average;", len(toes), "toe lines")

fills = [("#393a36", leg)] + [("#959491", t) for t in toes]
svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">\n' + "\n".join(
    f'<path d="{path_d(a)}" fill="{f}"/>' for f, a in fills) + "</svg>"
open(f"{ROOT}/art/{DOC}/leg-r-claude.svg", "w").write(svg)

# checks: over the model with the points, and alone
m = Image.fromarray(im.astype(np.uint8)).convert("RGBA")
ov = Image.new("RGBA", m.size)
d = ImageDraw.Draw(ov)
for f, a in fills:
    p = [tuple(x) for x in sample(a)]
    d.polygon(p, fill=(0, 160, 255, 90))
    d.line(p + [p[0]], fill=(0, 90, 255, 255), width=2)
    for x in a:
        d.ellipse((x[0] - 5, x[1] - 5, x[0] + 5, x[1] + 5), fill=(255, 0, 0, 255))
box = (600, 820, 940, 1240)
Image.alpha_composite(m, ov).crop(box).resize((680, 840)).save("out/puppet/lesson-leg.png")
al = Image.new("RGB", (S, S), (255, 255, 255))
d = ImageDraw.Draw(al)
for f, a in fills:
    d.polygon([tuple(x) for x in sample(a)], fill=f)
al.crop(box).resize((680, 840)).save("out/puppet/lesson-leg-alone.png")
