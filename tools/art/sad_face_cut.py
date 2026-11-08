"""The sad face (eyes, brows, mouth), cut the owner's way (lessons/LESSONS.md) from Codex's sad head (codex-sad/out.png, approved
9 Nov 2026), in the head's own layer space:
- the picture put on the rig by its unchanged parts: the two eye patches and the nose (their boxes' centres against the layers')
- each feature's edge at the half-shade (labels by nearest palette colour: lesson 20, fit to the edge's middle)
- his point counts: the eye as his eye (10), the brow as his (8), the mouth one outline with its stem (18, lesson 5), the stem
  carried up under the nose (hidden, generous: lesson 19)
- the screen-left eye and brow cut, the right ones his mirror about 626.5 (lessons 6, 7); the mouth cut whole
- his colours: eye #fef8e8, brow #393a36, mouth #363733
Writes <out>/{eyeL,eyeR,browL,browR,mouth}-sad.svg, place.json, check.png"""
import sys, os, json
sys.path.insert(0, 'C:/Users/domch/Documents/Projects/bubu-ios/tools/art')
import cv2, numpy as np
from PIL import Image
import principle_cut as PC, owner_transfer as T
SRC, DOC, OUTD = sys.argv[1], sys.argv[2], sys.argv[3]
MID = 626.5
PAL = {"magenta": (255, 0, 255), "cream": (253, 248, 231), "dark": (54, 56, 51), "pink": (247, 183, 185)}
NM = list(PAL)
img = Image.open(SRC).convert("RGB")
a = np.asarray(img).astype(float)
lab = np.argmin(((a[:, :, None, :] - np.array(list(PAL.values()), float)[None, None]) ** 2).sum(-1), -1)
dark0 = (lab == NM.index("dark")).astype(np.uint8)
cream0 = (lab == NM.index("cream")).astype(np.uint8)
d = json.load(open(DOC, encoding="utf-8"))
Ly = {l["id"]: l for l in d["layers"]}
box = lambda l: (l["x"], l["y"])
# (the patches: the two biggest dark pieces inside the head (not touching the top: the ears do); the nose: the dark piece
# between them, lower)
n, cc, st, cen = cv2.connectedComponentsWithStats(dark0)
H, W = dark0.shape
inner = [i for i in range(1, n) if st[i, 1] > H * 0.25 and st[i, 4] > 2000]
patches = sorted(sorted(inner, key=lambda i: -st[i, 4])[:2], key=lambda i: st[i, 0])
bc = lambda i: np.array([st[i, 0] + st[i, 2] / 2, st[i, 1] + st[i, 3] / 2])
pl, pr = bc(patches[0]), bc(patches[1])
noses = [i for i in range(1, n) if i not in patches and pl[0] < cen[i][0] < pr[0] and cen[i][1] > pl[1] and st[i, 4] > 300]
nose_i = max(noses, key=lambda i: st[i, 4])
# (the nose may run into the mouth's stem: its box is the blob's widest rows only)
blob = (cc == nose_i)
ys, xs = np.nonzero(blob)
rows = {y: xs[ys == y] for y in range(ys.min(), ys.max() + 1)}
wid = {y: r.max() - r.min() for y, r in rows.items() if len(r)}
wmax = max(wid.values())
nose_rows = [y for y in sorted(wid) if wid[y] > 0.25 * wmax]
# (the nose: from its top down to where it narrows to the stem)
nb = nose_rows[0]
for y in sorted(wid):
    if y > nose_rows[0] and wid[y] < 0.25 * wmax:
        break
    nb = y
