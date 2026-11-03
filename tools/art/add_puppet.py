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
# take A's small staring eyes read as scary (owner, 3 Nov 2026): edits of take A with only the eyes changed. The blink edit of rm-hero-5
# lost his eye patches, so the prompt holds them in place.
EYES = ("Edit the attached drawing of a panda and keep everything exactly as it is: the same pose, size, position, colours, head, ears, tuft, "
        "cheeks, nose, mouth, straps, paws and flat magenta backdrop. Keep both big black eye patches exactly as they are, the same size, shape "
        "and place. Change only the eyes inside the patches: {} Change nothing else.")
for name, eyes in (("happy", "draw each eye as a soft, happy closed upward arc in cream, like a smile, as in the second attached image."),
                   ("soft", "make each eye a big, friendly, gently tall oval in very dark brown, filling about half of its patch, set a little low, with a "
                            "large round white highlight at the top and a small one below it, so he looks warm, cute and gentle, never staring.")):
    jobs.append({"file": f"out/raw/rm-rest-a-{name}.png", "group": "puppet", "size": "1024x1024", "refs": ["out/raw/rm-rest-a.png", "out/raw/rm-hero-4.png"],
                 "prompt": EYES.format(eyes)})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("puppet jobs added")
