"""Bùbù stamps the screen when a lesson ends: five drawn poses (out/raw/rm-hero-<n>.png, from the board the owner took on 3 Nov 2026)
in the square above the title, on the app's background, with the title, tiles and button mocked up below to judge it in place.
Writes the Studio documents "hero-stamp" (dark) and "hero-stamp-light" and their art only. Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I hero_to_studio.py
"""
import json
import math
import os
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/hero-stamp"
W, H, MID, CY = 1024, 2220, 512, 560
RED = (214, 52, 30)
BOLD = "C:/Windows/Fonts/msyhbd.ttc"
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
BACK = [0.3, 1.5, 0.5, 1]
# the app's own grounds (Theme.swift Color.bg) and what reads on them
THEMES = {"hero-stamp": {"bg": (10, 20, 32), "text": (250, 247, 241), "panel": (22, 34, 48)},
          "hero-stamp-light": {"bg": (250, 247, 241), "text": (40, 44, 46), "panel": (255, 255, 255)}}
BURST, COIL, LUNGE, HIT, BOUNCE, WINK, END = 400, 640, 780, 860, 920, 2100, 3800
POSE = 900  # his height on screen at rest


def clean(n):
    rgb = np.asarray(Image.open(f"out/raw/rm-hero-{n}.png").convert("RGB").filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    im = Image.fromarray(np.dstack([colour, alpha * 255]).round().astype("uint8"), "RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    im.save(f"{ART}/pose{n}.png")
    return im.size


def text(name, s, size, colour):
    font = ImageFont.truetype(BOLD, size)
    box = font.getbbox(s)
    im = Image.new("RGBA", (box[2] - box[0] + 20, box[3] - box[1] + 20))
    ImageDraw.Draw(im).text((10 - box[0], 10 - box[1]), s, font=font, fill=colour + (255,))
    im.save(f"{ART}/{name}.png")


def tile(name, label, value, colour, panel):
    im = Image.new("RGBA", (280, 220))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 3, 277, 217), 34, fill=colour + (255,))
    d.rounded_rectangle((13, 72, 267, 207), 24, fill=panel + (255,))
    d.text((140, 38), label, font=ImageFont.truetype(BOLD, 34), fill=(255, 255, 255, 255), anchor="mm")
    d.text((140, 138), value, font=ImageFont.truetype(BOLD, 62), fill=colour + (255,), anchor="mm")
    im.save(f"{ART}/{name}.png")


os.makedirs(ART, exist_ok=True)
size = {n: clean(n) for n in range(1, 6)}
for name in ("print", "lines", "drop"):
    shutil.copy(f"{ROOT}/art/seal-slam/{name}.png", f"{ART}/{name}.png")
star = Image.new("RGBA", (120, 120))
ImageDraw.Draw(star).polygon([(60, 0), (72, 48), (120, 60), (72, 72), (60, 120), (48, 72), (0, 60), (48, 48)], fill=(246, 196, 60, 255))
star.save(f"{ART}/star.png")
button = Image.new("RGBA", (880, 150))
ImageDraw.Draw(button).rounded_rectangle((3, 3, 877, 147), 44, fill=RED + (255,))
ImageDraw.Draw(button).text((440, 74), "CONTINUE", font=ImageFont.truetype(BOLD, 56), fill=(255, 255, 255, 255), anchor="mm")
button.save(f"{ART}/button.png")
text("title", "No mistakes!", 84, RED)

