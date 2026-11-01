"""The Brain gains moment's books were a 143 x 174 picture, drawn about 3x too big on a phone (the owner: "books need
upresing"). This swaps in the same books at 4x, from the raw picture, in moments-player.html. The player sizes a layer
by its w and h, so nothing moves. Rerun after a bake (bubu-studio/tools/bake-moments.ts writes the page afresh).

    python fix_brain_books.py
"""
import base64
import io
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process

PAGE = os.path.join(HERE, "..", "..", "native", "Bubu", "Resources", "Moments", "moments-player.html")
RAW = os.path.join(HERE, "out", "raw", "mo-brain-books.png")
FIND = re.compile(r'("name": "books", "x": 467, "y": -8, "w": 201, "h": 244, "src": ")(data:image/[a-z]+;base64,)([A-Za-z0-9+/=]+)')


def main():
    s = open(PAGE, encoding="utf8", newline="").read()
    m = FIND.search(s)
    old = Image.open(io.BytesIO(base64.b64decode(m.group(3)))).convert("RGBA")
    new = process.key_full(Image.open(RAW).convert("RGBA"))
    new = new.crop(new.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox())
    # the old picture's margin kept, so the books sit where they did
    ob = old.getchannel("A").point(lambda v: 255 if v > 30 else 0).getbbox()
    k = 4
    canvas = Image.new("RGBA", (old.width * k, old.height * k), (0, 0, 0, 0))
    fit = new.resize(((ob[2] - ob[0]) * k, (ob[3] - ob[1]) * k), Image.LANCZOS)
    canvas.paste(fit, (ob[0] * k, ob[1] * k))
    b = io.BytesIO()
    canvas.save(b, "PNG", optimize=True)
    s = s[:m.start(2)] + "data:image/png;base64," + base64.b64encode(b.getvalue()).decode() + s[m.end(3):]
    open(PAGE, "w", encoding="utf8", newline="").write(s)
    print(old.size, ob, "->", canvas.size, "aspect", round(new.width / new.height, 3), "was", round((ob[2] - ob[0]) / (ob[3] - ob[1]), 3), len(b.getvalue()) // 1024, "KB")
    sheet = Image.new("RGBA", (old.width * k * 2 + 20, old.height * k), (247, 244, 238, 255))
    sheet.alpha_composite(old.resize(canvas.size, Image.BICUBIC), (0, 0))
    sheet.alpha_composite(canvas, (canvas.width + 20, 0))
    sheet.convert("RGB").save(sys.argv[1]) if len(sys.argv) > 1 else None


if __name__ == "__main__":
    main()
