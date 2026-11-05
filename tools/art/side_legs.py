"""The side view's legs, rigged to bend at a knee with a flat foot (the owner, 5 Nov 2026: the first rig's legs crumpled when a foot
lifted, and sank without bending when the hips dropped; "do a first pass on the legs and show me").

Studio's IK shares a bend evenly between a chain's joints, so four equal bones bent a leg into a banana. Here the chain is a long
thigh, two short knee bones and a long shin: its three joints sit within 20 px of the knee, so the thigh and shin stay straight and
the knee rounds. The foot is its own bone, `level` (Studio: carried by the shin's end, not turned with it), so it stays flat as the
shin tips. Pins: the hip, the thigh's middle, the knee, the shin's middle and the ankle on the chain; the heel, the foot's middle and
the toes on the foot.

The bone names stay (s legL 1..4, the IK on 4) so cover_check.py finds them. The owner's leg shapes are left as they are: only bones
and pins change. puppet_side.py builds its legs with leg_rig() too.

Save Studio first, then from tools/art: ../sfx/.venv/Scripts/python -I side_legs.py, then reload Studio without saving.
"""
import json
import math
import os

import numpy as np

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = os.environ.get("SIDE_DOC", "puppet-views")
KNEE = 0.5          # (the knee half way between the hip and the ankle)
KNEE_LEN = 20       # (the two short knee bones together: how round the knee is)
COLS = ["#e0574a", "#f2963d", "#4fd1c5", "#3b8eea", "#9b6dd6"]


def bone(id_, parent, a, b, follow=None, **extra):
    a, b = np.asarray(a, float), np.asarray(b, float)
    out = {"id": id_, "name": id_, "parent": parent, "hx": round(float(a[0]), 1), "hy": round(float(a[1]), 1),
           "angle": round(math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])), 1), "length": round(float(np.linalg.norm(b - a)), 1),
           "rotation": 0, "x": 0, "y": 0, "scale": 1, "keys": {}, "loop": 0, **extra}
    if follow:
        out["follow"] = follow
    return out


def leg_rig(prefix, hip, ankle, toe, heel, follow, bend, foot_oy, old_ik=None):
    """A leg's bones (thigh, two knee bones, shin with the IK, a level foot) and its pins, in the document."""
    hip, ankle = np.asarray(hip, float), np.asarray(ankle, float)
    d = (ankle - hip) / np.linalg.norm(ankle - hip)
    L = np.linalg.norm(ankle - hip)
    k0 = hip + d * (L * KNEE - KNEE_LEN / 2)
    k1 = hip + d * L * KNEE
    k2 = hip + d * (L * KNEE + KNEE_LEN / 2)
    ids = [f"{prefix}{i}" for i in range(1, 5)]
    ik = dict(old_ik or {})
    ik.update({"root": ids[0], "tx": round(float(ankle[0]), 1), "ty": round(float(ankle[1]), 1), "bend": bend, "kind": "foot", "oy": foot_oy})
    ik.setdefault("mix", 1); ik.setdefault("space", "view-side"); ik.setdefault("keys", {}); ik.setdefault("ox", 0)
    bones = [bone(ids[0], None, hip, k0, follow=follow, color=COLS[0]),
             bone(ids[1], ids[0], k0, k1, color=COLS[1]),
             bone(ids[2], ids[1], k1, k2, color=COLS[2]),
             bone(ids[3], ids[2], k2, ankle, color=COLS[3], ik=ik),
             bone(f"{prefix}foot", ids[3], ankle, toe, color=COLS[4], level=True)]
    mid_foot = (np.asarray(heel, float) + np.asarray(toe, float)) / 2
    pins = [("top", hip, ids[0]), ("thigh", (hip + k0) / 2, ids[0]), ("knee", k1, ids[2]), ("shin", (k2 + ankle) / 2, ids[3]),
            ("ankle", ankle, ids[3]), ("heel", heel, f"{prefix}foot"), ("midfoot", mid_foot, f"{prefix}foot"), ("toe", toe, f"{prefix}foot")]
    return bones, pins


def apply(doc):
    L = {l["id"]: l for l in doc["layers"]}
    B = {b["id"]: b for b in doc["bones"]}
    for side in ("L", "R"):
        lid, prefix = f"sLeg{side}", f"sleg{side}"
        old_end = B[f"{prefix}4"]
        hip = (B[f"{prefix}1"]["hx"], B[f"{prefix}1"]["hy"])
        ankle = (old_end["ik"]["tx"], old_end["ik"]["ty"])
        l = L[lid]
        x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
        # (the foot along its sole: the heel and toes from the leg's own outline, 25 px up from its lowest point)
        heel, toe = foot_of(lid, ankle)
        bones, pins = leg_rig(prefix, hip, ankle, toe, heel, B[f"{prefix}1"].get("follow", "sHips"), old_end["ik"]["bend"],
                              old_end["ik"].get("oy", 94), old_ik=old_end["ik"])
        doc["bones"] = [b for b in doc["bones"] if not b["id"].startswith(prefix)] + bones
        l["puppet"] = {**l.get("puppet", {}), "pins": [{"id": n, "rx": round(float(p[0] - x0), 1), "ry": round(float(p[1] - y0), 1), "x": 0, "y": 0,
                                                        "bone": b, "keys": {}} for n, p, b in pins]}
        print(f"  {lid}: hip {tuple(round(v) for v in hip)}, knee {tuple(round(float(v)) for v in (np.add(hip, ankle) / 2))}, "
              f"ankle {tuple(round(v) for v in ankle)}, heel {tuple(round(float(v)) for v in heel)}, toe {tuple(round(float(v)) for v in toe)}; "
              f"{len(pins)} pins, the foot level")


def foot_of(lid, ankle):
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import owner_transfer as T
    pts = np.concatenate([T.sample(s, 200) for f, s in T.shapes_of(DOC, lid) if f.lower() == "#393a36"])
    y = pts[:, 1].max() - 25
    row = pts[np.abs(pts[:, 1] - y) < 6]
    return (float(row[:, 0].min()) + 15, y), (float(row[:, 0].max()) - 15, y)


if __name__ == "__main__":
    path = f"{ROOT}/docs/{DOC}.json"
    d = json.load(open(path, encoding="utf-8"))
    apply(d)
    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{DOC}: the side's legs rigged with knees and level feet; reload Studio without saving")
