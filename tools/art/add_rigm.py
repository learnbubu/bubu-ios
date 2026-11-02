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
PIECE = ("The attached image is Bùbù's model sheet. Edit it by erasing everything except the piece described below. The piece "
         "stays at EXACTLY the size, position and angle it has on the sheet: never move, re-centre or enlarge it, even though it "
         "leaves it off-centre with a lot of empty canvas. It has to stack back onto the other pieces. Square canvas, the same "
         "framing.\n\nThe piece: ")
JOINT = " Where it joins the next part it ends in a soft rounded end, extended a little past the joint, so it can turn there with no gap."
PARTS = {
    # the body
    "torso": "his torso alone, staying where it is on the sheet: the black chest, the cream belly and the two red straps, with NO head, arms, legs or backpack. Where the head covered his chest, complete the black chest and the straps up to a rounded neck." + JOINT,
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
    # arms: upper, lower, paws in every shape a move needs
    "arm-l": "only the top half of his left arm (viewer's left), from the shoulder down to the elbow, which is halfway down the arm: black fur only, with NO forearm, NO paw, NO strap and NO backpack." + JOINT,
    "forearm-l": "only the lower half of his left arm (viewer's left), from the elbow, which is halfway down the arm, to the wrist: black fur only, with NO upper arm, NO paw and NO strap." + JOINT,
    "arm-r": "only the top half of his right arm (viewer's right), from the shoulder down to the elbow, which is halfway down the arm: black fur only, with NO forearm, NO paw, NO strap and NO backpack." + JOINT,
    "forearm-r": "only the lower half of his right arm (viewer's right), from the elbow, which is halfway down the arm, to the wrist: black fur only, with NO upper arm, NO paw and NO strap." + JOINT,
    "paw-open": "ONLY his right paw (viewer's right), the rounded end of the arm with its two grey toe lines, as on the sheet." + JOINT,
    "paw-fist": "ONLY his right paw closed in a round fist, at the same place and size." + JOINT,
    "paw-point": "ONLY his right paw pointing with one rounded finger, at the same place and size." + JOINT,
    "paw-thumb": "ONLY his right paw giving a thumbs up, at the same place and size." + JOINT,
    # legs
    "leg-l": "his left thigh alone (viewer's left), hip to knee." + JOINT,
    "shin-l": "his left lower leg alone, knee to ankle, with NO foot." + JOINT,
    "foot-l": "his left foot alone." + JOINT,
    "leg-r": "his right thigh alone (viewer's right), hip to knee." + JOINT,
    "shin-r": "his right lower leg alone, knee to ankle, with NO foot." + JOINT,
    "foot-r": "his right foot alone." + JOINT,
}
BACKDROP = "\n\nThe backdrop is one flat solid magenta (#FF00FF) with nothing else on it: no shadow, no ground, no text."

jobs = [j for j in jobs if j["group"] != "rigm"]
jobs.append({"file": "out/raw/rm-master.png", "group": "rigm", "size": "1024x1024",
             "refs": ["refs/ref-rig-idle.png", "refs/ref-rig5-head.png"], "prompt": MASTER + BACKDROP + STYLE})
for k, text in PARTS.items():
    jobs.append({"file": f"out/raw/rm-{k}.png", "group": "rigm", "size": "1024x1024",
                 "refs": ["out/raw/rm-master.png"], "prompt": PIECE + text + BACKDROP + STYLE})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(PARTS) + 1, "jobs in rigm")
