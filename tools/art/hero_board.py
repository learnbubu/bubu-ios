"""Bùbù stamps the screen, panel by panel as the board the owner took (out/raw/rm-board-hero-legs.png, 3 Nov 2026): 1 leaps up with the
seal raised, 2 winds up, 3 slams it at us, 4 lands sitting and beaming, 5 winks with the seal up. Two fixes on hero-stamp: all five poses
ride one shared motion (each swap continues the move instead of jumping), and the print lands where the seal hit the glass, then
carries down to the title as its badge. Writes the Studio document "hero-board" (dark) and its art only, sharing hero-stamp's folder.

From tools/art: ../sfx/.venv/Scripts/python -I hero_board.py
"""
import json
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu"
ART = f"{ROOT}/art/hero-stamp"
W, H, MID, CY = 1024, 2220, 512, 560
GROUND = CY + 440
RED = (214, 52, 30)
HOLD, OUT, IN, SOFT, LINE = [1, 0, 1, 0], [0.16, 1, 0.3, 1], [0.7, 0, 0.84, 0], [0.42, 0, 0.58, 1], [0, 0, 1, 1]
BACK = [0.3, 1.5, 0.5, 1]
LEAP, WIND, SLAM, HIT, LAND, CARRY, WINK, END = 400, 780, 960, 1040, 1320, 1620, 2400, 4300
MELT = 40

# --- the board's marks: red bangs (1, 4), speed dashes (1), whoosh arcs (2), white burst (3)
bang = Image.new("RGBA", (240, 200))
d = ImageDraw.Draw(bang)
for a in (-38, 0, 38):
    r = math.radians(a - 90)
    d.line([(120 + math.cos(r) * 70, 190 + math.sin(r) * 70), (120 + math.cos(r) * 175, 190 + math.sin(r) * 175)], fill=RED + (255,), width=22)
bang.save(f"{ART}/bang.png")
speed = Image.new("RGBA", (220, 220))
d = ImageDraw.Draw(speed)
for k in range(4):
    d.line([(20 + k * 46, 40 + k * 18), (70 + k * 46, 190 - k * 8)], fill=(170, 176, 186, 255), width=10)
speed.save(f"{ART}/speed.png")
whoosh = Image.new("RGBA", (240, 240))
d = ImageDraw.Draw(whoosh)
for k in range(3):
    d.arc((30 + k * 28, 30 + k * 28, 210 - k * 28, 210 - k * 28), 200, 280, fill=(200, 206, 214, 255), width=12)
whoosh.save(f"{ART}/whoosh.png")
rays = Image.new("RGBA", (1600, 1600))
d = ImageDraw.Draw(rays)
for k in range(14):
    a = k / 14 * math.tau + (0.12 if k % 2 else 0)
    w = 0.05
    near, far = 520, 790 if k % 2 else 760
    d.polygon([(800 + math.cos(a - w) * near, 800 + math.sin(a - w) * near), (800 + math.cos(a) * far, 800 + math.sin(a) * far),
               (800 + math.cos(a + w) * near, 800 + math.sin(a + w) * near)], fill=(255, 255, 255, 255))
rays.save(f"{ART}/rays.png")

layers = []


def pic(name, art, x, y, s, keys, rot=0):
    pw, ph = Image.open(f"{ART}/{art}.png").size
    k = {p: [{"t": t, "v": v, "ease": e} for t, v, e in ks] for p, ks in keys.items()}
    layers.append({"id": name, "name": name, "art": f"{art}.png", "w": pw, "h": ph, "x": x, "y": y, "scale": s, "rotation": rot, "flipX": False,
                   "opacity": 1, "visible": True, "locked": False, "pivot": {"x": x, "y": y}, "keys": k, "loop": 0, "blink": 0})


def shown(start, end=None):
    return [(0, 0, HOLD), (start, 1, HOLD)] + ([(end, 0, HOLD)] if end else [])


