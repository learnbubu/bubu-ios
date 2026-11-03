"""Bùbù's puppet, step 2 of PUPPET.md: the front rest pose (out/raw/rm-rest-a-happy.png) traced into whole vector parts, the hidden bits
drawn in full (ears as whole ovals behind the head, arm tops round under the shoulder, leg tops round under the belly, a whole torso behind
the belly and straps), limbs split at wrist and ankle with round overlapping ends. Writes each part as an SVG into Studio's art/bubu-puppet/,
the document "bubu-puppet" (parented as PUPPET.md section 4), and two checks into out/puppet/: rebuilt.png (the parts laid back together beside
the original) and joints.png (every joint turned 45 degrees both ways, to look for gaps).

From tools/art: ../sfx/.venv/Scripts/python -I puppet_trace.py
"""
import json
import math
import os
import cv2
import numpy as np
from PIL import Image

SRC = "out/raw/rm-rest-a-happy.png"
ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = "bubu-puppet"
ART = f"{ROOT}/art/{DOC}"
OUT = "out/puppet"
PALETTE = {"magenta": (255, 0, 255), "cream": (253, 248, 231), "dark": (54, 56, 51), "red": (244, 95, 68), "pink": (247, 183, 185), "grey": (146, 145, 140)}
NAMES = list(PALETTE)
HEX = {k: "#%02x%02x%02x" % v for k, v in PALETTE.items()}

im = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
P = np.array(list(PALETTE.values()), float)
label = np.argmin(((im[:, :, None, :] - P[None, None]) ** 2).sum(-1), -1)
S = im.shape[0]
K3 = np.ones((3, 3), np.uint8)


def colour(name):
    m = (label == NAMES.index(name)).astype(np.uint8)
    return cv2.morphologyEx(cv2.morphologyEx(m, cv2.MORPH_OPEN, K3), cv2.MORPH_CLOSE, K3)


def comp(mask, x, y):
    """the piece of mask nearest (x, y)"""
    n, cc = cv2.connectedComponents(mask)
    ys, xs = np.nonzero(cc)
    k = cc[ys[np.argmin((xs - x) ** 2 + (ys - y) ** 2)], xs[np.argmin((xs - x) ** 2 + (ys - y) ** 2)]]
    return (cc == k).astype(np.uint8)


def filled(mask):
    """holes filled: the outline's whole inside"""
    cs, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    out = np.zeros_like(mask)
    cv2.drawContours(out, cs, -1, 1, -1)
    return out


def disc(cx, cy, rx, ry=None, angle=0):
    m = np.zeros((S, S), np.uint8)
    cv2.ellipse(m, (round(cx), round(cy)), (round(rx), round(ry or rx)), angle, 0, 360, 1, -1)
    return m


def half(mask, p, n, keep_front):
    """the side of the line through p with normal n: in front of it (keep_front) or behind"""
    yy, xx = np.mgrid[0:S, 0:S]
    side = (xx - p[0]) * n[0] + (yy - p[1]) * n[1]
    return mask * ((side >= 0) if keep_front else (side < 0)).astype(np.uint8)


cream, dark, red, pink, grey = (colour(c) for c in ("cream", "dark", "red", "pink", "grey"))
parts = {}  # name -> list of (mask, colour name)


