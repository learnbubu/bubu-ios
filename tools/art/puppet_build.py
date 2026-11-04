"""Bùbù's front puppet, every part cut the owner's way (lessons/LESSONS.md), put together as PUPPET.md sections 3 and 4 lay out. It
replaces puppet_trace.py, whose parts were cut by mask arithmetic and came out ragged.
- Limbs and ears come from lesson_fit.py (lessons 2-4). The head is the owner's own (lesson 1).
- Round pieces (belly, eye patches, cheeks, nose): the head's rule, 4 points at the shape's extremes in its own frame, handles along
  the edge.
- Strokes (eye arcs, brows, mouth, straps): the toe lines' rule, 8 points bent along the drawn line. A strap's ends run on hidden under
  the head and belly that cover them (lesson 3).
- The torso has no outline of its own in the front view: everything round it is covered. It's one smooth body under the head, arms,
  legs and belly that fills the chest, reaching each shoulder and hip joint so a turn never shows a gap.
Writes the Studio document "bubu-puppet-front" and its art, and checks to out/puppet/: front-rebuilt.png (beside the drawing, with how
many pixels differ), front-parts.png (each part alone) and front-joints.png (joints turned).

From tools/art: ../sfx/.venv/Scripts/python -I puppet_build.py
"""
import json
import math
import os
import subprocess
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import lesson_fit as F  # noqa: E402

S = F.S
ROOT = F.ROOT
DOC = "bubu-puppet-front"
ART = f"{ROOT}/art/{DOC}"
OUT = "out/puppet"
os.makedirs(ART, exist_ok=True)
# (the owner cleans parts up in Studio: once a part's art isn't the file this script wrote, the document is theirs, and rebuilding
# would throw their work away; --force only when they ask for a fresh build)
if os.path.exists(f"{ROOT}/docs/{DOC}.json") and "--force" not in sys.argv:
    theirs = [l["id"] for l in json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"]
              if l.get("art", "").endswith(".svg") and l["art"] != f"{l['id']}.svg"]
    if theirs:
        sys.exit(f"{DOC} has the owner's edits ({', '.join(theirs)}): not rebuilt. Learn from them instead (lessons/LESSONS.md); --force to rebuild.")
subprocess.run([sys.executable, "-I", "lesson_fit.py"], check=True, stdout=subprocess.DEVNULL)

label = F.label
COL = {}
for nm in F.NAMES:
    px = F.im[label == F.NAMES.index(nm)]
    COL[nm] = "#%02x%02x%02x" % tuple(int(v) for v in np.median(px, 0)) if len(px) else "#000000"
DARK, GREY = "#393a36", "#959491"        # as the owner picked them (lesson 2)
CREAM = "#fef8e8"                        # the owner's head (lesson 1)


