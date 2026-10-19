"""Codex's Bùbùs for the achievement badges (out/raw/achv4-<family>.png, on magenta) into the app: cut out, cropped to
him, 560 pixels tall, as native/Bubu/Resources/Achievements/achv-<family>.png (the badge puts him on the coin).
Run from tools/art after Codex makes more:  python install_achievements.py"""
import os, glob
import numpy as np
from PIL import Image
from process import cutout_array

OUT = os.path.join('..', '..', 'native', 'Bubu', 'Resources', 'Achievements')
os.makedirs(OUT, exist_ok=True)
for f in sorted(glob.glob('out/raw/achv4-*.png')):
    family = os.path.basename(f)[len('achv4-'):-4]
    a = cutout_array(Image.open(f).convert('RGBA'))
    im = Image.fromarray(a) if isinstance(a, np.ndarray) else a
    im = im.crop(im.getchannel('A').getbbox())
    im = im.resize((round(im.width * 560 / im.height), 560), Image.LANCZOS)
    im.save(os.path.join(OUT, f'achv-{family}.png'), optimize=True)
    print(family, im.size)
