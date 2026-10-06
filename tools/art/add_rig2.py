"""Bùbù in parts, the body again (owner, 6 Oct 2026: not a fan of how the backpack looks).
The body comes with the two red straps only, and the backpack is its own piece behind him, so
it can be placed and sized on its own and bounce a little when he jumps. (The arms are fine now:
rig_straps.py keys the straps over them.) Jobs for Codex, saved as rig2-*.
"""
import json

import make_prompts as mp

REFS = ["refs/ref-rig-idle.png", "refs/panda-celebrate.png"]
SAME = ("The FIRST attached image is Bùbù standing, the panda this is a part of. Draw ONLY the part described, "
        "at the same size and in the same style as he is drawn there. Square canvas, the part centred.")

RIG2 = [
    ("rig2-body", "his body without the head, without the arms and WITHOUT the backpack: the cream belly, the black chest, "
     "shoulders, legs and feet, and just the two flat red backpack straps running from the top of each shoulder down over the "
     "chest to under the arms, exactly as in the reference. The shoulders end in clean rounded black curves where the arms "
     "attach, with nothing sticking out past them, and no pack showing at either side."),
    ("rig2-pack", "only his red backpack, on its own, as it would sit behind him: a soft rounded red pack, a little taller "
     "than wide, with one small front pocket with a rounded flap and a darker red underside, simple and neat in the flat "
     "storybook style of the reference, about the size of his upper body. No straps hanging off it, no panda, nothing else."),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    # the earlier rig2 set (body and four arms) is replaced by this one
    jobs = [j for j in jobs if j.get("group") != "rig2"]
    for name, d in RIG2:
        jobs.append({"file": f"out/raw/{name}.png", "group": "rig2", "size": "1024x1024", "refs": REFS,
                     "prompt": f"{SAME}\n\n{mp.STYLE}\n\nDraw {d}\n\n{mp.KEY}"})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(RIG2), "rig2 jobs")
