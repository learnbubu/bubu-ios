"""Installs the effects art into the app (owner, 6 Oct 2026): the firecracker burst's pieces and
Bùbù in parts. Each rig part is trimmed to its own edges and its place on Bùbù (on panda-idle's
420 x 643 canvas, after the trim) is written to Model/RigArt.swift, which the app draws from.

Run after rig_trim.py, rig_straps.py and rig_blend.py (which make out/rig/*).
"""
import json
import os

from PIL import Image

from rig_layout import L

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..", "..", "native", "Bubu")
ASSETS = os.path.join(APP, "Assets.xcassets")
RIG = os.path.join(HERE, "out", "rig")
FINAL = os.path.join(HERE, "out", "final")

PARTS = ["rig2-pack-side", "rig2-body", "rig4-torso-arms",
         "rig-arm-left-up", "rig-arm-right-up", "rig-arm-left-down", "rig-arm-right-down",
         "rig-head", "rig-mouth-smile", "rig-mouth-open",
         "rig-glint-open-L", "rig-glint-open-R", "rig-glint-blink-L", "rig-glint-blink-R", "rig-glint-wow-L", "rig-glint-wow-R"]
# the burst's pieces, by their longest side in pixels
FX = {"fx-firecracker": 140, "fx-firecracker-knot-nocord": 260, "fx-pop-1": 160, "fx-pop-2": 260, "fx-pop-3": 240, "fx-seal": 340}
# the app's part names, drawn from the third body and arms (rig3: rounded shoulders, so no trims or strap layers)
SOURCE = {"rig2-body": "rig3-body", "rig-arm-left-down": "rig3-arm-down", "rig-arm-right-down": "rig3-arm-down-R",
          "rig-arm-left-up": "rig3-arm-up", "rig-arm-right-up": "rig3-arm-up-R"}
GONE = ["rig2-body-trim", "rig2-body-trim-L", "rig2-body-trim-R", "rig-straps-L", "rig-straps-R", "rig-straps-L-top", "rig-straps-R-top"]
DENSITY = 1.25      # rig parts are stored at 1.25 px per canvas px (Bùbù shows about 0.35 pt per canvas px)


def imageset(name, im):
    d = os.path.join(ASSETS, name + ".imageset"); os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, name + ".png"), optimize=True)
    json.dump({"images": [{"filename": name + ".png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
              open(os.path.join(d, "Contents.json"), "w"), indent=2)


def main():
    rects, aspects = {}, {}
    import shutil
    for n in GONE:
        shutil.rmtree(os.path.join(ASSETS, n + ".imageset"), ignore_errors=True)
    for n in PARTS:
        src = SOURCE.get(n, n)
        x, y, w = L[src]
        im = Image.open(os.path.join(RIG, src + ".png")).convert("RGBA")
        s = w / im.width                          # canvas px per image px
        box = im.getbbox()
        im = im.crop(box)
        rx, ry, rw, rh = x + box[0] * s, y + box[1] * s, im.width * s, im.height * s
        out = im.resize((max(1, round(rw * DENSITY)), max(1, round(rh * DENSITY))), Image.LANCZOS)
        imageset(n, out)
        rects[n] = (round(rx, 1), round(ry, 1), round(rw, 1), round(rh, 1))
    for n, longest in FX.items():
        src = os.path.join(FINAL, n + ".png")
        im = Image.open(src).convert("RGBA"); im = im.crop(im.getbbox())
        im.thumbnail((longest, longest), Image.LANCZOS)
        imageset(n, im)
        aspects[n] = round(im.height / im.width, 4)
    lines = ["import CoreGraphics", "",
             "// Made by tools/art/install_fx.py: where each of Bùbù's parts sits, on panda-idle's",
             "// 420 x 643 canvas, and the burst pieces' shapes (height over width). Don't edit by hand.",
             "enum RigArt {",
             "    static let canvas = CGSize(width: 420, height: 643)",
             "    static let rect: [String: CGRect] = ["]
    lines += [f'        "{n}": CGRect(x: {r[0]}, y: {r[1]}, width: {r[2]}, height: {r[3]}),' for n, r in rects.items()]
    lines += ["    ]", "    static let aspect: [String: CGFloat] = ["]
    lines += [f'        "{n}": {a},' for n, a in aspects.items()]
    lines += ["    ]", "}", ""]
    open(os.path.join(APP, "Model", "RigArt.swift"), "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    total = sum(os.path.getsize(os.path.join(ASSETS, n + ".imageset", n + ".png")) for n in PARTS + list(FX))
    print(len(rects), "parts,", len(aspects), "burst pieces,", total // 1024, "KB")


if __name__ == "__main__":
    main()
