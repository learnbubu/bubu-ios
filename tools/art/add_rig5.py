"""Bùbù, the professional set (owner, 7 Oct 2026: "tell me what you need to make things more
professional! skies the limit"). Every piece is an EDIT of art we already have, the way
rig4-torso-arms was, so it lines up with the rig without guessing:

  heads   - his head as it is, only the face changed (expressions; eyes looking about)
  torsos  - his torso with arms down (rig4), only the arms re-posed
  arms    - single raised arms holding a gesture
  fx      - little marks drawn around him (sweat drop, question mark, sparkles, hearts)

Jobs for Codex in the "rig5" group, saved as rig5-*. References are made here.
"""
import json
import os

from PIL import Image

import make_prompts as mp
from rig_layout import compose

HERE = os.path.dirname(os.path.abspath(__file__))


def ref(names, path, crop=None):
    im = compose(names, pad=0)
    if crop: im = im.crop(crop)
    im.thumbnail((760, 760))
    c = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    c.alpha_composite(im, ((1024 - im.width) // 2, (1024 - im.height) // 2))
    c.convert("RGB").save(path)


HEAD_KEEP = ("The FIRST attached image is Bùbù's head. EDIT it: keep the head EXACTLY as it is - the same size and place on the "
             "canvas, the same outline, ears, tuft of hair, the black eye patches (their shape and position unchanged), the nose, the "
             "pink cheeks and the colours - and change ONLY the face as described: ")
TORSO_KEEP = ("The FIRST attached image is Bùbù's body with his arms down. EDIT it: keep the torso, belly, legs, feet and the two red "
              "straps EXACTLY as they are - same size, same place - and change ONLY the arms as described, each arm still growing "
              "smoothly out of its shoulder with no seam, the straps staying on top of the shoulders: ")
END = ("\n\nKeep the background flat solid magenta (#FF00FF) exactly as in the first image, nothing else added. No text, no letters.")

HEADS = {
    "sad": "a sad face: the eyes as soft downturned arcs (looking down), small worried eyebrows slanting up in the middle above the "
           "eye patches, and a small frown mouth under the nose.",
    "wince": "an oops face: the eyes squeezed shut as tight > < shapes inside the patches, a small wavy embarrassed mouth, a tiny "
             "worried eyebrow over each patch.",
    "wow": "an amazed face: big round shining eyes with a white highlight in each patch, eyebrows raised, and a small round 'o' mouth.",
    "grin": "a delighted face: happy closed-arc eyes, and a big open grin showing a little pink tongue, wider than his usual laugh.",
    "think": "a thinking face: the eyes looking up and to the right (round pupils near the top corner of each patch), and the mouth "
             "a small sideways line pushed to one side.",
    "look-down": "his usual smile, but the eyes open and looking DOWN and slightly to the right (round dark-brown pupils with a white "
                 "highlight, near the bottom of each patch), as if reading something below him.",
    "wink": "a cheeky face: the left eye a happy closed arc, the right eye open with a round pupil and highlight, and a sideways smile.",
    "proud": "a proud face: calm closed-arc eyes, a small confident smile, the chin a touch up (the face only, the head stays still).",
    "sleepy": "a sleepy face: the eyes as flat half-closed lines, and a small open yawn mouth.",
}
TORSOS = {
    "hips": "both hands on his hips, elbows bent out to the sides (a proud pose).",
    "cheer-fists": "both arms bent with small fists pumped up in front of his chest (a 'yes!' pose).",
    "scratch": "his right arm (on the picture's left) raised and bent so the paw is up by where his head would be, as if scratching "
               "his head; the other arm hanging down as now.",
    "hug": "both arms wrapped around his own belly, paws meeting at the front (a happy self-hug).",
}
ARMS = {
    "thumbs-up": "ONLY his arm on the left of the picture, raised up and out, its paw making a clear thumbs-up. Plain black fur, a "
                 "rounded shoulder end, no strap. Square canvas, the arm centred.",
    "point": "ONLY his arm on the left of the picture, held out to the side and slightly up, its paw pointing with one finger. Plain "
             "black fur, a rounded shoulder end, no strap. Square canvas, the arm centred.",
}
FX = {
    "sweat": "one small light-blue sweat drop with a white highlight",
    "question": "one chunky question mark in the app's teal green (#2B776D), soft rounded ends",
    "sparkles": "three small four-point sparkle stars in warm gold, of different sizes, in a loose cluster",
    "hearts": "two small rounded hearts in soft coral red, one larger than the other",
    "zzz": "three small 'z' shapes in soft grey-blue, getting bigger up and to the right",
    "lines": "three short curved motion lines in charcoal, like a cartoon 'whoosh'",
}

if __name__ == "__main__":
    ref(["rig-head", "rig-glint-open-L", "rig-glint-open-R", "rig-mouth-smile"], os.path.join(HERE, "refs", "ref-rig5-head.png"), (0, 0, 420, 330))
    ref(["rig4-torso-arms"], os.path.join(HERE, "refs", "ref-rig5-torso.png"))
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "rig5"]
    head_refs = ["refs/ref-rig5-head.png", "refs/ref-rig-idle.png"]
    for k, d in HEADS.items():
        jobs.append({"file": f"out/raw/rig5-head-{k}.png", "group": "rig5", "size": "1024x1024", "refs": head_refs,
                     "prompt": HEAD_KEEP + d + "\n\n" + mp.STYLE + END})
    for k, d in TORSOS.items():
        jobs.append({"file": f"out/raw/rig5-torso-{k}.png", "group": "rig5", "size": "1024x1024",
                     "refs": ["refs/ref-rig5-torso.png", "refs/ref-rig-idle.png"],
                     "prompt": TORSO_KEEP + d + "\n\n" + mp.STYLE + END})
    for k, d in ARMS.items():
        jobs.append({"file": f"out/raw/rig5-arm-{k}.png", "group": "rig5", "size": "1024x1024",
                     "refs": ["refs/ref-rig-idle.png", "refs/panda-celebrate.png"],
                     "prompt": "The attached images are Bùbù. Draw " + d + "\n\n" + mp.STYLE + "\n\n" + mp.KEY})
    for k, d in FX.items():
        jobs.append({"file": f"out/raw/rig5-fx-{k}.png", "group": "rig5", "size": "1024x1024", "refs": ["refs/ref-rig-idle.png"],
                     "prompt": ("The attached image is existing art from the same app: match its style. Draw ONLY " + d +
                                ", small and centred, nothing else (no character).\n\n" + mp.STYLE + "\n\n" + mp.KEY)})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(1 for j in jobs if j.get("group") == "rig5"), "rig5 jobs")
