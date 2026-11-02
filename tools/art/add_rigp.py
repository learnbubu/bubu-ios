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
    "launch": "Taking off. He is stretched upward to about one and a half times his normal height, still chunky and soft, not thin: a long round belly, two separate thick legs pushing off with the feet just leaving the bottom of the frame, arms flung up over his head, chin lifted, one big open mouth with joy.",
    "apex": "The top of the jump, floating and joyful. His whole body is a round star shape in mid-air: arms thrown up and out in a V with the paws spread, both knees tucked up with his feet pulled up under his belly and turned outward, head tilted a little, big happy closed eyes and a huge open mouth.",
    "land": "Landing, the moment his feet hit the ground. He is squashed very flat and wide, knees splayed, feet planted at the bottom of the frame, belly bulging out, arms still flung up and dragging behind the fall, his two ears still perfectly round and black like on the sheet, eyes shut and big smile.",
}
jobs = [j for j in jobs if j["group"] != "rigp"]
for name, text in POSES.items():
    jobs.append({"file": f"out/raw/rm-pose-{name}.png", "group": "rigp", "size": "1024x1024", "refs": ["out/raw/rm-master.png"],
                 "prompt": BASE + text + BACKDROP + "\n\nStyle:" + style})
for name, text in {
    "stand": "Standing happily and relaxed, feet at the bottom of the frame, arms loose at his sides, a warm closed-mouth smile with happy closed eyes.",
    "dip": "Starting to sink before a jump: knees just bending, body a little lower and wider than standing, arms starting to swing out and back, eyes closing, one closed smile. His feet are at the bottom of the frame.",
    "fall": "Falling back down from a jump, stretched a little taller than normal: both legs reaching straight down with the toes pointing toward the ground, arms high above and trailing up behind the fall, ears still perfectly round, excited wide eyes, one big open mouth.",
    "settle": "Bouncing back up just after a landing: a little taller and thinner than normal, feet on the ground at the bottom of the frame, arms swinging down and out from his sides, happy closed eyes, one big open smile.",
}.items():
    jobs.append({"file": f"out/raw/rm-pose-{name}.png", "group": "rigp", "size": "1024x1024",
                 "refs": ["out/raw/rm-master.png", "out/raw/rm-pose-crouch.png"],
                 "prompt": BASE + text + " He has exactly one mouth. Draw him in the same way as the second attached image." + BACKDROP + "\n\nStyle:" + style})
jobs.append({"file": "out/raw/rm-pose-launch.png", "group": "rigp", "size": "1024x1024", "refs": ["out/raw/rm-pose-launch-2.png"],
             "prompt": "Edit the attached drawing of a panda and keep everything exactly as it is, the same pose, size, position, colours and "
                       "flat magenta backdrop, except this. He has two mouths: a small smile under his nose and a big open mouth below it. "
                       "Remove the small smile, so that one big open happy mouth starts right under his nose, joined to it by the short line."})
jobs = [j for i, j in enumerate(jobs) if not (j["file"] == "out/raw/rm-pose-launch.png" and "two mouths" not in j["prompt"])]
# Hard cuts between eight poses read as a glitch (owner, 2 Nov 2026): a drawing halfway across each big change
for name, a, b in (("push", "crouch", "launch"), ("rise", "launch", "apex"), ("drop", "apex", "fall"), ("preland", "fall", "land"),
                   ("rebound", "land", "settle"), ("ease", "settle", "stand")):
    jobs.append({"file": f"out/raw/rm-pose-{name}.png", "group": "rigp", "size": "1024x1024",
                 "refs": [f"out/raw/rm-pose-{a}.png", f"out/raw/rm-pose-{b}.png"],
                 "prompt": "The two attached images are consecutive key poses of one animation of this panda. Draw the in-between frame, exactly "
                           "halfway between them, as an animator would: every part (body height and width, arms, legs, feet, head tilt, ears) is "
                           "halfway from its place in the first image to its place in the second. The same character, facing us, his head the same "
                           "size as in the first image, one mouth only, two toe lines on each paw and foot, flat clean shapes." + BACKDROP + "\n\nStyle:" + style})
next(j for j in jobs if j["file"] == "out/raw/rm-pose-stand.png")["prompt"] = (
    BASE + "Standing straight on, perfectly symmetrical: his body upright with no lean or twist, feet apart at the bottom of the frame, arms "
    "hanging loosely at his sides, a warm closed-mouth smile with happy closed eyes. His head is the same size as in the second attached "
    "image. He has exactly one mouth. Draw him in the same way as the second attached image." + BACKDROP + "\n\nStyle:" + style)
# the first apex was the one to keep, but with two mouths and paw pads: fixed by editing it, not redrawing
next(j for j in jobs if j["file"] == "out/raw/rm-pose-apex.png").update({
    "refs": ["out/raw/rm-pose-apex-1.png"],
    "prompt": "Edit the attached drawing of a panda and keep everything exactly as it is, the same pose, size, position, colours and "
              "flat magenta backdrop, except these two things. 1. He has two mouths: a small smile under his nose and a big open mouth "
              "below it. Remove the small smile, so that one big open happy mouth starts right under his nose, joined to it by the "
              "short line. 2. His paws show pink-grey pads. Remove the pads, so each paw is plain black with two small grey toe lines."})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(POSES), "jobs in rigp")
