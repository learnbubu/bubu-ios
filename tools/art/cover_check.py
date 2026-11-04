"""Does everything stay covered when he moves? (the owner, lesson 12: "make sure that it extends enough so if things move it still is
covered", and "think where those lines may lead... needs to make sense if he lifts his arm up"). A copy of a puppet document with
poses keyed one a second (the head tilted each way, each arm raised and swung out), for rendering in Studio and looking for any
hidden end that shows, or a part that stops where it should carry on.

Save Studio first. This writes docs/<doc>-cover.json (and copies its art), adds it to project.json, then reload Studio without saving
and render each second with render_frame (t = 0, 1000, 2000...).

From tools/art: ../sfx/.venv/Scripts/python -I cover_check.py [doc] [view: q for the three-quarter, f for the front]
"""
import json
import shutil
import sys

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = sys.argv[1] if len(sys.argv) > 1 else "puppet-views"
VIEW = sys.argv[2] if len(sys.argv) > 2 else "q"
OUT = f"{DOC}-cover"
d = json.load(open(f"{ROOT}/docs/{DOC}.json", encoding="utf-8"))
d["id"], d["name"] = OUT, d["name"] + " (cover check)"
q = VIEW == "q"
if d.get("turn"):
    d["turn"]["at"], d["turn"]["keys"] = (2 if q else 1), []
L = {l["id"]: l for l in d["layers"]}
B = {b["id"]: b for b in d.get("bones", [])}
head, arm_l, arm_r = ("qHead", "qarmL4", "qarmR4") if q else ("head", "armL4", "armR4")
key = lambda v, t: {"t": t, "v": v, "ease": [0, 0, 1, 1]}
# poses, a second each: rest; head tilted back; head tilted forward; near arm up; near arm out; far arm up; both up, head tilted
POSES = [{}, {"head": -15}, {"head": 15}, {"armL": (-60, -230)}, {"armL": (-150, -60)}, {"armR": (60, -230)},
         {"armL": (-60, -230), "armR": (60, -230), "head": -12}]
d["duration"] = len(POSES) * 1000
d["work"] = [0, d["duration"]]
for l in d["layers"]:
    l["keys"] = {}
hl = L[head]
hl["keys"]["rotation"] = [key(p.get("head", 0), i * 1000) for i, p in enumerate(POSES)]
for side, bid in (("armL", arm_l), ("armR", arm_r)):
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