def ear(x, y):
    cs, _ = cv2.findContours(comp(dark, x, y), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    (cx, cy), (w, h), a = cv2.fitEllipse(max(cs, key=len))
    seen = comp(dark, x, y)
    # the drawn ear as it is, carried on as the fitted oval only where the head covers it
    return seen | disc(cx, cy, w / 2, h / 2, a) * head, (cx, cy)


head = filled(comp(cream, 625, 300))
earL, earLc = ear(400, 150)
earR, earRc = ear(850, 150)
parts["earL"], parts["earR"] = [(earL, "dark")], [(earR, "dark")]
head = filled(comp(cream, 625, 300))
parts["head"] = [(head, "cream")]
for side, x in (("L", 495), ("R", 758)):
    parts[f"brow{side}"] = [(comp(dark, x, 230), "dark")]
    parts[f"patch{side}"] = [(filled(comp(dark, x - 5, 350)), "dark")]
    parts[f"eye{side}"] = [(comp(cream, x, 347), "cream")]
    parts[f"cheek{side}"] = [(comp(pink, x - 70 if side == "L" else x + 70, 460), "pink")]
nm = comp(dark, 627, 410)
yy = np.mgrid[0:S, 0:S][0]
parts["nose"] = [(nm * (yy < 401), "dark")]
parts["mouth"] = [(nm * (yy >= 401), "dark")]
belly = comp(cream, 624, 850)
strapL, strapR = comp(red, 446, 700), comp(red, 806, 700)
chest = comp(dark, 627, 640)
hull = cv2.convexHull(np.argwhere((chest | strapL | strapR | belly) > 0)[:, ::-1].astype(np.int32))
torso = np.zeros((S, S), np.uint8)
cv2.fillPoly(torso, [hull], 1)
torso |= disc(627, 960, 245, 95) * (yy < 1050)  # the hips under the belly, so splayed legs never open a gap
parts["torso"], parts["belly"], parts["strapL"], parts["strapR"] = [(torso, "dark")], [(belly, "cream")], [(strapL, "red")], [(strapR, "red")]

pivots = {}
for side, (x, y) in (("L", (330, 720)), ("R", (920, 720))):
    arm = comp(dark, x, y)
    pts = np.argwhere(arm > 0)[:, ::-1].astype(float)
    c = pts.mean(0)
    axis = np.linalg.svd(pts - c, full_matrices=False)[2][0]
    if axis[1] < 0:
        axis = -axis  # from the shoulder (top) down to the paw
    proj = (pts - c) @ axis
    top, end = c + axis * proj.min(), c + axis * proj.max()
    width = np.percentile(np.abs((pts - c) @ np.array([-axis[1], axis[0]])), 97) * 2
    r = width / 2
    shoulder = top + axis * r * 0.9
    wrist = top + (end - top) * 0.7
    # the round top carries on only where the torso covers it at rest, so nothing pokes out
    tip = filled(arm | disc(*shoulder, r) * torso)
    parts[f"arm{side}"] = [(half(tip, wrist + axis * r * 0.35, axis, False) | disc(*wrist, r * 0.92), "dark")]
    paw = half(tip, wrist - axis * r * 0.1, axis, True) | disc(*wrist, r * 0.92) * half(np.ones((S, S), np.uint8), wrist - axis * r * 0.6, axis, True)
    toes = grey * half(np.ones((S, S), np.uint8), wrist, axis, True) * (np.abs(np.mgrid[0:S, 0:S][1] - end[0]) < 120)
    parts[f"paw{side}"] = [(paw, "dark"), (toes, "grey")]
    pivots[f"arm{side}"], pivots[f"paw{side}"] = tuple(shoulder), tuple(wrist)
for side, (x, y) in (("L", (480, 1060)), ("R", (770, 1060))):
    leg = comp(dark, x, y)
    rows = np.nonzero(leg[960])[0]
    cx, hw = (rows.min() + rows.max()) / 2, (rows.max() - rows.min()) / 2
    hip = (cx + (20 if side == "L" else -20), 930)
    leg = leg | disc(cx, 900, hw * 1.12, 120) * (torso | belly)  # its top carries on round under the belly
    ankle_rows = np.nonzero(leg[1110])[0]
    ax, ahw = (ankle_rows.min() + ankle_rows.max()) / 2, (ankle_rows.max() - ankle_rows.min()) / 2
    parts[f"leg{side}"] = [(leg * (yy < 1135) | disc(ax, 1115, ahw * 0.95), "dark")]
    parts[f"foot{side}"] = [((leg * (yy >= 1105)) | disc(ax, 1125, ahw * 0.9, ahw * 0.55), "dark"), (grey * (yy > 1100) * (np.abs(np.mgrid[0:S, 0:S][1] - ax) < 140), "grey")]
    pivots[f"leg{side}"], pivots[f"foot{side}"] = hip, (ax, 1115)

# back to front, as PUPPET.md section 3
ORDER = ["earL", "earR", "legL", "legR", "footL", "footR", "torso", "armL", "armR", "pawL", "pawR", "belly", "strapL", "strapR", "head",
         "cheekL", "cheekR", "patchL", "patchR", "eyeL", "eyeR", "browL", "browR", "nose", "mouth"]
PARENT = {"earL": "head", "earR": "head", "legL": "hips", "legR": "hips", "footL": "legL", "footR": "legR", "torso": "hips", "armL": "torso",
          "armR": "torso", "pawL": "armL", "pawR": "armR", "belly": "torso", "strapL": "torso", "strapR": "torso", "head": "torso"}
for f in ("cheekL", "cheekR", "patchL", "patchR", "browL", "browR", "nose", "mouth"):
    PARENT[f] = "head"
PARENT["eyeL"], PARENT["eyeR"] = "patchL", "patchR"
hb = cv2.boundingRect(head)
pivots.update({"head": (hb[0] + hb[2] / 2, hb[1] + hb[3] - 20), "earL": earLc, "earR": earRc, "torso": (627, 900)})
HIPS = (627, 900)


def contours(mask):
    cs, _ = cv2.findContours(mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    return [cv2.approxPolyDP(c, 1.0, True)[:, 0, :].astype(float) for c in cs if cv2.contourArea(c) > 20]


def smooth_path(pts, ox, oy):
    """a closed Catmull-Rom curve through the points, as cubic beziers"""
    n = len(pts)
    p = lambda i: pts[i % n] - (ox, oy)
    d = "M%.1f %.1f" % tuple(p(0))
    for i in range(n):
        p0, p1, p2, p3 = p(i - 1), p(i), p(i + 1), p(i + 2)
        c1, c2 = p1 + (p2 - p0) / 6, p2 - (p3 - p1) / 6
        d += "C%.1f %.1f %.1f %.1f %.1f %.1f" % (*c1, *c2, *p2)
    return d + "Z"


def sampled(pts):
    """the same curve, sampled, for the checks"""
    n, out = len(pts), []
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1, c2 = p1 + (p2 - p0) / 6, p2 - (p3 - p1) / 6
        for t in np.linspace(0, 1, 6, endpoint=False):
            out.append((1 - t) ** 3 * p1 + 3 * (1 - t) ** 2 * t * c1 + 3 * (1 - t) * t * t * c2 + t ** 3 * p2)
    return np.array(out)


os.makedirs(ART, exist_ok=True)
os.makedirs(OUT, exist_ok=True)
layers, drawn = [], {}
for name in ORDER:
    pieces = [(contours(m), c) for m, c in parts[name]]
    allpts = np.concatenate([q for cs, _ in pieces for q in cs])
    x0, y0 = allpts.min(0) - 3
    x1, y1 = allpts.max(0) + 3
    w, h = x1 - x0, y1 - y0
    paths = "".join(f'<path fill="{HEX[c]}" d="{"".join(smooth_path(q, x0, y0) for q in cs)}"/>' for cs, c in pieces)
    open(f"{ART}/{name}.svg", "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.1f}" height="{h:.1f}" viewBox="0 0 {w:.1f} {h:.1f}">{paths}</svg>')
    rgba = np.zeros((S, S, 4), np.uint8)
    for cs, c in pieces:
        m = np.zeros((S, S), np.uint8)
        cv2.fillPoly(m, [np.round(sampled(q)).astype(np.int32) for q in cs], 1)
        rgba[m > 0] = PALETTE[c] + (255,)
    drawn[name] = rgba
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    pv = pivots.get(name, (cx, cy))
    layers.append({"id": name, "name": name, "art": f"{name}.svg", "w": round(w, 1), "h": round(h, 1), "x": round(cx, 1), "y": round(cy, 1), "scale": 1,
                   "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": round(pv[0], 1), "y": round(pv[1], 1)},
                   "keys": {}, "loop": 0, "blink": 0, "parent": PARENT.get(name)})
layers.insert(0, {"id": "hips", "name": "hips", "art": "", "w": 60, "h": 60, "x": HIPS[0], "y": HIPS[1], "scale": 1, "rotation": 0, "flipX": False, "opacity": 1,
                  "visible": True, "locked": False, "pivot": {"x": HIPS[0], "y": HIPS[1]}, "keys": {}, "loop": 0, "blink": 0, "nullObj": True})
doc = {"id": DOC, "name": "Bùbù Puppet", "width": S, "height": S, "duration": 2000, "loop": True, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if DOC not in project["docs"]:
    project["docs"].append(DOC)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)


def pose(turns, bg=(255, 255, 255)):
    """the parts composited with each one turned about its pivot (degrees), carried by its parents"""
    def mat(name):
        if name is None or name == "hips":
            return np.eye(3)
        px, py = pivots.get(name, (layers[[l["id"] for l in layers].index(name)]["pivot"][k] for k in "xy"))
        a = math.radians(turns.get(name, 0))
        r = np.array([[math.cos(a), -math.sin(a), px - px * math.cos(a) + py * math.sin(a)], [math.sin(a), math.cos(a), py - px * math.sin(a) - py * math.cos(a)], [0, 0, 1]])
        return mat(PARENT.get(name)) @ r
    canvas = Image.new("RGBA", (S, S), bg + (255,))
    for name in ORDER:
        m = mat(name)
        if np.allclose(m, np.eye(3)):
            part = Image.fromarray(drawn[name])
        else:
            inv = np.linalg.inv(m)
            part = Image.fromarray(drawn[name]).transform((S, S), Image.AFFINE, tuple(inv[:2].ravel()), Image.BICUBIC)
        canvas.alpha_composite(part)
    return canvas.convert("RGB")


rest = pose({})
orig = Image.open(SRC).convert("RGB")
key = (np.asarray(orig).astype(int) - (255, 0, 255))
orig_w = np.asarray(orig).copy()
orig_w[(np.abs(key).sum(-1) < 120)] = 255
diff = np.abs(np.asarray(rest).astype(int) - orig_w.astype(int)).max(-1) > 60
print("rebuilt vs original: %.2f%% of pixels differ" % (diff.mean() * 100))
side = Image.new("RGB", (S * 2, S), "white")
side.paste(Image.fromarray(orig_w.astype("uint8")), (0, 0))
side.paste(rest, (S, 0))
side.resize((S, S // 2)).save(f"{OUT}/rebuilt.png")
tests = [{}, {"armL": 45, "armR": -45}, {"armL": -45, "armR": 45}, {"legL": 30, "legR": -30, "footL": -20, "footR": 20},
         {"head": 15, "earL": -15, "earR": 15}, {"pawL": 40, "pawR": -40, "armL": -20, "armR": 20}]
sheet = Image.new("RGB", (len(tests) * 420, 420), "white")
for k, t in enumerate(tests):
    sheet.paste(pose(t).resize((420, 420)), (k * 420, 0))
sheet.save(f"{OUT}/joints.png")
print(len(ORDER), "parts written to", ART)

# every part alone, outlined, to see each one is a whole, clean shape
names = ["torso", "armL", "pawL", "legL", "footL", "head", "earL", "belly", "strapL"]
tiles = []
for name in names:
    a = drawn[name]
    ys, xs = np.nonzero(a[..., 3])
    crop = Image.fromarray(a[ys.min() - 20:ys.max() + 20, xs.min() - 20:xs.max() + 20])
    bg = Image.new("RGBA", crop.size, (190, 200, 215, 255))
    bg.alpha_composite(crop)
    m = (np.asarray(crop)[..., 3] > 0).astype(np.uint8)
    edge = cv2.dilate(m, K3) - m
    arr = np.asarray(bg).copy()
    arr[edge > 0] = (255, 0, 120, 255)
    t = Image.fromarray(arr).convert("RGB")
    t.thumbnail((300, 300))
    tiles.append(t)
sheet = Image.new("RGB", (300 * len(tiles), 300), "white")
for k, t in enumerate(tiles):
    sheet.paste(t, (k * 300, 0))
sheet.save(f"{OUT}/parts.png")