def melt(start, end=None):
    """in over MELT ms, out over MELT ms: the swaps melt the way jump-five's did"""
    keys = [(0, 0, HOLD), (start, 0, LINE), (start + MELT, 1, HOLD)]
    return keys + ([(end, 1, LINE), (end + MELT, 0, HOLD)] if end else [])


def pop(name, art, x, y, s, t):
    pic(name, art, x, y, s, {"opacity": shown(t), "scale": [(t, 0.3 * s, BACK), (t + 240, s, HOLD)]})


# one body move all five poses ride: (time, rise, turn, size, ease to the next)
BODY = [(LEAP, 760, -14, 0.8, OUT), (LEAP + 230, -40, 5, 1.0, SOFT), (WIND, -60, 0, 1.0, IN), (WIND + 120, -80, -9, 0.96, IN),
        (SLAM, -70, -11, 0.92, IN), (HIT, 10, 0, 1.3, OUT), (HIT + 60, 0, 0, 1.24, SOFT), (LAND, 0, 0, 1.12, BACK),
        (LAND + 260, 0, 3, 1.0, SOFT), (1900, -10, -2, 1.0, SOFT), (WINK, 0, 0, 1.0, BACK), (WINK + 240, -8, 0, 1.0, SOFT),
        (3200, 4, 0, 1.0, SOFT), (END, -4, 0, 1.0, HOLD)]
SHAKE = [(HIT, 0, LINE), (HIT + 20, -16, LINE), (HIT + 40, 14, LINE), (HIT + 60, -8, LINE), (HIT + 80, 0, HOLD)]
# pose: height on screen, and where it sits (the airborne ones by their middle, the rest on the ground)
POSES = {1: (880, None), 2: (800, None), 3: (780, GROUND), 4: (860, GROUND), 5: (860, GROUND)}
SHOWN = {1: (LEAP, WIND), 2: (WIND, SLAM), 3: (SLAM, LAND), 4: (LAND, WINK), 5: (WINK, None)}


def body(n):
    pw, ph = Image.open(f"{ART}/pose{n}.png").size
    s = POSES[n][0] / ph
    y = CY if POSES[n][1] is None else POSES[n][1] - POSES[n][0] / 2
    return pw, ph, s, y


pic("bg", "bg-dark", MID, H / 2, 40, {})
for n in range(1, 6):
    pw, ph, s, y = body(n)
    # the size keys grow from the middle: the slam grows both ways (at us), the sitting ones keep their feet down
    lift = lambda m: 0 if n < 4 else -(m - 1) * POSES[n][0] / 2
    pic(f"pose{n}", f"pose{n}", MID, y, s, {
        "opacity": melt(*SHOWN[n]) if n > 1 else [(0, 0, HOLD), (LEAP, 1, HOLD), (WIND, 1, LINE), (WIND + MELT, 0, HOLD)],
        "y": [(t, y + rise + lift(m), e) for t, rise, _, m, e in BODY],
        "rotation": [(t, turn, e) for t, _, turn, _, e in BODY],
        "scale": [(t, s * m, e) for t, _, _, m, e in BODY],
        "x": [(t, MID + v, e) for t, v, e in SHAKE]})
