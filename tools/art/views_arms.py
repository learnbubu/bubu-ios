"""The front's and three-quarter's arms rigged as the side's are (side_limbs.py), from the owner's own shapes (the owner, 5 Nov
2026: "now do the arms rig polish - arms flip on elbow for front view too").

- Every joint and pin on the arm's centre line, the middle of its width across the arm (the owner: "the centre point along the
  thickest width"). The front's arms hang out at a slant, so the width is measured square to the arm's own line (shoulder to
  hand), not across the page.
- The shoulder in the middle of the arm's round cap, half its widest width in from the top; the wrist where the paw's round end
  begins, half that from the bottom; the elbow half way between.
- A long upper arm, two short bones at the elbow, a long forearm: the bend gathers at the elbow (Studio's IK shares a bend
  evenly between a chain's joints), not a banana.
- The bones keep their names, so his animations (the front's wave keys its right hand's target and bend) still drive them; each
  hand's control stays where it was on the canvas.
- The front's arms bend as mirror images: its screen-left arm had the same bend as its right, so one elbow folded in.

Save Studio first, then from tools/art: ../sfx/.venv/Scripts/python -I views_arms.py, then reload Studio without saving.
"""
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
import owner_transfer as T  # noqa: E402
import side_limbs as S  # noqa: E402

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = os.environ.get("VIEWS_DOC", "puppet-views")
S.DOC = DOC
# each arm: its layer, its chain's four bones, top to the one with the IK, and its bend (None: as it is)
ARMS = [("armR", ["bUpperArmR", "Bkf8450c", "bForearmR", "Bizhnq98"], None),
        ("armL", ["bUpperArmL", "bUpperArmL2", "bForearmL", "bForearmL2"], 1),
        ("qArmL", ["qarmL1", "qarmL2", "qarmL3", "qarmL4"], 1),
        ("qArmR", ["qarmR1", "qarmR2", "qarmR3", "qarmR4"], -1)]
# (the bends: the elbow down with the hand raised up and out to its side (the owner, 5 Nov 2026: "default elbow down when arm
# up"), as measured with Studio's own IK; bubu-studio's tests/unit/puppet-elbows.test.ts checks every arm of every view)


def section(pts, c, n):
    """where the line through c along n crosses the outline: its two outermost crossings, as distances along n"""
    ts = []
    for a, b in zip(pts, np.roll(pts, -1, axis=0)):
        d = b - a
        den = n[0] * d[1] - n[1] * d[0]
        if abs(den) < 1e-9:
            continue
        w = a - c
        t = (w[0] * d[1] - w[1] * d[0]) / den          # (along n)
        u = (w[0] * n[1] - w[1] * n[0]) / den          # (along the edge)
        if 0 <= u <= 1:
            ts.append(t)
    return (min(ts), max(ts)) if len(ts) >= 2 else None


def centre_at(pts, o, u, n, s):
    c = o + u * s
    t = section(pts, c, n)
    return (c + n * (t[0] + t[1]) / 2, t[1] - t[0]) if t else (None, 0)


def arm(doc, lid, ids, bend):
    B = {b["id"]: b for b in doc["bones"]}
    top, end = B[ids[0]], B[ids[-1]]
    o = np.array([top["hx"], top["hy"]], float)
    ik = end["ik"]
    u = np.array([ik["tx"], ik["ty"]], float) - o
    u /= np.linalg.norm(u)
    n = np.array([-u[1], u[0]])
    pts = S.outline(lid)
    proj = (pts - o) @ u
    s0, s1 = proj.min(), proj.max()
    w = max(centre_at(pts, o, u, n, s)[1] for s in np.linspace(s0 + 4, s1 - 4, 80))
    shoulder, _ = centre_at(pts, o, u, n, s0 + w / 2)
    wrist, _ = centre_at(pts, o, u, n, s1 - w / 2)
    elbow, _ = centre_at(pts, o, u, n, (s0 + s1) / 2)
    paw, _ = centre_at(pts, o, u, n, s1 - w / 4)
    # (the four bones, renamed as they were: chain() names them prefix1..4, so they're given their own names after)
    made, (e0, e2) = S.chain("x", shoulder, elbow, wrist, top.get("follow"), ik, ik.get("kind", "hand"))
    rename = {f"x{i + 1}": ids[i] for i in range(4)}
    for b in made:
        b["id"] = b["name"] = rename[b["id"]]
        if b["parent"]:
            b["parent"] = rename[b["parent"]]
        old = B[b["id"]]
        b["name"], b["color"], b["keys"], b["loop"] = old["name"], old.get("color", b.get("color")), old.get("keys", {}), old.get("loop", 0)
        for k in ("rotation", "x", "y", "scale"):
            b[k] = old.get(k, b[k])
    made[-1]["ik"]["root"] = ids[0]
    made[-1]["ik"]["keys"] = ik.get("keys", {})
    if bend is not None:
        made[-1]["ik"]["bend"] = bend
    doc["bones"] = [made[ids.index(b["id"])] if b["id"] in ids else b for b in doc["bones"]]
    l = next(x for x in doc["layers"] if x["id"] == lid)
    x0, y0 = l["x"] - l["w"] / 2, l["y"] - l["h"] / 2
    pins = [("shoulder", shoulder, ids[0]), ("upper", (shoulder + e0) / 2, ids[0]), ("elbow", elbow, ids[2]),
            ("fore", (e2 + wrist) / 2, ids[3]), ("wrist", wrist, ids[3]), ("paw", paw, ids[3])]
    l["puppet"] = {**l.get("puppet", {}), "pins": [{"id": nm, "rx": round(float(p[0] - x0), 1), "ry": round(float(p[1] - y0), 1),
                                                    "x": 0, "y": 0, "bone": b, "keys": {}} for nm, p, b in pins]}
    r = lambda p: tuple(int(round(float(v))) for v in p)
    print(f"  {lid}: shoulder {r(shoulder)}, elbow {r(elbow)}, wrist {r(wrist)}, {made[-1]['ik']['bend']:+d} bend; 6 pins on its centre line")


if __name__ == "__main__":
    path = f"{ROOT}/docs/{DOC}.json"
    d = json.load(open(path, encoding="utf-8"))
    for lid, ids, bend in ARMS:
        arm(d, lid, ids, bend)
    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{DOC}: the front's and three-quarter's arms rigged on their centre lines; reload Studio without saving")
