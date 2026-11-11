"""The teary open eyes for the Wrong flop's sad face (the owner, 11 Nov 2026, of Codex's three sad-eye options: "3 is kinda funny,
lets try it"), cut from the third head of out/codex/sad-eyes/sad-eyes-options.png, in the head's own layer space.
There's no part of his for an open eye to reshape (lesson 24 starts from his part when there is one), so these are cut by his
principles: round forms with points at their extremes (lesson 1: 4 round the head), as few as hold the shape; the screen-left eye
cut and the right one its mirror about the face's middle (lessons 6, 7).
- the picture put on the rig by the screen-left patch: its box onto the patchL layer's (Codex moved this head's nose and patches)
- the eye: the cream inside the patch's dark rim, with what sits on it (pupil, glints, tear), one round shape
- the pupil: the dark disc on it, its glints filled; the glints: the two white dots; the tear: the blue along the eye's bottom
- each cut at 4x the doc's scale, where the picture's own edge is, then shrunk back
Writes <out>/{eye,tear,pupil,glint}{L,R}-teary.svg, place.json, check.png
usage: teary_eye_cut.py <options.png> <doc.json> <out>"""
import sys, os, json
sys.path.insert(0, 'C:/Users/domch/Documents/Projects/bubu-ios/tools/art')
import cv2, numpy as np
from PIL import Image
import principle_cut as PC, owner_transfer as T
SRC, DOC, OUTD = sys.argv[1], sys.argv[2], sys.argv[3]
MID = 626.5
PAL = {"magenta": (255, 0, 255), "cream": (254, 248, 229), "dark": (54, 56, 51), "pink": (247, 183, 185),
       "white": (255, 255, 255), "blue": (152, 224, 249)}
NM = list(PAL)
# (the third head only, on magenta)
full = np.asarray(Image.open(SRC).convert("RGB"))
a8 = np.full((560, 600, 3), (255, 0, 255), np.uint8)
a8[30:30 + 500, 30:30 + 536] = full[250:750, 1000:1536]
img = Image.fromarray(a8)
a = a8.astype(float)
lab = np.argmin(((a[:, :, None, :] - np.array(list(PAL.values()), float)[None, None]) ** 2).sum(-1), -1)
dark0 = (lab == NM.index("dark")).astype(np.uint8)
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
blob = (cc == nose_i)
ys, xs = np.nonzero(blob)
rows = {y: xs[ys == y] for y in range(ys.min(), ys.max() + 1)}
wid = {y: r.max() - r.min() for y, r in rows.items() if len(r)}
wmax = max(wid.values())
nose_rows = [y for y in sorted(wid) if wid[y] > 0.25 * wmax]
nb = nose_rows[0]
for y in sorted(wid):
    if y > nose_rows[0] and wid[y] < 0.25 * wmax:
        break
    nb = y
nr = np.array([[r.min(), r.max()] for y, r in rows.items() if y <= nb])
pn = np.array([(nr[:, 0].min() + nr[:, 1].max()) / 2, (ys.min() + nb) / 2])
src = np.array([pl, pr, pn]); dst = np.array([box(Ly["patchL"]), box(Ly["patchR"]), box(Ly["nose"])])
sm, dm = src.mean(0), dst.mean(0)
s = np.sqrt(((dst - dm) ** 2).sum() / ((src - sm) ** 2).sum())
t = dm - s * sm
print("scale", round(s, 4), "fit error", np.round(np.linalg.norm(s * src + t - dst, axis=1), 1))
# (Codex drew this head a little differently: its patches sit closer and its nose lower, so the three-point fit is off by tens of
# px. Only the eyes are taken, so the picture is put on the screen-left patch alone: its box onto the patchL layer's box, one
# scale, centres together)
lp = Ly["patchL"]
s = float(np.sqrt(lp["w"] * lp["h"] / (st[patches[0], 2] * st[patches[0], 3])))
t = np.array(box(lp)) - s * pl
print("on the patch: scale %.4f (w %.3f, h %.3f)" % (s, lp["w"] / st[patches[0], 2], lp["h"] / st[patches[0], 3]))
M = np.float32([[s, 0, t[0]], [0, s, t[1]]])
CW, CH = 1254, 900
Z = 4
up = lambda m: (cv2.warpAffine(m.astype(np.float32), M * Z, (CW * Z, CH * Z), flags=cv2.INTER_LINEAR) > 0.5).astype(np.uint8)
L = {k: up(lab == NM.index(k)) for k in ("dark", "cream", "white", "blue")}
patch4 = up(cc == patches[0])
fill = lambda m: cv2.drawContours(np.zeros_like(m), cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)[0], -1, 1, -1)
biggest = lambda m: (lambda n_, c_, s_, _: (c_ == max(range(1, n_), key=lambda i: s_[i, 4])).astype(np.uint8))(*cv2.connectedComponentsWithStats(m))
pf = fill(patch4)
# the eye: everything inside the rim (the patch's hole), filled
hole = (pf & (1 - patch4)).astype(np.uint8)
eye = fill(biggest(cv2.morphologyEx(hole, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))))
# the pupil: the dark inside the eye, its glints filled
pupil = fill(biggest(cv2.erode(L["dark"], np.ones((3, 3), np.uint8)) & cv2.erode(eye, np.ones((9, 9), np.uint8))))
pupil = cv2.dilate(pupil, np.ones((3, 3), np.uint8))
# the glints: the white dots on the pupil, the two biggest
n7, c7, s7, _ = cv2.connectedComponentsWithStats(L["white"] & cv2.dilate(pupil, np.ones((9, 9), np.uint8)))
gl = sorted(range(1, n7), key=lambda i: -s7[i, 4])[:2]
glints = [(c7 == i).astype(np.uint8) for i in gl]
# the tear: the blue on the eye
tear = biggest(L["blue"] & eye)
P = {}
def cut(name, m, fill_, maxp, tol=0.5):
    sh, npts, worst = PC.cut(m, None, tol=tol * Z, max_points=maxp)
    P[name] = (fill_, [({"raw": sh["raw"] / Z}, npts, worst / Z)])
