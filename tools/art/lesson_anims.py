"""The lesson mascot's animations, keyed on the turnaround rig's front view (the owner, 5 Nov 2026: the new Bùbù in the lessons,
"Claude first, you fix"): Idle, Right (an answer got right), Wrong, Wave (his own front wave, as it was) and Cheer.

Each animation is poses at times: offsets from rest for the hips (a move: the whole body, the feet staying put unless the pose
says), the chest's and head's turn, the head's drop, each ear's turn, the face's look, and where each hand and foot goes
(document units from where it rests). Studio keeps them as the document's animations (each with its own hand and foot keys).

Makes, from Studio's Puppet Views (never changed):
- <out>/bubu-lesson.json: a document with all five, the front shown, Idle being edited
- <out>/bubu-lesson-<name>.json: one document an animation, to render as a video
From tools/art: ../sfx/.venv/Scripts/python -I lesson_anims.py <docs folder in> <docs folder out>
"""
import copy
import json
import os
import sys

src_dir, out_dir = sys.argv[1], sys.argv[2]
base = json.load(open(os.path.join(src_dir, "puppet-views.json"), encoding="utf-8"))

SMOOTH, OUT, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [1, 0, 1, 0]
HANDS = {"R": "Bizhnq98", "L": "bForearmL2"}           # (the front's: screen right, screen left)
FEET = {"R": "bShinR2", "L": "bShinL2"}

L0 = {l["id"]: l for l in base["layers"]}
B0 = {b["id"]: b for b in base["bones"]}
REST = {"hips": (L0["hips"]["x"], L0["hips"]["y"]), "torso": L0["torso"]["rotation"], "head": (L0["head"]["y"], L0["head"]["rotation"]),
        "earL": L0["earL"]["rotation"], "earR": L0["earR"]["rotation"], "face": (L0["face"]["x"], L0["face"]["y"])}
HAND0 = {k: (B0[b]["ik"]["tx"], B0[b]["ik"]["ty"]) for k, b in HANDS.items()}
FOOT0 = {k: (B0[b]["ik"]["tx"], B0[b]["ik"]["ty"]) for k, b in FEET.items()}


def pose(**k):
    """a pose: hips (dx, dy), torso (deg), head (dy, deg), earL / earR (deg), face (dx, dy), hR / hL (dx, dy), fR / fL (dx, dy)"""
    return k


def keys_of(timeline):
    """[(t, pose, ease)] -> the keys for every channel, rest wherever a pose doesn't say"""
    ch = {}
    for t, p, e in timeline:
        g = lambda k, d: p.get(k, d)
        hx, hy = g("hips", (0, 0)); ch.setdefault(("hips", "x"), []).append((t, REST["hips"][0] + hx, e)); ch.setdefault(("hips", "y"), []).append((t, REST["hips"][1] + hy, e))
        ch.setdefault(("torso", "rotation"), []).append((t, REST["torso"] + g("torso", 0), e))
        dy, rot = g("head", (0, 0)); ch.setdefault(("head", "y"), []).append((t, REST["head"][0] + dy, e)); ch.setdefault(("head", "rotation"), []).append((t, REST["head"][1] + rot, e))
        for ear in ("earL", "earR"):
            ch.setdefault((ear, "rotation"), []).append((t, REST[ear] + g(ear, 0), e))
        fx, fy = g("face", (0, 0)); ch.setdefault(("face", "x"), []).append((t, REST["face"][0] + fx, e)); ch.setdefault(("face", "y"), []).append((t, REST["face"][1] + fy, e))
        for s in ("R", "L"):
            dx, dy2 = g("h" + s, (0, 0)); ch.setdefault((HANDS[s], "tx"), []).append((t, HAND0[s][0] + dx, e)); ch.setdefault((HANDS[s], "ty"), []).append((t, HAND0[s][1] + dy2, e))
            dx, dy2 = g("f" + s, (0, 0)); ch.setdefault((FEET[s], "tx"), []).append((t, FOOT0[s][0] + dx, e)); ch.setdefault((FEET[s], "ty"), []).append((t, FOOT0[s][1] + dy2, e))
    return ch


R0 = pose()
# Idle, round and round: breathing (the body rises and settles), a slow sway of the chest and head the other way, the face drifting,
# an ear flicking, the hands swaying with the body a beat behind
IDLE = [(0, R0, SMOOTH),
        (800, pose(hips=(0, -3), torso=1.2, head=(-2, -1.5), face=(4, -1), hR=(2, -3), hL=(2, -2)), SMOOTH),
        (1600, pose(hips=(0, 0), torso=0, head=(0, 0), face=(6, 0), hR=(0, 0), hL=(0, 0)), SMOOTH),
        (2000, pose(face=(6, 0), earR=-9), OUT),
        (2150, pose(face=(5, 0), earR=3), SMOOTH),
        (2400, pose(hips=(0, -3), torso=-1.2, head=(-2, 1.5), face=(0, -1), hR=(-2, -2), hL=(-2, -3)), SMOOTH),
        (3200, R0, SMOOTH)]
