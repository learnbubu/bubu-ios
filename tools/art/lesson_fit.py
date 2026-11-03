"""Parts cut the owner's way (PUPPET.md, "The owner's method"): a few hand-placed points on the outline's extremes with smooth
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


def misfit(target, care, behind):
    """how far an outline sits from the drawing's edge, wherever that edge can be seen (care): a list of distances"""
    # (the part's own edge is where it meets what's behind it, the backdrop and anything it sits in front of; where it meets the belly
    # it is under, that's the belly's outline, not its own)
    edge = cv2.Canny(target * 255, 50, 150) & cv2.dilate(behind, np.ones((5, 5), np.uint8)) * 255
    dist = cv2.distanceTransform((edge == 0).astype(np.uint8), cv2.DIST_L2, 5)
    eys, exs = np.nonzero(edge & (care * 255))
    epts = np.stack([exs, eys], 1).astype(float)

    def of(anchors):
        pts = sample(anchors)
        xi, yi = np.clip(pts[:, 0].round().astype(int), 0, S - 1), np.clip(pts[:, 1].round().astype(int), 0, S - 1)
        r1 = np.where(care[yi, xi] > 0, dist[yi, xi], 0)
        # and every visible bit of the drawing's edge near the outline (so no part of it is skipped)
        d2 = np.sqrt(((epts[:, None, :] - pts[None, ::3, :]) ** 2).sum(-1)).min(1)
        return np.concatenate([r1, d2 * 0.5])
    return of


def place(init, target, care, behind):
    """the whole shape moved, turned and sized onto the drawing first (a mirrored part starts where the other side's was)"""
    of = misfit(target, care, behind)
    c = np.mean([a[:2] for a in init], 0)

    def moved(v):
        dx, dy, th, k = v
        co, si = math.cos(th), math.sin(th)
        return [[c[0] + dx + k * (co * (a[0] - c[0]) - si * (a[1] - c[1])), c[1] + dy + k * (si * (a[0] - c[0]) + co * (a[1] - c[1])),
                 a[2] + th, a[3] * k, a[4] * k] for a in init]
    r = least_squares(lambda v: of(moved(v)), [0, 0, 0, 1], bounds=([-80, -80, -0.5, 0.8], [80, 80, 0.5, 1.25]), diff_step=1e-3)
    return moved(r.x)


def fit(init, free, target, care, behind):
    """nudge the free anchors until the outline lies on the target's edge wherever the edge can be seen (care)"""
    of = misfit(target, care, behind)
    base = [list(a) for a in init]

    def build(v):
        an = [list(a) for a in base]
        for k, i in enumerate(free):
            an[i] = list(v[k * 5:k * 5 + 5])
        return an

    def resid(v):
        return of(build(v))

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


def anchors_of(svg_file, index=0):
    """a drawn shape's points back as anchors (x, y, angle, in length, out length), from its SVG path"""
    import re
    d = re.findall(r' d="([^"]+)"', open(f"{ROOT}/art/{DOC}/{svg_file}").read())[index]
    n = [float(x) for x in re.findall(r"-?[\d.]+", d)]
    segs_ = [(n[i:i + 2], n[i + 2:i + 4], n[i + 4:i + 6]) for i in range(2, len(n) - 5, 6)]
    pts = [n[0:2]] + [s[2] for s in segs_][:-1]
    out = []
    for k, p in enumerate(pts):
        c_out, c_in = segs_[k][0], segs_[k - 1][1]
        lo, li = math.dist(p, c_out), math.dist(p, c_in)
        ang = math.atan2(c_out[1] - p[1], c_out[0] - p[0]) if lo > 0.5 else math.atan2(p[1] - c_in[1], p[0] - c_in[0])
        out.append([p[0], p[1], ang, li, lo])
    return out


def mirror(anchors):
    """the other side: the model is drawn symmetric about its middle"""
    return [[S - a[0], a[1], math.pi - a[2], a[3], a[4]] for a in anchors]


