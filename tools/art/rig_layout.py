"""Where each rig part sits on Bùbù, in the standing pose's pixels (panda-idle, 420 x 643):
left, top and width (the height follows the part's own shape). Codex trimmed each part to its
edges, so the places are fitted by eye against panda-idle (rig_check.png)."""
import json
import os
import sys

from PIL import Image

L = {
    "rig-body": (50, 248, 360),
    "rig-arm-left-down": (6, 292, 88),      # the right one mirrored (it had no strap painted on)
    "rig-arm-right-down": (322, 292, 88),
    "rig-arm-left-up": (34, 165, 128),
    "rig-arm-right-up": (254, 165, 128),     # the left one mirrored (rig_straps)
    "rig-straps": (0, 0, 420),
    # the second body (straps only) and the backpack on its own, behind his right side
    "rig2-body": (50, 274, 316),
    "rig2-pack": (290, 285, 150),
    "rig2-pack-side": (285, 262, 135),
    # the third body and arms (rig3): drawn to fit each other, rounded shoulders, no strap on the arms
    "rig3-body": (50, 258, 316),
    "rig4-torso-arms": (-4, 252, 424),      # the torso with its arms down drawn on (lined up by the belly, feet on the ground)
    "rig4-torso-armL": (0, 0, 420),         # the same with the arm on the picture's right taken off, for the wave
    "rig3-arm-down": (-15, 311, 94),
    "rig3-arm-down-R": (337, 311, 94),
    "rig3-arm-up": (-12, 168, 150),
    "rig3-arm-up-R": (278, 168, 150),
    "rig2-body-cut": (0, 0, 420),          # rig_cut.py: the strap cut to his outline where the arms are down
    "rig2-body-trim": (0, 0, 420), "rig2-body-trim-L": (0, 0, 420), "rig2-body-trim-R": (0, 0, 420),
    "rig-straps-L": (0, 0, 420), "rig-straps-R": (0, 0, 420),
    "rig-straps-L-top": (0, 0, 420), "rig-straps-R-top": (0, 0, 420),         # rig_trim.py: the shoulder stubs off                # the chest straps, drawn over the arms
    "rig-head": (32, 4, 352),
    "rig-eyes-open": (86, 128, 256),
    "rig-eyes-happy": (86, 128, 256),
    "rig-eyes-wow": (80, 122, 270),
    "rig-eyes-blink": (90, 132, 248),
    # just the light eye marks (rig_glint): swapped over the head's own eye patches, which never change
    "rig-glint-open": (86, 128, 256),
    "rig-glint-happy": (86, 128, 256),
    "rig-glint-wow": (80, 122, 270),
    "rig-mouth-smile": (174, 188, 68),
    "rig-mouth-open": (179, 212, 58),
    "rig-tears": (62, 186, 300),
}
# the eye marks, one per eye, placed by rig_eyes.py
_eyes = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "rig", "eyes.json")
if os.path.exists(_eyes):
    L.update({k: tuple(v) for k, v in json.load(open(_eyes)).items()})
# the professional set, placed by rig5_fit.py
_r5 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out", "rig", "rig5.json")
if os.path.exists(_r5):
    L.update({k: tuple(v) for k, v in json.load(open(_r5)).items()})
SIZE = (420, 643)
HERE = os.path.dirname(os.path.abspath(__file__))


def part(n):
    im = Image.open(os.path.join(HERE, "out", "rig", n + ".png")).convert("RGBA")
    x, y, w = L[n]
    return im.resize((round(w), round(w * im.height / im.width)), Image.LANCZOS), (round(x), round(y))


def compose(names, pad=60):
    c = Image.new("RGBA", (SIZE[0] + 2 * pad, SIZE[1] + 2 * pad), (0, 0, 0, 0))
    for n in names:
        im, (x, y) = part(n)
        c.alpha_composite(im, (x + pad, y + pad))
    return c


if __name__ == "__main__":
    pad = 60
    idle = Image.open(os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets", "panda-idle.imageset", "panda-idle.png")).convert("RGBA")
    ref = Image.new("RGBA", (SIZE[0] + 2 * pad, SIZE[1] + 2 * pad), (0, 0, 0, 0)); ref.alpha_composite(idle, (pad, pad))
    a = compose(["rig-body", "rig-arm-left-down", "rig-arm-right-down", "rig-head", "rig-eyes-open", "rig-mouth-smile"])
    b = compose(["rig-arm-left-up", "rig-arm-right-up", "rig-body", "rig-head", "rig-eyes-happy", "rig-mouth-open", "rig-tears"])
    c = compose(["rig-body", "rig-arm-left-down", "rig-arm-right-down", "rig-head", "rig-eyes-wow", "rig-mouth-open"])
    ov = ref.copy(); half = a.copy(); half.putalpha(a.getchannel("A").point(lambda v: v // 2)); ov.alpha_composite(half)
    W = ref.width
    out = Image.new("RGBA", (W * 5, ref.height), (236, 232, 224, 255))
    for i, im in enumerate([ref, a, ov, b, c]):
        out.alpha_composite(im, (i * W, 0))
    out.save(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "rig_check.png"))