nose_bot = nb
nr = np.array([[r.min(), r.max()] for y, r in rows.items() if y <= nose_bot])
pn = np.array([(nr[:, 0].min() + nr[:, 1].max()) / 2, (ys.min() + nose_bot) / 2])
src = np.array([pl, pr, pn]); dst = np.array([box(Ly["patchL"]), box(Ly["patchR"]), box(Ly["nose"])])
# (a similarity, scale and move only: least squares)
sm, dm = src.mean(0), dst.mean(0)
s = np.sqrt(((dst - dm) ** 2).sum() / ((src - sm) ** 2).sum())
t = dm - s * sm
print("scale", round(s, 4), "fit error", np.round(np.linalg.norm(s * src + t - dst, axis=1), 1))
M = np.float32([[s, 0, t[0]], [0, s, t[1]]])
CW, CH = 1254, 900
warp = lambda m: cv2.warpAffine(m.astype(np.uint8), M, (CW, CH), flags=cv2.INTER_NEAREST)
# (labels warped at 4x then shrunk, so the half-shade edge survives the scale)
M4 = M * 4
up = lambda m: (cv2.resize(cv2.warpAffine(m.astype(np.float32), M4, (CW * 4, CH * 4), flags=cv2.INTER_LINEAR), (CW, CH), interpolation=cv2.INTER_AREA) > 0.5).astype(np.uint8)
dark, cream = up(dark0), up(cream0)
patchL = warp(cc == patches[0]); patchR = warp(cc == patches[1])
fill = lambda m: cv2.drawContours(np.zeros_like(m), cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)[0], -1, 1, -1)
P = {}
# eyes: the cream inside the screen-left patch
pf = fill(patchL)
eye = (cream & cv2.erode(pf, np.ones((3, 3), np.uint8))).astype(np.uint8)
n2, c2, s2, _ = cv2.connectedComponentsWithStats(eye)
eye = (c2 == max(range(1, n2), key=lambda i: s2[i, 4])).astype(np.uint8)
P["eyeL-sad"] = ("#fef8e8", PC.cut(eye, None, tol=0.6, max_points=10))
# brows: the dark stroke above the screen-left patch
n3, c3, s3, ce3 = cv2.connectedComponentsWithStats(dark)
ptop = np.nonzero(pf)[0].min()
pxl, pxr = np.nonzero(pf)[1].min(), np.nonzero(pf)[1].max()
br = [i for i in range(1, n3) if ce3[i][1] < ptop and pxl - 40 < ce3[i][0] < pxr + 40 and 100 < s3[i, 4] < 20000]
brow = (c3 == max(br, key=lambda i: s3[i, 4])).astype(np.uint8)
P["browL-sad"] = ("#393a36", PC.cut(brow, None, tol=1.0, max_points=8))
# the mouth (refined 9 Nov 2026, the owner: "mouth could be a bit better, refine it more to the reference"): cut at 4x the doc's
# scale, where the picture's own edge is (at 1x the stroke is a few pixels wide and the fit sat outside its underside), then
# shrunk back. The dark below the nose's widest part, its stem carried up 12 under the nose (hidden there)
Z = 4
dark4 = (cv2.warpAffine(dark0.astype(np.float32), M * Z, (CW * Z, CH * Z), flags=cv2.INTER_LINEAR) > 0.5).astype(np.uint8)
nose4 = (cv2.warpAffine(blob.astype(np.float32), M * Z, (CW * Z, CH * Z), flags=cv2.INTER_LINEAR) > 0.5).astype(np.uint8)
nby = int(round(s * nose_bot + t[1]))
n5, c5, s5, ce5 = cv2.connectedComponentsWithStats(dark4)
mo = [i for i in range(1, n5) if ce5[i][1] > (nby - 30) * Z and abs(ce5[i][0] - MID * Z) < 120 * Z and s5[i, 4] > 100 * Z * Z]
m = np.isin(c5, mo).astype(np.uint8)
# (the stem's width a little below the nose; above that row only the stem's columns are the mouth, carried up under the nose)
r0 = (nby + 10) * Z
stemx = np.nonzero(m[r0])[0]
m[:r0, :] = 0
m[(nby - 12) * Z: r0, stemx.min(): stemx.max() + 1] = 1
n4, c4, s4, _ = cv2.connectedComponentsWithStats(m)
m = (c4 == max(range(1, n4), key=lambda i: s4[i, 4])).astype(np.uint8)
seen = (1 - cv2.dilate(nose4, np.ones((5, 5), np.uint8))).astype(np.uint8)
seen[: (nby - 2) * Z] = 0
# (his mouth's stroke ends are round caps of three points each (lessons 5, 7: his ends fuller than Claude's): asked for at
# each tip of the frown and either side of it; and a point at each corner where the stem meets the frown)
cm = PC.contour(m)
caps = []
for tip in (int(np.argmin(cm[:, 0])), int(np.argmax(cm[:, 0]))):
    caps += [cm[(tip + o) % len(cm)] for o in (-26, 0, 26)]
