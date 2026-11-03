"""The jump for joy from five strong poses (owner, 3 Nov 2026) instead of a flipbook: stand, crouch, stretch, apex, squash, each
matched by head size, moved and settled by Studio between cuts, with a landing puff. Writes the Studio document "jump-five" and
its art only. Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I jump5_to_studio.py
"""
import json
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/jump-five"
SIZE = 1024
FUR = np.array([52.0, 56, 57])
HOLD, OUT, IN, SOFT = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1]
SCALE, GROUND, MID = 0.72, 950, 512
# each drawing's head width in its own pixels, so he stays one size from pose to pose
POSES = {"stand": ("rm-master", 512), "crouch": ("rm-pose-crouch-a", 697), "stretch": ("rm-pose-stretch", 585),
         "apex": ("rm-pose-apex-a", 627), "squash": ("rm-pose-squash", 688)}
# pose, shown from, until, height keys (t, v, ease), size keys (t, v, ease) as a multiple of its size
TIMES = [
    ("stand", 0, 170, [(0, 0, HOLD)], None),
    ("crouch", 170, 420, [(170, 0, HOLD)], [(170, 1.05, SOFT), (250, 0.98, SOFT), (420, 1, HOLD)]),
    ("stretch", 420, 530, [(420, 0, OUT), (530, -170, HOLD)], None),
    ("apex", 530, 830, [(530, -180, SOFT), (680, -225, SOFT), (830, -180, HOLD)], None),
    ("stretch", 830, 930, [(830, -170, IN), (930, 0, HOLD)], None),
    ("squash", 930, 1100, [(930, 0, HOLD)], [(930, 1.06, SOFT), (1020, 0.99, SOFT), (1100, 1, HOLD)]),
    ("stand", 1100, 2000, [(1100, 0, HOLD)], [(1100, 0.96, SOFT), (1200, 1.02, SOFT), (1300, 1, HOLD)]),
]


def clean(name, raw):
    rgb = np.asarray(Image.open(f"out/raw/{raw}.png").convert("RGB").filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    colour[np.abs(colour - FUR).max(-1) < 30] = FUR
    im = Image.fromarray(np.dstack([colour, alpha * 255]).round().astype("uint8"), "RGBA")
    box = im.getchannel("A").getbbox()
    im.crop(box).save(f"{ART}/{name}.png")
    return box, im.width


os.makedirs(ART, exist_ok=True)
layers, boxes = [], {}
for i, (name, start, end, heights, sizes) in enumerate(TIMES):
    raw, head = POSES[name]
    box, width = boxes.setdefault(name, clean(name, raw))
    w, h = box[2] - box[0], box[3] - box[1]
    s = SCALE * 512 / head
    x = MID + ((box[0] + box[2]) / 2 - width / 2) * s
    y = GROUND - h * s / 2
    opacity = ([] if start == 0 else [{"t": 0, "v": 0, "ease": HOLD}]) + [{"t": start, "v": 1, "ease": HOLD}, {"t": end, "v": 0, "ease": HOLD}]
    keys = {"opacity": opacity, "y": [{"t": t, "v": y + v, "ease": e} for t, v, e in heights]}
    if sizes:
        keys["scale"] = [{"t": t, "v": s * v, "ease": e} for t, v, e in sizes]
        # it grows about its middle, so its middle moves to keep his feet on the ground
        keys["y"] = [{"t": t, "v": GROUND - h * s * v / 2, "ease": e} for t, v, e in sizes]
    layers.append({
        "id": f"L{i + 1}", "name": f"{i + 1} {name}", "art": f"{name}.png", "w": w, "h": h, "x": x, "y": y, "scale": s,
        "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y},
        "keys": keys, "loop": 0, "blink": 0,
    })
# the landing puff: soft cream rounds thrown out along the ground either side of his feet
puff = Image.new("RGBA", (200, 200))
ImageDraw.Draw(puff).ellipse((6, 6, 194, 194), fill=(255, 250, 235, 170))
puff.save(f"{ART}/puff.png")
for j, (dx, dy, size) in enumerate(((-300, -30, 0.5), (300, -30, 0.5), (-210, -70, 0.34), (210, -70, 0.34), (-390, -55, 0.24), (390, -55, 0.24))):
    x0, y0 = MID + dx * 0.45, GROUND - 25
    x1, y1 = MID + dx, GROUND + dy
    layers.append({
        "id": f"P{j + 1}", "name": f"puff {j + 1}", "art": "puff.png", "w": 200, "h": 200, "x": x0, "y": y0, "scale": size,
        "rotation": 0, "flipX": False, "opacity": 0, "visible": True, "locked": False, "pivot": {"x": x0, "y": y0},
        "keys": {
            "x": [{"t": 930, "v": x0, "ease": OUT}, {"t": 1260, "v": x1, "ease": HOLD}],
            "y": [{"t": 930, "v": y0, "ease": OUT}, {"t": 1260, "v": y1, "ease": HOLD}],
            "scale": [{"t": 930, "v": size * 0.3, "ease": OUT}, {"t": 1060, "v": size, "ease": IN}, {"t": 1260, "v": 0, "ease": HOLD}],
            "opacity": [{"t": 0, "v": 0, "ease": HOLD}, {"t": 930, "v": 1, "ease": HOLD}, {"t": 1260, "v": 0, "ease": HOLD}],
        },
        "loop": 0, "blink": 0,
    })
layers.reverse()
layers = [l for l in layers if not l["id"].startswith("P")] + [l for l in layers if l["id"].startswith("P")]
doc = {"id": "jump-five", "name": "Jump Five", "width": 1024, "height": 1024, "duration": 2000, "loop": True, "layers": layers, "bones": []}
json.dump(doc, open(f"{ROOT}/docs/jump-five.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "jump-five" not in project["docs"]:
    project["docs"].append("jump-five")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
