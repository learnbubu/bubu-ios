"""Bùbù's master rig: takes the Codex parts in out/raw/rm-*.png off their magenta, splits the whole limbs at their joints
with a round overlap, trims the pose paws down to the hand, and writes out/rigm/<part>.png (full 1024 canvas, so they stack
as they are) and out/rigm/rig.json (where each joint is). Then draws a few test poses to out/rigm/pose-test.png.

From tools/art: ../sfx/.venv/Scripts/python -I rig_cut.py
"""
import json
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = "out/rigm"
SIZE = 1024
PLAIN = ("torso pack tail head ear-l ear-r brows patches nose cheeks eyes-open eyes-happy eyes-shut eyes-wow "
         "eyes-squint mouth-smile mouth-open mouth-o mouth-frown").split()
FUR = np.array([52.0, 56, 57])
LEG_OUT = 730  # how far down his side a leg first shows
# how far along each limb its joints are
ARM = {"top": 0.10, "mid": 0.52, "end": 0.80}
STRAP_TOP, STRAP_SEEDS = 430, [(327, 555), (686, 555)]
LEG = {"top": 0.12, "mid": 0.50, "end": 0.84}


def load(name):
    """RGBA floats, with the magenta taken off: its share of each edge pixel becomes transparency."""
    # a small median takes out Codex's mottling and keeps the shapes
    rgb = np.asarray(Image.open(f"out/raw/rm-{name}.png").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.MedianFilter(5)), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
    colour[np.abs(colour - FUR).max(-1) < 30] = FUR  # one black
    # one piece only: stray specks go
    return np.dstack([colour, alpha * 255])


def save(name, a):
    Image.fromarray(a.round().astype("uint8"), "RGBA").save(f"{OUT}/{name}.png")


def axis(a, flip_to=None):
    """Distance along a limb from its body end, 0 to 1, for every pixel, and the point on its centre at any distance."""
    ys, xs = np.nonzero(a[..., 3] > 128)
    pts = np.column_stack([xs, ys]).astype(float)
    centre = pts.mean(0)
    _, vecs = np.linalg.eigh(np.cov((pts - centre).T))
    v = vecs[:, -1]
    if v[1] < 0:
        v = -v  # limbs hang: 0 is the top
    t = (pts - centre) @ v
    lo, hi = t.min(), t.max()
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    along = (((np.dstack([xx, yy]) - centre) @ v) - lo) / (hi - lo)

    def at(d):
        band = np.abs(along - d) < 0.012
        band &= a[..., 3] > 128
        by, bx = np.nonzero(band)
        p = np.array([bx.mean(), by.mean()])
        reach = np.hypot(bx - p[0], by - p[1]).max()
        return p, reach

    return along, at


def piece(a, along, lo, hi, joints):
    """The stretch of limb from lo to hi, with a round end of fur added at each joint so it turns with no gap."""
    keep = (along >= lo) & (along < hi)
    out = a.copy()
    out[..., 3] = a[..., 3] * keep
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    fur = np.median(a[a[..., 3] > 200][:, :3], axis=0)
    for p, r in joints:
        d = np.hypot(xx - p[0], yy - p[1])
        cover = np.clip(r + 0.5 - d, 0, 1)
        add = cover > out[..., 3] / 255
        out[add, :3] = fur
        out[add, 3] = cover[add] * 255
    return out


def split(name, side, stops, parts):
    a = load(name)
    if "leg" in name:
        # a leg only shows where it shows standing: Codex carried the hip out past the belly's edge
        bare = load("bare")[..., 3] / 255
        a[..., 3] *= np.asarray(Image.fromarray((bare * 255).astype("uint8")).filter(ImageFilter.MaxFilter(3)), float) / 255
        # that outline includes his arms, so above where a leg comes out it has to stay behind the belly
        # and it leaves the belly's edge at a slant, with no step where it starts
        for row in range(SIZE):
            inside = np.nonzero(share[row] > 0.5)[0]
            # above the belly's widest line its own edge; below, that widest width, opening out on the slant
            width = half if row >= waist else ((inside.max() - inside.min()) / 2 if len(inside) > 8 else 0)
            a[row, :, 3] *= np.abs(np.arange(SIZE) - cx) <= width + max(0, row - LEG_OUT) * 0.6
    save(name, a)  # whole, for Studio's bones: rigid pieces lump at their joints (owner, 2 Nov 2026)
    along, at = axis(a)
    top, _ = at(stops["top"])
    mid, mr = at(stops["mid"])
    end, er = at(stops["end"])
    (one, two, three) = parts
    save(f"{one}-{side}", piece(a, along, -1, stops["mid"], [(mid, mr)]))
    save(f"{two}-{side}", piece(a, along, stops["mid"], stops["end"], [(mid, mr), (end, er)]))
    save(f"{three}-{side}", piece(a, along, stops["end"], 2, [(end, er)]))
    return {f"{one}-{side}": top.round(1).tolist(), f"{two}-{side}": mid.round(1).tolist(), f"{three}-{side}": end.round(1).tolist()}


