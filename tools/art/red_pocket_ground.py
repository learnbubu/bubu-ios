# The red hongbao's prize ground: a lighter red, not the dark one (the owner, 2 Nov 2026), as the lucky pocket's.
# From tools/art: ../sfx/.venv/Scripts/python -I red_pocket_ground.py
import numpy as np
from PIL import Image

P = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu/art/hongbao-bg-dark/hb-dark-sweep.png"
LIGHT = np.array([217, 83, 74], np.float32) / 255
a = np.asarray(Image.open(P).convert("RGBA")).astype(np.float32) / 255
v = a[..., :3].max(-1)
shade = v / max(float(np.percentile(v[a[..., 3] > 0.5], 95)), 1e-3)
rgb = LIGHT[None, None] * np.clip(0.9 + 0.1 * shade, 0, 1.1)[..., None]
Image.fromarray((np.clip(np.dstack([rgb, a[..., 3]]), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(P)
