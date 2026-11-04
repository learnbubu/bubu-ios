"""Bùbù's three-quarter view, cut the owner's way (lessons/LESSONS.md, the same rules as puppet_build.py's front), from the model
out/raw/rm-rest-quarter.png (drawn at the front's height and foot line). The owner, 4 Nov 2026: "think we need the other angles now...
we want it all in one rig". So the parts go into one rig with the front: the Studio document "puppet-views", a copy of puppet-ik
(the owner's playground stays his), each view under its own root, switched by the Turn control.
- Ears: a round shape each, drawn whole behind the head (lesson 7). Head: one shape with its tuft (lesson 1), more points only at
  the tuft's corners.
- Round pieces (patches, cheeks, nose, belly, backpack): 4 points at the extremes in their own frame, handles along the edge.
- Strokes (eyes, brows, mouth, straps): 8-point rounded strokes bent along the drawn line (lesson 3's toe lines).
- Limbs: lesson_fit's limb (8 points in the limb's own frame, a round cap hidden past where it goes under), toe lines their own
  little shapes in the same layer.
- The torso: one smooth body filling the chest and round every shoulder and hip joint, so a turn never shows a gap.
Writes q*.svg into the document's art, the layers under "view-quarter", and out/puppet/quarter-rebuilt.png (beside the model).

From tools/art: ../sfx/.venv/Scripts/python -I puppet_quarter.py
"""
import json
import math
import os
import shutil
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402
import owner_transfer as T  # noqa: E402

S, ROOT = F.S, F.ROOT
SRC = "out/raw/rm-rest-quarter.png"
DOC, FROM = "puppet-views", "puppet-ik"
ART = f"{ROOT}/art/{DOC}"
OUT = "out/puppet"

# --- the model, its colours labelled as lesson_fit labels the front's ---------------------------------------------------------
F.im = np.asarray(Image.open(SRC).convert("RGB").resize((S, S))).astype(float)
F.label = np.argmin(((F.im[:, :, None, :] - np.array(list(F.PALETTE.values()), float)[None, None]) ** 2).sum(-1), -1)
colour = F.colour
F.magenta, F.cream, F.dark = colour("magenta"), colour("cream"), colour("dark")
F.target = colour("dark", "grey")
F.NEAR = cv2.dilate(F.magenta, np.ones((9, 9), np.uint8))
magenta, cream, dark, red, pink, grey = F.magenta, F.cream, F.dark, colour("red"), colour("pink"), colour("grey")
DARK, GREY, CREAM = "#393a36", "#959491", "#fef8e8"
PINK, RED = "#f7b7b9", "#f45f44"


