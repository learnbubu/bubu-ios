"""Bùbù's master rig into Studio: out/rig/*.png trimmed into the project's art, and a document "rig" with every part jointed
to its parent, the spare faces and paws hidden, and a test wave. Replaces only that document and its art. Run with Studio
saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I rig_to_studio.py
"""
import json
import os
from PIL import Image

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/rig"
JOINTS = json.load(open("out/rig/rig.json"))
SMOOTH = [0.42, 0, 0.58, 1]
NECK, WAIST = [505, 470], [505, 640]

# back to front: part, parent, pivot, shown
STACK = [
    ("pack", "torso", WAIST, True),
    ("tail", "torso", WAIST, True),
    ("limb-leg-l", None, [512, 512], True),
    ("limb-leg-r", None, [512, 512], True),
    ("limb-arm-l", None, [512, 512], True),
    ("limb-arm-r", None, [512, 512], True),
    ("torso", None, WAIST, True),
    ("straps", "torso", WAIST, True),
    ("belly", "torso", WAIST, True),
    ("ear-l", "head", [340, 150], True), ("ear-r", "head", [680, 150], True),
    ("head", "torso", NECK, True),
    ("brows", "head", NECK, True),
    ("cheeks", "head", NECK, True),
    ("patches", "head", NECK, True),
    ("eyes-open", "head", NECK, False), ("eyes-happy", "head", NECK, True), ("eyes-shut", "head", NECK, False),
    ("eyes-wow", "head", NECK, False), ("eyes-squint", "head", NECK, False),
    ("nose", "head", NECK, True),
    ("mouth-smile", "head", NECK, False), ("mouth-open", "head", NECK, True), ("mouth-o", "head", NECK, False),
    ("mouth-frown", "head", NECK, False),
]
# the pose paws drawn elsewhere are carried to the wrist
SHIFT = {p: [JOINTS["paw-r"][i] - JOINTS[p][i] for i in (0, 1)] for p in ("paw-fist", "paw-point", "paw-thumb")}


def keys(*pairs):
    return [{"t": t, "v": v, "ease": SMOOTH} for t, v in pairs]


# a wave: the arm up, the forearm swinging, his head and body going with it
WAVE = {
    "head": {"rotation": keys((0, 0), (400, 5), (2000, 5), (2400, 0))},
}

os.makedirs(ART, exist_ok=True)
layers = []
ids = {name: f"L{i + 1}" for i, (name, *_) in enumerate(STACK)}
for name, parent, pivot, shown in STACK:
    im = Image.open(f"out/rig/{name}.png")
    box = im.getchannel("A").getbbox()
    im.crop(box).save(f"{ART}/{name}.png")
    dx, dy = SHIFT.get(name, (0, 0))
    joint = pivot or JOINTS[name]
    layer = {
        "id": ids[name], "name": name, "art": f"{name}.png", "w": box[2] - box[0], "h": box[3] - box[1],
        "x": (box[0] + box[2]) / 2 + dx, "y": (box[1] + box[3]) / 2 + dy, "scale": 1, "rotation": 0, "flipX": False,
        "opacity": 1, "visible": shown, "locked": False,
        "pivot": {"x": joint[0] + dx, "y": joint[1] + dy} if name not in SHIFT else {"x": JOINTS["paw-r"][0], "y": JOINTS["paw-r"][1]},
        "keys": WAVE.get(name, {}), "loop": 0, "blink": 0,
    }
    if parent:
        layer["parent"] = ids[parent]
    layers.append(layer)
layers.reverse()  # top first

doc = {"id": "rig", "name": "Rig", "width": 1024, "height": 1024, "duration": 2400, "loop": True, "layers": layers, "bones": []}
json.dump(doc, open(f"{ROOT}/docs/rig.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
print([k for k in project])
key = "docs" if "docs" in project else "order"
if "rig" not in project[key]:
    project[key].append("rig")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
