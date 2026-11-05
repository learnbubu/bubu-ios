"""Bùbù's side view, from the model out/raw/rm-rest-side.png (drawn at the front's height and foot line, facing right), in the one
rig with the front and the three-quarter. Second cut (the owner, 4 Nov 2026: "side is kinda bad... follow how we made things from the
recording. Things will be different shapes etc but the same principles apply"): the first carried his three-quarter shapes over
whole; now every part is cut by his principles (principle_cut.py) from its whole shape:
- what the drawing shows, plus what Codex shows under the parts in front (out/codex/side2-*: no near arm, no head, neither)
- points at the part's extremes in its own frame, corners kept, handles along the edge, then a point added only where the shape can't
  be held without one; visible edges within 1.5 px of the drawing, hidden ones generous
- strokes (eye, brow, toe lines) the 8-point rule; the mouth one outline, its stem up under the nose; the nose's bottom over it
- the near strap one loop, off the bag's top, over the shoulder, down his front and back into the bag's bottom (Codex)
- limbs with generous round hidden caps tucked under what covers them: the arm's under the strap's arch, the leg's high under the
  belly; the paw a round end; the foot its own bump
- in profile the near ear is in front of the head, and the belly over the leg's top
The parts go under "view-side", in the Layers panel's "Side" group, with the same rig as the three-quarter, and the Turn control has
the side each way (the left one mirrored).

A part the owner has edited (its file no longer the plain s*.svg) or approved is kept as it is on a re-run. Afterwards run
strap_over.py sStrapL sArmL 900 --ref out/raw/rm-rest-side.png and side_face.py.
From tools/art (Studio saved first, then reload without saving): ../sfx/.venv/Scripts/python -I puppet_side.py
"""
import json
import math
import os
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402
import owner_transfer as T  # noqa: E402
import principle_cut as PC  # noqa: E402

S, ROOT = F.S, F.ROOT
SRC = "out/raw/rm-rest-side.png"
DOC = os.environ.get("SIDE_DOC", "puppet-views")   # (a copy to try on: SIDE_DOC=<doc id>)
ART = f"{ROOT}/art/{DOC}"
OUT = "out/puppet"
APPROVED = set()            # (parts the owner has looked at and said are good, unchanged)

F.im = np.asarray(Image.open(SRC).convert("RGB").resize((S, S))).astype(float)
F.label = np.argmin(((F.im[:, :, None, :] - np.array(list(F.PALETTE.values()), float)[None, None]) ** 2).sum(-1), -1)
colour = F.colour
F.magenta, F.cream, F.dark = colour("magenta"), colour("cream"), colour("dark")
F.target = colour("dark", "grey")
F.NEAR = cv2.dilate(F.magenta, np.ones((9, 9), np.uint8))
magenta, cream, dark, red, pink = F.magenta, F.cream, F.dark, colour("red"), colour("pink")
DARK, GREY, CREAM, PINK, RED = "#393a36", "#959491", "#fef8e8", "#f7b7b9", "#f45f44"


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


def box(x0, y0, x1, y1):
    r = np.zeros((S, S), np.uint8)
    r[max(0, y0):y1, max(0, x0):x1] = 1
    return r


def poly(pts):
    """a rough outline (points round it) as anchors with no handles: only where a part goes, for carrying his over"""
    return [[float(x), float(y), 0, 0, 0] for x, y in pts]


def rough_of(mask, n=24):
    cs, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=len)[:, 0, :]
    return poly(c[np.linspace(0, len(c) - 1, n).astype(int)])


def coded(pic):
    imc = np.asarray(Image.open(pic).convert("RGB").resize((S, S))).astype(float)
    labc = np.argmin(((imc[:, :, None, :] - np.array(list(F.PALETTE.values()), float)[None, None]) ** 2).sum(-1), -1)
    m = lambda n: cv2.morphologyEx(cv2.morphologyEx((labc == F.NAMES.index(n)).astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)),
                                   cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
    return {n: m(n) for n in ("dark", "red", "cream")}


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


