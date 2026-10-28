"""Hangs each hook piece from its master mount, so every bracket is the same bracket.

For each job with a "mount" (batch path4, add_path4.py): the object Codex drew (out/final/obj-*.png, keyed and trimmed
by process.py) hangs on a cord that runs up to its top edge. Here:
  - the cord's top is found (the middle of what's visible in the top rows), and where the object itself starts (the
    first row clearly wider than the cord);
  - the object is scaled so its body is BODY_W wide (or BODY_H tall, whichever is smaller), the same for every piece,
    since the masters all come from the same canvas at the same scale;
  - the cord is cut to CORD long, and its top tucked up behind the master's ring, at the tie point in
    masters/masters.json (masters.py);
  - the master is laid over it, and the piece is saved as out/final/<job's out>.png, with a mirrored -right copy for
    the other side of the path, like every hanging piece.

Run by process.py after keying; on its own: python hang.py
"""
import json
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
MASTERS = os.path.join(HERE, "masters")

BODY_W, BODY_H = 220, 310   # the object (not its cord), in the masters' pixels (owner: "smaller and on a longer rope")
CORD = 150                  # visible cord, from the bottom of the ring to the object's top
TUCK = 14                   # how far the cord runs up behind the ring
MOUNT = 0.65                # the masters, scaled to the size of the brackets in the pieces already in the app


def cord_and_body(im):
    """(cord's x at the top, the row where the object starts, the cord's width)."""
    a = np.asarray(im)[..., 3] > 100
    rows = a.sum(axis=1)
    top = [x for y in range(min(8, a.shape[0])) for x in np.nonzero(a[y])[0]]
    cx = float(np.mean(top)) if top else a.shape[1] / 2
    cw = max(2, int(np.median([r for r in rows[:20] if r]) if rows[:20].any() else 4))
    body = next((y for y in range(a.shape[0]) if rows[y] > 4 * cw), 0)
    return cx, body, cw


def hang(obj, master, tie):
    master = master.resize((round(master.width * MOUNT), round(master.height * MOUNT)), Image.LANCZOS)
    tie = (tie[0] * MOUNT, round(tie[1] * MOUNT))
    cx, body, _ = cord_and_body(obj)
    # the cord, cut to length: drop the rows above (body - CORD - TUCK in the scaled object)
    bw, bh = obj.width, obj.height - body
    s = min(BODY_W / max(1, bw), BODY_H / max(1, bh))
    o = obj.resize((max(1, round(obj.width * s)), max(1, round(obj.height * s))), Image.LANCZOS)
    cx, body = cx * s, round(body * s)
    keep = CORD + TUCK
    if body > keep:
        o = o.crop((0, body - keep, o.width, o.height))
    else:                                    # a short cord: extend it with its own top row
        pad = keep - body
        top = o.crop((0, 0, o.width, 1)).resize((o.width, pad))
        ext = Image.new("RGBA", (o.width, o.height + pad))
        ext.paste(top, (0, 0)); ext.paste(o, (0, pad))
        o = ext
    ox, oy = round(tie[0] - cx), tie[1] - TUCK
    left = min(0, ox)
    W = max(master.width, ox + o.width) - left
    H = max(master.height, oy + o.height)
    out = Image.new("RGBA", (W, H))
    out.alpha_composite(o, (ox - left, oy))
    out.alpha_composite(master, (-left, 0))
    return out


def main():
    jobs = json.load(open(os.path.join(HERE, "jobs.json"), encoding="utf-8"))
    meta = json.load(open(os.path.join(MASTERS, "masters.json")))
    n = 0
    for j in jobs:
        if not j.get("mount"):
            continue
        f = os.path.join(FINAL, os.path.basename(j["file"]))
        m = meta.get(j["mount"])
        if not os.path.exists(f) or not m or not m["tie"]:
            continue
        out = hang(Image.open(f).convert("RGBA"), Image.open(os.path.join(MASTERS, m["file"])).convert("RGBA"), m["tie"])
        out.save(os.path.join(FINAL, j["out"] + ".png"))
        out.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(FINAL, j["out"] + "-right.png"))
        n += 1
    print(n, "hook pieces hung from their masters")


if __name__ == "__main__":
    main()
