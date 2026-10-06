"""Bùbù in parts, second go at the body and arms (owner, 6 Oct 2026: "the backpack is a bit
odd"). The first arms came with pieces of backpack strap painted on, which doubled up with the
straps on the body, and the raised arms ended in a strap cuff where the shoulder should be.
These ask for the backpack on the body only, and arms that are plain black fur with a rounded
shoulder end that tucks behind the body. Jobs for Codex, saved as rig2-* (the first set stays).
"""
import json

import make_prompts as mp

REFS = ["refs/ref-rig-idle.png", "refs/panda-celebrate.png"]
SAME = ("The FIRST attached image is Bùbù standing, the panda this is a part of. Draw ONLY the part described, "
        "at the same size and in the same style as he is drawn there. Square canvas, the part centred.")
ARM = ("Plain black fur only: NO backpack, NO straps, NO red or orange anywhere on it. The shoulder end is a smooth, "
       "rounded end (like the end of a sausage), so it can tuck behind his body; the paw end has the light grey claw marks "
       "or paw pad as in the references.")

RIG2 = [
    ("rig2-body", "his body without the head and without the arms: the cream belly, the black chest and legs and feet, "
     "and the red backpack exactly as in the reference: two red straps over the chest and the pack showing at his right side "
     "(the left of the picture's right edge). The shoulders end in clean rounded black curves where the arms attach, with "
     "nothing sticking out past them."),
    ("rig2-arm-left-down", "his arm on the left of the picture, hanging down at his side as in the reference, slightly curved. " + ARM),
    ("rig2-arm-right-down", "his arm on the right of the picture, hanging down at his side as in the reference, slightly curved. " + ARM),
    ("rig2-arm-left-up", "his arm on the left of the picture, raised high in a cheer, angled up and out, the paw open showing "
     "its grey pad. " + ARM),
    ("rig2-arm-right-up", "his arm on the right of the picture, raised high in a cheer, angled up and out, the paw open "
     "showing its grey pad. " + ARM),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = 0
    for name, d in RIG2:
        f = f"out/raw/{name}.png"
        if f in have:
            continue
        jobs.append({"file": f, "group": "rig2", "size": "1024x1024", "refs": REFS,
                     "prompt": f"{SAME}\n\n{mp.STYLE}\n\nDraw {d}\n\n{mp.KEY}"})
        add += 1
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(add, "jobs added")