# --- the parts, each cut by his principles (principle_cut.py) from its whole shape: what the drawing shows, plus what Codex's
# pictures show under the parts in front (out/codex/side2-*: no near arm, no head, neither), plus generous hidden ends -------------
NA, NH, NB = (coded(f"out/codex/side2-{n}/out.png") for n in ("no-arm", "no-head", "no-both"))
P = {}
bg = cv2.dilate(magenta, np.ones((7, 7), np.uint8))


def put(nm, col, mask, seen, tol=2.0, tol_hidden=8.0, extra=(), why="", most=20):
    """`most`: no more points than his own part of the kind has (belly 9, backpack 7, strap 10, torso 8, arm 8, leg 12)"""
    shape, n, w = PC.cut(mask.astype(np.uint8), seen, tol=tol, tol_hidden=tol_hidden, extra=extra, max_points=most)
    P[nm] = {"shapes": [(col, shape)]}
    print(f"  {nm}: {n} points{', still ' + format(w, '.1f') + 'x off somewhere' if w > 1 else ''}  {why}")


def edge_of(*masks):
    """where a part's own edge shows: next to these"""
    m = np.zeros((S, S), np.uint8)
    for x in masks:
        m |= x.astype(np.uint8)
    return cv2.dilate(m, np.ones((7, 7), np.uint8))


