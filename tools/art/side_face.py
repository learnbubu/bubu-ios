"""The side view's face look control, as the front's and the three-quarter's (quarter_face.py): an "sFace" null on the head with the
nose-shaped control, the features linked to it. In profile every feature is on the near side, so they all follow at the front's rates,
but the nose and mouth sit on the head's front edge: sideways they go no further forward than the edge (they'd leave the head), so
they follow less that way. The ear goes a little the other way. Every link is set so the face sits exactly as drawn at rest.

Save Studio first, then run this, then reload Studio without saving.
From tools/art: ../sfx/.venv/Scripts/python -I side_face.py
"""
import json
import os

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = os.environ.get("SIDE_DOC", "puppet-views")   # (a copy to try on: SIDE_DOC=<doc id>)
path = f"{ROOT}/docs/{DOC}.json"
d = json.load(open(path, encoding="utf-8"))
L = {l["id"]: l for l in d["layers"]}
MUL = {"sNose": 1, "sMouth": 0.9, "sBrow": 0.8, "sPatch": 0.75, "sEye": 0.1, "sCheek": 0.55, "sEarL": -0.3}
MUL_X = dict(MUL, sNose=0.4, sMouth=0.4)
nose = L["sNose"]
fx, fy = nose["x"], nose["y"]
face = {"id": "sFace", "name": "face (look) (side)", "art": "", "w": 60, "h": 60, "x": fx, "y": fy, "scale": 1, "rotation": 0,
        "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": fx, "y": fy}, "keys": {}, "loop": 0, "blink": 0,
        "nullObj": True, "parent": "sHead", "group": "Side",
        "control": {"kind": "move", "shape": "nose", "like": "sNose", "x": fx, "y": fy, "r": 40}}
if "sFace" in L:
    face["keys"] = L["sFace"].get("keys", {})
    L["sFace"].update(face)
else:
    i = next(k for k, l in enumerate(d["layers"]) if l["id"] == "sHead")
    d["layers"].insert(i, face)
for lid, m in MUL.items():
    l, mx = L[lid], MUL_X[lid]
    l["links"] = {"x": {"layer": "sFace", "prop": "x", "mul": mx, "add": round(l["x"] - mx * fx, 2)},
                  "y": {"layer": "sFace", "prop": "y", "mul": m, "add": round(l["y"] - m * fy, 2)}}
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"sFace at ({fx:.0f}, {fy:.0f}) on the head, {len(MUL)} features linked")
