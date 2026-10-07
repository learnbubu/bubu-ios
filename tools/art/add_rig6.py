"""The results moments' art, redone for how each one animates (owner, 7 Oct 2026: "regen the stuff
we need but take into account how it needs to be animated"). Planned motion first:

  flawless  - swap: stamp held high (anticipation) -> slammed down on the paper (impact squash); the
              print appears. Pieces: body without arms; arms+stamp HIGH; arms+stamp DOWN; paper blank;
              paper printed.
  kungfu    - swap: ready stance (feet down, fists up) -> the kick (the sticker's pose) with a whoosh.
              Pieces: Bùbù ready; whoosh arc.
  sweep     - rotate a little: the broom swings +/-12 deg about his paws. Pieces: body without arms;
              arms+broom with both paws close together near the top of the handle.
  nightowl  - rotate a little: the lantern swings like a pendulum from his raised paw. Pieces: body
              (with the raised arm, paw closed round nothing); lantern alone with its loop handle.
  earlybird - swap: cup held in his lap -> raised to his mouth, eyes closed (a sip). Pieces: body
              without arms; arms+cup in lap; arms+cup at mouth.
  brain     - rotate a little: each arm see-saws from its shoulder, the books sway from his head.
              Pieces: body without arms or books; left arm; right arm; book stack.

Every piece is drawn on its own over the finished sticker as reference, at the size and place it has
there, so the pieces stack. Jobs for Codex in the "rig6" group, saved as m6-<k>-<piece>.png.
"""
import json

import make_prompts as mp

REF = "The attached image is a finished sticker from the app: Bùbù the panda, {scene}. "
SAME = ("Draw ONLY the piece described below - nothing else on the canvas - at EXACTLY the size, position and angle it has in "
        "the sticker, so it can be stacked back onto the other pieces. Square canvas, the same framing as the sticker.\n\n")
JOINT = ("Each arm (or leg) ends where it joins his body in a soft ROUNDED end of plain black fur, with no outline, so it can sit "
         "over his shoulder (or hip) and turn there without a gap. ")
EARS = "Bùbù has exactly two round black ears. "

PIECES = {
    "flawless": ("stamping a red 满分 seal onto paper", {
        "body": "Bùbù's body and head only, standing as in the sticker, with NO arms and NO stamp: draw his chest and sides whole, with "
                "smooth rounded black shoulders. " + EARS,
        "arms-high": "ONLY his two arms and the red seal stamp, the arms raised so the stamp is held up high in front of his face "
                     "(just above his head), ready to slam down; the shoulders where they are in the sticker. " + JOINT,
        "arms-down": "ONLY his two arms and the red seal stamp, exactly as in the sticker: pressing the stamp down onto the paper. " + JOINT,
        "paper": "ONLY the sheet of paper on the ground, with the red 满分 seal print on it (copy the characters exactly).",
        "paper-blank": "ONLY the sheet of paper on the ground, blank, with no print.",
    }),
    "kungfu": ("doing a high kung-fu kick", {
        "ready": "Bùbù in a READY stance instead of kicking: both feet on the ground, knees slightly bent, both fists up in front of "
                 "him, a determined grin - the same size and position as in the sticker, the same face. " + EARS,
        "whoosh": "ONLY one curved white swoosh arc tracing the path of the kicking foot, from low at his hip sweeping up to where the "
                  "foot is in the sticker.",
    }),
    "sweep": ("sweeping with a little bamboo broom", {
        "body": "Bùbù's body and head only, as in the sticker, with NO arms and NO broom: his chest and sides whole, smooth rounded "
                "black shoulders. " + EARS,
        "arms-broom": "ONLY his two arms and the broom: both paws holding the broom handle close together near its top, in front of "
                      "his chest, the broom angled down to the floor as in the sticker. " + JOINT,
    }),
    "nightowl": ("in pyjamas holding up a glowing paper lantern", {
        "body": "Bùbù in his pyjamas and nightcap with his arm raised as in the sticker, its paw closed in a fist as if holding a "
                "handle, but with NO lantern (draw whatever the lantern covered). " + EARS,
        "lantern": "ONLY the glowing paper lantern with its little loop handle at the top and its tassel, hanging straight down "
                   "from where his paw is in the sticker.",
    }),
    "earlybird": ("sitting with a cup of tea", {
        "body": "Bùbù's body and head only, sitting as in the sticker, with NO arms and NO cup: his chest and belly whole, smooth "
                "rounded black shoulders, his face as in the sticker. " + EARS,
        "arms-lap": "ONLY his two arms and the tea cup, exactly as in the sticker: the cup held in both paws in front of his belly. " + JOINT,
        "arms-sip": "ONLY his two arms and the tea cup, the cup lifted up to where his mouth is in the sticker, tilted a little as if "
                    "sipping. " + JOINT,
    }),
    "brain": ("balancing a stack of books on his head", {
        "body": "Bùbù's body and head only, as in the sticker, with NO arms and NO books: the top of his head whole with both ears, "
                "smooth rounded black shoulders. " + EARS,
        "arm-left": "ONLY his arm on the picture's left, held out for balance as in the sticker. " + JOINT,
        "arm-right": "ONLY his arm on the picture's right, held out for balance as in the sticker. " + JOINT,
        "books": "ONLY the stack of books, exactly as in the sticker, its bottom book flat (it rests on his head).",
    }),
}

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "rig6"]
    for k, (scene, pieces) in PIECES.items():
        for name, d in pieces.items():
            jobs.append({"file": f"out/raw/m6-{k}-{name}.png", "group": "rig6", "size": "1024x1024",
                         "refs": [f"out/raw/mo-{k}.png", "refs/ref-rig-idle.png"],
                         "prompt": REF.format(scene=scene) + SAME + "The piece: " + d + "\n\n" + mp.STYLE + "\n\n" + mp.KEY})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(1 for j in jobs if j.get("group") == "rig6"), "rig6 jobs")
