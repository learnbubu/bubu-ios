"""Turns out/raw/*.png (art on solid magenta) into app-ready transparent PNGs in out/final/:

- the magenta is keyed out, with the pink fringe on soft edges cleaned up (despill), and the
  image is trimmed to its artwork;
- corners and hanging pieces also get a mirrored copy (-right) for the other side of the path;
- picture sheets (4 columns) are sliced into one PNG per word, named after the word, using
  picture_sheets.json for the order; words that share a picture get a copy each.

Then out/review.html shows everything on a checkerboard and on the app's cream, to catch any
leftover pink, missing icons or text the model added.
"""
import glob
import json
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "out", "raw")
FINAL = os.path.join(HERE, "out", "final")


def background(a):
    """The backdrop colour, read from the four corners (pure magenta is asked for, but the
    model sometimes drifts, e.g. to raspberry)."""
    k = 12
    patches = np.concatenate([a[:k, :k].reshape(-1, 3), a[:k, -k:].reshape(-1, 3),
                              a[-k:, :k].reshape(-1, 3), a[-k:, -k:].reshape(-1, 3)])
    return np.median(patches, axis=0)


def key(im, bg=None):
    """The backdrop -> transparent, trimmed to the artwork."""
    im = Image.fromarray(cutout_array(im, bg), "RGBA")
    bbox = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop(bbox) if bbox else im


def key_full(im, bg=None):
    """The backdrop -> transparent, on the image's own canvas (not trimmed, so its shape and place hold)."""
    return Image.fromarray(cutout_array(im, bg), "RGBA")


def cutout_array(im, bg=None):
    """Keep existing transparency; only colour-key fully opaque source images."""
    rgba = np.asarray(im.convert("RGBA"))
    if rgba[..., 3].min() < 255:
        return rgba.copy()
    a = rgba[..., :3].astype(np.float32)
    return _key_array(a, background(a) if bg is None else bg)


def _key_array(a, bg):
    """RGB float array -> RGBA uint8, the backdrop keyed out, the fringe despilled."""
    if np.abs(bg - np.array([255, 0, 255])).max() < 60:
        # true magenta: key on 'magenta-ness' (red and blue both above green), which nothing in
        # the palette has, so soft edges come out clean
        m = np.minimum(a[..., 0], a[..., 2]) - a[..., 1]
        alpha = 1 - np.clip((m - 60) / (190 - 60), 0, 1)
    else:
        # anything else (e.g. raspberry): distance from it, kept tight because the coral
        # backpack sits only ~75 away from raspberry
        d = np.sqrt(((a - bg) ** 2).sum(axis=2))
        alpha = np.clip((d - 22) / (62 - 22), 0, 1)
    # despill: on soft edges, remove the backdrop's share of the colour (un-premultiply)
    edge = (alpha > 0) & (alpha < 1)
    fg = a.copy()
    fg[edge] = (a[edge] - (1 - alpha[edge, None]) * bg) / np.maximum(alpha[edge, None], 0.05)
    return np.dstack([fg, alpha * 255]).clip(0, 255).astype(np.uint8)


# pieces whose art came back with pink in it that two regenerations didn't shift: the pink is
# recoloured, to white (mist) or gold (leaves)
DEPINK = {"corner-tall-karst-pillar": "white", "corner-tall-ginkgo": "gold"}


