"""The side view's arms and legs rigged from the owner's own shapes (the owner, 5 Nov 2026, after the first pass on the legs: "arm
pins/bones need to follow the shape of the arm more too", "legs as well", and how he places them: "normally takes the centre point
along the thickest width where it gets placed").

Every joint and pin sits on the limb's centre line, read off his outline across its width:
- the hip and the shoulder in the middle of the limb's round top: half its widest width down from its top (the round thigh's
  middle, the arm's cap's middle)
- the ankle at the leg's narrowest neck above the foot; the wrist where the paw's round end begins, half the arm's width up from
  its end (the arm has no neck: it's as wide all the way down)
- the knee and the elbow half way between, on the centre line

A bend is shared evenly between a chain's joints in Studio's IK, so four even bones bent a limb into a banana. Each chain is a long
upper bone, two short ones at the joint and a long lower one: its three joints sit within 20 px of the knee or elbow, so the limb
stays straight either side and the joint rounds. The foot is its own `level` bone (carried by the shin's end, not turned with it),
so it stays flat as the shin tips. The bone names stay (s legL 1..4, s armL 1..4, the IK on 4) so cover_check.py finds them; the IK
controls stay where they were on the canvas. The owner's shapes are left as they are: only bones and pins change.

puppet_side.py rigs its limbs with apply() too. Save Studio first, then from tools/art:
../sfx/.venv/Scripts/python -I side_limbs.py, then reload Studio without saving.
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import owner_transfer as T  # noqa: E402

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = os.environ.get("SIDE_DOC", "puppet-views")
JOINT_LEN = 20      # (the two short joint bones together: how round a knee or elbow is)
DARK = "#393a36"
COLS = ["#e0574a", "#f2963d", "#4fd1c5", "#3b8eea", "#9b6dd6"]


def outline(lid):
    return np.concatenate([T.sample(s, 400) for f, s in T.shapes_of(DOC, lid) if f.lower() == DARK][:1])


def across(pts, y):
    """the outline's width at height y: its left and right edges (the outermost crossings)"""
    xs = []
    for a, b in zip(pts, np.roll(pts, -1, axis=0)):
        if (a[1] - y) * (b[1] - y) < 0:
            xs.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
    return (min(xs), max(xs)) if len(xs) >= 2 else None


def centre(pts, y):
    w = across(pts, y)
    return np.array([(w[0] + w[1]) / 2, float(y)])


def widest(pts, y0, y1):
    ys = [y for y in range(int(y0), int(y1)) if across(pts, y)]
    return max(ys, key=lambda y: across(pts, y)[1] - across(pts, y)[0])


def narrowest(pts, y0, y1):
    ys = [y for y in range(int(y0), int(y1)) if across(pts, y)]
    return min(ys, key=lambda y: across(pts, y)[1] - across(pts, y)[0])


def bone(id_, parent, a, b, follow=None, **extra):
    a, b = np.asarray(a, float), np.asarray(b, float)
    out = {"id": id_, "name": id_, "parent": parent, "hx": round(float(a[0]), 1), "hy": round(float(a[1]), 1),
           "angle": round(math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])), 1), "length": round(float(np.linalg.norm(b - a)), 1),
           "rotation": 0, "x": 0, "y": 0, "scale": 1, "keys": {}, "loop": 0, **extra}
    if follow:
        out["follow"] = follow
    return out


def chain(prefix, top, joint, end, follow, old_ik, kind, bend=None, ctl=None):
    """the four bones: upper, two short ones either side of the joint, lower (with the IK); the IK's control kept where it was"""
    top, joint, end = (np.asarray(p, float) for p in (top, joint, end))
    bend = old_ik["bend"] if bend is None else bend
    # (drawn leaning the other way from its bend, Studio's Rest pose turns the bend round to lie as drawn, and the elbow flipped:
    # the owner, 5 Nov 2026, "the elbow should be the other way round... by default". Then the joint goes on the straight line)
    a, b = joint - top, end - joint
    if np.sign(a[0] * b[1] - a[1] * b[0]) == -bend:
        d = (end - top) / np.linalg.norm(end - top)
        joint = top + d * float((joint - top) @ d)
    u, v = (joint - top) / np.linalg.norm(joint - top), (end - joint) / np.linalg.norm(end - joint)
    j0, j2 = joint - u * JOINT_LEN / 2, joint + v * JOINT_LEN / 2
    ids = [f"{prefix}{i}" for i in range(1, 5)]
    ik = dict(old_ik)
    # (the control off the end by `ctl`; else where it was on the canvas. Kept where it was, a hand dragged away when the rig was
    # remade took its control 400 px off with it: "broken hand controls positions", the owner, 5 Nov 2026)
    if ctl is None:
        ctl = (old_ik["tx"] + old_ik.get("ox", 0) - end[0], old_ik["ty"] + old_ik.get("oy", 0) - end[1])
    ik.update({"root": ids[0], "tx": round(float(end[0]), 1), "ty": round(float(end[1]), 1), "kind": kind, "bend": bend,
               "ox": round(float(ctl[0]), 1), "oy": round(float(ctl[1]), 1)})
    return [bone(ids[0], None, top, j0, follow=follow, color=COLS[0]), bone(ids[1], ids[0], j0, joint, color=COLS[1]),
            bone(ids[2], ids[1], joint, j2, color=COLS[2]), bone(ids[3], ids[2], j2, end, color=COLS[3], ik=ik)], (j0, j2)


