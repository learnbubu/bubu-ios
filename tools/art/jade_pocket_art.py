# The lucky pocket's pictures: the red hongbao's own, repainted. Only the reds go green, so the gold stays gold.
# Writes jade-*.png into Studio's art folder. From tools/art: ../sfx/.venv/Scripts/python -I jade_pocket_art.py
import glob, os, shutil
import numpy as np
from PIL import Image

ART = r"C:\Users\domch\Documents\Projects\bubu-studio\projects\bubu\art"
JADE_HUE = 142 / 360


def repaint(path, out):
    a = np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a[..., :3].max(-1), a[..., :3].min(-1)
    d = np.maximum(mx - mn, 1e-5)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    s = np.where(mx > 0, d / np.maximum(mx, 1e-5), 0)
    v = mx
    # how red: full up to 18 degrees round red, none by 32, so orange and gold keep their own colour
    dist = np.minimum(h, 1 - h) * 360
    t = np.clip((32 - dist) / 14, 0, 1)
    nh = h * (1 - t) + JADE_HUE * t
    nv = v * (1 - t * 0.28)              # green reads brighter than red at the same value
    i = np.floor(nh * 6) % 6
    f = nh * 6 - np.floor(nh * 6)
    p, q, u = nv * (1 - s), nv * (1 - f * s), nv * (1 - (1 - f) * s)
    out_rgb = np.zeros(a.shape[:2] + (3,), np.float32)
    table = [(nv, u, p), (q, nv, p), (p, nv, u), (p, q, nv), (u, p, nv), (nv, p, q)]
    for k, (cr, cg, cb) in enumerate(table):
        m = i == k
        out_rgb[..., 0][m], out_rgb[..., 1][m], out_rgb[..., 2][m] = cr[m], cg[m], cb[m]
    res = np.dstack([out_rgb, a[..., 3]])
    Image.fromarray((np.clip(res, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(out)


DOCS = {"pocket-parts": "jade-pocket-parts", "pocket-open": "jade-pocket-open", "pocket-away": "jade-pocket-away",
        "hongbao-bg": "jade-bg", "hongbao-bg-dark": "jade-bg-dark", "prize-small": "jade-prize", "coin-rain": "jade-rain"}
RENAME = {"pk2-red-body": "jade-body", "pk2-red-flap": "jade-flap", "pk2-red-flap-inside": "jade-flap-inside", "pk2-red-front": "jade-front",
          "pk2-red-seal": "jade-seal", "hb-red": "jade-ground", "hb-pattern": "jade-pattern", "hb-vignette": "jade-vignette",
          "hb-dark-sweep": "jade-dark-sweep", "pk2-beam": "jade-beam", "pk2-rays": "jade-rays"}
BOLT = "C:/Users/domch/Documents/Projects/bubu-ios/tools/art/out/final/stat-xp-bolt.png"

for src, to in DOCS.items():
    out = os.path.join(ART, to)
    os.makedirs(out, exist_ok=True)
    for f in glob.glob(os.path.join(ART, src, "*.png")):
        n = os.path.splitext(os.path.basename(f))[0]
        if n in RENAME:
            repaint(f, os.path.join(out, RENAME[n] + ".png"))
    # the XP bolt, the icon the app already uses, for the prize and the falling ones
    shutil.copy(BOLT, os.path.join(out, "jade-bolt.png"))
    print(to, sorted(os.listdir(out)))

# the prize's ground: a lighter green, not the red's dark one (the owner, 2 Nov 2026). Its shading kept, in that colour.
LIGHT = np.array([62, 168, 100], np.float32) / 255
p = os.path.join(ART, "jade-bg-dark", "jade-dark-sweep.png")
a = np.asarray(Image.open(p).convert("RGBA")).astype(np.float32) / 255
v = a[..., :3].max(-1)
shade = v / max(float(np.percentile(v[a[..., 3] > 0.5], 95)), 1e-3)
rgb = LIGHT[None, None] * np.clip(0.9 + 0.1 * shade, 0, 1.1)[..., None]
Image.fromarray((np.clip(np.dstack([rgb, a[..., 3]]), 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(p)
