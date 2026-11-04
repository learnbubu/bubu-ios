"""The test clip's wave on the FK rig (the owner, 4 Nov 2026: "a blend of these pins and then like an FK rig"): two bones in the
waving arm (shoulder to elbow, elbow to wrist), the arm's three puppet pins following them, and the wave keyed as the bones'
turns: the upper arm out, the forearm up and waving, a beat behind it (overlap). The puppet bends the arm smoothly between the
pins; the arm itself isn't bound to the bones.

Writes its own copy, "puppet-fk" (from puppet-test, whose arm the owner is trying the tool on), its arm's pins put back as three.

From tools/art: ../sfx/.venv/Scripts/python -I puppet_test_fk.py   (save Studio first; reload it after)
"""
import json
import shutil
import os

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
SOFT, OUT, IN, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [1, 0, 1, 0]
SRC, DOC = "puppet-test", "puppet-fk"
doc = json.load(open(f"{ROOT}/docs/{SRC}.json", encoding="utf-8"))
doc.update({"id": DOC, "name": "Puppet FK"})
os.makedirs(f"{ROOT}/art/{DOC}", exist_ok=True)
for f in os.listdir(f"{ROOT}/art/{SRC}"):
    shutil.copy(f"{ROOT}/art/{SRC}/{f}", f"{ROOT}/art/{DOC}/{f}")
path = f"{ROOT}/docs/{DOC}.json"
doc["bones"] = [b for b in doc["bones"] if b["name"] not in ("upperArmR", "forearmR")]
SHOULDER, ELBOW, WRIST = (776, 616), (880, 740), (965, 840)


def bone(id_, name, head, tail, parent, keys):
    import math
    return {"id": id_, "name": name, "parent": parent, "hx": head[0], "hy": head[1],
            "angle": round(math.degrees(math.atan2(tail[1] - head[1], tail[0] - head[0])), 2),
            "length": round(math.dist(head, tail), 1), "rotation": 0, "x": 0, "y": 0, "scale": 1, "loop": 0, "color": "#e0574a",
            "keys": {"rotation": [{"t": t, "v": v, "ease": e} for t, v, e in keys]}}


# (a turn: + is clockwise on screen. His arm rests 50 degrees below level: the upper arm at -55 is about level, out to the side;
# the forearm at -72 more stands about upright beside the head, waving either side of that, never back over it)
UPPER = [(0, 0, HOLD), (1200, 0, SOFT), (1400, 4, OUT), (1750, -55, SOFT), (2250, -58, SOFT), (2750, -53, SOFT), (3000, -55, IN),
         (3350, 4, SOFT), (3550, -1, SOFT), (3750, 0, HOLD)]
FORE = [(0, 0, HOLD), (1300, 0, SOFT), (1500, 5, OUT), (1850, -72, SOFT), (2000, -58, SOFT), (2250, -82, SOFT), (2500, -58, SOFT),
        (2750, -82, SOFT), (3000, -72, IN), (3450, 8, SOFT), (3650, -3, SOFT), (3850, 0, HOLD)]
doc["bones"] += [bone("bUpperArmR", "upperArmR", SHOULDER, ELBOW, None, UPPER),
                 bone("bForearmR", "forearmR", ELBOW, WRIST, "bUpperArmR", FORE)]
arm = next(l for l in doc["layers"] if l["id"] == "armR")
ox, oy = arm["x"] - arm["w"] / 2, arm["y"] - arm["h"] / 2
# (the three pins where puppet_test_pins.py stuck them, each following its bone)
PINS = {"shoulder": ((776, 616), "bUpperArmR"), "upper": ((856, 712), "bUpperArmR"), "wrist": ((938, 808), "bForearmR")}
FOLLOW = {k: v[1] for k, v in PINS.items()}
arm["puppet"] = {"pins": [{"id": k, "rx": round(p[0] - ox, 1), "ry": round(p[1] - oy, 1), "x": 0, "y": 0, "bone": b, "keys": {}}
                          for k, (p, b) in PINS.items()], "spacing": 12}
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if DOC not in project["docs"]:
    project["docs"].append(DOC)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(DOC, "written; armR's pins follow", FOLLOW)