def leg(lid, prefix, old):
    pts = outline(lid)
    top = pts[:, 1].min()
    hip_y = top + (lambda y: across(pts, y)[1] - across(pts, y)[0])(widest(pts, top + 20, 1000)) / 2   # (the round thigh's middle)
    sole = pts[:, 1].max()
    ankle_y = narrowest(pts, hip_y + 100, sole - 50)                  # (the neck above the foot)
    hip, ankle = centre(pts, hip_y), centre(pts, ankle_y)
    knee = centre(pts, (hip_y + ankle_y) / 2)
    bones, (k0, k2) = chain(prefix, hip, knee, ankle, old[f"{prefix}1"].get("follow", "sHips"), old[f"{prefix}4"]["ik"], "foot", 1,   # (knee forward)
                            ctl=(0, sole + 26 - ankle[1]))                                                               # (its control under the sole)
    # (the foot: a level bone from the ankle to the toes, along the sole 25 px up; heel and toes the outline's ends there)
    y = sole - 25
    heel, toe = np.array([across(pts, y)[0] + 15, y]), np.array([across(pts, y)[1] - 15, y])
    bones.append(bone(f"{prefix}foot", f"{prefix}4", ankle, toe, color=COLS[4], level=True))
    ids = [b["id"] for b in bones]
    pins = [("top", hip, ids[0]), ("thigh", (hip + k0) / 2, ids[0]), ("knee", knee, ids[2]), ("shin", (k2 + ankle) / 2, ids[3]),
            ("ankle", ankle, ids[3]), ("heel", heel, ids[4]), ("midfoot", (heel + toe) / 2, ids[4]), ("toe", toe, ids[4])]
    r = lambda p: tuple(int(round(float(v))) for v in p)
    return bones, pins, f"hip {r(hip)}, knee {r(knee)}, ankle {r(ankle)}"


def arm(lid, prefix, old):
    pts = outline(lid)
    top, bottom = pts[:, 1].min(), pts[:, 1].max()
    w = max(across(pts, y)[1] - across(pts, y)[0] for y in range(int(top) + 5, int(bottom) - 5) if across(pts, y))
    shoulder_y = top + w / 2                                          # (the cap's middle)
    wrist_y = bottom - w / 2                                          # (where the paw's round end begins)
    shoulder, wrist = centre(pts, shoulder_y), centre(pts, wrist_y)
    elbow = centre(pts, (shoulder_y + wrist_y) / 2)
    paw = centre(pts, (wrist_y + bottom) / 2)
    fore = (wrist - elbow) / np.linalg.norm(wrist - elbow)
    bones, (e0, e2) = chain(prefix, shoulder, elbow, wrist, old[f"{prefix}1"].get("follow", "sTorso"), old[f"{prefix}4"]["ik"], "hand", -1,   # (elbow down, measured)
                            ctl=fore * 55)                                                                               # (its control on past the wrist, at the paw)
    ids = [b["id"] for b in bones]
    pins = [("top", shoulder, ids[0]), ("upper", (shoulder + e0) / 2, ids[0]), ("elbow", elbow, ids[2]),
            ("fore", (e2 + wrist) / 2, ids[3]), ("wrist", wrist, ids[3]), ("paw", paw, ids[3])]
    r = lambda p: tuple(int(round(float(v))) for v in p)
    return bones, pins, f"shoulder {r(shoulder)}, elbow {r(elbow)}, wrist {r(wrist)}"


def apply(doc):
    L = {l["id"]: l for l in doc["layers"]}
    old = {b["id"]: b for b in doc["bones"]}
    for lid, prefix, how in (("sLegL", "slegL", leg), ("sLegR", "slegR", leg), ("sArmL", "sarmL", arm), ("sArmR", "sarmR", arm)):
        bones, pins, said = how(lid, prefix, old)
        doc["bones"] = [b for b in doc["bones"] if not b["id"].startswith(prefix)] + bones
        l = L[lid]
        x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
        l["puppet"] = {**l.get("puppet", {}), "pins": [{"id": n, "rx": round(float(p[0] - x0), 1), "ry": round(float(p[1] - y0), 1),
                                                        "x": 0, "y": 0, "bone": b, "keys": {}} for n, p, b in pins]}
        print(f"  {lid}: {said}; {len(pins)} pins on its centre line")


if __name__ == "__main__":
    path = f"{ROOT}/docs/{DOC}.json"
    d = json.load(open(path, encoding="utf-8"))
    apply(d)
    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{DOC}: the side's arms and legs rigged on their centre lines; reload Studio without saving")