xx, yy = np.arange(S)[None, :], np.arange(S)[:, None]
print("head and ears:")
head = comp_at(cream, 500, 350)
head[600:] = 0
ear = comp_at(dark, 480, 150)
face = comp_at(dark, 870, 380)
# the near ear: in profile it's in front of the head, a round piece (lesson 1: points at its extremes); the far ear's bump is cut off
# it by the near ear's own ellipse, fitted where the near ear's edge shows
cs, _ = cv2.findContours(ear, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
ce = max(cs, key=len)[:, 0, :]
el = cv2.fitEllipse(ce[~((ce[:, 0] > 560) & (ce[:, 1] < 115))].astype(np.float32))
near_ear = np.zeros((S, S), np.uint8)
cv2.ellipse(near_ear, el, 1, -1)
near_ear &= cv2.dilate(ear, np.ones((5, 5), np.uint8))
put("sEarL", DARK, near_ear, edge_of(magenta, cream), why="(round, in front of the head)")
# the far ear: the bump that peeks over the back of the head, carried on as a round ear behind it (lesson 15)
bump = ear & (1 - cv2.dilate(near_ear, np.ones((5, 5), np.uint8)))
bump = comp_at(bump, 600, 80)
ys, xs = np.nonzero(bump)
far_ear = np.zeros((S, S), np.uint8)
r = int(max(30, (xs.max() - xs.min()) * 0.6))
cv2.circle(far_ear, (int(xs.mean()) + 5, int(ys.min()) + r - 2), r, 1, -1)   # (its top where the bump peeks, the rest behind)
far_ear |= bump
put("sEarR", DARK, far_ear, edge_of(magenta), why="(peeking; round behind the head)")
# the head: the head's round carried on under the ear (a circle through its edge either side of the ear), and the snout on under
# the nose and mouth, which sit on it (lesson 18)
cs, _ = cv2.findContours(head, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
c = max(cs, key=len)[:, 0, :]
earz = cv2.dilate(ear, np.ones((61, 61), np.uint8))
near = c[(earz[c[:, 1], c[:, 0]] > 0) & (bg[c[:, 1], c[:, 0]] > 0) & (c[:, 0] < 640)]
A = np.c_[near, np.ones(len(near))]
sol = np.linalg.lstsq(A, (near ** 2).sum(1), rcond=None)[0]
cx, cy = sol[0] / 2, sol[1] / 2
circ = np.zeros((S, S), np.uint8)
cv2.circle(circ, (int(cx), int(cy)), int(math.sqrt(sol[2] + cx * cx + cy * cy)), 1, -1)
hullh = np.zeros((S, S), np.uint8)
cv2.fillPoly(hullh, [cv2.convexHull(np.argwhere(head[150:] > 0)[:, ::-1].astype(np.int32) + [0, 150])], 1)
whole_head = head | (circ & cv2.dilate(ear, np.ones((9, 9), np.uint8))) | (face & hullh)
whole_head = cv2.morphologyEx(whole_head.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
put("sHead", CREAM, whole_head, edge_of(magenta), tol=2.0, why="(one shape with the tuft, lesson 1)")
print("face:")
patch = comp_at(dark, 750, 330)
put("sPatch", DARK, patch, edge_of(cream), why="(round)")
cheek = comp_at(pink, 705, 453)
put("sCheek", PINK, cheek, edge_of(cream), why="(round)")
# the eye and brow: strokes, 8 points with full round ends (lessons 3, 6, 7, 17)
eye = comp_at(cream & box(720, 300, 830, 360), 775, 330)
P["sEye"] = {"shapes": [(CREAM, F.fit(stroke(eye), list(range(8)), eye, F.care_in((710, 295, 840, 365), dark), dark)[0])]}
brow = comp_at(dark & box(690, 190, 780, 245), 735, 215)
P["sBrow"] = {"shapes": [(DARK, F.fit(stroke(brow), list(range(8)), brow, F.care_in((690, 190, 780, 245), cream), cream)[0])]}
print("  sEye, sBrow: 8-point strokes")
# the nose and mouth: the nose's bottom comes down a little over the stem's join, and the stem's top runs up under the nose
# (lesson 18); the mouth is one outline (lesson 5)
split = 400
nose = (face & (yy < split)).astype(np.uint8)
nose = (nose | (cv2.dilate(nose, np.ones((9, 1), np.uint8)) & (yy < split + 4) & hullh)).astype(np.uint8)
put("sNose", DARK, nose, edge_of(cream, magenta), why="(its bottom over the stem's top)")
mouth = (face & (yy >= split - 2)).astype(np.uint8)
ys, xs = np.nonzero(mouth & (yy < split + 10))
stem_x = int(np.median(xs))
mouth[split - 14:split, stem_x - 4:stem_x + 5] = 1                    # (the stem on up under the nose)
put("sMouth", DARK, mouth, edge_of(cream), tol=1.5, why="(one outline, its top under the nose)")
print("body:")
# the belly: as drawn, and on under the arm where Codex shows it
belly = comp_at(cream, 720, 830)
belly_na = comp_at(NA["cream"] & box(540, 600, 880, 1050), 720, 830)
whole_belly = (belly | belly_na).astype(np.uint8)
whole_belly = cv2.morphologyEx(whole_belly, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
put("sBelly", CREAM, whole_belly, edge_of(magenta), why="(not an oval, lesson 13)", most=9)
# the backpack: its whole bag from Codex (the red that isn't the strap's loop), as drawn where it shows
bag_seen = red & box(320, 560, 440, 900) & (xx < 445)
bag = ((NB["red"] | NA["red"]) & box(320, 560, 465, 900)) | bag_seen
hb = np.zeros((S, S), np.uint8)
cv2.fillPoly(hb, [cv2.convexHull(np.argwhere(bag)[:, ::-1].astype(np.int32))], 1)
bag = hb
put("sPack", RED, bag, edge_of(magenta), why="(whole, lessons 12, 13)", most=7)
# the near strap: one loop off the bag's top, over the shoulder, down his front and back into the bag's bottom (Codex, both
# pictures); as drawn where it shows; its two ends run into the bag
inside_bag = cv2.erode(bag, np.ones((21, 21), np.uint8))          # (its ends go 10 px into the bag)
strap = ((NA["red"] | NB["red"] | red) & box(380, 520, 700, 920) & (1 - inside_bag)).astype(np.uint8)
strap = cv2.morphologyEx(strap, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
strap = comp_at(strap, 640, 720)
# (the bag's own area isn't the strap's, but for the ends' 10 px into it)
strap &= (1 - cv2.erode(bag, np.ones((21, 21), np.uint8)))
put("sStrapL", RED, strap, edge_of(dark, cream, magenta), why="(a band off the bag's top and back into its bottom, lesson 12)", most=10)
# the torso: the body as Codex shows it with the head and the near arm away, the drawn chest, down to under the belly and legs
# (all of it: in Codex's picture the strap's loop cuts the body into pieces, and the body runs on under the strap and the belly. So the
# trunk's dark, the strap's loop and the belly together, filled round as one body)
trunk = ((NB["dark"] | NB["red"] | NA["red"] | (dark & box(600, 560, 800, 740))) & box(400, 520, 830, 1010) & (xx > 430)).astype(np.uint8)
trunk |= whole_belly
hull_b = np.zeros((S, S), np.uint8)
cv2.fillPoly(hull_b, [cv2.convexHull(np.argwhere(trunk)[:, ::-1].astype(np.int32))], 1)
body = hull_b
put("sTorso", DARK, body, edge_of(magenta, cream), why="(the body from Codex, lesson 13)", most=8)
print("limbs:")
# the near arm: its edges as drawn (the bag's red behind it, the strap's red and the belly in front), its paw's round end (a shade
# lighter than the leg), and a generous round cap tucked up under the strap's arch over the shoulder (lessons 4, 11, 14)
lum = F.im.mean(2)
lt = ((lum > 60.5) & (lum < 80)).astype(np.uint8)                        # (the paw's shade, a touch lighter than the leg)
lt = cv2.morphologyEx(lt, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
rows = {}
for y in range(600, 980):
    run = np.nonzero(dark[y, 425:625])[0] + 425
    if len(run) == 0:
        continue
    if y >= 890:
        # (the paw: its row by its lighter shade, as far down as it goes)
        pw = np.nonzero(lt[y, 425:625])[0] + 425
        if len(pw) < 12:
            if y > 930:
                break
            continue
        rows[y] = (int(pw.min()), int(pw.max()))
        continue
    reds = np.nonzero(red[y, 400:700])[0] + 400
    left = reds[reds < 520].max() + 1 if (reds < 520).any() else run.min()
    if (reds > 540).any():
        right = reds[reds > 540].min() - 1
    elif cream[y, 540:700].any():
        right = np.nonzero(cream[y, 540:700])[0].min() + 539
    else:
        right = run.max()
    rows[y] = (int(left), int(right))
paw = np.zeros((S, S), np.uint8)
arm = np.zeros((S, S), np.uint8)
for y, (a, b) in rows.items():
    arm[y, a:b + 1] = 1
arm |= paw
cv2.ellipse(arm, (int((rows[620][0] + rows[620][1]) / 2), 620), (int((rows[620][1] - rows[620][0]) / 2), 45), 0, 180, 360, 1, -1)
arm = cv2.morphologyEx(arm, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (31, 31)))   # (no notch where the paw starts)
arm = cv2.morphologyEx(arm, cv2.MORPH_OPEN, np.ones((7, 7), np.uint8))
put("sArmL", DARK, arm, edge_of(red, cream), why="(paw round, cap under the strap's arch)", most=8)
# the far arm: hangs behind the body, the same arm a little back (hidden at rest; there when he swings it)
# (whole, not shrunk: the owner drew the far leg as full as the near one, lesson 19)
put("sArmR", DARK, np.roll(np.roll(arm, 25, axis=1), -5, axis=0), np.zeros((S, S), np.uint8), tol_hidden=10, why="(behind the body, whole)", most=8)
# the near leg: as drawn below the belly and the paw, its foot's own bump at the top front (lesson 10), and a tall round cap well up
# under the belly (lesson 16)
leg = (dark & box(440, 940, 760, 1215) & (1 - cv2.dilate(paw, np.ones((5, 5), np.uint8)))).astype(np.uint8)
leg = comp_at(leg, 580, 1100)
ys, xs = np.nonzero(leg & (yy < 1010))
lx0, lx1 = int(np.percentile(xs, 2)), int(np.percentile(xs, 98))
_art_of = lambda nm: next((l.get("art") for l in json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"] if l["id"] == nm), None)
# (the thigh: the owner's far leg (lesson 19) has a big round thigh up under the belly, as wide as the hip. The near leg is the same
# leg in front, so it takes his thigh; before he'd drawn it, a round cap the leg's width)
his_leg = [sh for f, sh in T.shapes_of("puppet-views", "sLegR") if f.lower() == DARK.lower()] if _art_of("sLegR") not in (None, "sLegR.svg") else []
if his_leg:
    th = np.zeros((S, S), np.uint8)
    cv2.fillPoly(th, [np.array(T.sample(his_leg[0], 200)).round().astype(np.int32)], 1)
    leg |= th & (yy < 1010)
else:
    cv2.ellipse(leg, ((lx0 + lx1) // 2, 960), ((lx1 - lx0) // 2, 85), 0, 180, 360, 1, -1)
    cv2.rectangle(leg, (lx0, 960), (lx1, 1010), 1, -1)
leg = cv2.morphologyEx(leg, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
foot_top = next((x, y) for y in range(1080, 1180) for x in range(760, 600, -1) if leg[y, x])
put("sLegL", DARK, leg, edge_of(magenta, cream), extra=(foot_top,), why="(cap high under the belly; the foot's bump)", most=12)
put("sLegR", DARK, cv2.erode(leg, np.ones((9, 9), np.uint8)), np.zeros((S, S), np.uint8), tol_hidden=10, why="(right behind the near one)")
# toe lines: the drawn grey ones, as the toe-line rule cuts them
P["sArmL"]["shapes"] += [(GREY, t) for t in F.toe_lines(box(440, 880, 600, 960).astype(bool))]
P["sLegL"]["shapes"] += [(GREY, t) for t in F.toe_lines(box(620, 1120, 735, 1200).astype(bool))]

# pivots: the shoulder (the cap's middle), the hip, the neck, the ears' bases
P["sArmL"]["pivot"], P["sArmR"]["pivot"] = ((rows[640][0] + rows[640][1]) / 2, 640), ((rows[640][0] + rows[640][1]) / 2 + 25, 635)
P["sLegL"]["pivot"], P["sLegR"]["pivot"] = ((lx0 + lx1) / 2, 960), ((lx0 + lx1) / 2, 960)
P["sTorso"]["pivot"] = (600, 960)
P["sHead"]["pivot"] = (610, 575)
P["sEarL"]["pivot"], P["sEarR"]["pivot"] = (540, 200), (600, 125)
WRIST = ((rows[870][0] + rows[870][1]) / 2, 875)
ANKLE = ((lx0 + lx1) / 2 + 8, 1140)

OLD = {l["id"]: l for l in json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"]}
for nm in P:
    if nm in OLD and (OLD[nm].get("art") not in (None, f"{nm}.svg") or nm in APPROVED):
        P[nm]["shapes"] = T.shapes_of(DOC, nm)
        P[nm]["his"] = OLD[nm]
        print(f"  {nm}: the owner's ({OLD[nm]['art']}), kept")

PARENT = {"sLegL": "sHips", "sLegR": "sHips", "sTorso": "sHips", "sArmL": "sTorso", "sArmR": "sTorso", "sStrapL": "sTorso",
          "sPack": "sTorso", "sBelly": "sTorso", "sHead": "sTorso", "sEarL": "sHead", "sEarR": "sHead", "sCheek": "sHead",
          "sPatch": "sHead", "sNose": "sHead", "sMouth": "sHead", "sBrow": "sHead", "sEye": "sPatch"}
# back to front: the far arm, leg and ear behind everything; the body; the bag on its back (over the body's back edge, as drawn);
# the near leg under the belly (in profile the belly overlaps the leg's top); the strap; the near arm; the head; the near ear in front
# of the head (in profile it covers the head's back); the face
ORDER = ["sArmR", "sLegR", "sEarR", "sTorso", "sPack", "sLegL", "sBelly", "sStrapL", "sArmL", "sHead", "sEarL", "sCheek", "sPatch",
         "sEye", "sBrow", "sNose", "sMouth"]
for nm, p in P.items():
    if "pivot" not in p:
        p["pivot"] = tuple(np.concatenate([T.anchors(an) for _, an in p["shapes"]]).mean(0))

# --- into the document ---------------------------------------------------------------------------------------------------------
d = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))
keep_ids = {nm for nm in P if "his" in P[nm]}
d["layers"] = [l for l in d["layers"] if not (l["id"].startswith("s") and l["id"][1:2].isupper()) and l["id"] != "view-side"]
null = lambda id_, x, y, parent=None: {"id": id_, "name": id_, "art": "", "w": 60, "h": 60, "x": x, "y": y, "scale": 1, "rotation": 0,
                                        "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": {},
                                        "loop": 0, "blink": 0, "nullObj": True, "group": "Side", **({"parent": parent} if parent else {})}
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
    layers.append({"id": nm, "name": nm[1:] + " (side)", "art": f"{nm}.svg", "w": float(w), "h": float(h), "x": float((x0 + x1) / 2),
                   "y": float((y0 + y1) / 2), "scale": 1, "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False,
                   "pivot": {"x": round(float(pv[0]), 1), "y": round(float(pv[1]), 1)}, "keys": {}, "loop": 0, "blink": 0,
                   "parent": PARENT.get(nm), "group": "Side"})
ships = null("sHips", 590, 960, "view-side")
ships["control"] = {"kind": "move", "shape": "hips", "x": 590, "y": 1000, "r": 130}
CTL = {"sTorso": {"kind": "turn", "x": 600, "y": 745, "r": 95}, "sHead": {"kind": "turn", "x": 615, "y": 25, "r": 130},
       "sEarL": {"kind": "turn", "x": 420, "y": 30, "r": 55}}
for l in layers:
    if l["id"] in CTL and "his" not in P[l["id"]]:
        l["control"] = CTL[l["id"]]
# the side's reference drawing and Codex's pictures, locked guides (shown while editing, never in renders), the drawing on
refs = [{"id": rid, "name": name, "art": art, "w": 1254, "h": 1254, "x": 627, "y": 627, "scale": 1, "rotation": 0, "flipX": False,
         "opacity": 1, "visible": vis, "locked": True, "guide": True, "pivot": {"x": 627, "y": 627}, "keys": {}, "loop": 0, "blink": 0,
         "parent": "view-side", "group": "Side"}
        for rid, name, art, vis in (("refSide", "ref (side)", "ref-side.png", True), ("refSideNoArm", "ref (side, no near arm, Codex)", "ref-side-no-arm.png", False),
                                    ("refSideNoHead", "ref (side, no head or near arm, Codex)", "ref-side-no-head.png", False),
                                    ("refSideNoLeg", "ref (side, no near leg, Codex)", "ref-side-no-leg.png", False),
                                    ("refSide2NoArm", "ref (side, no near arm, Codex 2)", "ref-side2-no-arm.png", False),
                                    ("refSide2NoHead", "ref (side, no head, Codex 2)", "ref-side2-no-head.png", False),
                                    ("refSide2NoBoth", "ref (side, no head or near arm, Codex 2)", "ref-side2-no-both.png", False))]
for src_, dst in (("out/raw/rm-rest-side.png", "ref-side.png"), ("out/codex/side-no-arm/no-arm.png", "ref-side-no-arm.png"),
                  ("out/codex/side-no-head/no-head.png", "ref-side-no-head.png"), ("out/codex/side-no-leg/no-leg.png", "ref-side-no-leg.png"),
                  ("out/codex/side2-no-arm/out.png", "ref-side2-no-arm.png"), ("out/codex/side2-no-head/out.png", "ref-side2-no-head.png"),
                  ("out/codex/side2-no-both/out.png", "ref-side2-no-both.png")):
    Image.open(src_).convert("RGB").resize((S, S)).save(f"{ART}/{dst}")
d["layers"] = layers[::-1] + [ships] + [r for r in refs if r["id"] not in {l["id"] for l in d["layers"]}] + d["layers"] + [dict(null("view-side", 627, 1200), group="Views")]
d["layers"] = [l for i, l in enumerate(d["layers"]) if l["id"] not in {x["id"] for x in d["layers"][:i]}]
# (the Turn control: the side each way past the three-quarters, the left one mirrored)
tn = d["turn"]
ids = [v["id"] for v in tn["views"]]
if "side-r" not in ids:
    shift = 1 if "side-l" not in ids else 0
    tn["views"] = [{"id": "side-l", "name": "side, left", "root": "view-side", "mirror": True}] + [v for v in tn["views"] if v["id"] != "side-l"] + \
                  [{"id": "side-r", "name": "side, right", "root": "view-side"}]
    tn["at"] = tn.get("at", 1) + shift
    for k in tn.get("keys", []):
        k["v"] += shift
    tn["w"] = 300
    tn["x"] = 1060

# --- the limbs rigged as the three-quarter's -------------------------------------------------------------------------------------
LAYER = {l["id"]: l for l in layers}
bones = [b for b in d.get("bones", []) if not b["id"].startswith("s ") and not b["id"].startswith("sarm") and not b["id"].startswith("sleg")]
COLS = ["#e0574a", "#3b8eea", "#2a9d8f", "#f2b33d"]


def chain(prefix, top, joint, end, follow, kind, bend):
    pts = [top, (np.array(top) + joint) / 2, joint, (np.array(joint) + end) / 2, end]
    out_ = []
    for i in range(4):
        a, b = np.array(pts[i], float), np.array(pts[i + 1], float)
        out_.append({"id": f"{prefix.replace(' ', '')}{i + 1}", "name": f"{prefix} {i + 1}", "parent": out_[-1]["id"] if out_ else None,
                     "hx": round(float(a[0]), 1), "hy": round(float(a[1]), 1), "angle": round(math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])), 1),
                     "length": round(float(np.linalg.norm(b - a)), 1), "rotation": 0, "x": 0, "y": 0, "scale": 1, "keys": {}, "loop": 0, "color": COLS[i]})
    out_[0]["follow"] = follow
    e = out_[-1]
    a_ = math.radians(e["angle"])
    e["ik"] = {"root": out_[0]["id"], "tx": round(float(end[0]), 1), "ty": round(float(end[1]), 1), "mix": 1, "bend": bend, "kind": kind,
               "space": "sTorso" if kind == "hand" else "view-side", "keys": {},
               **({"ox": round(math.cos(a_) * 55, 1), "oy": round(math.sin(a_) * 55, 1)} if kind == "hand" else {"ox": 0, "oy": 0})}
    return out_


def pins(layer, bs, top, end):
    l = LAYER[layer]
    ox, oy = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    at = [(top, bs[0])] + [((b["hx"] + math.cos(math.radians(b["angle"])) * b["length"] / 2, b["hy"] + math.sin(math.radians(b["angle"])) * b["length"] / 2), b) for b in bs] + [(end, bs[-1])]
    names = ["top", "pin1", "pin2", "pin3", "pin4", "end"]
    l["puppet"] = {"pins": [{"id": n, "rx": round(p[0] - ox, 1), "ry": round(p[1] - oy, 1), "x": 0, "y": 0, "bone": b["id"], "keys": {}} for n, (p, b) in zip(names, at)]}


# (an elbow bends back, a knee forward: facing right, an elbow's middle bulges left and a knee's right)
for nm, prefix, follow, kind, end, bulge in (("sArmL", "s armL", "sTorso", "hand", WRIST, -1), ("sArmR", "s armR", "sTorso", "hand", (WRIST[0] + 25, WRIST[1] - 5), -1),
                                             ("sLegL", "s legL", "sHips", "foot", ANKLE, 1), ("sLegR", "s legR", "sHips", "foot", ANKLE, 1)):
    top, end = np.array(P[nm]["pivot"], float), np.array(end, float)
    joint = (top + end) / 2
    bs = chain(prefix, top, joint, end, follow, kind, 0)
    d_ = end - top
    left = np.array([d_[1], -d_[0]])
    bs[-1]["ik"]["bend"] = 1 if left[0] * bulge < 0 else -1
    if kind == "foot":
        l = LAYER[nm]
        bs[-1]["ik"]["oy"] = round(float(l["y"] + l["h"] / 2 - end[1] + 26), 1)
    bones += bs
    if "his" not in P[nm] or not LAYER[nm].get("puppet"):
        pins(nm, bs, top, end)
    print(f"  {nm}: 4 bones {tuple(round(float(v)) for v in top)} -> {tuple(round(float(v)) for v in end)}, bends {bs[-1]['ik']['bend']}")
d["bones"] = bones
json.dump(d, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

# --- check: the parts drawn back over the model ---------------------------------------------------------------------------------
al = Image.new("RGB", (S, S), (255, 0, 255))
dr = ImageDraw.Draw(al)
for nm in ORDER:
    for f, a in P[nm]["shapes"]:
        dr.polygon([tuple(x) for x in T.sample(a)], fill=f)
model = Image.open(SRC).convert("RGB").resize((S, S))
both = Image.new("RGB", (S * 2, S))
both.paste(model, (0, 0))
both.paste(al, (S, 0))
both.resize((S, S // 2)).save(f"{OUT}/side-rebuilt.png")
diff = (np.abs(np.asarray(al).astype(int) - np.asarray(model).astype(int)).sum(2) > 60).mean()
print(f"rebuilt: {diff * 100:.2f}% of pixels differ from the model")
