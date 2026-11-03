"""Bùbù stamps the screen with one drawing moved whole, the way Duolingo's bird is: the five separate poses swapped hands and shapes
(owner, 3 Nov 2026). The wink pose (rm-hero-5) whips in, leans back, stamps toward us leaving the print, settles and blinks (rm-hero-5-blink,
an edit of the same drawing). Title, tiles and button are the same mockup as hero-stamp. Writes the Studio document "hero-one" and its art
only (sharing hero-stamp's art folder). Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I hero_one.py
"""
import json
import math
import numpy as np
from PIL import Image, ImageFilter

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/hero-stamp"
W, H, MID, CY = 1024, 2220, 512, 560
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
BACK = [0.3, 1.5, 0.5, 1]
ARRIVE, LEAN, STAMP, HIT, END = 400, 720, 800, 860, 3800
BLINKS = []  # the blink edit lost his eye patches: no blink for now
PRINT = (790, 250)


def clean(src, name):
    rgb = np.asarray(Image.open(f"out/raw/{src}.png").convert("RGB").filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    im = Image.fromarray(np.dstack([colour, alpha * 255]).round().astype("uint8"), "RGBA")
    # the blink is cut to the same box as the wink, so the two sit exactly on each other
    box = Image.fromarray((np.asarray(Image.open("out/raw/rm-hero-5.png").convert("RGB"), float)[..., 1] > 60).astype("uint8") * 255).getbbox()
    im.crop(box).save(f"{ART}/{name}.png")
    return im.crop(box).size


w, h = clean("rm-hero-5", "one")
clean("rm-hero-5-blink", "one-blink")
S = 900 / h
layers = []


def pic(name, art, x, y, s, keys, rot=0):
    pw, ph = Image.open(f"{ART}/{art}.png").size
    k = {p: [{"t": t, "v": v, "ease": e} for t, v, e in ks] for p, ks in keys.items()}
    layers.append({"id": name, "name": name, "art": f"{art}.png", "w": pw, "h": ph, "x": x, "y": y, "scale": s, "rotation": rot, "flipX": False,
                   "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": k, "loop": 0, "blink": 0})


def shown(start, end=None):
    return [(0, 0, HOLD), (start, 1, HOLD)] + ([(end, 0, HOLD)] if end else [])


def pop(name, art, x, y, s, t):
    pic(name, art, x, y, s, {"opacity": shown(t), "scale": [(t, 0.3 * s, BACK), (t + 240, s, HOLD)]})


pic("bg", "bg-dark", MID, H / 2, 40, {})
# the print first, so he's in front of it
pic("print", "print", *PRINT, 0.24, {"opacity": shown(HIT), "scale": [(HIT, 0.4, OUT), (HIT + 140, 0.24, HOLD)]}, rot=-8)
pic("lines", "lines", *PRINT, 0.42, {"opacity": shown(HIT, HIT + 150), "scale": [(HIT, 0.3, OUT), (HIT + 150, 0.55, HOLD)]})
rng = np.random.default_rng(5)
for j in range(10):
    a = j / 10 * math.tau + rng.random() * 0.4
    far = 150 + rng.random() * 120
    x0, y0, x1, y1 = PRINT[0] + math.cos(a) * 90, PRINT[1] + math.sin(a) * 90, PRINT[0] + math.cos(a) * far, PRINT[1] + math.sin(a) * far
    s = 0.07 + rng.random() * 0.1
    pic(f"fleck{j}", "drop", x0, y0, s, {"opacity": shown(HIT, HIT + 380), "x": [(HIT, x0, OUT), (HIT + 380, x1, HOLD)], "y": [(HIT, y0, OUT), (HIT + 380, y1, HOLD)], "scale": [(HIT, s, IN), (HIT + 380, 0, HOLD)]})
# him: one drawing, moved whole. Whips in, leans back, stamps at the corner, recoils, floats
motion = {
    "y": [(ARRIVE, CY + 650, BACK), (ARRIVE + 240, CY, SOFT), (LEAN, CY + 16, IN), (STAMP, CY + 16, IN), (HIT, CY - 30, OUT), (HIT + 260, CY, SOFT), (1900, CY - 14, SOFT), (2700, CY + 6, SOFT), (END, CY, HOLD)],
    "x": [(0, MID, HOLD), (LEAN, MID, IN), (STAMP, MID - 20, IN), (HIT, MID + 40, OUT), (HIT + 260, MID, HOLD)],
    "scale": [(ARRIVE, S * 0.55, BACK), (ARRIVE + 240, S, SOFT), (LEAN, S * 0.96, IN), (STAMP, S * 0.95, IN), (HIT, S * 1.1, BACK), (HIT + 300, S, HOLD)],
    "rotation": [(ARRIVE, -22, BACK), (ARRIVE + 260, 0, SOFT), (LEAN, -9, IN), (STAMP, -10, IN), (HIT, 9, BACK), (HIT + 320, 0, SOFT), (2300, -2, SOFT), (END, 0, HOLD)],
}
wink = [(0, 0, HOLD), (ARRIVE, 1, HOLD)]
blink = [(0, 0, HOLD)]
for a, b in BLINKS:
    wink += [(a, 0, HOLD), (b, 1, HOLD)]
    blink += [(a, 1, HOLD), (b, 0, HOLD)]
pic("one", "one", MID, CY + 650, S * 0.55, {**motion, "opacity": wink})
pic("one-blink", "one-blink", MID, CY + 650, S * 0.55, {**motion, "opacity": blink})
for j, (x, y, s, t) in enumerate(((210, 260, 0.5, HIT + 200), (300, 160, 0.32, HIT + 280), (850, 780, 0.42, HIT + 360))):
    pic(f"star{j}", "star", x, y, s, {"opacity": shown(t), "scale": [(t, 0, BACK), (t + 240, s, SOFT), (t + 900, s * 0.8, SOFT), (t + 1600, s, HOLD)]})
pop("title", "title", MID, 1110, 1, HIT + 120)
pic("line", "line-dark", MID, 1215, 1, {"opacity": shown(HIT + 260)})
for k in range(3):
    pop(f"tile{k + 1}", f"tile{k + 1}-dark", 196 + 316 * k, 1480, 1, 1500 + 300 * k)
pic("button", "button", MID, 1990, 1, {"opacity": shown(2600), "y": [(2600, 2320, OUT), (2850, 1990, HOLD)]})

doc = {"id": "hero-one", "name": "Hero One", "width": W, "height": H, "duration": END, "loop": False, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/hero-one.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "hero-one" not in project["docs"]:
    project["docs"].append("hero-one")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