def depink(im, to):
    a = np.asarray(im.convert("RGBA")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    light = (r + g + b) / 3
    if to == "white":       # the mist: pale, pink-tinged (the model's try at see-through mist over magenta)
        pink = (light > 190) & (r - g > 10) & (r >= b) & (a[..., 3] > 0)
    else:                   # the specks: coral-pink among the gold leaves
        pink = (r - g > 40) & (b > g - 6) & (a[..., 3] > 0)
    if to == "white":
        v = np.clip(light * 1.03, 0, 255)
        for c, tint in enumerate((0.99, 1.0, 0.98)):              # a soft, slightly warm white
            a[..., c] = np.where(pink, np.clip(v * tint, 0, 255), a[..., c])
        a[..., 3] = np.where(pink, a[..., 3] * 0.85, a[..., 3])   # and a little see-through, as mist
    else:                                                         # a warm gold at the same lightness
        k = light / 200
        for c, base in enumerate((240, 178, 60)):
            a[..., c] = np.where(pink, np.clip(base * k, 0, 255), a[..., c])
    return Image.fromarray(a.clip(0, 255).astype(np.uint8), "RGBA")


def leftover_pink(im):
    """Share of visible pixels that still look magenta: a sign the model put pink in the art."""
    a = np.asarray(im).astype(np.int32)
    vis = a[..., 3] > 200
    m = (np.minimum(a[..., 0], a[..., 2]) - a[..., 1]) > 90
    return float((m & vis).sum()) / max(1, vis.sum())


def slice_sheet(im, n, bg, cols=4):
    """One icon per cell. The whole sheet is keyed first, then each cell keeps only the shapes
    whose centre falls inside it, so a neighbour's edge poking over the line isn't cut in."""
    from scipy import ndimage
    rows = (n + cols - 1) // cols
    W, H = im.size
    full = cutout_array(im, bg)
    mask = full[..., 3] > 40
    lab, k = ndimage.label(mask)
    cents = ndimage.center_of_mass(mask, lab, range(1, k + 1))
    sizes = ndimage.sum(mask, lab, range(1, k + 1))
    cells = []
    for i in range(n):
        x, y = i % cols, i // cols
        x0, y0, x1, y1 = x * W // cols, y * H // rows, (x + 1) * W // cols, (y + 1) * H // rows
        keep = [j + 1 for j, (cy, cx) in enumerate(cents)
                if x0 <= cx < x1 and y0 <= cy < y1 and sizes[j] > 30]
        cell = full.copy()
        cell[..., 3] = np.where(np.isin(lab, keep), cell[..., 3], 0)
        img = Image.fromarray(cell, "RGBA")
        bbox = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        cells.append(img.crop(bbox) if bbox else img.crop((x0, y0, x1, y1)))
    return cells


def main():
    os.makedirs(FINAL, exist_ok=True)
    sheets = json.load(open(os.path.join(HERE, "picture_sheets.json"), encoding="utf-8"))
    report = []
    for p in sorted(glob.glob(os.path.join(RAW, "*.png"))):
        name = os.path.splitext(os.path.basename(p))[0]
        raw = Image.open(p)
        if name.startswith("pictures-picture-sheet-"):
            i = int(name.split("-")[3]) - 1
            words = sheets["sheets"][i]
            os.makedirs(os.path.join(FINAL, "pictures"), exist_ok=True)
            bg = background(np.asarray(raw.convert("RGB")).astype(np.float32))
            for k, it in zip(slice_sheet(raw, len(words), bg, cols=min(4, len(words))), words):
                k.save(os.path.join(FINAL, "pictures", it["w"] + ".png"))
                report.append(("pictures/" + it["w"] + ".png", it["d"], leftover_pink(k)))
            continue
        k = key(raw)
        if name in DEPINK:
            k = depink(k, DEPINK[name])
        k.save(os.path.join(FINAL, name + ".png"))
        report.append((name + ".png", "", leftover_pink(k)))
        if name.startswith(("corner-", "hang-")):
            k.transpose(Image.FLIP_LEFT_RIGHT).save(os.path.join(FINAL, name + "-right.png"))
    # single-icon redos replace a sliced card (picfix.json: file -> word)
    fixes = json.load(open(os.path.join(HERE, "picfix.json"), encoding="utf-8")) if os.path.exists(os.path.join(HERE, "picfix.json")) else {}
    for f, w in fixes.items():
        src = os.path.join(FINAL, f + ".png")
        if os.path.exists(src):
            shutil.move(src, os.path.join(FINAL, "pictures", w + ".png"))
            target = "pictures/" + w + ".png"
            report = [row for row in report if row[0] not in (f + ".png", target)]
            report.append((target, "(redo)", leftover_pink(Image.open(os.path.join(FINAL, target)))))
    # words drawn with another word's picture
    for w, same in sheets.get("same", {}).items():
        src = os.path.join(FINAL, "pictures", same + ".png")
        if os.path.exists(src):
            shutil.copy(src, os.path.join(FINAL, "pictures", w + ".png"))
    rows = "".join(
        f'<figure><div class="ck"><img src="final/{f}"></div><div class="cr"><img src="final/{f}"></div>'
        f'<figcaption>{f}{" · " + d if d else ""}{" · <b>pink " + format(pk, ".1%") + "</b>" if pk > 0.002 else ""}</figcaption></figure>'
        for f, d, pk in report)
    html = ("<!doctype html><meta charset=utf-8><title>Bùbù art review</title><style>body{font-family:system-ui;margin:16px;background:#fff}"
            "main{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:14px}figure{margin:0}"
            ".ck,.cr{height:140px;display:grid;place-items:center;border-radius:8px}"
            ".ck{background:repeating-conic-gradient(#ccc 0 25%,#fff 0 50%) 0 0/16px 16px}.cr{background:#f6f1e4;margin-top:4px}"
            "img{max-width:96%;max-height:130px}figcaption{font-size:12px;margin-top:4px}b{color:#c00}</style>"
            f"<h1>Bùbù art review ({len(report)})</h1><main>{rows}</main>")
    open(os.path.join(HERE, "out", "review.html"), "w", encoding="utf-8").write(html)
    flagged = [f for f, _, pk in report if pk > 0.002]
    print(f"{len(report)} images to out/final; {len(flagged)} with leftover pink: {flagged[:10]}")


if __name__ == "__main__":
    main()
