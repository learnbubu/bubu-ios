"""Speaking's chat photos (the owner, 23 Oct 2026: "lets make the wechat"): each of the cast's approved drawings
(out/raw/cast-<name>.png, magenta backdrop) cut out and cropped to head and shoulders, on a soft colour of their own,
square, as WeChat's profile photos; into the app's asset catalogue as chat-<name>. The app rounds them.

    python make_chat_photos.py
"""
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import add_sparkle  # noqa: E402
import check_head  # noqa: E402
import process  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")
SIZE = 330

# each one's photo ground, picked from what they wear
CAST = {
    "xiaoyu": 0xFBEBC2,     # her mustard cardigan, softened
    "chenming": 0xF9D9CF,   # his red towel
    "chenmama": 0xF6D6D9,   # her red apron, pinker
    "chenbaba": 0xE3DCCB,   # his brown waistcoat, light
    "duoduo": 0xD6E6F5,     # her denim dungarees
}


def process_backdrop(a):
    return (a[..., 0] > 200) & (a[..., 2] > 200) & (a[..., 1] < 80)


def photo(name, ground):
    src = Image.open(os.path.join(HERE, "out", "raw", f"cast-{name}.png")).convert("RGB")
    a = np.array(src).astype(int)
    top, bottom, chin, head = check_head.measure(a)
    # centred and sized by the eyes (nothing else is mistaken for them: by the ears, a hand waved at ear height pulled
    # 朵朵's photo off centre): the head's middle between them, its size from how far apart they are (2.72 x their
    # distance is the face's width, ear to ear, on the others)
    eyes = add_sparkle.find_eyes(a)
    ex = [(b[0] + b[2]) / 2 for b in eyes]
    cx, width = sum(ex) / 2, (ex[1] - ex[0]) * 2.72
    # every head the same size (the face's width sets the scale) and the head in the middle (the owner: "make sure
    # the head is the centred bit", "all same sizes"): the head is everything above the chin over the face, hair
    # included, whatever its colour
    side = width * 1.6
    fig = ~process_backdrop(a)
    band = fig[:chin, max(0, round(cx - width * 0.75)):round(cx + width * 0.75)]
    hair_top = int(np.nonzero(band.any(1))[0].min())
    cy = (hair_top + chin) / 2
    box = (round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))
    cut = process.key_full(src)
    tile = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), tuple(ground.to_bytes(3, "big")) + (255,))
    tile.alpha_composite(cut.crop(box))
    tile = tile.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    d = os.path.join(ASSETS, f"chat-{name}.imageset")
    os.makedirs(d, exist_ok=True)
    tile.save(os.path.join(d, f"chat-{name}.png"), optimize=True)
    json.dump({"info": {"author": "xcode", "version": 1}, "images": [{"idiom": "universal", "filename": f"chat-{name}.png"}]},
              open(os.path.join(d, "Contents.json"), "w"), indent=2)
    return tile


if __name__ == "__main__":
    tiles = [photo(n, g) for n, g in CAST.items()]
    sheet = Image.new("RGB", (len(tiles) * (SIZE + 20) + 20, SIZE + 40), (248, 244, 236))
    for i, t in enumerate(tiles):
        m = Image.new("L", t.size, 0)
        from PIL import ImageDraw
        ImageDraw.Draw(m).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
        sheet.paste(t, (20 + i * (SIZE + 20), 20), m)
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "out", "chat-photos.png")
    sheet.save(out)
    print("ok", out)
