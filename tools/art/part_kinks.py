"""Spikes and pinches in a document's vector parts, hidden or not (the owner's strap fix, 4 Nov 2026: Claude's strap had a spike
and a flag on its hidden ends that nothing flagged, because they're covered at rest; they'd show the moment it moves). Each outline
is walked closely, and every sharp turn is listed with where it is in the composition.

From tools/art: ../sfx/.venv/Scripts/python -I part_kinks.py [doc] [degrees, default 50]
"""
import json
import math
import re
import sys
import numpy as np

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = sys.argv[1] if len(sys.argv) > 1 else "bubu-puppet-front"
LIMIT = float(sys.argv[2]) if len(sys.argv) > 2 else 50
doc = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))
found = 0
for l in doc["layers"]:
    if not l.get("art", "").endswith(".svg"):
        continue
    t = open(f"{ROOT}/art/{DOC}/{l['art']}").read()
    vb = [float(v) for v in re.search(r'viewBox="([^"]+)"', t).group(1).split()]
    k = l["w"] / vb[2]
    x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    for si, el in enumerate(re.findall(r"<path\b[^>]*/>", t)):
        d = re.search(r' d="([^"]+)"', el).group(1)
        if re.search(r"[LlHhVvSsQqTtAa]", d):
            continue
        tr = re.search(r"translate\(([-\d.]+),([-\d.]+)\)", el)
        tx, ty = (float(tr.group(1)), float(tr.group(2))) if tr else (0, 0)
        p = np.array([float(v) for v in re.findall(r"-?[\d.]+(?:e-?\d+)?", d)]).reshape(-1, 2) + [tx, ty]
        pts, cur = [], p[0]
        for i in range(1, len(p) - 2, 3):
            c1, c2, e = p[i], p[i + 1], p[i + 2]
            for s in np.linspace(0, 1, 40, endpoint=False):
                u = 1 - s
                pts.append(u ** 3 * cur + 3 * u * u * s * c1 + 3 * u * s * s * c2 + s ** 3 * e)
            cur = e
        pts = np.array(pts)
        # (a turn over ~3 units either side, so a tight but smooth round end isn't counted)
        bad = []
        n = len(pts)
        for i in range(n):
            a, b, c = pts[i - 3], pts[i], pts[(i + 3) % n]
            v1, v2 = b - a, c - b
            if np.linalg.norm(v1) < 0.3 or np.linalg.norm(v2) < 0.3:
                continue
            turn = math.degrees(math.acos(np.clip(v1 @ v2 / np.linalg.norm(v1) / np.linalg.norm(v2), -1, 1)))
            if turn > LIMIT:
                bad.append((turn, x0 + (b[0] - vb[0]) * k, y0 + (b[1] - vb[1]) * k))
        # (one line per spike: neighbours on the same spike folded together)
        spikes = []
        for turn, x, y in sorted(bad, reverse=True):
            if all(math.dist((x, y), s[1:]) > 8 for s in spikes):
                spikes.append((turn, x, y))
        for turn, x, y in spikes:
            found += 1
            print(f"{l['id']:<8} shape {si}: a {turn:.0f} degree turn at ({x:.0f}, {y:.0f})")
print(f"{found} sharp turns over {LIMIT:.0f} degrees in {DOC}")
