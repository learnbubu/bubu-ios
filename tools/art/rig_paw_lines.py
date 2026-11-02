"""The toe lines on the rig sheets' paws stopped short of the edge (owner, 2 Nov 2026); on the feet they run to it. Carries
each paw line on in its own direction to the paw's edge, leaving every other pixel alone.

From tools/art: ../sfx/.venv/Scripts/python -I rig_paw_lines.py
"""
from collections import deque
from statistics import median
from PIL import Image, ImageDraw

BOXES = [(150, 680, 300, 775), (720, 680, 870, 775)]
SS = 4


def is_line(c):
    return 72 < c[0] < 175 and max(c) - min(c) < 28


def is_fur(c):
    return c[0] < 175 and max(c) - min(c) < 28


def lines_in(px, box):
    x0, y0, x1, y1 = box
    seen, found = set(), []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if (x, y) in seen or not is_line(px[x, y]):
                continue
            part, todo = [], deque([(x, y)])
            seen.add((x, y))
            while todo:
                p = todo.popleft()
                part.append(p)
                for n in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                    if n not in seen and x0 <= n[0] < x1 and y0 <= n[1] < y1 and is_line(px[n]):
                        seen.add(n)
                        todo.append(n)
            if len(part) > 60:
                found.append(part)
    return found


def row(part, y):
    xs = [p[0] for p in part if p[1] == y]
    return (min(xs) + max(xs)) / 2, max(xs) - min(xs) + 1


def extend(name):
    path = f"out/raw/rm-{name}.png"
    img = Image.open(path).convert("RGB")
    px = img.load()
    for box in BOXES:
        for part in lines_in(px, box):
            bottom = max(p[1] for p in part)
            ex, _ = row(part, bottom - 3)
            sx, width = row(part, bottom - 12)
            step = (ex - sx) / 9
            colour = tuple(int(median(px[p][i] for p in part)) for i in range(3))
            # as far as the paw goes in that direction
            n = 0
            while is_fur(px[round(ex + step * (n + 1)), bottom - 3 + n + 1]) and n < 60:
                n += 1
            mask = Image.new("L", (img.width * SS, img.height * SS), 0)
            ImageDraw.Draw(mask).line([(ex * SS, (bottom - 3) * SS), ((ex + step * (n + 2)) * SS, (bottom - 1 + n) * SS)],
                                      fill=255, width=round(width * SS))
            mask = mask.resize(img.size, Image.LANCZOS).load()
            for y in range(bottom - 6, bottom + n + 3):
                for x in range(box[0], box[2]):
                    a = mask[x, y] / 255
                    if a > 0 and is_fur(px[x, y]) and not is_line(px[x, y]):
                        px[x, y] = tuple(round(px[x, y][i] * (1 - a) + colour[i] * a) for i in range(3))
            print(name, "line at", round(ex), "carried on", n)
    img.save(path)


for sheet in ("master", "bare"):
    extend(sheet)
