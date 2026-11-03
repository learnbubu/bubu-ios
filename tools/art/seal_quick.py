"""The lesson-complete seal on Duolingo's timing (owner's recording, 3 Nov 2026): an empty beat, a very fast entrance, a hold, a cut to
a small header, then the results one at a time. The tiles and button are a mockup for judging the flow, not the app's. Uses the
art from "seal-slam"; writes the Studio document "seal-quick" and its art only. Run with Studio saved, then reload it.

From tools/art: ../sfx/.venv/Scripts/python -I seal_quick.py
"""
import json
import math
import os
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/seal-quick"
W, H, MID = 1024, 2220, 512
RED = (214, 52, 30)
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
BACK = [0.3, 1.5, 0.5, 1]
SLAM, LIFT, POP, CUT, END = 600, 670, 800, 1900, 4200
BOLD = "C:/Windows/Fonts/msyhbd.ttc"

os.makedirs(ART, exist_ok=True)
for name in ("paper", "print", "lines", "red", "drop", "stone", "cheer"):
    shutil.copy(f"{ROOT}/art/seal-slam/{name}.png", f"{ART}/{name}.png")


def words(name, text, size, colour):
    font = ImageFont.truetype(BOLD, size)
    box = font.getbbox(text)
    im = Image.new("RGBA", (box[2] - box[0] + 20, box[3] - box[1] + 20))
    ImageDraw.Draw(im).text((10 - box[0], 10 - box[1]), text, font=font, fill=colour)
    im.save(f"{ART}/{name}.png")


def tile(name, label, value, colour):
    im = Image.new("RGBA", (280, 220))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3, 3, 277, 217), 34, fill=colour)
    d.rounded_rectangle((13, 72, 267, 207), 24, fill=(255, 250, 238, 255))
    small, big = ImageFont.truetype(BOLD, 34), ImageFont.truetype(BOLD, 62)
    d.text((140, 38), label, font=small, fill=(255, 255, 255, 255), anchor="mm")
    d.text((140, 138), value, font=big, fill=colour, anchor="mm")
    im.save(f"{ART}/{name}.png")


words("perfect", "Perfect lesson!", 104, RED + (255,))
words("flawless", "No mistakes!", 76, RED + (255,))
tile("tile1", "XP", "15", (214, 52, 30, 255))
tile("tile2", "ACCURACY", "100%", (196, 140, 40, 255))
tile("tile3", "TIME", "2:07", (52, 56, 57, 255))
button = Image.new("RGBA", (880, 150))
d = ImageDraw.Draw(button)
d.rounded_rectangle((3, 3, 877, 147), 44, fill=RED + (255,))
d.text((440, 74), "CONTINUE", font=ImageFont.truetype(BOLD, 56), fill=(255, 255, 255, 255), anchor="mm")
button.save(f"{ART}/button.png")

layers = []


def pic(name, art, x, y, s, keys):
    w, h = Image.open(f"{ART}/{art}.png").size
    k = {p: [{"t": t, "v": v, "ease": e} for t, v, e in ks] for p, ks in keys.items()}
    layers.append({"id": name, "name": name, "art": f"{art}.png", "w": w, "h": h, "x": x, "y": y, "scale": s, "rotation": 0, "flipX": False,
                   "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": k, "loop": 0, "blink": 0})


def shown(start, end=None):
    return [(0, 0, HOLD), (start, 1, HOLD)] + ([(end, 0, HOLD)] if end else [])


def pop(name, art, x, y, s, t):
    pic(name, art, x, y, s, {"opacity": shown(t), "scale": [(t, 0.3 * s, BACK), (t + 240, s, HOLD)]})


KICK = lambda y, a=1: [(SLAM, y + 34 * a, SOFT), (SLAM + 70, y - 16 * a, SOFT), (SLAM + 150, y + 6 * a, SOFT), (SLAM + 230, y, HOLD)]
pic("paper", "paper", MID, H / 2, 1.46, {"y": [(0, H / 2, HOLD)] + KICK(H / 2)})
PRINT_Y = 660
pic("print", "print", MID, PRINT_Y, 0.86, {
    "opacity": shown(SLAM),
    "scale": [(SLAM, 0.98, OUT), (SLAM + 200, 0.86, HOLD), (CUT, 0.86, OUT), (CUT + 180, 0.3, HOLD)],
    "y": KICK(PRINT_Y) + [(CUT, PRINT_Y, OUT), (CUT + 180, 270, HOLD)],
})
stone_w = Image.open(f"{ART}/stone.png").width
S = 600 / stone_w
# it starts already huge and above the screen: the whole entrance is a fifth of a second
pic("stone", "stone", MID, -1800, S * 5, {
    "opacity": shown(400, LIFT + 200),
    "y": [(400, -1800, IN), (SLAM, 1000, HOLD), (LIFT, 1000, IN), (LIFT + 200, -2000, HOLD)],
    "scale": [(400, S * 5, IN), (SLAM, S * 3.8, HOLD)],
})
pic("flash", "red", MID, H / 2, 40, {"opacity": shown(SLAM, SLAM + 50)})
pic("lines", "lines", MID, 900, 1.1, {"opacity": shown(SLAM + 34, SLAM + 170), "scale": [(SLAM + 34, 1.0, OUT), (SLAM + 170, 1.5, HOLD)]})
rng = np.random.default_rng(3)
for j in range(16):
    a = j / 16 * math.tau + rng.random() * 0.3
    far = 500 + rng.random() * 480
    x0, y0, x1, y1 = MID + math.cos(a) * 320, 900 + math.sin(a) * 320, MID + math.cos(a) * far, 900 + math.sin(a) * far * 1.4
    s = 0.12 + rng.random() * 0.26
    pic(f"fleck{j}", "drop", x0, y0, s, {"opacity": shown(SLAM + 34, SLAM + 520), "x": [(SLAM + 34, x0, OUT), (SLAM + 520, x1, HOLD)], "y": [(SLAM + 34, y0, OUT), (SLAM + 520, y1, HOLD)], "scale": [(SLAM + 34, s, IN), (SLAM + 520, 0, HOLD)]})
pic("perfect", "perfect", MID, 1180, 1, {"opacity": shown(POP, CUT), "scale": [(POP, 0.5, BACK), (POP + 220, 1, HOLD)]})
cheer_w = Image.open(f"{ART}/cheer.png").width
C = 640 / cheer_w
pic("cheer", "cheer", MID, 1740, C, {
    "opacity": shown(POP),
    "y": [(POP, 2740, BACK), (POP + 260, 1740, SOFT), (CUT, 1725, OUT), (CUT + 180, 700, HOLD)],
    "scale": [(0, C, HOLD), (CUT, C, OUT), (CUT + 180, C * 0.62, HOLD)],
})
pic("flawless", "flawless", MID, 1120, 1, {"opacity": shown(CUT + 120), "scale": [(CUT + 120, 0.5, BACK), (CUT + 340, 1, HOLD)]})
pop("tile1", "tile1", 196, 1400, 1, CUT + 450)
pop("tile2", "tile2", 512, 1400, 1, CUT + 750)
pop("tile3", "tile3", 828, 1400, 1, CUT + 1050)
pic("button", "button", MID, 1960, 1, {"opacity": shown(CUT + 1400), "y": [(CUT + 1400, 2320, OUT), (CUT + 1650, 1960, HOLD)]})

doc = {"id": "seal-quick", "name": "Seal Quick", "width": W, "height": H, "duration": END, "loop": False, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/seal-quick.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "seal-quick" not in project["docs"]:
    project["docs"].append("seal-quick")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers")
