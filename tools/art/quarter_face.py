"""The three-quarter's face look control, as the front's (4 Nov 2026): a "face (look)" null on the head with the nose-shaped control,
and the features linked to it with the front's parallax. The nose and mouth move with it most, the patches and brows less, the cheeks
less again, the eyes ride on their patches, and the ears go a little the other way. Every link is set so the face sits exactly as
drawn at rest. Run it again whenever a feature's layer has moved (it rewrites the links, nothing else).

Save Studio first, then run this, then reload Studio without saving.
From tools/art: ../sfx/.venv/Scripts/python -I quarter_face.py
"""
import json

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = "puppet-views"
path = f"{ROOT}/docs/{DOC}.json"
d = json.load(open(path, encoding="utf-8"))
L = {l["id"]: l for l in d["layers"]}
# (the front's parallax, feature by feature)
MUL = {"qNose": 1, "qMouth": 0.9, "qBrowL": 0.8, "qBrowR": 0.8, "qPatchL": 0.75, "qPatchR": 0.75, "qEyeL": 0.1, "qEyeR": 0.1,
       "qCheekL": 0.55, "qCheekR": 0.55, "qEarL": -0.3, "qEarR": -0.3}
nose = L["qNose"]
fx, fy = nose["x"], nose["y"]
face = {"id": "qFace", "name": "face (look) (3/4)", "art": "", "w": 60, "h": 60, "x": fx, "y": fy, "scale": 1, "rotation": 0,
        "flipX": False, "opacity": 1, "visible": True, "locked": False, "pivot": {"x": fx, "y": fy}, "keys": {}, "loop": 0, "blink": 0,
        "nullObj": True, "parent": "qHead", "group": "Three-quarter",
        "control": {"kind": "move", "shape": "nose", "like": "qNose", "x": fx, "y": fy, "r": 44}}
if "qFace" in L:
    face["keys"] = L["qFace"].get("keys", {})
    L["qFace"].update(face)
else:
    i = next(k for k, l in enumerate(d["layers"]) if l["id"] == "qHead")
    d["layers"].insert(i, face)
# (but sideways, the far side bunches up: turned away, its features go round the head's edge, so they follow less. The far cheek,
# which already runs off the head's edge, doesn't follow sideways at all, or it slides out past the head)
MUL_X = dict(MUL, qPatchR=0.45, qBrowR=0.5, qCheekR=0, qEarR=-0.15)
for lid, m in MUL.items():
    l, mx = L[lid], MUL_X[lid]
    l["links"] = {"x": {"layer": "qFace", "prop": "x", "mul": mx, "add": round(l["x"] - mx * fx, 2)},
                  "y": {"layer": "qFace", "prop": "y", "mul": m, "add": round(l["y"] - m * fy, 2)}}
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(f"qFace at ({fx:.0f}, {fy:.0f}) on the head, {len(MUL)} features linked")
