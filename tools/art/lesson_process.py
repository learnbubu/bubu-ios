"""How the owner works a shape out by eye, from a recording (the owner, 4 Nov 2026: "not everything is going to be the same, but we
need to learn how I work things out by eye"). Not his final shape, which the lessons keep, but his way to it:
- step by step, which point he moved (or added, or took out), how far, and whether only its handles changed
- where that point is: on the drawing's visible edge or hidden under another part, and whether the move brought it onto the drawn edge
  or took it off it on purpose
- per part: the order he visited the points in, how the moves shrink from rough to fine, and how long each stage took

From tools/art: ../sfx/.venv/Scripts/python -I lesson_process.py lessons/recordings/<file> [--model out/raw/rm-rest-quarter.png]
Prints the steps and a summary, and writes out/lessons/<file>-process.json for the catalogue.
"""
import json
import math
import os
import re
import sys
import cv2
import numpy as np
from PIL import Image

S = 1254
src = sys.argv[1]
MODEL = sys.argv[sys.argv.index("--model") + 1] if "--model" in sys.argv else "out/raw/rm-rest-a-happy.png"
name = os.path.splitext(os.path.basename(src))[0]
lines = [json.loads(l) for l in open(src, encoding="utf-8")]

# the drawing's edges: where one flat colour meets another
PALETTE = {"magenta": (255, 0, 255), "cream": (253, 248, 231), "dark": (54, 56, 51), "red": (244, 95, 68), "pink": (247, 183, 185),
           "grey": (146, 145, 140)}
im = np.asarray(Image.open(MODEL).convert("RGB").resize((S, S))).astype(float)
lab = np.argmin(((im[:, :, None, :] - np.array(list(PALETTE.values()), float)[None, None]) ** 2).sum(-1), -1).astype(np.uint8)
lab = cv2.medianBlur(lab, 5)
edge = np.zeros((S, S), np.uint8)
edge[:, 1:] |= (lab[:, 1:] != lab[:, :-1]).astype(np.uint8)
edge[1:, :] |= (lab[1:, :] != lab[:-1, :]).astype(np.uint8)
dist = cv2.distanceTransform((1 - edge).astype(np.uint8), cv2.DIST_L2, 5)
to_edge = lambda p: float(dist[min(S - 1, max(0, round(p[1]))), min(S - 1, max(0, round(p[0])))])


def anchors(d, place, box):
    """an SVG path's points in the composition: (point, in handle, out handle) each"""
    n = [float(x) for x in re.findall(r"-?[\d.]+(?:e-?\d+)?", d)]
    p = np.array(n).reshape(-1, 2)
    k = place["w"] / box[2] * place.get("scale", 1)
    p = np.stack([place["x"] + (p[:, 0] - box[0] - box[2] / 2) * k, place["y"] + (p[:, 1] - box[1] - box[3] / 2) * k], 1)
    m = (len(p) - 1) // 3
    return [(p[3 * i], p[(3 * i - 1) % (len(p) - 1)], p[3 * i + 1]) for i in range(m)]


steps = []
for e in lines:
    if e.get("kind") != "shapes" or not e.get("changed") or not e.get("place"):
        continue
    box = e.get("svgBox")
    for ch in e["changed"]:
        fr, to = ch.get("from"), ch.get("to")
        if not fr or not to or "d" not in fr or "d" not in to:
            continue
        a, b = anchors(fr["d"], e["place"], box), anchors(to["d"], e["place"], box)
        st = {"t": e["t"] / 1000, "layer": e["layer"], "what": e.get("after", ""), "shape": ch.get("index", 0)}
        if len(a) != len(b):
            # a point added or taken out: where (the new one: furthest from any old point)
            new, old = (b, a) if len(b) > len(a) else (a, b)
            far = max(new, key=lambda q: min(math.dist(q[0], o[0]) for o in old))
            st.update(kind="add" if len(b) > len(a) else "remove", at=[round(far[0][0]), round(far[0][1])], points=len(b),
                      edge=round(to_edge(far[0]), 1))
        else:
            moved = [(i, math.dist(a[i][0], b[i][0]), max(math.dist(a[i][1], b[i][1]), math.dist(a[i][2], b[i][2])))
                     for i in range(len(a))]
            pts = [m for m in moved if m[1] > 0.3]
            hds = [m for m in moved if m[1] <= 0.3 and m[2] > 0.3]
            if not pts and not hds:
                continue
            if pts:
                i, d, _ = max(pts, key=lambda m: m[1])
                st.update(kind="point", index=i, at=[round(b[i][0][0]), round(b[i][0][1])], moved=round(d, 1), points=len(b),
                          edge_before=round(to_edge(a[i][0]), 1), edge_after=round(to_edge(b[i][0]), 1), many=len(pts))
            else:
                i, _, h = max(hds, key=lambda m: m[2])
                st.update(kind="handle", index=i, at=[round(b[i][0][0]), round(b[i][0][1])], moved=round(h, 1), points=len(b))
        steps.append(st)

