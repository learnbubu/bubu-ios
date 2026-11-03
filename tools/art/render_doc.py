"""Renders a simple Studio document (pictures moved, scaled, turned and faded by keys: no bones, bends or masks) to an mp4, for when
Studio's own export is stuck.

From tools/art: ../sfx/.venv/Scripts/python -I render_doc.py <doc id> <out.mp4> [scale]
"""
import json
import subprocess
import sys
from PIL import Image

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
doc_id, out = sys.argv[1], sys.argv[2]
k = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
doc = json.load(open(f"{ROOT}/docs/{doc_id}.json", encoding="utf-8"))
W, H = round(doc["width"] * k), round(doc["height"] * k)


def bezier(ease, u):
    """a CSS-style cubic ease: the curve's y where its x is u"""
    if list(ease) == [1, 0, 1, 0]:
        return 0.0  # a hold: no change until the next key
    x1, y1, x2, y2 = ease
    lo, hi = 0.0, 1.0
    for _ in range(40):
        s = (lo + hi) / 2
        x = 3 * (1 - s) ** 2 * s * x1 + 3 * (1 - s) * s * s * x2 + s ** 3
        lo, hi = (s, hi) if x < u else (lo, s)
    s = (lo + hi) / 2
    return 3 * (1 - s) ** 2 * s * y1 + 3 * (1 - s) * s * s * y2 + s ** 3


def value(layer, prop, t):
    keys = layer["keys"].get(prop)
    if not keys:
        return layer[prop]
    if t <= keys[0]["t"]:
        return keys[0]["v"]
    for a, b in zip(keys, keys[1:]):
        if t <= b["t"]:
            u = (t - a["t"]) / (b["t"] - a["t"]) if b["t"] > a["t"] else 1
            return a["v"] + (b["v"] - a["v"]) * bezier(a["ease"], u)
    return keys[-1]["v"]


art = {}
ffmpeg = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", "60", "-i", "-",
                           "-pix_fmt", "yuv420p", "-c:v", "libx264", "-crf", "18", out], stdin=subprocess.PIPE)
for f in range(round(doc["duration"] * 60 / 1000)):
    t = f * 1000 / 60
    frame = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    for layer in reversed(doc["layers"]):
        o = value(layer, "opacity", t)
        if o <= 0.003 or not layer.get("visible", True):
            continue
        name = layer["art"]
        if name not in art:
            for folder in (doc_id, "hero-stamp", "seal-slam", "seal-quick"):
                try:
                    art[name] = Image.open(f"{ROOT}/art/{folder}/{name}").convert("RGBA")
                    break
                except FileNotFoundError:
                    pass
        s = value(layer, "scale", t) * k
        w, h = max(1, round(layer["w"] * s)), max(1, round(layer["h"] * s))
        im = art[name].resize((w, h), Image.BILINEAR)
        r = value(layer, "rotation", t)
        if r:
            im = im.rotate(-r, resample=Image.BICUBIC, expand=True)
        if o < 1:
            im.putalpha(im.getchannel("A").point(lambda v: round(v * o)))
        x, y = value(layer, "x", t) * k, value(layer, "y", t) * k
        frame.paste(im, (round(x - im.width / 2), round(y - im.height / 2)), im)
    ffmpeg.stdin.write(frame.convert("RGB").tobytes())
ffmpeg.stdin.close()
ffmpeg.wait()
print("wrote", out)
