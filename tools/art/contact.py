"""Review strips: out/final images at one height on the app's cream, in rows.
    python contact.py out/batch.png "corner-tall-*" "hang-*"   (globs in out/final; -right copies skipped)"""
import glob
import os
import sys

from PIL import Image


def strip(fs, H=300):
    ims = [Image.open(f) for f in fs]
    ims = [i.resize((max(1, int(i.width * H / i.height)), H)) for i in ims]
    s = Image.new("RGB", (sum(i.width for i in ims) + 14 * len(ims), H + 10), (246, 241, 228))
    x = 5
    for i in ims:
        s.paste(i, (x, 5), i)
        x += i.width + 14
    return s


if __name__ == "__main__":
    out, pats = sys.argv[1], sys.argv[2:]
    fs = [f for p in pats for f in sorted(glob.glob(os.path.join("out", "final", p))) if not f.endswith("-right.png")]
    rows = [strip(fs[i:i + 7]) for i in range(0, len(fs), 7)]
    img = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows)), (246, 241, 228))
    y = 0
    for r in rows:
        img.paste(r, (0, y))
        y += r.height
    img.save(out)
    print(len(fs), "images:", ", ".join(os.path.basename(f)[:-4] for f in fs))