magenta = colour("magenta")
cream = colour("cream")
dark = colour("dark")
target = colour("dark", "grey")
NEAR = cv2.dilate(magenta, np.ones((9, 9), np.uint8))


def care_in(box, behind):
    """where a part's own outline can be seen: next to what's behind it, inside its box (x0, y0, x1, y1)"""
    c = np.zeros((S, S), np.uint8)
    c[max(0, box[1]):box[3], max(0, box[0]):box[2]] = 1
    return c & cv2.dilate(behind, np.ones((9, 9), np.uint8))


def cut(name, init, box, toes=None, move=False, behind=None):
    """fit a part: the points on the drawing's visible edge move, the hidden ones (under something) stay as placed"""
    behind = magenta if behind is None else behind
    care = care_in(box, behind)
    init = place(init, target, care, behind) if move else init
    # (a point counts as on the visible edge when the backdrop is within ~15 px of it; deeper ones are hidden and stay put)
    seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
    free = [i for i, a in enumerate(init) if seen[min(S - 1, round(a[1])), min(S - 1, round(a[0]))]]
    shape, err = fit(init, free, target, care, behind)
    lines = toe_lines(toes) if toes is not None else []
    print(f"{name}: {len(shape)} points ({len(free)} on the visible edge), off it by {err:.2f} px on average; {len(lines)} toe lines")
    fills = [("#393a36", shape)] + [("#959491", t) for t in lines]
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{S}" height="{S}" viewBox="0 0 {S} {S}">\n' + "\n".join(
        f'<path d="{path_d(a)}" fill="{f}"/>' for f, a in fills) + "</svg>"
    open(f"{ROOT}/art/{DOC}/{name}-claude.svg", "w").write(svg)
    return fills


def region(x0, y0, x1, y1):
    r = np.zeros((S, S), bool)
    r[max(0, y0):y1, max(0, x0):x1] = True
    return r


parts = {}

# --- the right leg and foot, one shape like the owner's arm and paw ---------------------------------------------------
# The owner's fix: the leg owns its whole visible outline, right up to where it goes under the belly (the hip), and only then rounds
# over in a cap that rises a little above that point and reaches a little past the inner edge, all hidden.
hip_y = next(y for y in range(860, 1100) if dark[y, 830:880].any() and not cream[y, 830:880].all())
hip_x = int(np.nonzero(dark[hip_y + 2, 830:880])[0].mean()) + 830
gap_y = next(y for y in range(1000, 1150) if magenta[y, 640:700].any())
inner_x = int(np.nonzero(dark[gap_y + 5, 640:760])[0].min()) + 640
cap_x, cap_y = (inner_x - 8 + hip_x) / 2 - 10, hip_y - 35
side = (inner_x - 8, (hip_y + gap_y) / 2)
LEG_R = [(cap_x, cap_y, 0, 45, 45),                     # cap top (hidden)
         (hip_x, hip_y - 8, 1.1, 30, 30),               # the hip: where the outer edge goes under the belly
         (858, 1017, math.pi / 2, 50, 50),              # outer edge
         (849, 1118, math.pi / 2, 30, 20),              # where the foot starts
         (886, 1170, math.pi / 2, 25, 25),              # toe tip
         (850, 1207, math.pi, 30, 50),                  # sole, front
         (725, 1203, math.pi, 50, 25),                  # sole, back
         (681, 1166, -math.pi / 2, 12, 10),             # heel
         (683, 1145, -math.pi / 2, 8, 20),              # heel top: a little step where the leg meets the foot
         (668, 1100, -math.pi / 2 - 0.25, 40, 50),      # inner edge
         (side[0], side[1], -math.pi / 2, 50, 45)]      # cap side (hidden)
