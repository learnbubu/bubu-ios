"""The front puppet's first motion test (the owner, 4 Nov 2026: "make the test clip"), to see the joints, overlaps and layer order
hold up moving, not just in stills. A copy of bubu-puppet-front (the owner's master stays clean) with keys, 4 s on a loop:
- idle: a slow breath (belly swells, head rises a touch), the screen-left arm swaying with it, an ear flick;
- a wave: the screen-right arm dips (anticipation), swings up, waves four times, drops back past rest and settles (overshoot);
  the head tilts towards the wave and the body leans a touch away, and the ears follow the head a beat late (overlap).
Writes the Studio document "puppet-test" and its art (copied).

From tools/art: ../sfx/.venv/Scripts/python -I puppet_test.py   (save Studio first; reload it after)
"""
import copy
import json
import os
import shutil
import subprocess
import sys

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
SRC, DOC = "bubu-puppet-front", "puppet-test"
SOFT, OUT, IN, LINE, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0, 0, 1, 1], [1, 0, 1, 0]
END = 4000

doc = json.load(open(f"{ROOT}/docs/{SRC}.json", encoding="utf-8"))
os.makedirs(f"{ROOT}/art/{DOC}", exist_ok=True)
layers = []
for l in doc["layers"]:
    if l.get("art", "").endswith(".png"):
        continue                                    # (the reference drawing stays behind)
    l = copy.deepcopy(l)
    l["keys"] = {}
    if l.get("art"):
        shutil.copy(f"{ROOT}/art/{SRC}/{l['art']}", f"{ROOT}/art/{DOC}/{l['art']}")
    layers.append(l)
# the ears' hinges (puppet_elbow.py --ears) go on the copy before its keys; the limbs bend on bones, added in Studio after
json.dump({"id": DOC, "name": "Puppet Test", "width": doc["width"], "height": doc["height"], "duration": END, "loop": True,
           "layers": layers, "bones": [], "background": [247, 243, 236, 1]}, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False)
subprocess.run([sys.executable, "-I", "puppet_elbow.py", DOC, "--ears"], check=True)
layers = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))["layers"]
L = {l["id"]: l for l in layers}


def key(layer, prop, ks, rel=False):
    """keys (time, value, ease to the next); rel: values are added to the layer's resting value (for x and y)"""
    base = L[layer][prop] if rel else 0
    L[layer]["keys"][prop] = [{"t": t, "v": round(base + v, 3), "ease": e} for t, v, e in ks]


# idle: the breath, two in the loop
key("belly", "scale", [(0, 1, SOFT), (1000, 1.02, SOFT), (2000, 1, SOFT), (3000, 1.02, SOFT), (END, 1, HOLD)])
key("head", "y", [(0, 0, SOFT), (1000, -3, SOFT), (2000, 0, SOFT), (3000, -3, SOFT), (END, 0, HOLD)], rel=True)
key("armL", "rotation", [(0, 0, SOFT), (1000, 2, SOFT), (2000, 0, SOFT), (3000, 2, SOFT), (END, 0, HOLD)])
# a quick flick of the screen-left ear before the wave
key("earL", "rotation", [(0, 0, HOLD), (600, 0, OUT), (680, -14, SOFT), (800, 5, SOFT), (900, 0, HOLD),
                         # (and the head's tilt, a beat late: it lags as the head goes over, then catches up past it)
                         (1550, 0, SOFT), (1950, -7, SOFT), (2150, 3, SOFT), (2350, 0, HOLD),
                         (3250, 0, SOFT), (3650, 7, SOFT), (3850, -2, SOFT), (END, 0, HOLD)])
key("earR", "rotation", [(0, 0, HOLD), (1550, 0, SOFT), (1950, -8, SOFT), (2150, 4, SOFT), (2350, 0, HOLD),
                         (3250, 0, SOFT), (3650, 8, SOFT), (3850, -2, SOFT), (END, 0, HOLD)])
# the wave is keyed on the arm's bones (Spine-style: the owner, 4 Nov 2026), in Studio
key("head", "rotation", [(0, 0, HOLD), (1500, 0, SOFT), (1900, 5, SOFT), (3200, 5, SOFT), (3600, 0, HOLD)])
key("torso", "rotation", [(0, 0, HOLD), (1500, 0, SOFT), (1900, -2, SOFT), (3200, -2, SOFT), (3600, 0, HOLD)])

out = {"id": DOC, "name": "Puppet Test", "width": doc["width"], "height": doc["height"], "duration": END, "loop": True,
       "layers": layers, "bones": [], "background": [247, 243, 236, 1]}
json.dump(out, open(f"{ROOT}/docs/{DOC}.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if DOC not in project["docs"]:
    project["docs"].append(DOC)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers,", sum(len(v) for l in layers for v in l["keys"].values()), "keys in", DOC)