def hand(name, towards, wrist_share):
    """A pose paw on the viewer's right. Codex drew these on the left, with some arm: mirrored, and cut back to the hand."""
    a = load(name)[:, ::-1].copy()
    if wrist_share is None:
        ys, xs = np.nonzero(a[..., 3] > 128)
        save(name, a)
        return [round(float(xs.mean()), 1), round(float(ys.min()), 1)]
    along, at = axis(a)
    if towards == "top":
        along = 1 - along
    p, r = at(wrist_share)
    save(name, piece(a, along, wrist_share, 2, [(p, r)]))
    return p.round(1).tolist()


os.makedirs(OUT, exist_ok=True)
for n in PLAIN:
    save(n, load(n))

# Codex's torso keeps stumps of arm down each side, which stay behind when an arm lifts. Only the egg of his body stays;
# the arms' own shoulders fill the rest. (The belly's edge is inside it.)
torso = load("torso")
# the belly on its own, so the straps can run under it as they do on the sheet
fur_tone = np.median(torso[(torso[..., 3] > 200) & (torso[..., 0] < 100)][:, :3], axis=0)
share = np.clip((torso[..., :3].min(-1) - 130) / 70, 0, 1)  # above the fur's mottling and any grey toe lines
belly_part = torso.copy()
belly_part[..., 3] = torso[..., 3] * share
belly_part[..., :3] = np.clip((torso[..., :3] - (1 - share[..., None]) * fur_tone) / np.maximum(share[..., None], 0.05), 0, 255)
save("belly", belly_part)
ys, xs = np.mgrid[0:SIZE, 0:SIZE]
ax = np.nonzero(load("limb-arm-l")[..., 3].sum(0))[0]
belly = (torso[..., :3].min(-1) > 200) & (torso[..., 3] > 128)
by, bx = np.nonzero(belly)
# (Codex left thin specks beside it: shrinking the shape and growing it back removes them and keeps its real edge)
solid = Image.fromarray(((share > 0.3) * 255).astype("uint8")).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
solid = solid.filter(ImageFilter.MinFilter(7)).filter(ImageFilter.MaxFilter(9))
solid = np.asarray(solid) > 128
share = share * solid
belly_part[..., 3] *= solid
save("belly", belly_part)
sy, sx = np.nonzero(solid)
cx, half = (sx.min() + sx.max()) / 2, (sx.max() - sx.min()) / 2
by = sy
top = np.nonzero(torso[..., 3].sum(1))[0][0]
cy, tall = (top + by.max()) / 2, (by.max() - top) / 2
# Standing, no black shows beside his belly (owner, 2 Nov 2026): the chest tapers from the neck into the belly's widest
# line, and below that line there's only belly.
waist = by.mean()
reach = 150 + (half - 10 - 150) * np.clip((ys - top) / (waist - top), 0, 1)
torso[..., 3] *= np.clip(reach - np.abs(xs - cx) + 0.5, 0, 1) * (ys < waist) + (share > 0.5) * (ys >= waist)
save("torso", torso)

# Codex's straps came out padded and bulky, so they're lifted straight from the approved master.
sheet = np.asarray(Image.open("out/raw/rm-master.png").convert("RGB"), float)
red = (sheet[..., 0] > 150) & (sheet[..., 1] < 150) & (sheet[..., 2] < 125) & (np.arange(SIZE)[:, None] >= STRAP_TOP)
seen = np.zeros_like(red)
for seed in STRAP_SEEDS:
    todo = [seed]
    while todo:
        x, y = todo.pop()
        if 0 <= x < SIZE and 0 <= y < SIZE and red[y, x] and not seen[y, x]:
            seen[y, x] = True
            todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
soft = np.asarray(Image.fromarray((seen * 255).astype("uint8")).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(0.7)), float)
strap_colour = sheet.copy()
strap_colour[~seen] = np.median(sheet[seen], axis=0)  # so the soft edge doesn't carry the backdrop's or the head's colour
save("straps", np.dstack([strap_colour, soft]))