# (the hip point sits just above where it goes under, so it counts as seen)
parts["leg-r"] = cut("leg-r", LEG_R, (640, 900, S, S), region(640, 1100, S, S))
# the other leg: the same points mirrored, then fitted to that side's own edge
parts["leg-l"] = cut("leg-l", mirror(LEG_R), (0, 900, 615, S), region(0, 1100, 615, S), move=True)
# the other arm: the owner's arm and paw (8 points) mirrored, then fitted to that side's own edge
# the other arm: placed by hand at the same spots as the owner's (his arm mirrored doesn't land: this arm hangs at another angle). Its
# strap runs over it down to the belly, so below the shoulder only the outer edge and the paw show; the rest is hidden.


def handles(pts):
    """points placed with their direction of travel: handles a third of the way to each neighbour, the owner's long smooth curves"""
    out = []
    for k, (x, y, ang) in enumerate(pts):
        prev, nxt = pts[k - 1], pts[(k + 1) % len(pts)]
        out.append((x, y, ang, math.dist((x, y), prev[:2]) / 3, math.dist((x, y), nxt[:2]) / 3))
    return out


ARM_R = handles([(920, 685, 0.70),     # outer edge
                 (1020, 770, 1.1),     # outer edge, into the paw
                 (1032, 815, 1.57),    # paw tip
                 (975, 872, 3.25),     # paw bottom, its lowest point (heading left)
                 (865, 785, -2.3),     # where it goes under the strap and belly
                 (805, 690, -2.0),     # armpit (hidden)
                 (717, 575, -1.0),     # shoulder cap (hidden, under the head)
                 (826, 579, 0.6)])     # cap top, where the outer edge starts
parts["arm-r"] = cut("arm-r", ARM_R, (640, 500, S, 950), region(640, 750, S, 950))


# --- the ears: a round shape each, like the owner's head (points at the extremes, handles along the edge); the part under the head
# drawn whole, so the ear can turn without a gap
def ear(cx, cy):
    ys, xs = np.nonzero(cv2.Canny(dark * 255, 50, 150) & (NEAR * 255) & (region(cx - 170, cy - 170, cx + 170, cy + 170) * 255).astype(np.uint8))
    # the circle through the visible rim (least squares)
    A_ = np.stack([xs, ys, np.ones_like(xs)], 1).astype(float)
    sol = np.linalg.lstsq(A_, xs ** 2 + ys ** 2, rcond=None)[0]
    ex, ey = sol[0] / 2, sol[1] / 2
    r = math.sqrt(sol[2] + ex ** 2 + ey ** 2)
    k = 0.552 * r
    an = [(ex + r * math.cos(t), ey + r * math.sin(t), t + math.pi / 2, k, k) for t in (0, math.pi / 2, math.pi, 3 * math.pi / 2)]
    print(f"  ear circle at ({ex:.0f}, {ey:.0f}), radius {r:.0f}")
    return an, (int(ex - r - 30), int(ey - r - 30), int(ex + r + 30), int(ey + r + 30))


for nm, (cx, cy) in (("ear-l", (400, 150)), ("ear-r", (850, 150))):
    an, box = ear(cx, cy)
    parts[nm] = cut(nm, an, box)

# checks: over the model with the points, each part alone in a row
m = Image.fromarray(im.astype(np.uint8)).convert("RGBA")
ov = Image.new("RGBA", m.size)
d = ImageDraw.Draw(ov)
for fills in parts.values():
    for f, a in fills:
        p = [tuple(x) for x in sample(a)]
        d.polygon(p, fill=(0, 160, 255, 80))
        d.line(p + [p[0]], fill=(0, 90, 255, 255), width=2)
        for x in a:
            d.ellipse((x[0] - 4, x[1] - 4, x[0] + 4, x[1] + 4), fill=(255, 0, 0, 255))
Image.alpha_composite(m, ov).save("out/puppet/lesson-parts.png")
al = Image.new("RGB", (S, S), (255, 255, 255))
d = ImageDraw.Draw(al)
for fills in parts.values():
    for f, a in fills:
        d.polygon([tuple(x) for x in sample(a)], fill=f)
al.save("out/puppet/lesson-parts-alone.png")