# the marks, placed as on the board around each pose
pic("speedL", "speed", MID - 360, CY + 40, 0.9, {"opacity": shown(LEAP + 60, WIND), "y": [(LEAP + 60, CY + 140, OUT), (WIND, CY + 20, HOLD)]}, rot=180)
pic("speedR", "speed", MID + 330, CY - 120, 0.8, {"opacity": shown(LEAP + 60, WIND), "y": [(LEAP + 60, CY - 20, OUT), (WIND, CY - 140, HOLD)]})
pic("bang1", "bang", MID + 120, CY - 520, 0.8, {"opacity": shown(LEAP + 180, WIND), "scale": [(LEAP + 180, 0.3, BACK), (LEAP + 320, 0.8, HOLD)]})
pic("whooshL", "whoosh", MID - 300, CY - 360, 1.0, {"opacity": shown(WIND + 40, SLAM)})
pic("whooshR", "whoosh", MID + 330, CY - 120, 0.9, {"opacity": shown(WIND + 70, SLAM)}, rot=150)
pic("rays", "rays", MID, CY + 60, 0.8, {"opacity": shown(HIT, LAND), "scale": [(HIT, 0.7, OUT), (HIT + 200, 0.86, SOFT), (LAND, 0.9, HOLD)]})
layers.insert(1, layers.pop())  # the burst behind him
pic("bang4", "bang", MID + 260, CY - 470, 0.8, {"opacity": shown(LAND + 120, WINK), "scale": [(LAND + 120, 0.3, BACK), (LAND + 260, 0.8, HOLD)]}, rot=20)
# the print: left on the glass right where the seal's face hit, seen once he springs back off it, then carried down beside the title
# as its badge
_, ph3, s3, y3 = body(3)
m = 1.3
seal_x = MID + (433 - 866 / 2) * s3 * m
seal_y = y3 + 10 + (1000 - ph3 / 2) * s3 * m
big = 714 * s3 * m * 0.8 / 944
BADGE = (MID + 286 + 70, 1100)
pic("print", "print", seal_x, seal_y, big, {
    "opacity": shown(LAND),
    "x": [(CARRY, seal_x, IN), (CARRY + 260, BADGE[0], HOLD)],
    "y": [(CARRY, seal_y, IN), (CARRY + 260, BADGE[1], HOLD)],
    "scale": [(CARRY, big, IN), (CARRY + 260, 0.13, BACK), (CARRY + 400, 0.15, HOLD)],
    "rotation": [(CARRY, 0, IN), (CARRY + 260, -10, HOLD)]})
rng = np.random.default_rng(5)
for j in range(12):
    a = j / 12 * math.tau + rng.random() * 0.4
    far = 340 + rng.random() * 160
    x0, y0, x1, y1 = seal_x + math.cos(a) * 220, seal_y + math.sin(a) * 120, seal_x + math.cos(a) * far, seal_y + math.sin(a) * far * 0.7
    s = 0.1 + rng.random() * 0.14
    pic(f"fleck{j}", "drop", x0, y0, s, {"opacity": shown(HIT, HIT + 400), "x": [(HIT, x0, OUT), (HIT + 400, x1, HOLD)], "y": [(HIT, y0, OUT), (HIT + 400, y1, HOLD)], "scale": [(HIT, s, IN), (HIT + 400, 0, HOLD)]})
# 5: sparkles where the board has them, two above his head and one by his foot
for j, (x, y, s, t) in enumerate(((MID - 230, CY - 420, 0.5, WINK + 60), (MID - 70, CY - 480, 0.36, WINK + 140), (MID + 330, CY + 160, 0.42, WINK + 220))):
    pic(f"star{j}", "star", x, y, s, {"opacity": shown(t), "scale": [(t, 0, BACK), (t + 240, s, SOFT), (t + 900, s * 0.8, SOFT), (t + 1600, s, HOLD)]})
# the results, mocked up in the app's place for them
pop("title", "title", MID - 40, 1110, 1, CARRY + 200)
pic("line", "line-dark", MID, 1215, 1, {"opacity": shown(CARRY + 340)})
for k in range(3):
    pop(f"tile{k + 1}", f"tile{k + 1}-dark", 196 + 316 * k, 1480, 1, 1900 + 300 * k)
pic("button", "button", MID, 1990, 1, {"opacity": shown(3000), "y": [(3000, 2320, OUT), (3250, 1990, HOLD)]})

doc = {"id": "hero-board", "name": "Hero Board", "width": W, "height": H, "duration": END, "loop": False, "layers": layers[::-1], "bones": []}
json.dump(doc, open(f"{ROOT}/docs/hero-board.json", "w", encoding="utf-8"), ensure_ascii=False)
project = json.load(open(f"{ROOT}/project.json", encoding="utf-8"))
if "hero-board" not in project["docs"]:
    project["docs"].append("hero-board")
    json.dump(project, open(f"{ROOT}/project.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print(len(layers), "layers; print lands at", round(seal_x), round(seal_y), "scale", round(big, 3))