def comp_at(mask, x, y):
    """the piece of a colour nearest (x, y), its holes filled"""
    n, cc = cv2.connectedComponents(mask)
    ys, xs = np.nonzero(cc)
    i = np.argmin((xs - x) ** 2 + (ys - y) ** 2)
    one = (cc == cc[ys[i], xs[i]]).astype(np.uint8)
    cs, _ = cv2.findContours(one, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    out = np.zeros_like(one)
    cv2.drawContours(out, cs, -1, 1, -1)
    return out


def fit_to(init, target, behind, label_="", free=None):
    """the lesson fit: its edge is where it meets what's behind it; points far from that edge are hidden and stay"""
    care = cv2.dilate(behind, np.ones((9, 9), np.uint8))
    zone = np.zeros((S, S), np.uint8)
    cv2.polylines(zone, [F.sample(init).round().astype(np.int32)], True, 1, 50)
    care &= zone
    seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
    if free is None:
        free = [i for i, a in enumerate(init) if seen[min(S - 1, max(0, round(a[1]))), min(S - 1, max(0, round(a[0])))]]
    if not free:
        return [list(a) for a in init], 0.0
    shape, err = F.fit(init, free, target, care, behind)
    if label_:
        print(f"  {label_}: {len(shape)} points ({len(free)} on its seen edge), off it by {err:.2f} px")
    return shape, err


def oval(mask):
    """4 points at an oval's extremes in its own frame, handles along the edge (lesson 1)"""
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    (cx, cy), (A, B), ang = cv2.fitEllipse(max(cs, key=len))
    e1 = np.array([math.cos(math.radians(ang)), math.sin(math.radians(ang))])
    e2 = np.array([-e1[1], e1[0]])
    a, b = A / 2, B / 2
    out = []
    for t in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        p = np.array([cx, cy]) + e1 * a * math.cos(t) + e2 * b * math.sin(t)
        d = -e1 * a * math.sin(t) + e2 * b * math.cos(t)
        k = 0.552 * (b if t in (0, math.pi) else a)
        out.append([p[0], p[1], math.atan2(d[1], d[0]), k, k])
    return out


def outline(mask, n, corners=()):
    """a shape's outline as n points spaced round it, handles along the edge; more where its corners are (x, y, how many)"""
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=len)[:, 0, :].astype(float)
    if cv2.contourArea(c.astype(np.float32)) < 0:
        c = c[::-1]
    seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.r_[c, c[:1]], axis=0), axis=1))]
    L = seg[-1]
    at = sorted(set([L * k / n for k in range(n)] + [seg[np.argmin(((c - [x, y]) ** 2).sum(1))] + d * L / 150
                                                       for x, y, m in corners for d in range(-(m // 2), m // 2 + 1)]))
    pts = [c[min(len(c) - 1, np.searchsorted(seg, s))] for s in at]
    out = []
    for k, p in enumerate(pts):
        a_, b_ = pts[k - 1], pts[(k + 1) % len(pts)]
        d = b_ - a_
        out.append([p[0], p[1], math.atan2(d[1], d[0]), np.linalg.norm(p - a_) / 3, np.linalg.norm(b_ - p) / 3])
    return out


def stroke(mask, extend=(0, 0)):
    """a drawn line as an 8-point rounded stroke bent along it (the toe lines' rule, lesson 3)"""
    ys, xs = np.nonzero(mask)
    c = np.array([xs.mean(), ys.mean()])
    _, v = np.linalg.eigh(np.cov(np.stack([xs, ys])))
    ax = v[:, 1]
    nrm = np.array([-ax[1], ax[0]])
    rel = np.stack([xs, ys], 1) - c
    s, o = rel @ ax, rel @ nrm
    bend = np.polyfit(s, o, 2)
    bins = np.linspace(s.min(), s.max(), 10)
    r = max(2.5, float(np.median([(o[(s >= p) & (s < q)].max() - o[(s >= p) & (s < q)].min()) / 2
                                  for p, q in zip(bins, bins[1:]) if ((s >= p) & (s < q)).sum() > 2])))
    at = lambda t: c + ax * t + nrm * np.polyval(bend, t)

    def tn(t):
        d = ax + nrm * np.polyval(np.polyder(bend), t)
        d = d / np.linalg.norm(d)
        return d, np.array([-d[1], d[0]])
    s1, s2 = s.min() + r - extend[0], s.max() - r + extend[1]
    sm = (s1 + s2) / 2
    q, side = 0.552 * r, (s2 - s1) / 6
    ang = lambda d: math.atan2(d[1], d[0])
    (t1, n1), (t2, n2), (tm, nm) = tn(s1), tn(s2), tn(sm)
    p1, p2, pm = at(s1), at(s2), at(sm)
    return [[*(p2 + n2 * r), ang(t2), side, q], [*(p2 + t2 * r), ang(-n2), q, q], [*(p2 - n2 * r), ang(-t2), q, side],
            [*(pm - nm * r), ang(-tm), side, side],
            [*(p1 - n1 * r), ang(-t1), side, q], [*(p1 - t1 * r), ang(n1), q, q], [*(p1 + n1 * r), ang(t1), q, side],
            [*(pm + nm * r), ang(tm), side, side]]


def box(x0, y0, x1, y1):
    r = np.zeros((S, S), np.uint8)
    r[max(0, y0):y1, max(0, x0):x1] = 1
    return r


def limb(name, bx, outward, toes):
    """a limb by lesson_fit's rules: its own frame, its hidden round cap; toe lines in the same layer"""
    init = F.limb(bx, outward)
    care = F.care_in(bx, magenta)
    zone = np.zeros((S, S), np.uint8)
    cv2.polylines(zone, [F.sample(init).round().astype(np.int32)], True, 1, 50)
    care &= zone
    seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
    free = [i for i, a in enumerate(init) if seen[min(S - 1, round(a[1])), min(S - 1, round(a[0]))]]
    shape, err = F.fit(init, free, F.target, care, magenta)
    print(f"  {name}: {len(shape)} points ({len(free)} on the visible edge), off it by {err:.2f} px")
    return [(DARK, shape)] + [(GREY, t) for t in F.toe_lines(toes.astype(bool))]


P = {}
print("ears:")
for nm, (cx, cy) in (("qEarL", (420, 150)), ("qEarR", (795, 150))):
    an, _ = F.ear(cx, cy)
    P[nm] = {"shapes": [(DARK, an)]}
print("head:")
head = comp_at(cream, 450, 350)
head[600:] = 0
P["qHead"] = {"shapes": [(CREAM, fit_to(outline(head, 10, corners=((640, 45, 5), (700, 45, 5), (715, 95, 3))), head, magenta, "qHead")[0])]}
print("round pieces:")
for nm, (x, y), col, behind in (("qPatchL", (615, 330), DARK, cream), ("qPatchR", (850, 335), DARK, cream),
                                ("qCheekL", (535, 452), PINK, cream)):
    m = comp_at(dark if col == DARK else pink, x, y)
    P[nm] = {"shapes": [(col, fit_to(oval(m), m, behind, nm)[0])]}
# (the far cheek runs off the head's edge: as much of it as shows, its edge the head's, not a whole oval sticking out past)
m = comp_at(pink, 882, 440)
P["qCheekR"] = {"shapes": [(PINK, fit_to(outline(m, 4), m, cream, "qCheekR")[0])]}
face = comp_at(dark, 790, 372)
nose = face.copy()
nose[390:] = 0
P["qNose"] = {"shapes": [(DARK, fit_to(oval(nose), nose, cream, "qNose")[0])]}
belly = comp_at(cream, 620, 830)
P["qBelly"] = {"shapes": [(CREAM, fit_to(oval(belly), belly, (dark | red | magenta).astype(np.uint8), "qBelly")[0])]}
pack = comp_at(red, 360, 620)
# (the backpack carries on down behind the arm to its bottom, where the near strap meets it: lesson 12, "think where those lines may
# lead". Its top and outer edge are fitted where they show; the rest is under the arm and the body at rest, there when he lifts his arm)
def smooth_loop(pts, k=1 / 3):
    out = []
    for i, p in enumerate(pts):
        a, b = np.array(pts[i - 1], float), np.array(pts[(i + 1) % len(pts)], float)
        d = b - a
        out.append([p[0], p[1], math.atan2(d[1], d[0]), math.dist(p, a) * k, math.dist(p, b) * k])
    return out
PACK = [(445, 518), (364, 564), (334, 660), (310, 750), (345, 808), (418, 778), (432, 690)]
P["qPack"] = {"shapes": [(RED, fit_to(smooth_loop(PACK), pack, magenta, "qPack")[0])]}
print("strokes:")
for nm, (x, y), box_ in (("qEyeL", (640, 322), (580, 290, 700, 350)), ("qEyeR", (850, 338), (820, 315, 880, 360))):
    m = comp_at(cream & box(*box_), x, y)
    P[nm] = {"shapes": [(CREAM, fit_to(stroke(m), m, dark, nm)[0])]}
for nm, (x, y) in (("qBrowL", (615, 205)), ("qBrowR", (812, 222))):
    m = comp_at(dark, x, y)
    P[nm] = {"shapes": [(DARK, fit_to(stroke(m), m, cream, nm)[0])]}
mouth = face.copy()
mouth[:388] = 0
xx, yy = np.arange(S)[None, :], np.arange(S)[:, None]
parts = (("stem", mouth * ((np.abs(xx - 795) <= 8) & (yy < 418)), (4, 4)), ("left", mouth * (xx < 792) * (yy >= 400), (0, 3)),
         ("right", mouth * (xx > 798) * (yy >= 400), (3, 0)))
P["qMouth"] = {"shapes": [(DARK, fit_to(stroke(m.astype(np.uint8), e), m.astype(np.uint8), cream, "mouth " + nm)[0]) for nm, m, e in parts]}
for nm, (x, y) in (("qStrapL", (520, 620)), ("qStrapR", (805, 640))):
    m = comp_at(red, x, y)
    P[nm] = {"shapes": [(RED, fit_to(stroke(m, (25, 25)), m, (magenta | cream).astype(np.uint8), nm, free=[0, 2, 3, 4, 6, 7])[0])]}
print("limbs:")
P["qArmL"] = {"shapes": limb("qArmL", (270, 600, 470, 880), 1, box(270, 760, 470, 880))}
P["qArmR"] = {"shapes": limb("qArmR", (800, 600, 960, 880), -1, box(820, 760, 960, 880))}
# legs: the right leg's points from lesson 3 (cap top, the hip where it goes under the belly, its edges, the foot's top, toe, sole
# and heel, the cap's sides), placed on this view's legs by eye, then fitted: going round clockwise from the cap's top
H = math.pi / 2
LEGS = {"qLegL": [(490, 860, 0, 45, 45), (575, 960, H, 45, 45), (592, 1060, H + 0.1, 40, 25), (585, 1112, H - 0.6, 15, 15),
                  (601, 1152, H, 18, 18), (560, 1195, math.pi, 25, 50), (420, 1195, math.pi, 50, 15), (403, 1160, -H, 15, 25),
                  (398, 1080, -H, 50, 50), (392, 905, -H, 40, 30), (425, 862, -H + 0.9, 25, 30)],
        "qLegR": [(725, 915, 0, 45, 45), (820, 952, H, 30, 40), (812, 1040, H, 40, 25), (812, 1105, H - 0.7, 15, 15),
                  (848, 1158, H, 18, 18), (800, 1192, math.pi, 25, 50), (670, 1190, math.pi, 50, 15), (650, 1165, -H, 15, 20),
                  (641, 1080, -H, 40, 40), (642, 1030, -H, 20, 30), (660, 950, -H + 0.5, 35, 30)]}
for nm, init in LEGS.items():
    bx = (370, 860, 620, 1210) if nm == "qLegL" else (625, 900, 870, 1210)
    care = F.care_in(bx, magenta)
    zone = np.zeros((S, S), np.uint8)
    cv2.polylines(zone, [F.sample(init).round().astype(np.int32)], True, 1, 50)
    care &= zone
    seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
    free = [i for i, a in enumerate(init) if seen[min(S - 1, round(a[1])), min(S - 1, round(a[0]))]]
    shape, err = F.fit([list(a) for a in init], free, F.target, care, magenta)
    print(f"  {nm}: {len(shape)} points ({len(free)} on the visible edge), off it by {err:.2f} px")
    P[nm] = {"shapes": [(DARK, shape)] + [(GREY, t) for t in F.toe_lines(box(bx[0], 1100, bx[2], 1210).astype(bool))]}

# pivots: shoulders and hips at the middle of each limb's cap, the ears' at their base inside the head
for nm in ("qArmL", "qArmR"):
    an = P[nm]["shapes"][0][1]
    P[nm]["pivot"] = tuple(np.mean([an[i][:2] for i in (0, 6, 7)], 0))
for nm in ("qLegL", "qLegR"):
    an = P[nm]["shapes"][0][1]
    P[nm]["pivot"] = tuple(np.mean([an[i][:2] for i in (0, 1, 10)], 0))
HEAD_C = (615, 340)
for nm in ("qEarL", "qEarR"):
    an = P[nm]["shapes"][0][1]
    ec = np.mean([a[:2] for a in an], 0)
    r = math.dist(ec, an[0][:2])
    d = (np.array(HEAD_C) - ec) / np.linalg.norm(np.array(HEAD_C) - ec)
    P[nm]["pivot"] = tuple(ec + d * r * 0.6)

# --- the owner's own parts carried over (4 Nov 2026: "make sure we're following what we learnt from those recordings and apply it
# to these turns"). The cuts above are only rough placings; each part he drew or fixed is his own shape moved onto the three-quarter
# drawing (owner_transfer.py), keeping his points, handles, round caps and stroke ends. Pivots were taken from the rough cuts above.
print("his parts, carried onto the three-quarter:")
MINE = "puppet-ik"
his = lambda lid, i=0: T.shapes_of(MINE, lid)[i][1]
rough = lambda nm: P[nm]["shapes"][0][1]
# lesson 1: the head and tuft as one shape, his 11 points
P["qHead"]["shapes"] = [(CREAM, T.transfer(his("head"), rough("qHead"), head, F.care_in((300, 0, 960, 600), magenta), magenta, reach=25, label="qHead (lesson 1)"))]
# lesson 5: the mouth one outline, his 18 points, not three strokes laid over each other
mouth_all = (face * (yy >= 380)).astype(np.uint8)
union = np.concatenate([F.sample(a) for _, a in P["qMouth"]["shapes"]])
P["qMouth"]["shapes"] = [(DARK, T.transfer(his("mouth"), [[x, y, 0, 0, 0] for x, y in union[::6]], mouth_all, F.care_in((740, 380, 860, 450), cream), cream, reach=8, label="qMouth (lesson 5)"))]
# lessons 6 and 7: his eyes and brows, fuller ends, carried whole and not refitted
for nm, lid, tgt, bh in (("qEyeL", "eyeL", cream, dark), ("qEyeR", "eyeR", cream, dark), ("qBrowL", "browL", dark, cream), ("qBrowR", "browR", dark, cream)):
    an = rough(nm)
    xs, ys = [a[0] for a in an], [a[1] for a in an]
    bx = (int(min(xs)) - 15, int(min(ys)) - 15, int(max(xs)) + 15, int(max(ys)) + 15)
    P[nm]["shapes"] = [(P[nm]["shapes"][0][0], T.transfer(his(lid), an, tgt & box(*bx), F.care_in(bx, bh), bh, refit=False, similar=True, label=f"{nm} (lessons 6-7)"))]
# (the straps: the owner is showing how the three-quarter's are cut, 4 Nov 2026; until then they stay the rough 8-point strokes above.
# His front strap carried over didn't fit: the near one here runs on into the backpack's bottom as one red shape)
# lessons 2, 4, 11: his arms, 8 points, the fuller cap under the head; lessons 3, 10: his leg, 12 points with the foot's own bump
# (both legs from his right leg: in this view both feet point the same way)
for nm, lid, bx in (("qArmL", "armL", (270, 600, 470, 880)), ("qArmR", "armR", (800, 600, 960, 880)),
                    ("qLegL", "legR", (370, 860, 620, 1210)), ("qLegR", "legR", (625, 900, 870, 1210))):
    P[nm]["shapes"] = [(DARK, T.transfer(his(lid), rough(nm), F.target, F.care_in(bx, magenta), magenta, reach=20, label=f"{nm} ({lid}, lessons 2-4, 10-11)"))] + P[nm]["shapes"][1:]

# (a part the owner has edited in Studio is his: kept as he left it, never rebuilt. Studio names an edited part's file after the edit,
# so any three-quarter layer whose art isn't the plain q*.svg written here is his; lesson 12's straps were the first)
OLD = {l["id"]: l for l in json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"]} if os.path.exists(f"{ROOT}/docs/{DOC}.json") else {}
for nm in P:
    if nm in OLD and OLD[nm].get("art") not in (None, f"{nm}.svg"):
        P[nm]["shapes"] = T.shapes_of(DOC, nm)
        P[nm]["his"] = OLD[nm]
        print(f"  {nm}: the owner's ({OLD[nm]['art']}), kept")

print("torso:")
others = np.zeros((S, S), np.uint8)
for nm in ("qArmL", "qArmR", "qLegL", "qLegR", "qEarL", "qEarR"):
    for _, an in P[nm]["shapes"]:
        cv2.fillPoly(others, [T.sample(an).round().astype(np.int32)], 1)
own = dark & (1 - cv2.dilate(others, np.ones((3, 3), np.uint8)))
own[:560] = 0
own = cv2.morphologyEx(own, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
need = own.copy()
for j in ("qArmL", "qArmR"):
    cv2.circle(need, tuple(int(v) for v in P[j]["pivot"]), 50, 1, -1)
for j in ("qLegL", "qLegR"):
    cv2.circle(need, tuple(int(v) for v in P[j]["pivot"]), 65, 1, -1)
hull = cv2.convexHull(np.argwhere(need)[:, ::-1].astype(np.int32))
body = np.zeros((S, S), np.uint8)
cv2.fillPoly(body, [hull], 1)
# (none of it below the belly but under the legs: it showed in the gap between them)
cover = np.zeros((S, S), np.uint8)
for nm in ("qBelly", "qLegL", "qLegR"):
    cv2.fillPoly(cover, [T.sample(P[nm]["shapes"][0][1]).round().astype(np.int32)], 1)
low = np.zeros((S, S), np.uint8)
low[1000:] = 1
body &= (1 - (low & (1 - cover))).astype(np.uint8)
body = cv2.morphologyEx(body, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
init = outline(body, 8)
torso, err = F.fit(init, list(range(len(init))), body, np.ones((S, S), np.uint8), (1 - body).astype(np.uint8))
P["qTorso"] = {"shapes": [(DARK, torso)], "pivot": (620, 960)}
print(f"  qTorso: {len(torso)} points, off the body it must fill by {err:.2f} px")
P["qHead"]["pivot"] = (615, 575)

PARENT = {"qLegL": "qHips", "qLegR": "qHips", "qTorso": "qHips", "qArmL": "qTorso", "qArmR": "qTorso", "qStrapL": "qTorso",
          "qStrapR": "qTorso", "qPack": "qTorso", "qBelly": "qTorso", "qHead": "qTorso", "qEarL": "qHead", "qEarR": "qHead",
          "qCheekL": "qHead", "qCheekR": "qHead", "qPatchL": "qHead", "qPatchR": "qHead", "qNose": "qHead", "qMouth": "qHead",
          "qBrowL": "qHead", "qBrowR": "qHead", "qEyeL": "qPatchL", "qEyeR": "qPatchR"}
# back to front: the far arm and leg behind the body, the backpack behind the near arm, the near arm in front of all but the head
ORDER = ["qEarR", "qEarL", "qArmR", "qLegR", "qPack", "qTorso", "qStrapR", "qLegL", "qBelly", "qStrapL", "qArmL", "qHead",
         "qCheekL", "qCheekR", "qPatchL", "qPatchR", "qEyeL", "qEyeR", "qBrowL", "qBrowR", "qNose", "qMouth"]
for nm, p in P.items():
    if "pivot" not in p:
        p["pivot"] = tuple(np.concatenate([T.anchors(an) for _, an in p["shapes"]]).mean(0))

# --- the document: a copy of puppet-ik, the front under its own root, the three-quarter beside it -------------------------------
src = json.load(open(f"{ROOT}/docs/{FROM}.json", encoding="utf-8"))
if not os.path.exists(f"{ROOT}/docs/{DOC}.json"):
    shutil.copytree(f"{ROOT}/art/{FROM}", ART, dirs_exist_ok=True)
    d = dict(src, id=DOC, name="Puppet Views")
else:
    d = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))
os.makedirs(ART, exist_ok=True)
d["layers"] = [l for l in d["layers"] if not l["id"].startswith("q") and l["id"] not in ("view-front", "view-quarter")]
null = lambda id_, x, y, parent=None: {"id": id_, "name": id_, "art": "", "w": 60, "h": 60, "x": x, "y": y, "scale": 1, "rotation": 0,
                                        "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": {},
                                        "loop": 0, "blink": 0, "nullObj": True, **({"parent": parent} if parent else {})}
for l in d["layers"]:
    if l["id"] == "hips":
        l["parent"] = "view-front"
layers = []
for nm in ORDER:
    if "his" in P[nm]:
        layers.append(dict(P[nm]["his"]))
        continue
    pts = np.concatenate([T.sample(a) for _, a in P[nm]["shapes"]])
    x0, y0 = np.floor(pts.min(0)) - 2
    x1, y1 = np.ceil(pts.max(0)) + 2
    w, h = x1 - x0, y1 - y0
    paths = "\n".join(f'<path d="{T.path_d(T.shifted(a, x0, y0))}" fill="{f}"/>' for f, a in P[nm]["shapes"])
    open(f"{ART}/{nm}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.0f} {h:.0f}">\n{paths}</svg>')
    pv = P[nm]["pivot"]
    layers.append({"id": nm, "name": nm[1:] + " (3/4)", "art": f"{nm}.svg", "w": float(w), "h": float(h), "x": float((x0 + x1) / 2),
                   "y": float((y0 + y1) / 2), "scale": 1, "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False,
                   "pivot": {"x": round(float(pv[0]), 1), "y": round(float(pv[1]), 1)}, "keys": {}, "loop": 0, "blink": 0, "parent": PARENT.get(nm)})
qhips = null("qHips", 620, 960, "view-quarter")
# (its rig controls, as the front's: the hip line, the chest's and head's arcs, an arc past each ear's tip)
qhips["control"] = {"kind": "move", "shape": "hips", "x": 620, "y": 962, "r": 150}
CTL = {"qTorso": {"kind": "turn", "x": 640, "y": 745, "r": 95}, "qHead": {"kind": "turn", "x": 615, "y": 30, "r": 130},
       "qEarL": {"kind": "turn", "x": 360, "y": 45, "r": 55}, "qEarR": {"kind": "turn", "x": 840, "y": 55, "r": 45}}
for l in layers:
    if l["id"] in CTL:
        l["control"] = CTL[l["id"]]
# (the views' roots: at the foot line in the middle, where a mirrored view flips across)
d["layers"] = layers[::-1] + [qhips] + d["layers"] + [null("view-quarter", 627, 1200), null("view-front", 627, 1200)]
# (each view's layers in their own group in the Layers panel, folding under its name, so they're easy to find: the owner, 4 Nov 2026)
for l in d["layers"]:
    l["group"] = "Views" if l["id"] in ("view-quarter", "view-front") else "Three-quarter" if l["id"].startswith("q") or l["id"] == "refQuarter" else "Front"
d["turn"] = {"views": [{"id": "quarter-l", "name": "three-quarter, left", "root": "view-quarter", "mirror": True},
                       {"id": "front", "name": "front", "root": "view-front"},
                       {"id": "quarter-r", "name": "three-quarter, right", "root": "view-quarter"}],
             "at": 1, "x": 1090, "y": 60, "w": 220}
# --- the limbs rigged as the front's (4 Nov 2026): four bones each (the upper and lower halves cut in two), a pin on each bone's
# middle and at the shoulder or hip and the wrist or ankle (none on a joint), IK from the hand or foot with its control, the arms
# moving with the chest and the legs with the hips; the feet planted on the view (so a mirrored view's are mirrored too)
LAYER = {l["id"]: l for l in layers}
bones = [b for b in d.get("bones", []) if not b["id"].startswith("q")]
COLS = ["#e0574a", "#3b8eea", "#2a9d8f", "#f2b33d"]


def chain(prefix, top, joint, end, follow, kind, out):
    """four bones top -> joint -> end, each half cut in two; returns the bones (the last carrying the IK)"""
    pts = [top, (np.array(top) + joint) / 2, joint, (np.array(joint) + end) / 2, end]
    names = [f"{prefix} 1", f"{prefix} 2", f"{prefix} 3", f"{prefix} 4"]
    out_ = []
    for i in range(4):
        a, b = np.array(pts[i], float), np.array(pts[i + 1], float)
        out_.append({"id": f"{prefix.replace(' ', '')}{i + 1}", "name": names[i], "parent": out_[-1]["id"] if out_ else None,
                     "hx": round(float(a[0]), 1), "hy": round(float(a[1]), 1), "angle": round(math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])), 1),
                     "length": round(float(np.linalg.norm(b - a)), 1), "rotation": 0, "x": 0, "y": 0, "scale": 1, "keys": {}, "loop": 0, "color": COLS[i]})
    out_[0]["follow"] = follow
    e = out_[-1]
    a_ = math.radians(e["angle"])
    e["ik"] = {"root": out_[0]["id"], "tx": round(float(end[0]), 1), "ty": round(float(end[1]), 1), "mix": 1, "bend": out, "kind": kind,
               "space": "qTorso" if kind == "hand" else "view-quarter", "keys": {},
               **({"ox": round(math.cos(a_) * 55, 1), "oy": round(math.sin(a_) * 55, 1)} if kind == "hand" else {"ox": 0, "oy": 0})}
    return out_


def pins(layer, bs, top, end):
    """the limb's pins: its top, each bone's middle, its end; each following its bone"""
    l = LAYER[layer]
    ox, oy = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    at = [(top, bs[0])] + [((b["hx"] + math.cos(math.radians(b["angle"])) * b["length"] / 2, b["hy"] + math.sin(math.radians(b["angle"])) * b["length"] / 2), b) for b in bs] + [(end, bs[-1])]
    names = ["top", "pin1", "pin2", "pin3", "pin4", "end"]
    l["puppet"] = {"pins": [{"id": n, "rx": round(p[0] - ox, 1), "ry": round(p[1] - oy, 1), "x": 0, "y": 0, "bone": b["id"], "keys": {}} for n, (p, b) in zip(names, at)]}


for nm, prefix, follow, kind in (("qArmL", "q armL", "qTorso", "hand"), ("qArmR", "q armR", "qTorso", "hand"),
                                 ("qLegL", "q legL", "qHips", "foot"), ("qLegR", "q legR", "qHips", "foot")):
    an = T.anchors(P[nm]["shapes"][0][1])
    top = np.array(P[nm]["pivot"])
    if kind == "hand":
        tip = an[np.argmax(np.linalg.norm(an - top, axis=1))]   # (the paw's end, along the arm: his point furthest from the shoulder)
        end = top + (tip - top) * 0.8                      # the wrist: where the paw starts
    else:
        # the ankle: the middle of the leg where the foot starts, straight down from the hip
        ys = [a[1] for a in an]
        y_ank = max(ys) - 58
        xs = [a[0] for a in an if abs(a[1] - y_ank) < 60]
        end = np.array([float(np.mean(xs)) if xs else top[0], y_ank])
    joint = (top + end) / 2
    # (which way the elbow or knee goes: out, away from the body's middle)
    side = 1 if (top[0] + end[0]) / 2 > 620 else -1
    bs = chain(prefix, top, joint, end, follow, kind, 0)
    d_ = end - top
    # bend sign: a joint turning +1 (clockwise on screen) curves the chain so its middle bulges to the left of its way down
    left = np.array([d_[1], -d_[0]])
    bs[-1]["ik"]["bend"] = 1 if left[0] * side > 0 else -1
    if kind == "foot":
        # (the foot's control under the foot, clear of it)
        l = LAYER[nm]
        bs[-1]["ik"]["oy"] = round(float(l["y"] + l["h"] / 2 - end[1] + 26), 1)
    bones += bs
    pins(nm, bs, top, end)
    print(f"  {nm}: 4 bones {tuple(round(float(v)) for v in top)} -> {tuple(round(float(v)) for v in end)}, bends {bs[-1]['ik']['bend']}")
d["bones"] = bones
for l in d["layers"]:
    if l["id"] in LAYER:
        l.update(LAYER[l["id"]])
json.dump(d, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if DOC not in project["docs"]:
    project["docs"].append(DOC)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

# --- check: the parts drawn back over the model -------------------------------------------------------------------------------
al = Image.new("RGB", (S, S), (255, 0, 255))
dr = ImageDraw.Draw(al)
for nm in ORDER:
    for f, a in P[nm]["shapes"]:
        dr.polygon([tuple(x) for x in T.sample(a)], fill=f)
model = Image.open(SRC).convert("RGB").resize((S, S))
both = Image.new("RGB", (S * 2, S))
both.paste(model, (0, 0))
both.paste(al, (S, 0))
both.resize((S, S // 2)).save(f"{OUT}/quarter-rebuilt.png")
diff = (np.abs(np.asarray(al).astype(int) - np.asarray(model).astype(int)).sum(2) > 60).mean()
print(f"rebuilt: {diff * 100:.2f}% of pixels differ from the model")