# (the frown's arms bend along their length: a point half way along each, under and over, so the curve between the cap and the
# middle can't bow off the edge)
cx = cm[:, 0].mean()
for tipx in (cm[:, 0].min(), cm[:, 0].max()):
    xm = int(round((tipx + cx) / 2))
    col = np.nonzero(m[:, xm])[0]
    for yy in (col.max(), col.min()):
        caps.append(np.array([xm, yy], float))
sh, npts, worst = PC.cut(m, seen, tol=0.3 * Z, tol_hidden=4.0 * Z, max_points=18, extra=caps)
P["mouth-sad"] = ("#363733", ({"raw": sh["raw"] / Z}, npts, worst))
HIS_LAYER = Ly['mouth']
HIS_SVG = os.path.join(os.path.dirname(DOC), '..', 'art', d['id'], HIS_LAYER['art'])

# (the mouth his way, 9 Nov 2026, the owner: "look at how we've been doing the mouth and learn please, done it a few times now",
# and of the cut from scratch "the line in the middle leading up to his nose is weird". Lessons 5 and 18: his mouth is one outline
# of 18 points, its stem's top tucked up under the nose, the stem short, his stroke's thickness, round caps of three points. So it
# starts from his: the frown drawn at his stroke and his stem's length, then his 18 points carried onto it in his order round the
# outline (stem, the left arm's upper edge to its cap, the cap, under the arm to the middle, and the same on the right), each at
# the same share along its stretch as on his, the curves between them fitted to the drawing)
import re as _re
_t = open(HIS_SVG).read()
_p = np.array([float(v) for v in _re.findall(r"-?[\d.]+(?:e-?\d+)?", _re.search(r' d="([^"]+)"', _t).group(1))]).reshape(-1, 2)
his = _p + [HIS_LAYER['x'] - HIS_LAYER['w'] / 2, HIS_LAYER['y'] - HIS_LAYER['h'] / 2]
ha = his[0:-1:3]                                      # (his 18 points, in order)
assert len(ha) == 18, len(ha)
# his measures (doc px): the stroke, the stem's width and its length showing below the nose
nose_bottom = Ly['nose']['y'] + Ly['nose']['h'] / 2
his_stroke = float(np.linalg.norm(ha[2] - ha[6]))     # (the left arm, inner edge to outer)
his_stem_len = float(ha[1][1] - nose_bottom)
print("his mouth: stroke %.1f, stem %.1f wide, %.1f showing" % (his_stroke, ha[15][0] - ha[1][0], his_stem_len))
# the drawing's frown, at his stroke and his stem's length
dist = cv2.distanceTransform(m, cv2.DIST_L2, 5)
sk = cv2.ximgproc.thinning(m * 255) if hasattr(cv2, 'ximgproc') else None
ys_m, xs_m = np.nonzero(m)
row_w = {y: (xs_m[ys_m == y].max() - xs_m[ys_m == y].min() + 1) for y in np.unique(ys_m)}
stem_w = np.median([w for y, w in row_w.items() if (nby + 2) * Z <= y <= (nby + 8) * Z])
J = next(y for y in sorted(row_w) if y > (nby + 2) * Z and row_w[y] > 2.5 * stem_w)   # (where the stem meets the frown)
arms_ = m.copy(); arms_[:J] = 0
stroke = 2 * float(np.median(dist[arms_ > 0][dist[arms_ > 0] > 0.6 * dist[arms_ > 0].max()]))
print("the drawing's frown: stroke %.1f, stem %.1f showing" % (stroke / Z, (J / Z) - nby))
grow = int(round((his_stroke * Z - stroke) / 2))
if grow > 0:
    arms_ = cv2.dilate(arms_, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grow + 1, 2 * grow + 1)))
elif grow < 0:
    arms_ = cv2.erode(arms_, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (-2 * grow + 1, -2 * grow + 1)))
