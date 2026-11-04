"""How close the waving arm's held pose is to the owner's sketch (out/puppet/_sketch.json): a frame from Studio (its PNG path) with
the sketch's outline laid over it, and how much of the sketched arm the drawn arm covers, and how much it spills past it.

From tools/art: ../sfx/.venv/Scripts/python -I sketch_match.py <frame png at document size> <out png>
"""
import json
import sys
import cv2
import numpy as np
from PIL import Image, ImageDraw

frame = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
k = frame.shape[1] / 1254
sk = np.array(json.load(open("out/puppet/_sketch.json"))) * k
dark = (np.abs(frame - [57, 58, 54]).sum(-1) < 70) | (np.abs(frame - [146, 145, 140]).sum(-1) < 60)
want = np.zeros(dark.shape, np.uint8)
cv2.fillPoly(want, [sk.round().astype(np.int32)], 1)
# (only the part of the sketch past the body: right of the strap and above the arm's rest, where the raised arm alone is dark)
zone = np.zeros(dark.shape, np.uint8)
zone[: int(700 * k), int(870 * k):] = 1
got = dark & (zone > 0)
w = want.astype(bool) & (zone > 0)
print(f"sketch covered {100 * (got & w).sum() / w.sum():.0f}%, arm past the sketch {100 * (got & ~w).sum() / w.sum():.0f}% of it")
img = Image.fromarray(frame.astype(np.uint8))
ImageDraw.Draw(img).line([tuple(p) for p in sk] + [tuple(sk[0])], fill=(0, 170, 220), width=3)
img.save(sys.argv[2])
