"""The layer library for the studio's layer editor (owner, 8 Oct: place and mask the moment layers by hand,
like Photoshop). Every piece drawn for each moment, cropped to its pixels, at its place on the 1024 sticker:
out/rig/edlib.json = {moment: {piece: {src, x, y, w, h}}}."""
import base64
import glob
import io
import json
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RIG = os.path.join(HERE, "out", "rig")
PAD = 128
MOMENTS = ["speedy", "flawless", "kungfu", "sweep", "nightowl", "earlybird", "brain", "onfire", "spare", "classroom"]


def item(path):
    im = Image.open(path).convert("RGBA")
    if im.size != (1024 + 2 * PAD, 1024 + 2 * PAD): return None       # not in the placed frame
    bb = im.getbbox()
    if not bb: return None
    c = im.crop(bb); b = io.BytesIO(); c.save(b, "WEBP", quality=88, method=6)
    return {"src": "data:image/webp;base64," + base64.b64encode(b.getvalue()).decode(),
            "x": bb[0] - PAD, "y": bb[1] - PAD, "w": c.width, "h": c.height}


if __name__ == "__main__":
    out = {}
    for k in MOMENTS:
        lib = {}
        for p in sorted(glob.glob(os.path.join(RIG, f"mo-{k}-*-placed.png")) + glob.glob(os.path.join(RIG, f"m6-{k}-*.png"))):
            n = os.path.basename(p)[:-4].replace("-placed", "").replace(f"mo-{k}-", "").replace(f"m6-{k}-", "rig6 ")
            if n == "bubu": n = "original"
            it = item(p)
            if it: lib[n] = it
        for p in sorted(glob.glob(os.path.join(RIG, "fit", f"m6-{k}-*.png"))):
            it = item(p)
            if it: lib["fitted " + os.path.basename(p)[:-4].replace(f"m6-{k}-", "")] = it
        out[k] = lib
        print(k, list(lib))
    json.dump(out, open(os.path.join(RIG, "edlib.json"), "w"))
    print("size", os.path.getsize(os.path.join(RIG, "edlib.json")) // 1024, "KB")
