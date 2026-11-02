"""Bùbù's master rig (owner, 2 Nov 2026: "a rig that is versatile"): one neutral standing panda cut into every part a
character animator needs, so a moment is posed in Studio rather than drawn as a new sticker each time. Today's parts
were each made for one move, and his body and legs are one piece, so he can't crouch, leap or kick.

Everything is drawn over the approved master at its exact size and place, so the parts stack back into him. Jobs for
Codex in the group "rigm", saved as out/raw/rm-<part>.png. See RIG_MASTER.md.

From tools/art: ../sfx/.venv/Scripts/python -I add_rigm.py
"""
import json

jobs = json.load(open("jobs.json", encoding="utf-8"))
style = next(j for j in jobs if j["group"] == "rig6")["prompt"].split("Style:", 1)[1]
STYLE = "\n\nStyle:" + style

MASTER = ("The attached images show Bùbù the panda. Draw him as an animator's model sheet pose: standing straight, facing "
          "front, feet apart under his hips, arms hanging a little away from his sides so no part overlaps another, paws "
          "open, a calm closed-mouth smile with eyes open. Keep his exact proportions, face, colours and red backpack straps. "
          "He fills most of the square canvas, centred, with his whole body in frame and room around him.")
BARE = ("Edit the attached image: take off his backpack and its two red straps completely, and nothing else. Where the straps "
        "crossed his chest and shoulders, there's plain black fur and his cream belly's edge, and no red or orange is left "
        "anywhere. Keep everything else exactly as it is: the same pose, size, position, proportions, face and colours.")
PIECE = ("The attached image is Bùbù's model sheet. Edit it by erasing everything except the piece described below. The piece "
         "stays at EXACTLY the size, position and angle it has on the sheet: never move, re-centre or enlarge it, even though it "
         "leaves it off-centre with a lot of empty canvas. It has to stack back onto the other pieces. Square canvas, the same "
         "framing.\n\nThe piece: ")
JOINT = " Where it joins the next part it ends in a soft rounded end, extended a little past the joint, so it can turn there with no gap."
PARTS = {
    # the body
    "torso": "his torso alone, staying where it is on the sheet: the black chest and the cream belly, with NO head, arms or legs. Where the head covered his chest, complete the black chest up to a rounded neck." + JOINT,
    "straps": "ONLY his two red backpack straps, with no body. Where the head covered them, complete them up to where they'd go over his shoulders.",
    "pack": "his red backpack alone, as much of it as would sit behind his back, drawn whole.",
    "tail": "his small round tail alone.",
    # the head, built up
    "head": "his head alone: the cream shape with its soft hair tuft, with NO ears, NO eye patches, NO eyes, NO nose, NO mouth and NO cheeks. A blank face.",
    "ear-l": "his left ear alone (on the viewer's left), whole, including the part that would be hidden behind his head.",
    "ear-r": "his right ear alone (on the viewer's right), whole, including the part that would be hidden behind his head.",
    "patches": "ONLY his two black eye patches, with no eyes in them.",
    "nose": "ONLY his nose.",
    "cheeks": "ONLY his two pink cheeks.",
    # eyes, on the patches
    "eyes-open": "ONLY his two open eyes with their glints, as on the sheet, without the patches.",
    "eyes-happy": "ONLY his two eyes as happy upward curves, closed in a smile, without the patches.",
    "eyes-shut": "ONLY his two eyes gently closed in a level line (a blink), without the patches.",
    "eyes-wow": "ONLY his two eyes very wide with big glints, amazed, without the patches.",
    "eyes-squint": "ONLY his two eyes screwed shut as tight arcs like > <, without the patches.",
    # mouths
    "mouth-smile": "ONLY his closed smile.",
    "mouth-open": "ONLY a big open happy mouth with a little tongue.",
    "mouth-o": "ONLY a small round surprised O mouth.",
    "mouth-frown": "ONLY a small sad mouth, curving down.",
    # whole limbs, split at their joints in code (the model won't stop at an elbow), and the paws a split can't give
    "paw-fist": "ONLY his right paw closed in a round fist, at the same place and size." + JOINT,
    "paw-point": "ONLY his right paw pointing with one rounded finger, at the same place and size." + JOINT,
    "paw-thumb": "ONLY his right paw giving a thumbs up, at the same place and size." + JOINT,
    "limb-arm-l": "his whole left arm alone (viewer's left), shoulder to paw with its toe lines, and none of his body. Its top ends in a soft rounded shoulder where it meets his body.",
    "limb-arm-r": "his whole right arm alone (viewer's right), shoulder to paw with its toe lines, and none of his body. Its top ends in a soft rounded shoulder where it meets his body.",
    "limb-leg-l": "his whole left leg alone (viewer's left), hip to foot with its toe lines, and none of his belly. Where the belly covered it, complete the black leg up to a soft rounded hip.",
    "limb-leg-r": "his whole right leg alone (viewer's right), hip to foot with its toe lines, and none of his belly. Where the belly covered it, complete the black leg up to a soft rounded hip.",
}
BACKDROP = "\n\nThe backdrop is one flat solid magenta (#FF00FF) with nothing else on it: no shadow, no ground, no text."

jobs = [j for j in jobs if j["group"] != "rigm"]
jobs.append({"file": "out/raw/rm-master.png", "group": "rigm", "size": "1024x1024",
             "refs": ["refs/ref-rig-idle.png", "refs/ref-rig5-head.png"], "prompt": MASTER + BACKDROP + STYLE})
# the panda with nothing on, so no body part carries a strap or a bit of backpack; only those two are drawn from the master
jobs.append({"file": "out/raw/rm-bare.png", "group": "rigm", "size": "1024x1024", "refs": ["out/raw/rm-master.png"],
             "prompt": BARE + BACKDROP + STYLE})
for k, text in PARTS.items():
    sheet = "master" if k in ("pack", "straps") else "bare"
    jobs.append({"file": f"out/raw/rm-{k}.png", "group": "rigm", "size": "1024x1024",
                 "refs": [f"out/raw/rm-{sheet}.png"], "prompt": PIECE + text + BACKDROP + STYLE})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(PARTS) + 1, "jobs in rigm")
