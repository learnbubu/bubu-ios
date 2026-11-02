"""Key poses for Bùbù drawn whole by Codex (owner, 2 Nov 2026: "get codex to do the key poses"), to see if drawn poses beat
the bent rig. The jump for joy first. Jobs in the group "rigp", saved as out/raw/rm-pose-<name>.png.

From tools/art: ../sfx/.venv/Scripts/python -I add_rigp.py
"""
import json

jobs = json.load(open("jobs.json", encoding="utf-8"))
style = next(j for j in jobs if j["group"] == "rig6")["prompt"].split("Style:", 1)[1]

BASE = ("The attached image is Bùbù's model sheet. Redraw this same panda in the key pose below, as a professional character "
        "animator would draw it: a strong, clear, appealing silhouette with a real line of action, the pose pushed further than "
        "feels natural, and squash and stretch in his whole body. Keep his design: the same face, colours, red backpack straps, "
        "two toe lines on each paw and foot, and flat clean shapes. His volume stays about the same however he's squashed or "
        "stretched. He stays facing us, and his whole body is in frame with room around him.\n\nThe pose: ")
BACKDROP = "\n\nThe backdrop is one flat solid magenta (#FF00FF) with nothing else on it: no shadow, no ground, no text, no motion lines."
POSES = {
    "crouch": "Anticipation, about to jump. He is squashed down low and wide, knees bent and pointing out, body sunk between them, head pulled down into his shoulders, arms swung down and back behind his hips, eyes screwed shut with a tight smile. His feet are at the bottom of the frame.",
    "launch": "Taking off. He is stretched tall and thin, shooting upward, on the very tips of his toes with his legs straight together, body long, arms flung straight up over his head, chin lifted, eyes wide and mouth wide open with joy.",
    "apex": "The top of the jump, floating and joyful. His whole body is a round star shape in mid-air: arms thrown up and out in a V with the paws spread, both knees tucked up with his feet pulled up under his belly and turned outward, head tilted a little, big happy closed eyes and a huge open mouth.",
    "land": "Landing, the moment his feet hit the ground. He is squashed very flat and wide, knees splayed, feet planted at the bottom of the frame, belly bulging out, arms still flung up and dragging behind the fall, ears flopped down, eyes shut and big smile.",
}
jobs = [j for j in jobs if j["group"] != "rigp"]
for name, text in POSES.items():
    jobs.append({"file": f"out/raw/rm-pose-{name}.png", "group": "rigp", "size": "1024x1024", "refs": ["out/raw/rm-master.png"],
                 "prompt": BASE + text + BACKDROP + "\n\nStyle:" + style})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(POSES), "jobs in rigp")
