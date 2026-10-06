"""Bùbù in parts (owner, 6 Oct 2026): so the app can animate him the way Duolingo's owl moves,
with a squashing body, waving arms, blinking and happy-closed eyes, instead of swapping whole
poses. Each part is the standing panda (panda-idle) with everything else left out, drawn at the
same size and place on the canvas as in the reference, so the parts stack back together.
Jobs for Codex, saved as rig-*.
"""
import json

from PIL import Image

import make_prompts as mp

IDLE = "../../native/Bubu/Assets.xcassets/panda-idle.imageset/panda-idle.png"
REF = "refs/ref-rig-idle.png"
REFS = [REF, "refs/panda-celebrate.png"]

SAME = ("The FIRST attached image is Bùbù standing, the panda this is a part of. Draw ONLY the part described, "
        "exactly as it looks on him there: the same size, the same position on the canvas and the same angle, as if "
        "everything else had been erased from that picture, so the parts can be stacked back into the same panda. "
        "Square canvas, the panda filling the same area as in the reference.")

RIG = [
    ("rig-body", "his body without the head and without the arms: the cream belly, the black legs and feet, and the "
     "red backpack straps and pack, with clean rounded ends at the shoulders and neck where the arms and head attach."),
    ("rig-head", "his head only, with ears, the black eye patches, the cream face, nose and pink cheeks, but with NO eyes "
     "and NO mouth: the eye patches plain black, the face plain cream where the mouth would be."),
    ("rig-eyes-open", "only his two eyes, open and bright, exactly as they sit inside the black eye patches (draw the "
     "patches too, so they line up), nothing else."),
    ("rig-eyes-happy", "only his two eye patches with the eyes closed in happy upturned arcs, as when laughing, nothing else."),
    ("rig-eyes-wow", "only his two eye patches with big round sparkling star-shine eyes, amazed, nothing else."),
    ("rig-eyes-blink", "only his two eye patches with the eyes shut in calm straight lines, mid-blink, nothing else."),
    ("rig-mouth-smile", "only his small smiling mouth, where it sits on his face, nothing else."),
    ("rig-mouth-open", "only his mouth wide open in a happy laugh, a little pink tongue showing, where it sits on his face, nothing else."),
    ("rig-tears", "only two small happy tears, light blue drops springing out sideways from where his eyes are, nothing else."),
    ("rig-arm-left-down", "only his arm on the left of the picture, hanging down at his side as in the reference, nothing else."),
    ("rig-arm-left-up", "only his arm on the left of the picture, raised high in a cheer with the paw open, attached at "
     "the same shoulder point, nothing else."),
    ("rig-arm-right-down", "only his arm on the right of the picture, hanging down at his side as in the reference, nothing else."),
    ("rig-arm-right-up", "only his arm on the right of the picture, raised high in a cheer with the paw open, attached at "
     "the same shoulder point, nothing else."),
]

if __name__ == "__main__":
    im = Image.open(IDLE).convert("RGBA")
    bg = Image.new("RGBA", im.size, (255, 0, 255, 255))
    bg.alpha_composite(im)
    bg.convert("RGB").save(REF)
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = 0
    for name, d in RIG:
        f = f"out/raw/{name}.png"
        if f in have:
            continue
        jobs.append({"file": f, "group": "rig", "size": "1024x1024", "refs": REFS,
                     "prompt": f"{SAME}\n\n{mp.STYLE}\n\nDraw {d}\n\n{mp.KEY}"})
        add += 1
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(add, "jobs added")
