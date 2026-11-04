"""Claude's cut of a part against the owner's, as a lesson check: the two outlines over the drawing (Claude red, owner blue) and how
much of the shape differs, all of it and the part that shows against the backdrop.

From tools/art: ../sfx/.venv/Scripts/python -I lesson_compare.py <claude svg> <owner svg> <out png> [x0 y0 x1 y1]
(a bare name is looked for in lessons/owner/, then in Studio's art/cut-lesson/)
"""
import os
import re
import sys
import numpy as np
from PIL import Image, ImageDraw

STUDIO = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu/art/cut-lesson/"
S = 1254


def find(f):
    for p in (f, "lessons/owner/" + f, STUDIO + f):
        if os.path.exists(p):
            return p
    raise FileNotFoundError(f)


def outline(f):
    """the first shape's outline, sampled, and its points"""
    d = re.findall(r' d="([^"]+)"', open(find(f)).read())[0]
    n = [float(x) for x in re.findall(r"-?[\d.]+", d)]
    cur, pts, anc, i = (n[0], n[1]), [(n[0], n[1])], [(n[0], n[1])], 2
    while i + 5 < len(n):
        c1, c2, e = (n[i], n[i + 1]), (n[i + 2], n[i + 3]), (n[i + 4], n[i + 5])
        i += 6
        for k in range(1, 25):
            t = k / 24
            u = 1 - t
            pts.append(tuple(u ** 3 * cur[j] + 3 * u * u * t * c1[j] + 3 * u * t * t * c2[j] + t ** 3 * e[j] for j in (0, 1)))
        cur = e
        anc.append(e)
    return pts, anc[:-1]


def mask(pts):
    m = Image.new("L", (S, S))
    ImageDraw.Draw(m).polygon(pts, fill=1)
    return np.array(m).astype(bool)


MODEL = np.asarray(Image.open("out/raw/rm-rest-a-happy.png").convert("RGB").resize((S, S))).astype(int)
BACKDROP = np.abs(MODEL - [255, 0, 255]).sum(-1) < 80


def compare(mine, his, out=None, box=None):
    """{shape %: how much of the owner's shape differs, seen px: how much of that shows against the backdrop, points: (mine, his)}"""
    (p, pa), (q, qa) = outline(mine), outline(his)
    a, b = mask(p), mask(q)
    diff = a ^ b
    res = {"shape %": round(float(100 * diff.sum() / b.sum()), 1), "seen px": int((diff & BACKDROP).sum()), "points": (len(pa), len(qa))}
    if out:
        m = Image.fromarray(MODEL.astype(np.uint8)).convert("RGBA")
        ov = Image.new("RGBA", m.size)
        d = ImageDraw.Draw(ov)
        for pts, anc, col in ((p, pa, (255, 40, 40, 255)), (q, qa, (0, 200, 255, 255))):
            d.line(pts + [pts[0]], fill=col, width=2)
            for x in anc:
                d.ellipse((x[0] - 4, x[1] - 4, x[0] + 4, x[1] + 4), fill=col)
        img = Image.alpha_composite(m, ov)
        if box:
            img = img.crop(box).resize(((box[2] - box[0]) * 2, (box[3] - box[1]) * 2))
        img.save(out)
    return res


if __name__ == "__main__":
    mine, his, out = sys.argv[1:4]
    box = [int(v) for v in sys.argv[4:8]] if len(sys.argv) > 7 else None
    r = compare(mine, his, out, box)
    print(f"{mine} vs {his}: {r['points'][0]} points vs {r['points'][1]}; differ by {r['shape %']}% of the shape, "
          f"{r['seen px']} px where it shows against the backdrop")