lift = int(round(J - (nose_bottom + his_stem_len) * Z))   # (the frown brought up so the stem shows his length)
arms_ = np.roll(arms_, -lift, axis=0)
hx_ = (ha[1][0] + ha[15][0]) / 2 * Z; hw_ = (ha[15][0] - ha[1][0]) * Z
m2 = arms_.copy()
m2[int((nose_bottom - 12) * Z): J - lift + 4 * Z, int(hx_ - hw_ / 2): int(hx_ + hw_ / 2) + 1] = 1   # (his stem, up under the nose)
n6, c6, s6, _ = cv2.connectedComponentsWithStats(m2)
m2 = (c6 == max(range(1, n6), key=lambda i: s6[i, 4])).astype(np.uint8)
cm = PC.contour(m2)
N = len(cm)
# the drawing's landmarks on its outline: the stem's top corners and bottom corners, the two tips, the middle underneath
def nearest(p):
    return int(np.argmin(((cm - p) ** 2).sum(1)))
top_y = cm[:, 1].min()
tipL, tipR = int(np.argmin(cm[:, 0])), int(np.argmax(cm[:, 0]))
cx_ = cm[:, 0].mean()
low = [i for i in range(N) if abs(cm[i, 0] - cx_) < 3 * Z]
mid = max(low, key=lambda i: cm[i, 1])
# (the stem's foot corners: on each side of the stem, the outline's most turned point near where it meets the frown)
tn = PC.turns(cm)
def corner_near(p):
    cand = [i for i in range(N) if np.linalg.norm(cm[i] - p) < 6 * Z]
    return max(cand, key=lambda i: tn[i])
footL = corner_near(np.array([hx_ - hw_ / 2, J - lift]))
footR = corner_near(np.array([hx_ + hw_ / 2, J - lift]))
stem_tl, stem_tr = nearest(np.array([hx_ - hw_ / 2, top_y + 4 * Z])), nearest(np.array([hx_ + hw_ / 2, top_y + 4 * Z]))
stem_top = nearest(np.array([hx_, top_y]))
# his landmarks (indices of his 18): 0 stem top left, 1 stem foot left, 4 left tip, 8 middle, 12 right tip, 15 stem foot right,
# 16 stem top right, 17 stem top
H_land = [0, 1, 4, 8, 12, 15, 16, 17]
D_land = [stem_tl, footL, tipL, mid, tipR, footR, stem_tr, stem_top]
# (the outline's direction: his goes stem down the left first; the drawing's must go the same way)
fwd = lambda a, b: (b - a) % N
if fwd(stem_tl, footL) > fwd(footL, stem_tl):
    cm = cm[::-1].copy(); N = len(cm)
    D_land = [N - 1 - i for i in D_land]
def his_len(i, j):
    seg = list(range(i, j + 1)) if j > i else list(range(i, 18)) + list(range(0, j + 1))
    pts = np.array([ha[k] for k in seg])
    return np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
keys = {}
for (h0, d0), (h1, d1) in zip(zip(H_land, D_land), list(zip(H_land, D_land))[1:] + [(H_land[0], D_land[0])]):
    keys[h0] = d0
    cum = his_len(h0, h1)
    span = fwd(d0, d1)
    inner = (list(range(h0 + 1, h1)) if h1 > h0 else list(range(h0 + 1, 18)) + list(range(0, h1)))
    for k_, h in enumerate(inner, 1):
        keys[h] = (d0 + int(round(span * cum[k_] / cum[-1]))) % N
order = [keys[h] for h in range(18)]
corner = {footL, footR, stem_tl, stem_tr}
segs = []
for a_, b_ in zip(order, order[1:] + order[:1]):
    t0 = PC.tangent(cm, a_, 1) if a_ in corner else PC.tangent(cm, a_, 1)
    t3 = PC.tangent(cm, b_, -1)
    if a_ not in corner:
        t_in = PC.tangent(cm, a_, -1); t0 = (t0 + t_in) / (np.linalg.norm(t0 + t_in) + 1e-9)
    if b_ not in corner:
        t_out = PC.tangent(cm, b_, 1); t3 = (t3 + t_out) / (np.linalg.norm(t3 + t_out) + 1e-9)
    v, err, idx = PC.seg_fit(cm, a_, b_, t0, t3)
    segs.append((a_, b_, t0, t3, v, float(np.max(err)) if len(err) else 0))
