"""Rewatch a lesson: a Studio recording played back from its own lines (every shape step carries its whole outline), as a contact sheet
of the shape growing over the model, step by step, with the time and what was done, and the notes. For when a cut gets stuck: watch
how the owner did the nearest part before trying again.

From tools/art: ../sfx/.venv/Scripts/python -I lesson_replay.py lessons/recordings/<name>.jsonl [frames]
Writes out/lessons/<name>.png (the sheet) and prints the steps.
"""
import json
import os
import re
import sys
from PIL import Image, ImageDraw

S = 1254
src = sys.argv[1]
want = int(sys.argv[2]) if len(sys.argv) > 2 else 16
name = os.path.splitext(os.path.basename(src))[0]
lines = [json.loads(l) for l in open(src, encoding="utf-8")]


def outline(d, place, box):
    """an SVG path's outline in the composition's units (the layer's place, size and scale)"""
    n = [float(x) for x in re.findall(r"-?[\d.]+", d)]
    k = place["w"] / box[2] * place["scale"]
    to = lambda x, y: (place["x"] + (x - box[0] - box[2] / 2) * k, place["y"] + (y - box[1] - box[3] / 2) * k)
    cur, pts, anc, i = (n[0], n[1]), [to(n[0], n[1])], [to(n[0], n[1])], 2
    while i + 5 < len(n):
        c1, c2, e = (n[i], n[i + 1]), (n[i + 2], n[i + 3]), (n[i + 4], n[i + 5])
        i += 6
        for s in range(1, 13):
            t = s / 12
            u = 1 - t
            pts.append(to(*(u ** 3 * cur[j] + 3 * u * u * t * c1[j] + 3 * u * t * t * c2[j] + t ** 3 * e[j] for j in (0, 1))))
        cur = e
        anc.append(to(*e))
    return pts, anc[:-1]


# the shapes on each layer, step by step
state, frames = {}, []
for l in lines:
    if l["kind"] == "note":
        print(f"  {l['t'] / 1000:6.1f}s  NOTE: {l['text']}")
    if l["kind"] != "shapes":
        continue
    shapes = state.setdefault(l["layer"], [])
    for a in l.get("added", []):
        shapes.insert(a["index"], a["d"])
    for c in l.get("changed", []):
        # (a layer drawn before the recording started: its shapes are first seen as they change)
        while len(shapes) <= c["index"]:
            shapes.append(None)
        if shapes[c["index"]] is None:
            shapes[c["index"]] = c["from"]["d"]
            frames.append((l["t"], "as it was", l["layer"], {k: list(v) for k, v in state.items()}, l["place"], l["svgBox"]))
        shapes[c["index"]] = c["to"]["d"]
    if l.get("was") and len(shapes) < l["count"]:
        shapes.extend([None] * (l["count"] - len(shapes)))
    for r in l.get("removed", []):
        if r["d"] in shapes:
            shapes.remove(r["d"])
    frames.append((l["t"], l["after"], l["layer"], {k: list(v) for k, v in state.items()}, l["place"], l["svgBox"]))
    print(f"  {l['t'] / 1000:6.1f}s  {l['after']:<18} {l['layer']}: {len(shapes)} shapes")

if not frames:
    sys.exit("no shape steps in this recording")
pick = sorted({round(i * (len(frames) - 1) / max(1, want - 1)) for i in range(want)})
# the part's area: everything drawn, with a margin
allp = [p for f in frames for ds in f[3].values() for d in ds if d for p in outline(d, f[4], f[5])[0]]
x0, y0 = max(0, min(p[0] for p in allp) - 40), max(0, min(p[1] for p in allp) - 40)
x1, y1 = min(S, max(p[0] for p in allp) + 40), min(S, max(p[1] for p in allp) + 40)
model = Image.open("out/raw/rm-rest-a-happy.png").convert("RGBA").resize((S, S))
tw = 320
th = round(tw * (y1 - y0) / (x1 - x0))
cols = 4
sheet = Image.new("RGB", (cols * tw, ((len(pick) + cols - 1) // cols) * (th + 22)), (255, 255, 255))
for k, i in enumerate(pick):
    t, what, layer, st, place, box = frames[i]
    ov = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(ov)
    for ds in st.values():
        for path in ds:
            if not path:
                continue
            pts, anc = outline(path, place, box)
            d.polygon(pts, fill=(0, 160, 255, 80))
            d.line(pts + [pts[0]], fill=(0, 90, 255, 255), width=3)
            for a in anc:
                d.ellipse((a[0] - 5, a[1] - 5, a[0] + 5, a[1] + 5), fill=(255, 0, 0, 255))
    tile = Image.alpha_composite(model, ov).crop((int(x0), int(y0), int(x1), int(y1))).resize((tw, th)).convert("RGB")
    cx, cy = (k % cols) * tw, (k // cols) * (th + 22)
    sheet.paste(tile, (cx, cy + 22))
    ImageDraw.Draw(sheet).text((cx + 4, cy + 4), f"{t / 1000:.0f}s  {what}", fill=(0, 0, 0))
os.makedirs("out/lessons", exist_ok=True)
sheet.save(f"out/lessons/{name}.png")
print(f"{len(frames)} shape steps; sheet of {len(pick)}: out/lessons/{name}.png")
