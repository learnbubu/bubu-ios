"""Where each rig part sits on Bùbù, in the standing pose's pixels (panda-idle, 420 x 643):
left, top and width (the height follows the part's own shape). Codex trimmed each part to its
edges, so the places are fitted by eye against panda-idle (rig_check.png)."""
import json
import os
import sys

from PIL import Image

L = {
    "rig-body": (50, 248, 360),
    "rig-arm-left-down": (2, 282, 118),
    "rig-arm-right-down": (322, 292, 88),
    "rig-arm-left-up": (-30, 176, 128),
    "rig-arm-right-up": (312, 150, 148),
    "rig-head": (32, 4, 352),
    "rig-eyes-open": (86, 128, 256),
    "rig-eyes-happy": (86, 128, 256),
    "rig-eyes-wow": (80, 122, 270),
    "rig-eyes-blink": (90, 132, 248),
    "rig-mouth-smile": (174, 188, 68),
    "rig-mouth-open": (179, 212, 58),
    "rig-tears": (62, 186, 300),
}
SIZE = (420, 643)
HERE = os.path.dirname(os.path.abspath(__file__))


def part(n):
    im = Image.open(os.path.join(HERE, "out", "rig", n + ".png")).convert("RGBA")
    x, y, w = L[n]
    return im.resize((w, round(w * im.height / im.width)), Image.LANCZOS), (x, y)


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
