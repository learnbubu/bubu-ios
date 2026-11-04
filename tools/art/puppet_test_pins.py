"""The test clip's waving arm on Studio's new Puppet tool (the owner, 4 Nov 2026: bones bent it "super crunchy"; "more like the
puppet tool in Photoshop / After Effects"): the arm off its bones, three pins stuck in it (the shoulder, along the upper arm, the
wrist) and keyed into the owner's sketch (out/puppet/_sketch.json): out from the shoulder about level, a round bend up,
the paw beside the head, then waving. Everything between the pins is worked out as rigid as it can be.

From tools/art: ../sfx/.venv/Scripts/python -I puppet_test_pins.py   (save Studio first; reload it after)
"""
import json
import math

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = "puppet-test"
SOFT, OUT, IN, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [1, 0, 1, 0]
path = f"{ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
arm = next(l for l in doc["layers"] if l["id"] == "armR")
arm.pop("skin", None)
for b in doc["bones"]:
    if b["name"].startswith("armR"):
        b["keys"] = {}
ox, oy = arm["x"] - arm["w"] / 2, arm["y"] - arm["h"] / 2          # the composition to the arm's picture (it's not turned or scaled)

# (where each pin is stuck at rest, in the composition: the shoulder, along the upper arm, the wrist; none on a toe line, where the
# drawing under a pin pinches a little, and none at the elbow: a pin there made a corner of the bend, where left free between the
# upper arm's pin and the wrist's the arm curves on its own, as After Effects' users keep their pins few)
REST = {"shoulder": (776, 616), "upper": (856, 712), "wrist": (938, 808)}
# (and with the arm up: each section keeps its length (stretched, the paw broke its toe lines); the upper arm about level, and
# from there to the wrist the chord of the bend, rising steeply as the owner's sketch)
TURNS = (-3, -56)
UP = {"shoulder": (790, 622)}
_names = list(REST)
for a, b, turn in zip(_names, _names[1:], TURNS):
    length = math.dist(REST[a], REST[b])
    UP[b] = (UP[a][0] + length * math.cos(math.radians(turn)), UP[a][1] + length * math.sin(math.radians(turn)))
# (the wave: the paw and forearm swing either side, about the bend)
WAG = {"shoulder": (0, 0), "upper": (0, 0), "wrist": (22, 6)}


def pin(name):
    rx, ry = REST[name][0] - ox, REST[name][1] - oy
    ux, uy = UP[name][0] - REST[name][0], UP[name][1] - REST[name][1]
    wx, wy = WAG[name]
    late = 50 if name == "wrist" else 0          # (the end of the arm a beat behind its root)
    ks = lambda u, w, d: [(0, 0, HOLD), (1200 + late, 0, SOFT), (1400 + late, d, OUT), (1750 + late, u, SOFT),
                          (2000, u - w, SOFT), (2250, u + w, SOFT), (2500, u - w, SOFT), (2750, u + w, SOFT),
                          (3000, u, IN), (3350 + late, -d, SOFT), (3550 + late, d / 2, SOFT), (3750 + late, 0, HOLD)]
    as_keys = lambda k: [{"t": t, "v": round(v, 2), "ease": e} for t, v, e in k]
    return {"id": name, "rx": round(rx, 1), "ry": round(ry, 1), "x": 0, "y": 0,
            "keys": {"x": as_keys(ks(ux, wx, 2)), "y": as_keys(ks(uy, wy, 3))}}


arm["puppet"] = {"pins": [pin(n) for n in REST], "spacing": 12}
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False)
print("armR: puppet pins", [p["id"] for p in arm["puppet"]["pins"]])