def comp_at(mask, x, y):
    """the piece of a colour nearest (x, y), its holes filled"""
    n, cc = cv2.connectedComponents(mask)
    ys, xs = np.nonzero(cc)
    k = cc[ys[np.argmin((xs - x) ** 2 + (ys - y) ** 2)], xs[np.argmin((xs - x) ** 2 + (ys - y) ** 2)]]
    one = (cc == k).astype(np.uint8)
    cs, _ = cv2.findContours(one, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    out = np.zeros_like(one)
    cv2.drawContours(out, cs, -1, 1, -1)
    return out


def fit_to(init, target, behind, label_="", free=None):
    """the lesson_fit fit for any part: its edge is where it meets what's behind it; points far from that edge are hidden and stay"""
    care = cv2.dilate(behind, np.ones((9, 9), np.uint8))
    zone = np.zeros((S, S), np.uint8)
    cv2.polylines(zone, [F.sample(init).round().astype(np.int32)], True, 1, 50)
    care &= zone
    seen = cv2.dilate(care, np.ones((23, 23), np.uint8))
    if free is None:
        free = [i for i, a in enumerate(init) if seen[min(S - 1, round(a[1])), min(S - 1, round(a[0]))]]
    if not free:
        return [list(a) for a in init], 0.0
    shape, err = F.fit(init, free, target, care, behind)
    if label_:
        print(f"  {label_}: {len(shape)} points ({len(free)} on its seen edge), off it by {err:.2f} px")
    return shape, err


def oval(mask):
    """4 points at an oval's extremes in its own frame (lesson 1, and lesson 4's own frame), handles along the edge"""
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


def stroke(mask, extend=(0, 0)):
    """a drawn line as an 8-point rounded stroke bent along it (the toe lines' rule, lesson 3); `extend` runs each end on further,
    hidden under whatever covers it"""
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


def from_svg(path):
    """every shape in an SVG as (fill, anchors)"""
    import re
    out = []
    txt = open(path).read()
    for k, (d, fill) in enumerate(re.findall(r' d="([^"]+)" fill="([^"]+)"', txt)):
        n = [float(x) for x in re.findall(r"-?[\d.]+", d)]
        segs = [(n[i:i + 2], n[i + 2:i + 4], n[i + 4:i + 6]) for i in range(2, len(n) - 5, 6)]
        pts = [n[0:2]] + [s[2] for s in segs][:-1]
        an = []
        for j, p in enumerate(pts):
            co, ci = segs[j][0], segs[j - 1][1]
            lo, li = math.dist(p, co), math.dist(p, ci)
            a_ = math.atan2(co[1] - p[1], co[0] - p[0]) if lo > 0.5 else math.atan2(p[1] - ci[1], p[0] - ci[0])
            an.append([p[0], p[1], a_, li, lo])
        out.append((fill, an))
    return out


colour = F.colour
cream, dark, red, pink, magenta = colour("cream"), colour("dark"), colour("red"), colour("pink"), colour("magenta")
P = {}          # name: {"shapes": [(fill, anchors)], "pivot": (x, y), "parent": name}
CUT = f"{ROOT}/art/cut-lesson"

# --- limbs and ears, from the lessons -----------------------------------------------------------------------------------------
for name, src in (("armL", "arm-l-check"), ("armR", "arm-r"), ("legL", "leg-l"), ("legR", "leg-r"), ("earL", "ear-l"), ("earR", "ear-r")):
    P[name] = {"shapes": [(DARK if f.lower() == "#393a36" else GREY, a) for f, a in from_svg(f"{CUT}/{src}-claude.svg")]}
for side in "LR":
    arm = P["arm" + side]["shapes"][0][1]
    # (the shoulder: the middle of the round cap, from its top, back and the armpit)
    P["arm" + side]["pivot"] = tuple(np.mean([arm[i][:2] for i in (0, 6, 7)], 0))
    leg = P["leg" + side]["shapes"][0][1]
    # (the hip: the middle of the leg's cap, from its top, the hip point and the cap's side)
    P["leg" + side]["pivot"] = tuple(np.mean([leg[i][:2] for i in (0, 1, 10)], 0))
HEAD_C = (625, 351)
for side in "LR":
    ear = P["ear" + side]["shapes"][0][1]
    ec = np.mean([a[:2] for a in ear], 0)
    r = math.dist(ec, ear[0][:2])
    d = (np.array(HEAD_C) - ec) / np.linalg.norm(np.array(HEAD_C) - ec)
    P["ear" + side]["pivot"] = tuple(ec + d * r * 0.6)          # its base, inside the head

# --- the head: the owner's own (lesson 1) ---------------------------------------------------------------------------------------
P["head"] = {"shapes": from_svg("lessons/owner/head.svg"), "pivot": (627, 560)}
print("head: the owner's,", len(P["head"]["shapes"][0][1]), "points")

# --- round pieces ---------------------------------------------------------------------------------------------------------------
print("round pieces:")
belly = comp_at(cream, 625, 857)
P["belly"] = {"shapes": [(COL["cream"], fit_to(oval(belly), belly, (dark | red | magenta).astype(np.uint8), "belly")[0])]}
for side, (x, y) in (("L", (489, 353)), ("R", (762, 353))):
    m = comp_at(dark, x, y)
    P["patch" + side] = {"shapes": [(DARK, fit_to(oval(m), m, cream, "patch" + side)[0])]}
for side, (x, y) in (("L", (424, 459)), ("R", (828, 459))):
    m = comp_at(pink, x, y)
    P["cheek" + side] = {"shapes": [(COL["pink"], fit_to(oval(m), m, cream, "cheek" + side)[0])]}
face = comp_at(dark, 626, 412)
nose = face.copy()
nose[402:] = 0
P["nose"] = {"shapes": [(DARK, fit_to(oval(nose), nose, cream, "nose")[0])]}

# --- strokes --------------------------------------------------------------------------------------------------------------------
print("strokes:")
for side, (x, y) in (("L", (495, 345)), ("R", (758, 345))):
    m = comp_at(cream, x, y)
    P["eye" + side] = {"shapes": [(CREAM, fit_to(stroke(m), m, dark, "eye" + side)[0])]}
for side, (x, y) in (("L", (494, 227)), ("R", (758, 227))):
    m = comp_at(dark, x, y)
    P["brow" + side] = {"shapes": [(DARK, fit_to(stroke(m), m, cream, "brow" + side)[0])]}
# the mouth: the stem down from the nose and the two curves, three strokes in one layer, overlapping where they meet
mouth = face.copy()
mouth[:402] = 0
xx = np.arange(S)[None, :]
yy = np.arange(S)[:, None]
stem = mouth * ((np.abs(xx - 626) <= 8) & (yy < 432))
left = mouth * (xx < 625) * (yy >= 415)
right = mouth * (xx > 628) * (yy >= 415)
shapes = []
for nm, m, ext in (("stem", stem, (4, 4)), ("mouth left", left, (0, 3)), ("mouth right", right, (3, 0))):
    shapes.append((DARK, fit_to(stroke(m.astype(np.uint8), ext), m.astype(np.uint8), cream, nm)[0]))
P["mouth"] = {"shapes": shapes}
# the straps: their ends run on under the head (top) and belly (bottom), as far as they stay hidden there (lesson 3's cap, but a
# strap's bottom runs out sideways past the belly's edge if it goes too far)
head_m = np.zeros((S, S), np.uint8)
cv2.fillPoly(head_m, [F.sample(P["head"]["shapes"][0][1]).round().astype(np.int32)], 1)
belly_m = np.zeros((S, S), np.uint8)
cv2.fillPoly(belly_m, [F.sample(P["belly"]["shapes"][0][1]).round().astype(np.int32)], 1)
for side, (x, y) in (("L", (435, 680)), ("R", (815, 680))):
    m = comp_at(red, x, y)
    cover = m | head_m | belly_m
    best = None
    BC = np.array([627.0, 857.0])
    for e_top in range(0, 46, 5):
        for e_bot in range(0, 61, 5):
            st = stroke(m, (e_top, e_top))
            # (the stroke's two ends: 0-2 one end, 4-6 the other; the lower one hangs in front of the backdrop beside the belly, so its
            # hidden run-on bends in under the belly instead of running on down past it)
            lo = (0, 1, 2) if st[1][1] > st[5][1] else (4, 5, 6)
            hi = (4, 5, 6) if lo == (0, 1, 2) else (0, 1, 2)
            if st[hi[1]][1] > st[lo[1]][1]:
                lo, hi = hi, lo
            # (undo the top run-on at the bottom end, then bend it in)
            end_c = np.mean([st[i][:2] for i in lo], 0)
            dvec = (BC - end_c) / np.linalg.norm(BC - end_c)
            tang = np.array(st[lo[1]][:2]) - end_c
            tang = tang / np.linalg.norm(tang)
            for i in lo:
                st[i][0] += -tang[0] * e_top + dvec[0] * e_bot
                st[i][1] += -tang[1] * e_top + dvec[1] * e_bot
            a_, err_ = fit_to(st, m, (dark | magenta).astype(np.uint8), free=[0, 2, 3, 4, 6, 7])
            drawn = np.zeros((S, S), np.uint8)
            cv2.fillPoly(drawn, [F.sample(a_).round().astype(np.int32)], 1)
            out_ = int((drawn & (1 - cv2.dilate(cover, np.ones((3, 3), np.uint8)))).sum())
            miss = int((m & (1 - drawn)).sum())
            # (as little showing past its covers or missing from the drawn strap as can be, then the longest hidden run-on)
            key = ((out_ + miss) // 15, -(e_top + e_bot))
            if best is None or key < best[0]:
                best = (key, a_, err_, out_ + miss, (e_top, e_bot))
    _, an, err, out, ext = best
    print(f"  strap{side}: ends run on {ext} px under the head and belly, off its seen edge by {err:.2f} px, {out} px showing past them or missing")
    P["strap" + side] = {"shapes": [(COL["red"], an)]}

# --- the torso ------------------------------------------------------------------------------------------------------------------
# what it must fill: the chest, and round each shoulder and hip joint so the limbs turn over body, never a gap
chest = comp_at(dark, 626, 645)
others = np.zeros((S, S), np.uint8)
for nm_ in ("armL", "armR", "legL", "legR", "earL", "earR"):
    for _, an_ in P[nm_]["shapes"]:
        cv2.fillPoly(others, [F.sample(an_).round().astype(np.int32)], 1)
own = dark & (1 - cv2.dilate(others, np.ones((3, 3), np.uint8)))
own[:560] = 0                           # (the face's dark is the head's)
own = cv2.morphologyEx(own, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
need = chest | own
for j in ("armL", "armR"):
    cv2.circle(need, tuple(int(v) for v in P[j]["pivot"]), 55, 1, -1)
for j in ("legL", "legR"):
    cv2.circle(need, tuple(int(v) for v in P[j]["pivot"]), 70, 1, -1)
hull = cv2.convexHull(np.argwhere(need)[:, ::-1].astype(np.int32))
body = np.zeros((S, S), np.uint8)
cv2.fillPoly(body, [hull], 1)
init = oval(body)
# (6 points: the 4 extremes and a shoulder each side, so it can be broad at the top like the drawing)
torso, err = F.fit(init, list(range(len(init))), body, np.ones((S, S), np.uint8), (1 - body).astype(np.uint8))
P["torso"] = {"shapes": [(DARK, torso)], "pivot": (627, 950)}
print(f"torso: {len(torso)} points, off the body it must fill by {err:.2f} px")

# --- the tree (PUPPET.md section 4) and the order back to front (section 3) -----------------------------------------------------
PARENT = {"legL": "hips", "legR": "hips", "torso": "hips", "armL": "torso", "armR": "torso", "strapL": "torso", "strapR": "torso",
          "belly": "torso", "head": "torso", "earL": "head", "earR": "head", "cheekL": "head", "cheekR": "head", "patchL": "head",
          "patchR": "head", "nose": "head", "mouth": "head", "browL": "head", "browR": "head", "eyeL": "patchL", "eyeR": "patchR"}
ORDER = ["earL", "earR", "armL", "armR", "legL", "legR", "torso", "strapL", "strapR", "belly", "head", "cheekL", "cheekR",
         "patchL", "patchR", "eyeL", "eyeR", "browL", "browR", "nose", "mouth"]
HIPS = (627, 950)
for name, p in P.items():
    if "pivot" not in p:
        p["pivot"] = tuple(np.mean([a[:2] for _, an in p["shapes"] for a in an], 0))
    p["parent"] = PARENT.get(name)

# --- write the parts and the document -----------------------------------------------------------------------------------------
layers = []
for name in ORDER:
    pts = np.concatenate([F.sample(a) for _, a in P[name]["shapes"]])
    x0, y0 = np.floor(pts.min(0)) - 2
    x1, y1 = np.ceil(pts.max(0)) + 2
    w, h = x1 - x0, y1 - y0
    moved = lambda an: [[a[0] - x0, a[1] - y0, a[2], a[3], a[4]] for a in an]
    paths = "\n".join(f'<path d="{F.path_d(moved(a))}" fill="{f}"/>' for f, a in P[name]["shapes"])
    open(f"{ART}/{name}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" viewBox="0 0 {w:.0f} {h:.0f}">\n{paths}</svg>')
    pv = P[name]["pivot"]
    layers.append({"id": name, "name": name, "art": f"{name}.svg", "w": float(w), "h": float(h), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2),
                   "scale": 1, "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False,
                   "pivot": {"x": round(float(pv[0]), 1), "y": round(float(pv[1]), 1)}, "keys": {}, "loop": 0, "blink": 0, "parent": P[name]["parent"]})
layers.insert(0, {"id": "hips", "name": "hips", "art": "", "w": 60, "h": 60, "x": HIPS[0], "y": HIPS[1], "scale": 1, "rotation": 0, "flipX": False,
                  "opacity": 1, "visible": True, "locked": False, "pivot": {"x": HIPS[0], "y": HIPS[1]}, "keys": {}, "loop": 0, "blink": 0, "nullObj": True})
doc = {"id": DOC, "name": "Bùbù Puppet Front", "width": S, "height": S, "duration": 2000, "loop": True, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if DOC not in project["docs"]:
    project["docs"].append(DOC)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)


# --- checks ---------------------------------------------------------------------------------------------------------------------
def pose(turns, bg=(255, 255, 255), scale=1.0):
    """the parts drawn as vectors, each turned about its pivot (degrees) and carried by its parents"""
    def mat(name):
        if name is None or name == "hips":
            return np.eye(3)
        px, py = P[name]["pivot"]
        a = math.radians(turns.get(name, 0))
        r = np.array([[math.cos(a), -math.sin(a), px - px * math.cos(a) + py * math.sin(a)],
                      [math.sin(a), math.cos(a), py - px * math.sin(a) - py * math.cos(a)], [0, 0, 1]])
        return mat(P[name]["parent"]) @ r
    img = Image.new("RGB", (round(S * scale), round(S * scale)), bg)
    d = ImageDraw.Draw(img)
    for name in ORDER:
        m = mat(name)
        for f, an in P[name]["shapes"]:
            pts = F.sample(an)
            pts = (np.c_[pts, np.ones(len(pts))] @ m.T)[:, :2] * scale
            d.polygon([tuple(p) for p in pts], fill=f)
    return img


rest = pose({})
orig = F.im.astype(np.uint8).copy()
orig[magenta > 0] = 255
diff = np.abs(np.asarray(rest).astype(int) - orig.astype(int)).max(-1) > 60
print(f"rebuilt vs the drawing: {diff.mean() * 100:.2f}% of pixels differ")
side_ = Image.new("RGB", (S * 2, S), "white")
side_.paste(Image.fromarray(orig), (0, 0))
side_.paste(rest, (S, 0))
side_.resize((S, S // 2)).save(f"{OUT}/front-rebuilt.png")
heat = np.asarray(rest).copy() // 3 + 170
heat[diff] = (255, 0, 0)
Image.fromarray(heat.astype(np.uint8)).save(f"{OUT}/front-diff.png")
# (a positive turn is clockwise on screen: his left arm (on our left) goes up with +, his right with -)
tests = [({}, "rest"), ({"armL": 70, "armR": -70}, "arms out"), ({"armL": 100, "armR": -100}, "arms up"),
         ({"armL": -20, "armR": 20}, "arms in"), ({"legL": 25, "legR": -25}, "legs out"), ({"head": 12, "earL": -15, "earR": 15}, "head tilt"),
         ({"torso": -6, "head": -10, "armR": -105, "legL": 15}, "wave")]
sheet = Image.new("RGB", (len(tests) * 420, 450), "white")
for k, (t, nm) in enumerate(tests):
    sheet.paste(pose(t, scale=420 / S), (k * 420, 30))
    ImageDraw.Draw(sheet).text((k * 420 + 10, 8), nm, fill=(0, 0, 0))
sheet.save(f"{OUT}/front-joints.png")
# each part alone on blue-grey, to see every one is a whole clean shape, hidden bits and all
tiles = []
for name in ORDER:
    img = Image.new("RGB", (S, S), (190, 200, 215))
    d = ImageDraw.Draw(img)
    pts_all = []
    for f, an in P[name]["shapes"]:
        pts = [tuple(p) for p in F.sample(an)]
        pts_all += pts
        d.polygon(pts, fill=f)
    xs, ys = [p[0] for p in pts_all], [p[1] for p in pts_all]
    t = img.crop((int(min(xs)) - 15, int(min(ys)) - 15, int(max(xs)) + 15, int(max(ys)) + 15))
    t.thumbnail((200, 200))
    tile = Image.new("RGB", (210, 225), "white")
    tile.paste(t, (5, 20))
    ImageDraw.Draw(tile).text((5, 3), name, fill=(0, 0, 0))
    tiles.append(tile)
cols = 7
sheet = Image.new("RGB", (cols * 210, ((len(tiles) + cols - 1) // cols) * 225), "white")
for k, t in enumerate(tiles):
    sheet.paste(t, ((k % cols) * 210, (k // cols) * 225))
sheet.save(f"{OUT}/front-parts.png")
print(len(ORDER), "parts in the document", DOC)
