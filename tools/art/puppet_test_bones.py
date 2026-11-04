"""The test clip's limb keys on bones (Spine-style limbs: the owner, 4 Nov 2026): the wave bends at the elbow as his sketch, the
arm out to the side and curving up to the paw; the other arm's forearm sways a beat behind its upper arm.
Run after the bones are in puppet-test (upperArmL/R, forearmL/R, thighL/R, shinL/R) and the limbs bound to them.

From tools/art: ../sfx/.venv/Scripts/python -I puppet_test_bones.py   (save Studio first; reload it after)
"""
import json

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = "puppet-test"
SOFT, OUT, IN, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [1, 0, 1, 0]
END = 4000
path = f"{ROOT}/docs/{DOC}.json"
doc = json.load(open(path, encoding="utf-8"))
B = {b["name"]: b for b in doc["bones"]}


def key(bone, prop, ks):
    B[bone]["keys"][prop] = [{"t": t, "v": v, "ease": e} for t, v, e in ks]


# (a bone turns from its rest: + is clockwise on screen. His left arm, on our right, rests 50 degrees below level.) The arm is a
# chain of four short bones, Spine's bendy limb: two bones folded at one point and read as a 90 degree corner (the owner, 4 Nov
# 2026: "we want that nice bend shape, smooth"), so the bend is shared out along the arm and the outline curves. Shaped to the
# owner's sketch (out/puppet/_sketch.json): out from the shoulder about level, then a round bend up to the paw beside the head.
OUT_TO, BENDS, WAG = -55, (-15, -37, -33), (0, 6, 8)     # the first bone's turn; the others' bends; how far each wags
OUTK = [(0, 0, HOLD), (1200, 0, SOFT), (1400, 4, OUT), (1750, OUT_TO, SOFT), (2250, OUT_TO - 3, SOFT), (2750, OUT_TO + 2, SOFT),
        (3000, OUT_TO, IN), (3350, 4, SOFT), (3550, -1, SOFT), (3750, 0, HOLD)]
key("armR1", "rotation", OUTK)
# (and the arm slides out a little from under the head while it's up: the sketch's reaches further out than the arm is long; the
# shoulder end is hidden under the head and strap, so the slide doesn't show)
SLIDE = 35
key("armR1", "x", [(0, 0, HOLD), (1250, 0, SOFT), (1750, SLIDE, SOFT), (3000, SLIDE, IN), (3400, 0, HOLD)])
key("armR1", "y", [(0, 0, HOLD), (1250, 0, SOFT), (1750, -10, SOFT), (3000, -10, IN), (3400, 0, HOLD)])


def bend(to, wag):
    return [(0, 0, HOLD), (1250, 0, SOFT), (1450, 2, OUT), (1800, to, SOFT),
            (2000, to + wag, SOFT), (2250, to - wag, SOFT), (2500, to + wag, SOFT), (2750, to - wag, SOFT),
            (3000, to, IN), (3400, 2, SOFT), (3600, -1, SOFT), (3800, 0, HOLD)]


for k, (to, wag) in enumerate(zip(BENDS, WAG)):
    key(f"armR{k + 2}", "rotation", bend(to, wag))
key("forearmL", "rotation", [(0, 0, SOFT), (1200, 3, SOFT), (2200, 0, SOFT), (3200, 3, SOFT), (END, 0, HOLD)])
json.dump(doc, open(path, "w", encoding="utf-8"), ensure_ascii=False)
print("bone keys written:", sum(len(v) for b in doc["bones"] for v in b["keys"].values()))
