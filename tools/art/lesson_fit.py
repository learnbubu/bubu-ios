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
    """each grey toe line as a 6-point rounded stroke, the way the owner drew them"""
    grey = colour("grey") & region
    shapes = []
    n, cc, stats, _ = cv2.connectedComponentsWithStats(grey)
    for k in range(1, n):
        if stats[k, cv2.CC_STAT_AREA] < 40:
            continue
        ys, xs = np.nonzero(cc == k)
        c = np.array([xs.mean(), ys.mean()])
        w, v = np.linalg.eigh(np.cov(np.stack([xs, ys])))
        ax = v[:, 1]
        along = (np.stack([xs, ys], 1) - c) @ ax
        half_len = (along.max() - along.min()) / 2
        r = max(2.5, (cc == k).sum() / (2 * half_len + 1e-6) / 2)
        a = math.atan2(ax[1], ax[0])
        e1, e2 = c + ax * (half_len - r), c - ax * (half_len - r)
        nrm = np.array([-ax[1], ax[0]])
        q = 0.552 * r
        # round end, side, round end, side: 6 points as the owner's (end tip, two shoulders each end)
        an = [(*(e1 + nrm * r), a, q, q), (*(e1 + ax * r), a + math.pi / 2, q, q), (*(e1 - nrm * r), a + math.pi, q, q),
              (*(e2 - nrm * r), a + math.pi, q, q), (*(e2 - ax * r), a + 3 * math.pi / 2, q, q), (*(e2 + nrm * r), a, q, q)]
        # (the long sides' handles a third of the side)
        side = np.linalg.norm(e1 - e2) / 3
        an = [list(x) for x in an]
        an[2][4] = an[3][3] = side
        an[5][4] = an[0][3] = side
        shapes.append(an)
    return shapes


# --- the right leg and foot, one shape like the owner's arm and paw ---------------------------------------------------
target = colour("dark", "grey")
cream = colour("cream")
care = np.zeros((S, S), np.uint8)
care[1000:, 640:] = 1                     # below the belly, his right side: where the leg's edge shows
care &= (cream == 0).astype(np.uint8)
CX, R = 756, 99                           # the hidden top: a round cap the leg's width, up under the belly
H = 0.552 * R
init = [(CX, 1000 - R * 1.1, 0, H, H),                 # cap top (hidden)
        (855, 1010, math.pi / 2, 50, 50),               # outer edge
        (849, 1118, math.pi / 2, 30, 20),               # where the foot starts
        (886, 1170, math.pi / 2, 25, 25),               # toe tip
        (850, 1207, math.pi, 30, 50),                   # sole, front
        (722, 1203, math.pi, 50, 25),                   # sole, back
        (681, 1160, -math.pi / 2, 20, 20),              # heel
        (668, 1100, -math.pi / 2 - 0.25, 40, 40),       # inner edge
        (CX - R, 990, -math.pi / 2, H, H)]              # cap side (hidden)
leg, err = fit(init, [1, 2, 3, 4, 5, 6, 7], target, care)
toes = toe_lines((np.arange(S)[None, :] > 640) & (np.arange(S)[:, None] > 1100))
print("leg: 9 points, off the drawing's edge by", round(err, 2), "px on average;", len(toes), "toe lines")

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
