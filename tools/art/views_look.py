"""Every view of Puppet Views looks the same (the owner, 5 Nov 2026: "lets make sure colours match all the angles then add the
shadows to the other angles too").

1. Colours: the three-quarter's and side's fills made the front's (the front is his master puppet): the red of the straps and
   pack, the cheeks' pink, the head's and eyes' cream, the belly's cream and the mouth's dark. A part whose colours change gets a
   copy of its file, `<file>-colour.svg`, with only its fills changed; his shapes and his own files stay as they are.
2. Light: the document's light, as Relaxed has it (strength 0.16, 13 away, softness 1), a lamp up in front. Every part of the body
   casts and takes shadows in each view, but (the owner, the side, 5 Nov 2026):
   - the backpack and the straps take no shadows ("no shadow from body to backpack"; a strap's run beside the pack is the same red)
   - the belly throws none on the legs, and the near leg none on the torso ("front leg onto the black torso shadow")
   - the far leg and far arm are in a stronger light of their own (0.4), so they part from the near ones as they cross: a 16%
     shadow doesn't show on near-black
   The face is left alone.

Save Studio first, then from tools/art: ../sfx/.venv/Scripts/python -I views_look.py, then reload Studio without saving.
"""
import json
import os
import re

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
DOC = os.environ.get("VIEWS_DOC", "puppet-views")
ART = f"{ROOT}/art/{DOC}/"

FRONT = {"red": "#f56044", "cheek": "#fbb9b5", "head": "#fef8e8", "belly": "#fdf8e7", "mouth": "#363733"}
WAS = {"red": {"#f45f44"}, "cheek": {"#f7b7b9"}, "head": {"#fdf6e0", "#fdf6e4"}, "belly": {"#fef9e3", "#fffce8"}, "mouth": {"#393a36"}}


def role(lid):
    n = lid.lower()
    if "mouth" in n: return "mouth"
    if "cheek" in n: return "cheek"
    if "belly" in n: return "belly"
    if n in ("qhead", "shead") or "eye" in n: return "head"
    return None


def colours(d):
    made = {}
    for l in d["layers"]:
        if l.get("group") not in ("Side", "Three-quarter") or not l.get("art", "").endswith(".svg"):
            continue
        src, r = l["art"], role(l["id"])

        def fix(m):
            c = m.group(1).lower()
            if c in WAS["red"]: return f'fill="{FRONT["red"]}"'
            if r and c in WAS[r]: return f'fill="{FRONT[r]}"'
            return m.group(0)
        text = open(ART + src, encoding="utf-8").read()
        new = re.sub(r'fill="(#[0-9a-fA-F]{6})"', fix, text)
        if new == text:
            continue
        out = made.get(src) or re.sub(r"\.svg$", "", src) + "-colour.svg"
        if src not in made:
            open(ART + out, "w", encoding="utf-8").write(new)
            made[src] = out
        l["art"] = out
        print(f"  {l['id']}: {src} -> {out}")


VIEWS = {
    "front": dict(body=["head", "earL", "earR", "torso", "belly", "strapL", "strapR", "armL", "armR", "legL", "legR"],
                  pack=["strapL", "strapR"], belly="belly", legs=["legL", "legR"], near_leg=None, torso="torso", far=[]),
    "quarter": dict(body=["qHead", "qEarL", "qEarR", "qTorso", "qBelly", "qPack", "qStrapL", "qStrapLOver", "qStrapR", "qArmL", "qArmR", "qLegL", "qLegR"],
                    pack=["qPack", "qStrapL", "qStrapLOver", "qStrapR"], belly="qBelly", legs=["qLegL", "qLegR"], near_leg="qLegL", torso="qTorso",
                    far=["qLegR", "qArmR"]),
    "side": dict(body=["sHead", "sEarL", "sEarR", "sTorso", "sBelly", "sPack", "sStrapL", "sStrapLOver", "sArmL", "sArmR", "sLegL", "sLegR"],
                 pack=["sPack", "sStrapL", "sStrapLOver"], belly="sBelly", legs=["sLegL", "sLegR"], near_leg="sLegL", torso="sTorso",
                 far=["sLegR", "sArmR"]),
}
LAMP = {"on": True, "x": 1150, "y": -150, "distance": 13, "softness": 1}


def light(d):
    L = {l["id"]: l for l in d["layers"]}
    far = []
    for c in VIEWS.values():
        for lid in c["body"]:
            L[lid]["shade"] = {"cast": True, "receive": lid not in c["pack"]}
        L[c["belly"]]["shade"]["skip"] = list(c["legs"])
        if c["near_leg"]:
            L[c["near_leg"]]["shade"]["skip"] = [c["torso"]]
        far += c["far"]
    d["light"] = {**LAMP, "strength": 0.16}
    d["lights"] = [{**LAMP, "strength": 0.4, "only": far, "instead": True}]
    print(f"  lit: the body in every view; the far limbs ({', '.join(far)}) in a stronger light")


if __name__ == "__main__":
    path = f"{ROOT}/docs/{DOC}.json"
    d = json.load(open(path, encoding="utf-8"))
    colours(d)
    light(d)
    json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{DOC}: colours matched to the front, every view lit; reload Studio without saving")