for s in steps:
    if s["kind"] == "point":
        towards = "onto the edge" if s["edge_after"] < s["edge_before"] - 0.5 else "off the edge" if s["edge_after"] > s["edge_before"] + 0.5 else "along it"
        print(f"{s['t']:7.1f}s  {s['layer']:<14} point {s['index']:>2} {'(+' + str(s['many'] - 1) + ' more) ' if s['many'] > 1 else ''}moved {s['moved']:5.1f} px  {towards:<13} now {s['edge_after']:5.1f} px from a drawn edge  at {s['at']}")
    elif s["kind"] == "handle":
        print(f"{s['t']:7.1f}s  {s['layer']:<14} point {s['index']:>2} handles only, {s['moved']:.1f} px  at {s['at']}")
    else:
        print(f"{s['t']:7.1f}s  {s['layer']:<14} {s['kind']} a point at {s['at']} ({s['points']} now), {s['edge']} px from a drawn edge")

print("\n--- how he worked, part by part")
summary = {}
for layer in dict.fromkeys(s["layer"] for s in steps):
    ss = [s for s in steps if s["layer"] == layer]
    pts = [s for s in ss if s["kind"] == "point"]
    t0, t1 = ss[0]["t"], ss[-1]["t"]
    order = []
    for s in pts:
        if not order or order[-1] != s["index"]:
            order.append(s["index"])
    third = max(1, len(pts) // 3)
    early, late = pts[:third], pts[-third:]
    mean = lambda xs: round(float(np.mean(xs)), 1) if xs else 0
    on = [s for s in pts if s["edge_after"] < 3]
    info = {"seconds": round(t1 - t0, 1), "steps": len(ss), "point moves": len(pts),
            "handle-only": sum(s["kind"] == "handle" for s in ss), "added": sum(s["kind"] == "add" for s in ss),
            "removed": sum(s["kind"] == "remove" for s in ss), "points at the end": ss[-1]["points"],
            "order of points": order, "first moves (px)": mean([s["moved"] for s in early]),
            "last moves (px)": mean([s["moved"] for s in late]),
            "moves ending on a drawn edge": f"{len(on)} of {len(pts)}",
            "moves left off the edge (hidden or by eye)": [s["index"] for s in pts if s["edge_after"] >= 3]}
    summary[layer] = info
    print(f"{layer}: {info['seconds']} s, {info['steps']} steps ({info['point moves']} point moves, {info['handle-only']} handle-only, "
          f"{info['added']} added, {info['removed']} taken out), {info['points at the end']} points")
    print(f"   order he visited the points: {order}")
    print(f"   moves shrank from about {info['first moves (px)']} px to {info['last moves (px)']} px; "
          f"{info['moves ending on a drawn edge']} ended on a drawn edge")
    off = sorted(set(info["moves left off the edge (hidden or by eye)"]))
    if off:
        print(f"   points he put off any drawn edge: {off} (hidden parts, or shaped by eye)")
os.makedirs("out/lessons", exist_ok=True)
json.dump({"recording": name, "steps": steps, "summary": summary}, open(f"out/lessons/{name}-process.json", "w"), indent=1)
