"""Bùbù's rest pose in the new flat style (owner, 3 Nov 2026): the hero drawings (out/raw/rm-hero-1..5) are all action poses, and a puppet
is built from one neutral pose, straight on, with every limb clear of the body so its whole shape shows. Two takes, saved as
out/raw/rm-rest-a.png and rm-rest-b.png, to pick from.

From tools/art: ../sfx/.venv/Scripts/python -I add_puppet.py
"""
import json

jobs = json.load(open("jobs.json", encoding="utf-8"))
jobs = [j for j in jobs if j["group"] != "puppet"]
REST = ("The attached images are Bùbù the panda, drawn in a flat style with no black outline. Draw him once more in exactly that style, the same "
        "proportions, colours and shapes as the first three images, as a neutral rest pose for a character rig. He stands straight and faces us "
        "head on, perfectly symmetrical: his weight even on both feet, his legs a little apart with the feet flat and pointing slightly outward, "
        "his arms held away from his body and angled down, about 30 degrees out from his sides, the paws open and relaxed. No limb overlaps his "
        "body or another limb, so the whole outline of each arm and leg shows. A calm, friendly face: small round black eyes inside the round eye "
        "patches, and a small closed smile. Keep his design: the round eye patches, the tuft of hair on top of his head, his cheeks, two single "
        "muted red straps that never cross, and two grey toe lines on each paw and foot. He holds nothing: no seal. His whole body is in frame "
        "with plenty of room round him, centred. No action lines, sparkles, shadow, ground or text. The backdrop is one flat solid magenta "
        "(#FF00FF) with nothing else on it.")
for take in "ab":
    jobs.append({"file": f"out/raw/rm-rest-{take}.png", "group": "puppet", "size": "1024x1024",
                 "refs": ["out/raw/rm-hero-4.png", "out/raw/rm-hero-5.png", "out/raw/rm-hero-1.png", "out/raw/rm-master.png"], "prompt": REST})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("puppet jobs added")
