"""Puts the processed art (out/final) into the app:

- picture cards -> Assets.xcassets/pic-<utf8 hex of the word>.imageset (Pictures.asset(_:) finds them)
- panda poses   -> panda-<pose>.imageset (only names the app doesn't have yet)
- scenery corners and landmarks -> corner-*/scene-*.imageset, plus Model/NewArt.swift with their
  sizes and painted strips (slabs) for the path's automatic scenery

Images are scaled down to what the app draws (3x the largest point size) and saved as optimised PNGs.
Re-running replaces what it installed before.
"""
import json
import os
import shutil

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
APP = os.path.join(HERE, "..", "..", "native", "Bubu")
ASSETS = os.path.join(APP, "Assets.xcassets")

# longest side in pixels, per kind (3x of the largest size drawn)
MAX = {"pic": 300, "panda": 600, "corner": 900, "scene": 900, "hang": 900}


def imageset(name, im, longest):
    im = im.copy()
    im.thumbnail((longest, longest), Image.LANCZOS)
    d = os.path.join(ASSETS, name + ".imageset")
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    # 256 colours with alpha: the flat art loses nothing visible and the PNGs are about a third the size
    small = im.convert("RGBA").quantize(256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    small.save(os.path.join(d, name + ".png"), optimize=True)
    json.dump({"info": {"author": "xcode", "version": 1},
               "images": [{"idiom": "universal", "filename": name + ".png"}]},
              open(os.path.join(d, "Contents.json"), "w"), indent=2)
    return im


def slabs(im):
    """Ten strips top to bottom: the opaque extent of each as a fraction of the width."""
    a = np.asarray(im.getchannel("A")) > 40
    h, w = a.shape
    out = []
    for i in range(10):
        band = a[i * h // 10:(i + 1) * h // 10]
        cols = np.nonzero(band.any(axis=0))[0]
        out.append([round(cols[0] / w, 3), round((cols[-1] + 1) / w, 3)] if len(cols) else [0.0, 0.0])
    return out


def main():
    existing = {d[:-len(".imageset")] for d in os.listdir(ASSETS) if d.endswith(".imageset")}
    # remove what this script put there before, so renamed or dropped art doesn't linger
    for d in os.listdir(ASSETS):
        if d.startswith(("pic-", "corner-", "scene-", "hang-")) and d.endswith(".imageset"):
            shutil.rmtree(os.path.join(ASSETS, d))
    n = {"pic": 0, "panda": 0, "corner": 0, "scene": 0, "hang": 0}
    pics = os.path.join(FINAL, "pictures")
    for f in sorted(os.listdir(pics)):
        word = os.path.splitext(f)[0]
        imageset("pic-" + word.encode("utf-8").hex(), Image.open(os.path.join(pics, f)), MAX["pic"])
        n["pic"] += 1
    art, strips, corners, scenes, pandas = {}, {}, [], [], []
    for f in sorted(os.listdir(FINAL)):
        if not f.endswith(".png") or (f.endswith("-right.png") and f.startswith(("corner-", "hang-"))):
            continue
        name = f[:-4]
        kind = name.split("-")[0]
        if kind == "panda":
            if name in existing and name not in installed_pandas():
                continue                      # never replace the app's original poses
            imageset(name, Image.open(os.path.join(FINAL, f)), MAX["panda"])
            pandas.append(name)
        elif kind == "hang":
            # placed by hand in the path editor only (not in the automatic rotation); its size
            # comes to course.json from the editor's ART
            imageset(name, Image.open(os.path.join(FINAL, f)), MAX[kind])
        elif kind in ("corner", "scene"):
            im = imageset(name, Image.open(os.path.join(FINAL, f)), MAX[kind])
            # the tall, slim corners (batch 2) take less of the screen's width
            art[name] = {"w": (48 if "-tall-" in name else 60) if kind == "corner" else 65, "ar": round(im.height / im.width, 3),
                         "side": "left" if kind == "corner" else "any"}
            strips[name] = slabs(im)
            (corners if kind == "corner" else scenes).append(name)
        else:
            continue
        n[kind] += 1
    json.dump(pandas, open(os.path.join(HERE, "installed_pandas.json"), "w"))
    lines = ["import CoreGraphics", "",
             "/// Scenery made with the art pipeline (tools/art, Oct 2026). Written by tools/art/install.py; don't edit.",
             "enum NewArt {",
             "    /// Corners, anchored bottom-left like the fol- pieces; the path mirrors them for the right.",
             "    static let corners: [String] = [" + ", ".join(f'"{c}"' for c in corners) + "]",
             "    /// Free-standing landmarks, like the land- pieces.",
             "    static let landmarks: [String] = [" + ", ".join(f'"{s}"' for s in scenes) + "]",
             "    static let art: [String: ArtSize] = ["]
    lines += [f'        "{k}": ArtSize(w: {v["w"]}, ar: {v["ar"]}, side: "{v["side"]}"),' for k, v in art.items()]
    lines += ["    ]", "    static let slabs: [String: [[CGFloat]]] = ["]
    lines += [f'        "{k}": {json.dumps(v)},' for k, v in strips.items()]
    lines += ["    ]", "}", ""]
    open(os.path.join(APP, "Model", "NewArt.swift"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print(n)


def installed_pandas():
    p = os.path.join(HERE, "installed_pandas.json")
    return set(json.load(open(p))) if os.path.exists(p) else set()


if __name__ == "__main__":
    main()