# Right: a little crouch, a hop with both hands up and out, the head back, the ears flicking; landing with a squash, then rest
RIGHT = [(0, R0, SMOOTH),
         (140, pose(hips=(0, 14), head=(4, 0), hR=(6, 6), hL=(-6, 6)), OUT),
         (360, pose(hips=(0, -46), fR=(0, -32), fL=(0, -32), torso=0, head=(-4, -5), earL=-12, earR=12, face=(0, -8),
                    hR=(40, -300), hL=(-40, -300)), SMOOTH),
         (560, pose(hips=(0, 10), head=(3, -3), earL=6, earR=-6, face=(0, -6), hR=(45, -290), hL=(-45, -290)), OUT),
         (760, pose(hips=(0, -2), head=(0, -2), face=(0, -4), hR=(35, -260), hL=(-35, -260)), SMOOTH),
         (1300, R0, SMOOTH)]
# Wrong: the head drops and turns away a little, the body slumps, the ears droop, the hands come in, the face looks down; held, then
# back up
WRONG = [(0, R0, SMOOTH),
         (320, pose(hips=(0, 14), torso=-3, head=(24, 11), earL=20, earR=-20, face=(-12, 22), hR=(-70, 30), hL=(70, 30)), OUT),
         (1050, pose(hips=(0, 12), torso=-3, head=(22, 10), earL=18, earR=-18, face=(-10, 20), hR=(-65, 28), hL=(65, 28)), SMOOTH),
         (1500, R0, SMOOTH)]
# Cheer: a deeper crouch, a big jump, both arms straight up, the head back; a squash on landing, then rest
CHEER = [(0, R0, SMOOTH),
         (180, pose(hips=(0, 24), head=(6, 0), hR=(10, 10), hL=(-10, 10), earL=4, earR=-4), OUT),
         (430, pose(hips=(0, -60), fR=(0, -46), fL=(0, -46), head=(-6, 0), earL=-16, earR=16, face=(0, -10), hR=(20, -380), hL=(-20, -380)), SMOOTH),
         (620, pose(hips=(0, -45), fR=(0, -32), fL=(0, -32), head=(-4, 3), earL=-10, earR=10, face=(0, -10), hR=(30, -360), hL=(-30, -360)), SMOOTH),
         (820, pose(hips=(0, 18), head=(5, 0), earL=8, earR=-8, face=(0, -4), hR=(40, -230), hL=(-40, -230)), OUT),
         (1050, pose(hips=(0, -3), face=(0, -2), hR=(15, -70), hL=(-15, -70)), SMOOTH),
         (1600, R0, SMOOTH)]


def made(name, duration, loop, timeline):
    """the document with this animation on its layers and bones (its own keys only on what it moves)"""
    d = copy.deepcopy(base)
    d["turn"]["keys"] = [{"t": 0, "v": [v["id"] for v in d["turn"]["views"]].index("front"), "ease": HOLD}]
    for l in d["layers"]:
        l["keys"] = {}
    for b in d["bones"]:
        b["keys"] = {}
        if b.get("ik"):
            b["ik"]["keys"] = {}
    L = {l["id"]: l for l in d["layers"]}
    B = {b["id"]: b for b in d["bones"]}
    for (who, prop), ks in keys_of(timeline).items():
        k = [{"t": t, "v": round(v, 2), "ease": e} for t, v, e in ks]
        if who in L:
            L[who]["keys"][prop] = k
        else:
            B[who]["ik"]["keys"][prop] = k
    d["duration"], d["loop"] = duration, loop
    return d


def waved():
    """his own front wave, as Puppet Views has it (its keys, front only)"""
    d = copy.deepcopy(base)
    d["turn"]["keys"] = [{"t": 0, "v": [v["id"] for v in d["turn"]["views"]].index("front"), "ease": HOLD}]
    d["loop"] = False
    return d


anims = [("Idle", made("Idle", 3200, True, IDLE)), ("Right", made("Right", 1300, False, RIGHT)), ("Wrong", made("Wrong", 1500, False, WRONG)),
         ("Wave", waved()), ("Cheer", made("Cheer", 1600, False, CHEER))]


def capture(d, id_, name):
    bones = {b["id"]: {"keys": b["keys"], "loop": b.get("loop", 0), "rotation": b.get("rotation", 0), "x": b.get("x", 0), "y": b.get("y", 0), "scale": b.get("scale", 1),
                       **({"ik": {"keys": b["ik"]["keys"], "tx": b["ik"]["tx"], "ty": b["ik"]["ty"], "mix": b["ik"]["mix"], "bend": b["ik"]["bend"]}} if b.get("ik") else {})}
             for b in d["bones"]}
    layers = {l["id"]: {"keys": l["keys"], "loop": l.get("loop", 0), "blink": l.get("blink", 0)} for l in d["layers"]}
    return {"id": id_, "name": name, "duration": d["duration"], "loop": d["loop"], "bones": bones, "layers": layers}


os.makedirs(out_dir, exist_ok=True)
for name, d in anims:
    one = copy.deepcopy(d)
    one["id"], one["name"] = f"bubu-lesson-{name.lower()}", f"Bùbù lesson: {name}"
    json.dump(one, open(os.path.join(out_dir, one["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
all_ = copy.deepcopy(anims[0][1])
all_["id"], all_["name"] = "bubu-lesson", "Bùbù lesson"
all_["anims"] = [capture(d, f"A{name.lower()}", name) for name, d in anims]
all_["anim"] = "Aidle"
json.dump(all_, open(os.path.join(out_dir, "bubu-lesson.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("made:", ", ".join(f"{n} ({d['duration']} ms{', loops' if d['loop'] else ''})" for n, d in anims))
