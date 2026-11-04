"""Bùbù's side view, from the model out/raw/rm-rest-side.png (drawn at the front's height and foot line, facing right), into the one
rig with the front and the three-quarter (the owner, 4 Nov 2026: "yes start the side view"). Done the way the lessons say:
- every part starts from the owner's own finished part, carried onto this drawing (owner_transfer.py): the three-quarter's near
  side for the face (patch, eye, brow, cheek, nose), the head, belly, backpack, strap, arms and legs; his front ear for the near ear,
  which in profile sits in front of the head and so must be whole
- the profile's mouth is one curve, which none of his mouths is, so it starts as an 8-point stroke (lesson 3's toe-line rule)
- the hidden parts come from Codex's pictures of this view with the near arm, the head, or the near leg taken away
  (out/codex/side-*): the near strap is one loop, off the bag's top, over the shoulder, down his side and back into the bag's bottom;
  the far leg stands right behind the near one; the far arm hangs behind the body
- the far ear peeks over the back of the head
The parts go under "view-side", in the Layers panel's "Side" group, with the same rig as the three-quarter, and the Turn control gets
the side each way (the left one mirrored).

A part the owner has edited (its file no longer the plain s*.svg) or approved is kept as it is on a re-run. Afterwards run
strap_over.py sStrapL sArmL and side_face.py.
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

S, ROOT = F.S, F.ROOT
SRC = "out/raw/rm-rest-side.png"
DOC = "puppet-views"
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


NOARM = coded("out/codex/side-no-arm/no-arm.png")
NOHEAD = coded("out/codex/side-no-head/no-head.png")


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


his = lambda doc, lid, i=0: T.shapes_of(doc, lid)[i][1]
Q = lambda lid: his(DOC, lid)                     # (his three-quarter parts)
P = {}

print("his parts, carried onto the side:")
# the head: his three-quarter head (14 points, the tuft his), onto the profile; the profile's snout is the nose's, not the head's
head = comp_at(cream, 500, 350)
head[590:] = 0
P["sHead"] = {"shapes": [(CREAM, T.transfer(Q("qHead"), rough_of(head), head, F.care_in((330, 0, 960, 600), magenta | dark), (magenta | dark).astype(np.uint8),
                                            reach=30, label="sHead (lessons 1, 14)"))]}
# the face: the three-quarter's near side
patch = comp_at(dark, 750, 330)
P["sPatch"] = {"shapes": [(DARK, T.transfer(Q("qPatchL"), rough_of(patch, 12), patch, F.care_in((650, 240, 860, 440), cream), cream, reach=12, label="sPatch"))]}
eye = comp_at(cream & box(720, 300, 830, 360), 775, 330)
P["sEye"] = {"shapes": [(CREAM, T.transfer(Q("qEyeL"), stroke(eye), eye, F.care_in((710, 295, 840, 365), dark), dark, refit=False, similar=True, label="sEye (lessons 6, 17)"))]}
brow = comp_at(dark & box(690, 190, 780, 245), 735, 215)
P["sBrow"] = {"shapes": [(DARK, T.transfer(Q("qBrowL"), stroke(brow), brow, F.care_in((690, 190, 780, 245), cream), cream, refit=False, similar=True, label="sBrow (lessons 7, 17)"))]}
cheek = comp_at(pink, 705, 453)
P["sCheek"] = {"shapes": [(PINK, T.transfer(Q("qCheekL"), rough_of(cheek, 12), cheek, F.care_in((640, 400, 770, 500), cream), cream, reach=8, label="sCheek"))]}
face = comp_at(dark, 870, 380)
nose = face.copy()
nose[402:] = 0
P["sNose"] = {"shapes": [(DARK, T.transfer(Q("qNose"), rough_of(nose, 12), nose, F.care_in((820, 350, 930, 410), cream | magenta), (cream | magenta).astype(np.uint8), reach=10, label="sNose (lesson 18)"))]}
mouth = face.copy()
mouth[:398] = 0
# (the stem's top runs up under the nose: lesson 18)
P["sMouth"] = {"shapes": [(DARK, F.fit(stroke(mouth, (0, 8)), list(range(8)), mouth, F.care_in((820, 395, 920, 450), cream), cream)[0])]}
print("  sMouth: an 8-point stroke (the profile's mouth is one curve; none of his is)")
# the ears: the near one in front of the head in profile, so whole: his front ear; the far one peeks over the back of the head
ear = comp_at(dark, 480, 150)
earn = ear.copy()
earn[:, 600:] = 0
P["sEarL"] = {"shapes": [(DARK, T.transfer(his("puppet-ik", "earL"), rough_of(earn, 16), earn, F.care_in((360, 20, 620, 270), magenta | cream), (magenta | cream).astype(np.uint8), reach=12, label="sEarL (front's ear, lesson 7)"))]}
earf = ear & box(560, 40, 640, 120)
P["sEarR"] = {"shapes": [(DARK, T.transfer(Q("qEarR"), poly([(560, 60), (600, 55), (632, 80), (625, 125), (590, 140), (560, 120)]), earf, F.care_in((560, 40, 640, 110), magenta), magenta, reach=10, label="sEarR (peeking)"))]}
# the belly
belly = comp_at(cream, 720, 830)
P["sBelly"] = {"shapes": [(CREAM, T.transfer(Q("qBelly"), rough_of(belly, 24), belly, F.care_in((560, 630, 870, 1040), dark | magenta), (dark | magenta).astype(np.uint8), reach=15, label="sBelly (lesson 13)"))]}
# the backpack: Codex's whole bag (the red left of the strap's loop)
bag = comp_at(NOARM["red"] & box(330, 560, 470, 900), 380, 720)
bag = cv2.morphologyEx(bag, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
P["sPack"] = {"shapes": [(RED, T.transfer(Q("qPack"), rough_of(bag, 24), bag, F.care_in((330, 560, 470, 900), magenta), magenta, reach=15, label="sPack (lessons 12, 13)"))]}
# the near strap: what the drawing shows of it (the arch over the shoulder and the band down the front of the arm: the red that isn't
# the bag), carrying on under the arm to the bag's bottom as Codex's loop does (lesson 12, "think where those lines may lead"); fitted
# to the drawing where it shows. (Codex drew the loop a little off from the drawing, so it only says where the hidden part goes.)
seen_strap = red & (1 - cv2.dilate(bag, np.ones((9, 9), np.uint8))) & box(400, 540, 700, 900)
seen_strap = comp_at(seen_strap, 630, 720)
loop = NOARM["red"] & (1 - cv2.dilate(bag, np.ones((7, 7), np.uint8))) & box(400, 540, 700, 900)
under = cv2.dilate(F.target & box(420, 580, 625, 970), np.ones((3, 3), np.uint8))       # (the arm, where the loop is hidden)
whole = (seen_strap | (loop & under)).astype(np.uint8)
whole = cv2.morphologyEx(whole, cv2.MORPH_CLOSE, np.ones((15, 15), np.uint8))
P["sStrapL"] = {"shapes": [(RED, T.transfer(Q("qStrapL"), rough_of(whole, 28), seen_strap, F.care_in((400, 540, 700, 900), cream | magenta | dark) & cv2.dilate(seen_strap, np.ones((9, 9), np.uint8)),
                                            (cream | magenta | dark).astype(np.uint8), reach=20, hold_k=1.0, label="sStrapL (lessons 12, 13)"))]}
# the arms: the near one hanging in front of the body, his three-quarter near arm; the far one hangs behind the body, the same
# place a little back (hidden at rest)
ARM = [(522, 585), (580, 600), (612, 660), (610, 760), (590, 880), (565, 950), (510, 962), (450, 935), (432, 860), (435, 740), (452, 640), (480, 598)]
arm = F.target & box(420, 580, 625, 970)
P["sArmL"] = {"shapes": [(DARK, T.transfer(Q("qArmL"), poly(ARM), arm, F.care_in((420, 600, 625, 970), red | cream | magenta), (red | cream | magenta).astype(np.uint8), reach=15, label="sArmL (lessons 2, 4, 11, 14)"))]}
P["sArmR"] = {"shapes": [(DARK, T.transfer(Q("qArmR"), poly([(x + 45, y - 5) for x, y in ARM]), np.zeros((S, S), np.uint8), np.zeros((S, S), np.uint8), magenta, refit=False, label="sArmR (behind the body)"))]}
# the legs: his three-quarter near leg (its tall hidden cap, lesson 16), and the far one right behind it
LEG = [(560, 870), (640, 900), (690, 990), (688, 1100), (705, 1125), (722, 1165), (705, 1200), (600, 1202), (500, 1200), (486, 1170),
       (487, 1120), (468, 1040), (462, 960), (490, 890)]
leg = F.target & box(450, 960, 735, 1210)
P["sLegL"] = {"shapes": [(DARK, T.transfer(Q("qLegL"), poly(LEG), leg, F.care_in((450, 990, 735, 1210), magenta | cream), (magenta | cream).astype(np.uint8), reach=20, label="sLegL (lessons 3, 10, 16)"))]}
P["sLegR"] = {"shapes": [(DARK, T.transfer(Q("qLegR"), poly([(x - 18, y) for x, y in LEG]), np.zeros((S, S), np.uint8), np.zeros((S, S), np.uint8), magenta, refit=False, label="sLegR (right behind)"))]}
# toe lines: the near paw's and foot's own, as the toe-line rule cuts them; the far ones hidden
P["sArmL"]["shapes"] += [(GREY, t) for t in F.toe_lines(box(440, 880, 600, 960).astype(bool))]
P["sLegL"]["shapes"] += [(GREY, t) for t in F.toe_lines(box(620, 1120, 735, 1200).astype(bool))]

# pivots: the shoulder, the hip, the neck, the ears' bases
P["sArmL"]["pivot"], P["sArmR"]["pivot"] = (525, 640), (570, 635)
P["sLegL"]["pivot"], P["sLegR"]["pivot"] = (575, 950), (557, 950)
P["sHead"]["pivot"] = (610, 575)
P["sEarL"]["pivot"], P["sEarR"]["pivot"] = (540, 200), (590, 120)

OLD = {l["id"]: l for l in json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"]}
for nm in P:
    if nm in OLD and (OLD[nm].get("art") not in (None, f"{nm}.svg") or nm in APPROVED):
        P[nm]["shapes"] = T.shapes_of(DOC, nm)
        P[nm]["his"] = OLD[nm]
        print(f"  {nm}: the owner's ({OLD[nm]['art']}), kept")

print("torso:")
# the body: the drawing's dark that's none of the other parts, round the shoulder and hip joints, and the body Codex shows where the
# near arm and the head were (lesson 13)
others = np.zeros((S, S), np.uint8)
for nm in ("sArmL", "sLegL", "sEarL", "sEarR"):
    cv2.fillPoly(others, [T.sample(P[nm]["shapes"][0][1]).round().astype(np.int32)], 1)
need = (dark & (1 - cv2.dilate(others, np.ones((3, 3), np.uint8))) & box(380, 540, 820, 1000)).astype(np.uint8)
need = cv2.morphologyEx(need, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
for pic in (NOARM, NOHEAD):
    need |= pic["dark"] & box(400, 520, 800, 960)
cv2.circle(need, P["sArmL"]["pivot"], 50, 1, -1)
cv2.circle(need, P["sLegL"]["pivot"], 60, 1, -1)
hull = cv2.convexHull(np.argwhere(need)[:, ::-1].astype(np.int32))
body = np.zeros((S, S), np.uint8)
cv2.fillPoly(body, [hull], 1)
body = cv2.morphologyEx(body, cv2.MORPH_OPEN, np.ones((9, 9), np.uint8))
if "his" not in P.get("sTorso", {}):
    P["sTorso"] = {"shapes": [(DARK, T.transfer(Q("qTorso"), rough_of(body, 24), body, np.ones((S, S), np.uint8), (1 - body).astype(np.uint8), reach=25, label="sTorso (lesson 13)"))]}
P["sTorso"]["pivot"] = (590, 960)
if "sTorso" in OLD and OLD["sTorso"].get("art") not in (None, "sTorso.svg"):
    P["sTorso"]["shapes"], P["sTorso"]["his"] = T.shapes_of(DOC, "sTorso"), OLD["sTorso"]

PARENT = {"sLegL": "sHips", "sLegR": "sHips", "sTorso": "sHips", "sArmL": "sTorso", "sArmR": "sTorso", "sStrapL": "sTorso",
          "sPack": "sTorso", "sBelly": "sTorso", "sHead": "sTorso", "sEarL": "sHead", "sEarR": "sHead", "sCheek": "sHead",
          "sPatch": "sHead", "sNose": "sHead", "sMouth": "sHead", "sBrow": "sHead", "sEye": "sPatch"}
# back to front: the far arm and leg and ear behind everything, the bag behind the body, the near leg under the belly's bottom, the
# strap, the near arm, the head, and the near ear in front of the head (in profile it covers the head's back)
# (in profile the belly overlaps the leg's top, so the near leg goes under the belly, not over it as in the three-quarter)
ORDER = ["sArmR", "sLegR", "sEarR", "sPack", "sTorso", "sLegL", "sBelly", "sStrapL", "sArmL", "sHead", "sEarL", "sCheek", "sPatch",
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
                                    ("refSideNoLeg", "ref (side, no near leg, Codex)", "ref-side-no-leg.png", False))]
for src_, dst in (("out/raw/rm-rest-side.png", "ref-side.png"), ("out/codex/side-no-arm/no-arm.png", "ref-side-no-arm.png"),
                  ("out/codex/side-no-head/no-head.png", "ref-side-no-head.png"), ("out/codex/side-no-leg/no-leg.png", "ref-side-no-leg.png")):
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
for nm, prefix, follow, kind, end, bulge in (("sArmL", "s armL", "sTorso", "hand", (512, 880), -1), ("sArmR", "s armR", "sTorso", "hand", (557, 875), -1),
                                             ("sLegL", "s legL", "sHips", "foot", (585, 1140), 1), ("sLegR", "s legR", "sHips", "foot", (567, 1140), 1)):
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
