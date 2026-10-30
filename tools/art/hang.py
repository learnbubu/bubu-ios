"""Hangs each hook piece from its master mount, so every bracket is the same bracket.

For each job with a "mount" (batch path4, add_path4.py): the object Codex drew (out/final/obj-*.png, keyed and trimmed
by process.py) hangs on a cord that runs up to its top edge. Here:
  - the cord's top is found (the middle of what's visible in the top rows), and where the object itself starts (the
    first row clearly wider than the cord);
  - the object is scaled so its body is BODY_W wide (or BODY_H tall, whichever is smaller), the same for every piece,
    since the masters all come from the same canvas at the same scale;
  - the cord Codex drew is cut off (its thickness changed with each object's scale; the owner: "make sure that all the
    ropes are the same thickness and match to the ring"), and one rope, ROPE_W wide in ROPE red, runs CORD long from
    behind the master's ring, at the tie point in masters/masters.json (masters.py), down to the object;
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
CANVAS_W = 520              # every hook piece this wide (mount at the left), so one width on the path is one scale
MOUNT = 0.65                # the masters, scaled to the size of the brackets in the pieces already in the app


ROPE_W = 8                  # every rope this wide, whatever the object's size (the eave master's tied cord, scaled)
ROPE = "#c8391d"            # and this red (the eave's cord), so all ropes match each other and the eave

# the tassel: Codex drew one under each object, but it grew and shrank with the object's scale (the owner: "the
# tassels are all different sizes"). Cut off at its head (the gold cap, or the knot on it) and drawn TASSEL_H tall
# on every piece, whatever the ornament's size; the owner's "tassel" setting scales them all, and a piece's own
# "tassel" makes up for its mount's width on the path, so on the phone they all match (the owner: "tassels all the same size")
TASSEL_H = 120
TASSEL_TOP = {"hang-persimmon-charm": 897, "hang-plum-lantern-charm": 1126}   # heads that aren't gold, set by eye
NO_TASSEL = {"hang-butterfly-kite"}                                            # ribbons, not a tassel
# and only two tassels, the jade disc's red one and the ruyi jade's green one (the owner: "can we just use these two
# tassels for all of them?"): green where Codex drew a green one, red everywhere else
RED, GREEN = "hang-jade-disc", "hang-ruyi-jade"
GREENS = {"hang-ruyi-jade", "hang-persimmon-charm", "hang-lotus-fan-charm", "hang-bamboo-sachet"}
TASSELS = os.path.join(HERE, "masters", "tassels.json")   # each piece's tassel top, for the path editor's pages


def tassel_top(im):
    """The row each tassel starts at: up from the bottom to its gold cap, then up the cap to where it narrows (the
    bead or the cord above it)."""
    _, body, cw, _ = cord_and_body(im)
    a = np.asarray(im).astype(int)
    op = a[..., 3] > 100
    gold = op & (a[..., 0] > 190) & (a[..., 1] > 140) & (a[..., 2] < 140) & (a[..., 1] - a[..., 2] > 50)
    rows, grows = op.sum(1), gold.sum(1)
    bottom = int(np.nonzero(rows)[0][-1])
    y = bottom - int(0.05 * (bottom - body))
    while y > body and not (grows[y] > 0.5 * rows[y] and rows[y] > 2.5 * cw):
        y -= 1
    while y > body and grows[y - 1] > 0.4 * rows[y - 1] and rows[y - 1] >= 0.6 * rows[y:y + 6].max():
        y -= 1
    return y if y > body else None


def cord_and_body(im):
    """(cord's x at the top, the row where the object starts, the cord's width, the row where the cord ends)."""
    a = np.asarray(im)[..., 3] > 100
    rows = a.sum(axis=1)
    top = [x for y in range(min(8, a.shape[0])) for x in np.nonzero(a[y])[0]]
    cx = float(np.mean(top)) if top else a.shape[1] / 2
    cw = max(2, int(np.median([r for r in rows[:20] if r]) if rows[:20].any() else 4))
    body = next((y for y in range(a.shape[0]) if rows[y] > 4 * cw), 0)
    end = next((y for y in range(a.shape[0]) if rows[y] > 2 * cw), body)   # the first bead, loop or knot under the cord
    return cx, body, cw, end


def clean_cord(obj):
    """The cord Codex drew between the object's bead or knot and the object itself, taken out (the owner: "up to the knot
    we need to remove the rope"), so the one rope, drawn behind, shows there instead. Only rows as narrow as the cord
    (nothing else is beside it), only red, only near the cord's line: beads, knots and the object stay. In place: it
    runs on every hang, and the Hook pieces page (hooks.html) reads the cleaned picture too."""
    a = np.asarray(obj).copy()
    cx, body, cw, end = cord_and_body(obj)
    rows = (a[..., 3] > 100).sum(axis=1)
    r, g, b = (a[..., i].astype(int) for i in range(3))
    red = (r > 140) & (g < 130) & (b < 120) & (r - g > 60)
    x0, x1 = int(cx - 2 * cw), int(cx + 2 * cw) + 1
    n = 0
    for y in range(end, body):
        if rows[y] <= 2 * cw:
            m = red[y, x0:x1]
            a[y, x0:x1, 3][m] = 0
            n += int(m.sum())
    return Image.fromarray(a), n


def clean_master(im):
    """The master as drawn had a blotchy, patchy texture in its flat colour (the owner: "this weird artifact pattern",
    plainest on the roof), and a pink line round its edge from the magenta it was keyed off. Three bilateral passes
    smooth the colour but keep its edges; the edge pixels take the colour of the nearest solid pixel inside."""
    import cv2
    from scipy import ndimage
    a = np.asarray(im).copy()
    rgb = np.ascontiguousarray(a[..., :3])
    for _ in range(3):
        rgb = cv2.bilateralFilter(rgb, 9, 22, 6)
    solid = ndimage.binary_erosion(a[..., 3] == 255, iterations=2)
    if solid.any():
        _, (iy, ix) = ndimage.distance_transform_edt(~solid, return_indices=True)
        edge = ~solid & (a[..., 3] > 0)
        rgb[edge] = rgb[iy[edge], ix[edge]]
    a[..., :3] = rgb
    return Image.fromarray(a)


def rope(W, H, x, y0, y1, knot=None):
    """A rope ROPE_W wide down x from y0 to y1, on a W x H layer, and a knot centred at (x, knot) if given: drawn 4x
    and scaled down, so its edges are smooth."""
    k = 4
    big = Image.new("RGBA", (W * k, H * k))
    from PIL import ImageDraw
    d = ImageDraw.Draw(big)
    c = tuple(int(ROPE[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
    shade = tuple(round(v * 0.78) for v in c[:3]) + (255,)   # a darker right edge, as the drawn cords have
    d.rectangle((round((x - ROPE_W / 2) * k), round(y0 * k), round((x + ROPE_W / 2) * k), round(y1 * k)), fill=c)
    d.rectangle((round((x + ROPE_W / 2 - 2) * k), round(y0 * k), round((x + ROPE_W / 2) * k), round(y1 * k)), fill=shade)
    if knot is not None:
        kw, kh = ROPE_W * 1.0, ROPE_W * 0.75
        d.ellipse((round((x - kw) * k), round((knot - kh) * k), round((x + kw) * k), round((knot + kh) * k)), fill=c, outline=shade, width=2 * k)
    return big.resize((W, H), Image.LANCZOS)


# the owner's rope and ornament size, set in the path editor's Hook pieces page (hooks.html): for all pieces, and
# per piece ({"cord": 150, "size": 1, "pieces": {"hang-bronze-bell": {"cord": 200, "size": 0.8}}})
SETTINGS = os.path.join(MASTERS, "hang-settings.json")


def settings():
    try:
        return json.load(open(SETTINGS))
    except (OSError, ValueError):
        return {}


def hang(obj, master, tie, cord=CORD, size=1.0, band=0, tassel=None, tassel_h=TASSEL_H, tassel_from=None):
    master = master.resize((round(master.width * MOUNT), round(master.height * MOUNT)), Image.LANCZOS)
    tie, band = (tie[0] * MOUNT, round(tie[1] * MOUNT)), band * MOUNT
    cx, body, _, end = cord_and_body(obj)
    # the object, without the cord Codex drew (its thickness changes with each object's scale): it starts at the
    # first bead or knot under the cord, CORD below the ring; one drawn rope, the same for every piece, joins them
    bw, bh = obj.width, obj.height - body
    s = min(BODY_W * size / max(1, bw), BODY_H * size / max(1, bh))
    o = obj.crop((0, end, obj.width, tassel or obj.height))
    o = o.resize((max(1, round(o.width * s)), max(1, round(o.height * s))), Image.LANCZOS)
    # the tassel on its own, tassel_h tall whatever the object's scale, its middle under the object's at its top
    t = None
    if tassel:
        src, stop = tassel_from or (obj, tassel)                            # the tassel drawn: its own, or one of the two
        tx_obj = cx                                                         # where it hangs: under the cord (the koi's fin
                                                                            # reaches its tassel's top, so not that row's middle)
        sx = np.nonzero(np.asarray(src)[stop, :, 3] > 100)[0]
        t = src.crop((0, stop, src.width, src.height))
        x0 = t.getbbox()[0]
        t = t.crop(t.getbbox())
        x0 = x0 - (float(sx.mean()) - tx_obj) if len(sx) else x0           # the drawn tassel's middle under that
        ts = tassel_h / t.height
        t = t.resize((max(1, round(t.width * ts)), max(1, round(t.height * ts))), Image.LANCZOS)
    cx = cx * s
    ox, oy = round(tie[0] - cx), tie[1] + round(cord)
    if t:
        tox, toy = round(ox + tx_obj * s - (tx_obj - x0) * ts), oy + round((tassel - end) * s)
    left = min(0, ox, tox if t else 0)
    W = max(CANVAS_W, master.width, ox + o.width, tox + t.width if t else 0) - left
    H = max(master.height, oy + o.height, toy + t.height if t else 0)
    # behind the object: down past its bead to where the object itself starts, as the drawn cord there is gone
    out = rope(W, H, tie[0] - left, tie[1], oy + round((body - end) * s) + 6)
    out.alpha_composite(o, (ox - left, oy))
    if t:
        out.alpha_composite(t, (tox - left, toy))
    out.alpha_composite(master, (-left, 0))
    # tied on: over a ring, the rope wraps its bottom band (never up through the hole) with a knot under it; on the
    # eave's cord, it just carries on from the cord's end
    if band:
        out.alpha_composite(rope(W, H, tie[0] - left, tie[1] - band, tie[1], knot=tie[1] + ROPE_W * 0.4))
    else:
        out.alpha_composite(rope(W, H, tie[0] - left, tie[1] - 3, tie[1] + 1))
    return out


def main():
    jobs = json.load(open(os.path.join(HERE, "jobs.json"), encoding="utf-8"))
    meta = json.load(open(os.path.join(MASTERS, "masters.json")))
    st = settings()
    n, tops, cleaned = 0, {}, {}
    by_out = {j["out"]: j for j in jobs if "out" in j}
    def obj_of(out):
        return Image.open(os.path.join(FINAL, os.path.basename(by_out[out]["file"]))).convert("RGBA")
    reds, greens = obj_of(RED), obj_of(GREEN)
    two = {RED: (reds, TASSEL_TOP.get(RED) or tassel_top(reds)), GREEN: (greens, TASSEL_TOP.get(GREEN) or tassel_top(greens))}
    for j in jobs:
        if not j.get("mount"):
            continue
        f = os.path.join(FINAL, os.path.basename(j["file"]))
        m = meta.get(j["mount"])
        if not os.path.exists(f) or not m or not m["tie"]:
            continue
        own = (st.get("pieces") or {}).get(j["out"], {})
        # (a cord the master's tied cord was cut back to its knot by, added on, so the object hangs where it did)
        obj, gone = clean_cord(Image.open(f).convert("RGBA"))
        if gone:
            obj.save(f)
        top = None if j["out"] in NO_TASSEL else TASSEL_TOP.get(j["out"]) or tassel_top(obj)
        src = GREEN if j["out"] in GREENS else RED
        tops[j["out"]] = top and {"top": top, "from": os.path.basename(by_out[src]["file"]), "fromTop": two[src][1]}
        if m["file"] not in cleaned:   # cleaned once, and saved for the path editor's pages to draw
            cleaned[m["file"]] = clean_master(Image.open(os.path.join(MASTERS, m["file"])).convert("RGBA"))
            cleaned[m["file"]].save(os.path.join(MASTERS, "clean-" + m["file"]))
        out = hang(obj, cleaned[m["file"]], m["tie"],
                   cord=own.get("cord", st.get("cord", CORD)) + round(m.get("drop", 0) * MOUNT), size=own.get("size", st.get("size", 1.0)), band=m.get("band", 0),
                   tassel=top, tassel_h=TASSEL_H * st.get("tassel", 1.0) * own.get("tassel", 1.0), tassel_from=two[src])
        out.save(os.path.join(FINAL, j["out"] + ".png"))
        out.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(FINAL, j["out"] + "-right.png"))
        n += 1
    json.dump(tops, open(TASSELS, "w"), indent=1)
    print(n, "hook pieces hung from their masters")


if __name__ == "__main__":
    main()
