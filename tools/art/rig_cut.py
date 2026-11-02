"""Bùbù's master rig: takes the Codex parts in out/raw/rm-*.png off their magenta, splits the whole limbs at their joints
with a round overlap, trims the pose paws down to the hand, and writes out/rig/<part>.png (full 1024 canvas, so they stack
as they are) and out/rig/rig.json (where each joint is). Then draws a few test poses to out/rig/pose-test.png.

From tools/art: ../sfx/.venv/Scripts/python -I rig_cut.py
"""
import json
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = "out/rig"
SIZE = 1024
PLAIN = ("torso pack tail head ear-l ear-r brows patches nose cheeks eyes-open eyes-happy eyes-shut eyes-wow "
         "eyes-squint mouth-smile mouth-open mouth-o mouth-frown").split()
# how far along each limb its joints are
ARM = {"top": 0.10, "mid": 0.52, "end": 0.80}
STRAP_TOP, STRAP_SEEDS = 430, [(327, 555), (686, 555)]
LEG = {"top": 0.12, "mid": 0.50, "end": 0.84}


def load(name):
    """RGBA floats, with the magenta taken off: its share of each edge pixel becomes transparency."""
    rgb = np.asarray(Image.open(f"out/raw/rm-{name}.png").convert("RGB").resize((SIZE, SIZE), Image.LANCZOS), float)
    alpha = 1 - np.clip((np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1]) / 200, 0, 1)
    alpha[alpha < 0.04] = 0
    safe = np.maximum(alpha, 0.04)[..., None]
    colour = np.clip((rgb - (1 - safe) * np.array([255.0, 0, 255])) / safe, 0, 255)
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
share = np.clip((torso[..., :3].min(-1) - fur_tone.min()) / 150, 0, 1)
belly_part = torso.copy()
belly_part[..., 3] = torso[..., 3] * share
belly_part[..., :3] = np.clip((torso[..., :3] - (1 - share[..., None]) * fur_tone) / np.maximum(share[..., None], 0.05), 0, 255)
save("belly", belly_part)
ys, xs = np.mgrid[0:SIZE, 0:SIZE]
ax = np.nonzero(load("limb-arm-l")[..., 3].sum(0))[0]
belly = (torso[..., :3].min(-1) > 200) & (torso[..., 3] > 128)
by, bx = np.nonzero(belly)
cx, half = (bx.min() + bx.max()) / 2, (bx.max() - bx.min()) / 2
top = np.nonzero(torso[..., 3].sum(1))[0][0]
cy, tall = (top + by.max()) / 2, (by.max() - top) / 2
egg = ((xs - cx) / (half + 4)) ** 2 + ((ys - cy) / (tall + 4)) ** 2
torso[..., 3] *= np.clip((1 - egg) * half / 2 + 0.5, 0, 1)
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
save("straps", np.dstack([sheet, soft]))

# Codex's open mouth is far bigger than his smile and runs into his nose: brought down to a little wider than the smile.
smile, wide = Image.open(f"{OUT}/mouth-smile.png"), Image.open(f"{OUT}/mouth-open.png")
sb, wb = smile.getchannel("A").getbbox(), wide.getchannel("A").getbbox()
small = wide.crop(wb)
w = round((sb[2] - sb[0]) * 1.15)
small = small.resize((w, round(small.height * w / small.width)), Image.LANCZOS)
fixed = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
fixed.paste(small, (round((sb[0] + sb[2] - w) / 2), sb[1]))
fixed.save(f"{OUT}/mouth-open.png")

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