for doc_id, theme in THEMES.items():
    tag = "light" if "light" in doc_id else "dark"
    Image.new("RGB", (64, 64), theme["bg"]).save(f"{ART}/bg-{tag}.png")
    text(f"line-{tag}", "Not one slip. Stamped and sealed.", 46, theme["text"])
    for k, (label, value, colour) in enumerate((("XP", "15", RED), ("ACCURACY", "100%", (196, 140, 40)), ("TIME", "2:07", (60, 130, 200)))):
        tile(f"tile{k + 1}-{tag}", label, value, colour, theme["panel"])
    layers = []

    def pic(name, art, x, y, s, keys, rot=0):
        w, h = Image.open(f"{ART}/{art}.png").size
        k = {p: [{"t": t, "v": v, "ease": e} for t, v, e in ks] for p, ks in keys.items()}
        layers.append({"id": name, "name": name, "art": f"{art}.png", "w": w, "h": h, "x": x, "y": y, "scale": s, "rotation": rot, "flipX": False,
                       "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": k, "loop": 0, "blink": 0})

    def shown(start, end=None):
        return [(0, 0, HOLD), (start, 1, HOLD)] + ([(end, 0, HOLD)] if end else [])

    def pop(name, art, x, y, s, t):
        pic(name, art, x, y, s, {"opacity": shown(t), "scale": [(t, 0.3 * s, BACK), (t + 240, s, HOLD)]})

    fit = lambda n: POSE / size[n][1]
    pic("bg", f"bg-{tag}", MID, H / 2, 40, {})
    # 1: bursts up into the square
    s1 = fit(1)
    pic("pose1", "pose1", MID, CY, s1, {"opacity": shown(BURST, COIL), "y": [(BURST, CY + 700, BACK), (BURST + 200, CY, SOFT), (COIL, CY - 14, HOLD)],
                                        "scale": [(BURST, s1 * 0.7, BACK), (BURST + 200, s1, HOLD)], "rotation": [(BURST, -14, OUT), (COIL, -4, HOLD)]})
    # 2: coils back
    s2 = fit(2) * 0.95
    pic("pose2", "pose2", MID + 20, CY + 10, s2, {"opacity": shown(COIL, LUNGE), "rotation": [(COIL, 4, OUT), (LUNGE, 12, HOLD)], "y": [(COIL, CY, OUT), (LUNGE, CY + 24, HOLD)]})
    # 3: lunges at us and hits the glass
    s3 = fit(3)
    pic("pose3", "pose3", MID, CY, s3, {"opacity": shown(LUNGE, BOUNCE), "scale": [(LUNGE, s3 * 0.85, IN), (HIT, s3 * 1.4, OUT), (HIT + 30, s3 * 1.32, HOLD)],
                                        "x": [(HIT, MID, LINE), (HIT + 20, MID - 14, LINE), (HIT + 40, MID + 12, LINE), (HIT + 60, MID, HOLD)]})
    pic("lines", "lines", MID, CY + 60, 0.75, {"opacity": shown(HIT, HIT + 150), "scale": [(HIT, 0.6, OUT), (HIT + 150, 0.95, HOLD)]})
    rng = np.random.default_rng(5)
    for j in range(12):
        a = j / 12 * math.tau + rng.random() * 0.4
        far = 330 + rng.random() * 160
        x0, y0 = MID + math.cos(a) * 200, CY + 60 + math.sin(a) * 200
        x1, y1 = MID + math.cos(a) * far, CY + 60 + math.sin(a) * far
        s = 0.1 + rng.random() * 0.16
        pic(f"fleck{j}", "drop", x0, y0, s, {"opacity": shown(HIT, HIT + 420), "x": [(HIT, x0, OUT), (HIT + 420, x1, HOLD)], "y": [(HIT, y0, OUT), (HIT + 420, y1, HOLD)], "scale": [(HIT, s, IN), (HIT + 420, 0, HOLD)]})
    # the print he left, beside his head
    pic("print", "print", 820, 230, 0.22, {"opacity": shown(BOUNCE), "scale": [(BOUNCE, 0.3, BACK), (BOUNCE + 200, 0.22, HOLD)]}, rot=-8)
    # 4: bounces back beaming, and floats
    s4 = fit(4)
    pic("pose4", "pose4", MID - 30, CY + 20, s4, {"opacity": shown(BOUNCE, WINK), "scale": [(BOUNCE, s4 * 1.15, BACK), (BOUNCE + 260, s4, HOLD)],
                                                  "y": [(BOUNCE, CY + 20, SOFT), (1400, CY + 2, SOFT), (1800, CY + 20, SOFT), (WINK, CY + 8, HOLD)], "rotation": [(BOUNCE, 8, BACK), (BOUNCE + 300, -3, SOFT), (WINK, 0, HOLD)]})
    # 5: the wink, with sparkles
    s5 = fit(5)
    pic("pose5", "pose5", MID - 30, CY + 10, s5, {"opacity": shown(WINK), "scale": [(WINK, s5 * 0.94, BACK), (WINK + 220, s5, HOLD)],
                                                  "y": [(WINK, CY + 10, SOFT), (2800, CY - 6, SOFT), (3300, CY + 10, SOFT), (END, CY, HOLD)]})
    for j, (x, y, s, t) in enumerate(((240, 230, 0.5, WINK + 60), (330, 140, 0.32, WINK + 140), (840, 760, 0.42, WINK + 220))):
        pop(f"star{j}", "star", x, y, s, t)
    # the results, mocked up in the app's place for them
    pop("title", "title", MID, 1110, 1, BOUNCE + 120)
    pic("line", f"line-{tag}", MID, 1215, 1, {"opacity": shown(BOUNCE + 260)})
    for k in range(3):
        pop(f"tile{k + 1}", f"tile{k + 1}-{tag}", 196 + 316 * k, 1480, 1, 1500 + 300 * k)
    pic("button", "button", MID, 1990, 1, {"opacity": shown(2600), "y": [(2600, 2320, OUT), (2850, 1990, HOLD)]})
    doc = {"id": doc_id, "name": doc_id.replace("-", " ").title(), "width": W, "height": H, "duration": END, "loop": False, "layers": layers[::-1], "bones": []}
    json.dump(doc, open(f"{ROOT}/docs/{doc_id}.json", "w", encoding="utf-8"), ensure_ascii=False)
    project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
    if doc_id not in project["docs"]:
        project["docs"].append(doc_id)
        json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(doc_id, len(layers), "layers")