cut("eyeL-teary", eye, "#fef8e8", 6)
cut("tearL-teary", tear, "#98e0f9", 8)
cut("pupilL-teary", pupil, "#363733", 4)
P["glintL-teary"] = ("#ffffff", [])
# (the glints are a few px across: a cut finds pixel corners on them, so each is drawn as the circle of its area, 4 points at
# its extremes with the circle's handles)
K = 0.5523
for g in glints:
    yy, xx = np.nonzero(g)
    c0 = np.array([xx.mean(), yy.mean()]) / Z; r = np.sqrt(len(xx) / np.pi) / Z
    q = [c0 + r * np.array(v) for v in ((1, 0), (0, 1), (-1, 0), (0, -1))]
    raw = [q[0]]
    for i in range(4):
        p0, p1 = q[i], q[(i + 1) % 4]
        raw += [p0 + K * (p1 - c0 - (p0 - c0) * 0) * 0 + K * np.array([-(p0 - c0)[1], (p0 - c0)[0]]), p1 + K * np.array([(p1 - c0)[1], -(p1 - c0)[0]]), p1]
    P["glintL-teary"][1].append(({"raw": np.array(raw)}, 4, 0.0))
    print("glint r %.1f" % r)
for k, (f, parts) in P.items():
    print(k, [(p[1], round(p[2], 2)) for p in parts])
# (the right eye: his mirror of the left, about the face's middle)
mir = lambda a_: np.column_stack([2 * MID - a_[:, 0], a_[:, 1]])
for k in list(P):
    P[k.replace("L-", "R-")] = (P[k][0], [({"raw": mir(p[0]["raw"])},) + p[1:] for p in P[k][1]])
os.makedirs(OUTD, exist_ok=True)
out = {}
for nm, (f, parts) in P.items():
    pts = np.vstack([T.sample(p[0]) for p in parts])
    x0, y0 = np.floor(pts.min(0)) - 3; x1, y1 = np.ceil(pts.max(0)) + 3
    paths = "\n".join(f'<path d="{T.path_d(T.shifted(p[0], x0, y0))}" fill="{f}"/>' for p in parts)
    open(f"{OUTD}/{nm}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{x1-x0:.0f}" height="{y1-y0:.0f}" viewBox="0 0 {x1-x0:.0f} {y1-y0:.0f}">\n{paths}</svg>')
    out[nm] = {"w": float(x1 - x0), "h": float(y1 - y0), "x": float((x0 + x1) / 2), "y": float((y0 + y1) / 2),
               "points": [p[1] for p in parts]}
json.dump(out, open(f"{OUTD}/place.json", "w"), indent=1)
vis = cv2.warpAffine(np.asarray(img), M, (CW, CH), borderValue=(255, 0, 255)).copy()
for nm, (f, parts) in P.items():
    for p in parts:
        cv2.polylines(vis, [(T.sample(p[0], 200) * 8).round().astype(np.int32)], True, (0, 120, 255), 1, shift=3)
        for q in T.anchors(p[0]): cv2.circle(vis, (int(q[0]), int(q[1])), 2, (0, 200, 0), -1)
pxl = np.nonzero(pf)[1].min() // Z; pyt = np.nonzero(pf)[0].min() // Z
Image.fromarray(vis[pyt - 20:pyt + 200, pxl - 20:pxl + 520]).resize((1620, 660), Image.LANCZOS).save(f"{OUTD}/check.png")
print("ok")
