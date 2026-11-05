"""Does everything stay covered when he moves? (the owner, lesson 12: "make sure that it extends enough so if things move it still is
covered", and "think where those lines may lead... needs to make sense if he lifts his arm up"). A copy of a puppet document with
poses keyed one a second (the head tilted each way, each arm raised and swung out), for rendering in Studio and looking for any
hidden end that shows, or a part that stops where it should carry on.

Save Studio first. This writes docs/<doc>-cover.json (and copies its art), adds it to project.json, then reload Studio without saving
and render each second with render_frame (t = 0, 1000, 2000...).

From tools/art: ../sfx/.venv/Scripts/python -I cover_check.py [doc] [view: q for the three-quarter, s for the side, f for the front]
"""
import json
import shutil
import sys

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = sys.argv[1] if len(sys.argv) > 1 else "puppet-views"
VIEW = sys.argv[2] if len(sys.argv) > 2 else "q"
OUT = f"{DOC}-cover" + {"s": "-side", "f": "-front"}.get(VIEW, "")
d = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))
d["id"], d["name"] = OUT, d["name"] + " (cover check)"
q = VIEW in ("q", "s")
pre = VIEW if q else ""
if d.get("turn"):
    ids = [v["id"] for v in d["turn"]["views"]]
    d["turn"]["at"], d["turn"]["keys"] = ids.index({"q": "quarter-r", "s": "side-r"}.get(VIEW, "front")), []
L = {l["id"]: l for l in d["layers"]}
B = {b["id"]: b for b in d.get("bones", [])}
head, arm_l, arm_r = (f"{pre}Head", f"{pre}armL4", f"{pre}armR4") if q else ("head", "armL4", "armR4")
face, torso, hips = (f"{pre}Face", f"{pre}Torso", f"{pre}Hips") if q else ("face", "torso", "hips")
leg_l, leg_r = (f"{pre}legL4", f"{pre}legR4") if q else ("legL4", "legR4")
if VIEW == "f":       # (the front's bones, as the owner's front puppet names them)
    arm_l, arm_r, leg_l, leg_r = "bForearmL2", "Bizhnq98", "bShinL2", "bShinR2"
key = lambda v, t: {"t": t, "v": v, "ease": [0, 0, 1, 1]}
# poses, a second each: rest; head tilted back; head tilted forward; near arm up; near arm out; far arm up; both up, head tilted;
# the ears turned back; the ears turned forward; then the rest of the rig, a control at a time: the face looking back, then forward
# and up; the chest turned each way; the hips down (feet planted); each foot lifted; and all together
POSES = [{}, {"head": -15}, {"head": 15}, {"armL": (-60, -230)}, {"armL": (-150, -60)}, {"armR": (60, -230)},
         {"armL": (-60, -230), "armR": (60, -230), "head": -12}, {"ears": -20}, {"ears": 20},
         {"face": (-30, 0)}, {"face": (25, -15)}, {"torso": -8}, {"torso": 8}, {"hips": (0, 30)}, {"legL": (40, -90)}, {"legR": (40, -90)},
         {"hips": (-25, 20), "torso": 6, "head": -8, "face": (20, 5), "armL": (-40, -120), "legR": (30, -60)}]
# (from the side, raising an arm "up" in front means forward: the arms' and feet's moves go the way he faces)
if VIEW == "s":
    POSES = [{k: ((-v[0] + (60 if k.startswith("arm") else 0), v[1]) if k.startswith(("arm", "leg")) else v) for k, v in p.items()} for p in POSES]
d["duration"] = len(POSES) * 1000
d["work"] = [0, d["duration"]]
for l in d["layers"]:
    l["keys"] = {}
hl = L[head]
hl["keys"]["rotation"] = [key(p.get("head", 0), i * 1000) for i, p in enumerate(POSES)]
# (the ears turned each way about their bases, as the ear arcs turn them)
for e in ((f"{pre}EarL", f"{pre}EarR") if q else ("earL", "earR")):
    if e in L:
        L[e]["keys"]["rotation"] = [key(p.get("ears", 0), i * 1000) for i, p in enumerate(POSES)]
# (the face look, the chest's turn and the hips' move: keyed on the controls' layers, as dragging the controls keys them)
for lid, prop, val in ((face, "x", lambda p: p.get("face", (0, 0))[0]), (face, "y", lambda p: p.get("face", (0, 0))[1]),
                       (torso, "rotation", lambda p: p.get("torso", 0)), (hips, "x", lambda p: p.get("hips", (0, 0))[0]),
                       (hips, "y", lambda p: p.get("hips", (0, 0))[1])):
    if lid in L:
        base = L[lid].get(prop, 0)
        L[lid]["keys"][prop] = [key(base + val(p), i * 1000) for i, p in enumerate(POSES)]
for side, bid in (("armL", arm_l), ("armR", arm_r), ("legL", leg_l), ("legR", leg_r)):
    if bid not in B or not B[bid].get("ik"):
        continue                 # (the front's IK bones go by other names: only the three-quarter's are known here)
    ik = B[bid]["ik"]
    ik["keys"] = {"tx": [key(ik["tx"] + p.get(side, (0, 0))[0], i * 1000) for i, p in enumerate(POSES)],
                  "ty": [key(ik["ty"] + p.get(side, (0, 0))[1], i * 1000) for i, p in enumerate(POSES)]}
json.dump(d, open(f"{ROOT}/docs/{OUT}.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
shutil.copytree(f"{ROOT}/art/{DOC}", f"{ROOT}/art/{OUT}", dirs_exist_ok=True)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if OUT not in project["docs"]:
    project["docs"].append(OUT)
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(f"{OUT}: {len(POSES)} poses, one a second; reload Studio without saving and render t = 0, 1000 ... {(len(POSES) - 1) * 1000}")