raw = [cm[segs[0][0]]]
for a_, b_, t0, t3, v, e in segs:
    raw += [cm[a_] + t0 * v[0], cm[b_] - t3 * v[1], cm[b_]]
sh = {"raw": np.array(raw)}
m = m2
worst = max(e for *_, e in segs) / Z
print("mouth, his 18 points on the frown: worst segment %.2f px off" % worst)
P["mouth-sad"] = ("#363733", ({"raw": sh["raw"] / Z}, 18, worst))
# (a close check at 4x: the picture, the mask's edge in yellow, the cut in blue)
pic4 = cv2.warpAffine(np.asarray(img), M * Z, (CW * Z, CH * Z), flags=cv2.INTER_LINEAR).copy()
ys4, xs4 = np.nonzero(m)
bx0, by0, bx1, by1 = xs4.min() - 20, ys4.min() - 60, xs4.max() + 20, ys4.max() + 20
edge = m - cv2.erode(m, np.ones((3, 3), np.uint8))
pic4[edge > 0] = (255, 220, 0)
cv2.polylines(pic4, [T.sample(sh, 300).round().astype(np.int32)], True, (0, 120, 255), 2)
shp = np.zeros_like(m); cv2.fillPoly(shp, [T.sample(sh, 300).round().astype(np.int32)], 1)
print("mouth at 4x: cut outside the drawn mouth %.1f%%, drawn mouth outside the cut %.1f%%" % (100 * (shp & (1 - m) & seen).sum() / shp.sum(), 100 * (m & (1 - shp) & seen).sum() / m.sum()))
os.makedirs(OUTD, exist_ok=True)
Image.fromarray(pic4[by0:by1, bx0:bx1]).save(f"{OUTD}/check-mouth4.png")
for k, (f, (sh, npts, worst)) in P.items():
    print(k, npts, "points", "worst %.2f" % worst)
# (the right eye and brow: his mirror of the left, about the face's middle)
mir = lambda a_: np.column_stack([2 * MID - a_[:, 0], a_[:, 1]])
P["eyeR-sad"] = (P["eyeL-sad"][0], ({"raw": mir(P["eyeL-sad"][1][0]["raw"])},) + P["eyeL-sad"][1][1:])
P["browR-sad"] = (P["browL-sad"][0], ({"raw": mir(P["browL-sad"][1][0]["raw"])},) + P["browL-sad"][1][1:])
os.makedirs(OUTD, exist_ok=True)
out = {}
for nm, (f, (sh, npts, worst)) in P.items():
    pts = T.sample(sh)
    x0, y0 = np.floor(pts.min(0)) - 3; x1, y1 = np.ceil(pts.max(0)) + 3
    open(f"{OUTD}/{nm}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1-x0:.0f}" height="{y1-y0:.0f}" viewBox="0 0 {x1-x0:.0f} {y1-y0:.0f}">\n<path d="{T.path_d(T.shifted(sh, x0, y0))}" fill="{f}"/></svg>')
    out[nm] = {"w": float(x1 - x0), "h": float(y1 - y0), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2), "points": npts}
json.dump(out, open(f"{OUTD}/place.json", "w"), indent=1)
vis = cv2.warpAffine(np.asarray(img), M, (CW, CH), borderValue=(255, 0, 255)).copy()
for nm, (f, (sh, _, _)) in P.items():
    cv2.polylines(vis, [(T.sample(sh, 200) * 8).round().astype(np.int32)], True, (0, 120, 255), 1, shift=3)
    for q in T.anchors(sh): cv2.circle(vis, (int(q[0]), int(q[1])), 3, (0, 200, 0), -1)
Image.fromarray(vis[120:520, 330:930]).resize((1200, 800), Image.LANCZOS).save(f"{OUTD}/check.png")
Image.fromarray(vis[370:460, 571:681]).resize((1100, 900), Image.NEAREST).save(f"{OUTD}/check-mouth.png")
print("ok")