# Codex's open mouth is far bigger than his smile and runs into his nose: brought down to a little wider than the smile.
smile, wide = Image.open(f"{OUT}/mouth-smile.png"), Image.open(f"{OUT}/mouth-open.png")
sb, wb = smile.getchannel("A").getbbox(), wide.getchannel("A").getbbox()
small = wide.crop(wb)
w = round((sb[2] - sb[0]) * 1.15)
small = small.resize((w, round(small.height * w / small.width)), Image.LANCZOS)
fixed = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fixed.paste(small, (round((sb[0] + sb[2] - w) / 2), sb[1]))
fixed.save(f"{OUT}/mouth-open.png")

# the backpack came out a big slab showing down both sides: only a low rounded bag, from his shoulders to his chest
bag = Image.open(f"{OUT}/pack.png")
bb = bag.getchannel("A").getbbox()
small = bag.crop(bb)
small = small.resize((round(small.width * 0.9), round(small.height * 0.56)), Image.LANCZOS)
out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
out.paste(small, (round((bb[0] + bb[2] - small.width) / 2), bb[1]))
out.save(f"{OUT}/pack.png")

joints = {}
joints.update(split("limb-arm-l", "l", ARM, ("arm", "forearm", "paw")))
joints.update(split("limb-arm-r", "r", ARM, ("arm", "forearm", "paw")))
joints.update(split("limb-leg-l", "l", LEG, ("leg", "shin", "foot")))
joints.update(split("limb-leg-r", "r", LEG, ("leg", "shin", "foot")))
joints["paw-fist"] = hand("paw-fist", "bottom", None)
joints["paw-point"] = hand("paw-point", "top", 0.55)
joints["paw-thumb"] = hand("paw-thumb", "top", 0.62)
json.dump(joints, open(f"{OUT}/rig.json", "w"), indent=1)


def turned(name, pivot, degrees, moved=(0, 0)):
    im = Image.open(f"{OUT}/{name}.png")
    im = im.rotate(degrees, Image.BICUBIC, center=tuple(pivot))
    return Image.Transform and im.transform(im.size, Image.AFFINE, (1, 0, -moved[0], 0, 1, -moved[1]))


def chain(sheet, names, angles, start=(0, 0)):
    """Limb segments each turning on the one before: angles add up down the chain, and each joint is carried along."""
    total, move = 0, np.array(start, float)
    drawn = []
    for n, a in zip(names, angles):
        total += a
        pivot = np.array(joints[n], float)
        drawn.append(turned(n, pivot, total, tuple(move)))
        if n != names[-1]:
            nxt = np.array(joints[names[names.index(n) + 1]], float)
            r = np.radians(total)
            rel = nxt - pivot
            # PIL turns anticlockwise on screen
            now = np.array([rel[0] * np.cos(r) + rel[1] * np.sin(r), -rel[0] * np.sin(r) + rel[1] * np.cos(r)])
            move = move + pivot + now - nxt
    return drawn


def pose(left, right, legl, legr, face, down=0):
    canvas = Image.new("RGBA", (SIZE, SIZE), (205, 215, 225, 255))
    def put(im): canvas.alpha_composite(im)
    def plain(n, dy=0): put(Image.open(f"{OUT}/{n}.png").transform((SIZE, SIZE), Image.AFFINE, (1, 0, 0, 0, 1, -dy)))
    plain("pack", down); plain("tail", down)
    for im in chain(canvas, ["leg-l", "shin-l", "foot-l"], legl, (0, down)) + chain(canvas, ["leg-r", "shin-r", "foot-r"], legr, (0, down)):
        put(im)
    for im in chain(canvas, ["arm-l", "forearm-l", "paw-l"], left, (0, down)) + chain(canvas, ["arm-r", "forearm-r", "paw-r"], right, (0, down)):
        put(im)
    for n in ["torso", "straps", "belly", "ear-l", "ear-r", "head", "brows", "patches"] + face + ["nose", "cheeks"]:
        plain(n, down)
    return canvas.resize((400, 400), Image.LANCZOS)


poses = [
    pose((0, 0, 0), (0, 0, 0), (0, 0, 0), (0, 0, 0), ["eyes-open", "mouth-smile"]),
    pose((0, 0, 0), (75, 45, 0), (0, 0, 0), (0, 0, 0), ["eyes-happy", "mouth-open"]),
    pose((-85, -35, 0), (85, 35, 0), (0, 0, 0), (0, 0, 0), ["eyes-wow", "mouth-open"]),
    pose((-30, -50, 0), (30, 50, 0), (-25, 45, -20), (25, -45, 20), ["eyes-squint", "mouth-smile"], 40),
]
sheet = Image.new("RGB", (1600, 400))
for i, p in enumerate(poses):
    sheet.paste(p.convert("RGB"), (i * 400, 0))
sheet.save(f"{OUT}/pose-test.png")
print("joints", len(joints))
