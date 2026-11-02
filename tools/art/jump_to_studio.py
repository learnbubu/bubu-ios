"""The jump for joy from Codex's drawn key poses: each pose taken off its magenta and cleaned, then a Studio document
"jump-drawn" that swaps between them on exact frames, with small moves inside each hold. Replaces only that document and its
art. Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I jump_to_studio.py
"""
import json
import os
import numpy as np
from PIL import Image, ImageFilter

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/jump-drawn"
SIZE = 1024
FUR = np.array([52.0, 56, 57])
HOLD, SOFT, LINE = [1, 0, 1, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
SCALE, GROUND = 0.72, 950
# pose, shown from, until, height off the ground at its start and end
TIMES = [
    ("stand", 0, 220, 0, 0), ("dip", 220, 300, 0, 0), ("crouch", 300, 500, 0, 0), ("launch", 500, 580, -40, -130),
    ("apex", 580, 900, -250, -285), ("fall", 900, 1020, -190, -30), ("land", 1020, 1150, 0, 0), ("settle", 1150, 1270, 0, 0),
    ("crouch", 1270, 1330, 0, 0), ("stand", 1330, 2000, 0, 0),
]


def clean(name):
    rgb = np.asarray(Image.open(f"out/raw/rm-pose-{name}.png").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    colour[np.abs(colour - FUR).max(-1) < 30] = FUR
    im = Image.fromarray(np.dstack([colour, alpha * 255]).round().astype("uint8"), "RGBA")
    box = im.getchannel("A").getbbox()
    im.crop(box).save(f"{ART}/{name}.png")
    return box


os.makedirs(ART, exist_ok=True)
layers, boxes = [], {}
for i, (name, start, end, h0, h1) in enumerate(TIMES):
    box = boxes.setdefault(name, clean(name))
    w, h = box[2] - box[0], box[3] - box[1]
    foot = GROUND
    # every pose stands on one ground line and keeps its side-to-side place, shrunk for headroom
    x = SIZE / 2 + ((box[0] + box[2]) / 2 - SIZE / 2) * SCALE
    y = foot - h * SCALE / 2
    opacity = ([] if start == 0 else [{"t": 0, "v": 0, "ease": HOLD}]) + [{"t": start, "v": 1, "ease": HOLD}, {"t": end, "v": 0, "ease": HOLD}]
    layers.append({
        "id": f"L{i + 1}", "name": f"{i + 1} {name}", "art": f"{name}.png", "w": w, "h": h, "x": x, "y": y + h0, "scale": SCALE,
        "rotation": 0, "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y},
        "keys": {"opacity": opacity, "y": [{"t": start, "v": y + h0, "ease": SOFT if name == "apex" else LINE}, {"t": end, "v": y + h1, "ease": LINE}]},
        "loop": 0, "blink": 0,
    })
layers.reverse()
doc = {"id": "jump-drawn", "name": "Jump Drawn", "width": 1024, "height": 1024, "duration": 2000, "loop": True, "layers": layers, "bones": []}
json.dump(doc, open(f"{ROOT}/docs/jump-drawn.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "jump-drawn" not in project["docs"]:
    project["docs"].append("jump-drawn")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
