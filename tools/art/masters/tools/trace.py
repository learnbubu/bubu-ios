# A mount traced into smooth flat shapes (the owner: the blotchy texture, then "rough edge clean up"): from its
# smoothed copy (hang.py clean_master), 4x up so the pixel steps are tiny, corners rounded. Needs vtracer (system python).
#   python masters/tools/trace.py masters/clean-roof-eave.png masters/vec-roof-eave.svg 110 6 4
# (corner threshold, speck size, shade step); then render the SVG at 4x and shrink it to the master size as vec-<file>.png
import sys, re
import numpy as np
from PIL import Image
import vtracer
src, out, corner = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGBA")
W, H = im.size
K = 4
big = im.resize((W * K, H * K), Image.LANCZOS)
a = np.asarray(big).copy()
solid = a[..., 3] >= 128
a[..., 3] = np.where(solid, 255, 0); a[~solid, :3] = 0
tmp = out + ".in.png"
Image.fromarray(a).save(tmp)
vtracer.convert_image_to_svg_py(tmp, out, colormode="color", hierarchical="cutout", mode="spline", max_iterations=10,
    filter_speckle=int(sys.argv[4]) * K, color_precision=8, layer_difference=int(sys.argv[5]), corner_threshold=corner,
    length_threshold=4.0 * K / 2, splice_threshold=45, path_precision=2)
s = open(out, encoding="utf-8").read()
s = re.sub(r'<svg ([^>]*?)width="\d+" height="\d+"', lambda m: f'<svg {m.group(1)}width="{W * K}" height="{H * K}" viewBox="0 0 {W * K} {H * K}"', s, count=1)
open(out, "w", encoding="utf-8").write(s)
print(s.count("<path"), "paths")
