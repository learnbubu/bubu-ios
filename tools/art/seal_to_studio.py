"""The lesson-complete seal from Codex's storyboard (out/raw/rm-board-seal.png): Bùbù heaves a huge stone seal up, rides it into
the camera, it slams the whole screen, lifts off a giant 步步 print, and he pops up cheering. Writes the Studio document
"seal-slam" and its art only. Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I seal_to_studio.py
"""
import json
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/seal-slam"
W, H, GROUND, MID = 1024, 2220, 1980, 512
RED = (214, 52, 30)
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
BACK = [0.3, 1.5, 0.5, 1]  # overshoots a little


def clean(name):
    rgb = np.asarray(Image.open(f"out/raw/rm-seal-{name}.png").convert("RGB").filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    im = Image.fromarray(np.dstack([colour, alpha * 255]).round().astype("uint8"), "RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    im.save(f"{ART}/{name}.png")
    return im.size


def rough_print():
    """the giant print: real characters (Codex's were only nearly right), then worn like a real stamp"""
    size = 1000
    ink = Image.new("L", (size, size))
    d = ImageDraw.Draw(ink)
    d.rectangle((30, 30, size - 30, size - 30), outline=255, width=52)
    font = ImageFont.truetype("C:/Windows/Fonts/msyhbd.ttc", 410)
    for i in range(2):
        box = d.textbbox((0, 0), "步", font=font)
        d.text((size * (0.29 + 0.42 * i) - (box[0] + box[2]) / 2, size / 2 - (box[1] + box[3]) / 2), "步", font=font, fill=255)
    rng = np.random.default_rng(7)
    grain = np.asarray(Image.fromarray((rng.random((size, size)) * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.6)), float)
    blotch = np.asarray(Image.fromarray((rng.random((size // 16, size // 16)) * 255).astype("uint8")).resize((size, size), Image.BICUBIC), float)
    wear = (grain - grain.mean()) * 5 + (blotch - 128) * 0.35
    alpha = np.asarray(ink.filter(ImageFilter.GaussianBlur(1.5)), float) * (wear > -55)
    out = np.zeros((size, size, 4), "uint8")
    out[..., :3] = RED
    out[..., 3] = alpha
    Image.fromarray(out, "RGBA").filter(ImageFilter.GaussianBlur(0.6)).save(f"{ART}/print.png")


def lines():
    """white impact lines thrown out from the middle, as in panel 4"""
    im = Image.new("RGBA", (1400, 1400))
    d = ImageDraw.Draw(im)
    for k in range(14):
        a = k / 14 * math.tau + 0.11 * (k % 3)
        r0, r1, w = 430 + 40 * (k % 3), 700, 0.05
        d.polygon([(700 + r1 * math.cos(a - w), 700 + r1 * math.sin(a - w)), (700 + r1 * math.cos(a + w), 700 + r1 * math.sin(a + w)), (700 + r0 * math.cos(a), 700 + r0 * math.sin(a))], fill=(255, 255, 255, 255))
    im.save(f"{ART}/lines.png")


os.makedirs(ART, exist_ok=True)
size = {n: clean(n) for n in ("heave", "strain", "ride", "cheer", "stone")}
Image.open("out/raw/rm-seal-paper.png").convert("RGB").save(f"{ART}/paper.png")
rough_print()
lines()
Image.new("RGB", (64, 64), RED).save(f"{ART}/red.png")
drop = Image.new("RGBA", (100, 100))
ImageDraw.Draw(drop).ellipse((4, 4, 96, 96), fill=RED + (255,))
drop.save(f"{ART}/drop.png")
sizes = {**size, "paper": (1024, 1536), "print": (1000, 1000), "lines": (1400, 1400), "red": (64, 64), "drop": (100, 100)}
layers = []


def pic(name, art, x, y, s, keys, flat=None):
    w, h = sizes[art]
    k = {p: [{"t": t, "v": v, "ease": e} for t, v, e in ks] for p, ks in keys.items()}
    layers.append({"id": name, "name": name, "art": f"{art}.png", "w": w, "h": h, "x": x, "y": y, "scale": s, "rotation": 0, "flipX": False,
                   "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": k, "loop": 0, "blink": 0})


def shown(start, end=None):
    keys = [(0, 0, HOLD), (start, 1, HOLD)] if start else [(0, 1, HOLD)]
    return keys + ([(end, 0, HOLD)] if end else [])


LEAP, SLAM, LIFT, POP = 820, 1120, 1190, 1480
BUBU = 470 / size["heave"][0]
bubu_y = GROUND - size["heave"][1] * BUBU / 2
top = GROUND - size["heave"][1] * BUBU
STONE = 600 / size["stone"][0]
stone_h = size["stone"][1] * STONE
stone_y = top - stone_h / 2 + 34
RISE = 1000
SHAKE = [(t, MID + v, e) for t, v, e in [(300, 0, LINE), (340, -5, LINE), (380, 5, LINE), (420, -6, LINE), (460, 6, LINE), (500, -7, LINE), (540, 7, LINE), (590, 0, HOLD)]]

# the paper, kicked by the slam
pic("paper", "paper", MID, H / 2, 1.46, {"y": [(0, H / 2, HOLD), (SLAM, H / 2 + 34, SOFT), (SLAM + 70, H / 2 - 16, SOFT), (SLAM + 150, H / 2 + 6, SOFT), (SLAM + 230, H / 2, HOLD)]})
pic("print", "print", MID, 850, 0.9, {
    "opacity": shown(SLAM),
    "scale": [(SLAM, 1.0, OUT), (SLAM + 200, 0.9, HOLD)],
    "y": [(SLAM, 870, SOFT), (SLAM + 70, 838, SOFT), (SLAM + 150, 856, SOFT), (SLAM + 230, 850, HOLD)],
})
# the strain: he heaves it up from below the screen, then sinks under it and swings it back
pic("heave", "heave", MID, bubu_y, BUBU, {"opacity": shown(0, 600), "y": [(0, bubu_y + 1100, OUT), (280, bubu_y, HOLD)], "x": SHAKE})
sq = size["strain"][1] * BUBU * 1.04
pic("strain", "strain", MID, GROUND - sq / 2, BUBU * 1.04, {"opacity": shown(600, LEAP)})
# the stone: it holds on his paws, swings back and down with him, leaps at the camera, slams, lifts away
s0, s1, s2, s3 = STONE, STONE * 1.25, STONE * 3.8, STONE * 3.6
strain_top = GROUND - sq + 34
stone_keys = [(0, stone_y + 1100, OUT), (280, stone_y, HOLD), (600, stone_y, OUT), (700, strain_top - stone_h / 2, SOFT), (LEAP, strain_top - stone_h / 2 - 20, OUT), (RISE, 1000, IN), (SLAM, 1250, HOLD), (LIFT, 1250, IN), (LIFT + 240, -1900, HOLD)]
scale_keys = [(0, s0, HOLD), (LEAP, s0, OUT), (RISE, s1, IN), (SLAM, s2, HOLD), (LIFT, s3, IN), (LIFT + 240, s3, HOLD)]
pic("stone", "stone", MID, stone_y, STONE, {"y": stone_keys, "scale": scale_keys, "x": SHAKE, "rotation": [(600, 0, OUT), (720, -9, SOFT), (LEAP, -7, OUT), (RISE, 0, HOLD)]})
# he rides on top for the leap
RIDE = 230 / size["ride"][0]
ride_h = size["ride"][1] * RIDE
ride_at = lambda y, s: y - size["stone"][1] * s / 2 - ride_h / 2 + 30
ride_keys = [(LEAP, ride_at(strain_top - stone_h / 2 - 20, s0), OUT), (RISE, ride_at(1000, s1), IN), (SLAM - 70, ride_at(1000, s1) - 500, HOLD)]
pic("ride", "ride", MID, ride_keys[0][1], RIDE, {"opacity": shown(LEAP, SLAM - 70), "y": ride_keys})
# the slam: a blink of pure red, white lines, flecks of paste
pic("flash", "red", MID, H / 2, 40, {"opacity": shown(SLAM, SLAM + 50)})
pic("lines", "lines", MID, 1000, 1.1, {"opacity": shown(SLAM + 34, SLAM + 170), "scale": [(SLAM + 34, 1.0, OUT), (SLAM + 170, 1.5, HOLD)]})
rng = np.random.default_rng(3)
for j in range(16):
    a = j / 16 * math.tau + rng.random() * 0.3
    far = 500 + rng.random() * 480
    x0, y0, x1, y1 = MID + math.cos(a) * 320, 1000 + math.sin(a) * 320, MID + math.cos(a) * far, 1000 + math.sin(a) * far * 1.4
    s = 0.12 + rng.random() * 0.26
    pic(f"fleck{j}", "drop", x0, y0, s, {"opacity": shown(SLAM + 34, SLAM + 520), "x": [(SLAM + 34, x0, OUT), (SLAM + 520, x1, HOLD)], "y": [(SLAM + 34, y0, OUT), (SLAM + 520, y1, HOLD)], "scale": [(SLAM + 34, s, IN), (SLAM + 520, 0, HOLD)]})
# he pops up in front of the print
CHEER = 700 / size["cheer"][0]
cheer_y = 1760
pic("cheer", "cheer", MID, cheer_y, CHEER, {"opacity": shown(POP), "y": [(POP, cheer_y + 1000, BACK), (POP + 280, cheer_y, SOFT), (2200, cheer_y - 12, SOFT), (2600, cheer_y, HOLD)]})

doc = {"id": "seal-slam", "name": "Seal Slam", "width": W, "height": H, "duration": 2600, "loop": False, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/seal-slam.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "seal-slam" not in project["docs"]:
    project["docs"].append("seal-slam")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
