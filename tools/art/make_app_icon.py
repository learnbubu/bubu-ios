"""The app icon from the owner's picture (refs/app-icon-source.png, 31 Oct 2026). The picture is a rounded square on a
white margin; iOS wants a full, opaque square and rounds it itself. So the margin and corners are filled with the
nearest colour inside (black ear, black paw, cream), then it's cropped and sized to 1024."""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "refs", "app-icon-source.png")
OUT = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets", "AppIcon.appiconset", "icon.png")
CROP = 22         # past the white margin and its soft edge, each side


def main():
    a = np.asarray(Image.open(SRC).convert("RGB"))
    white = a.min(axis=2) >= 251
    lab, _ = ndimage.label(white)
    edge = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
    edge.discard(0)
    outside = ndimage.binary_dilation(np.isin(lab, list(edge)), iterations=12)   # and its soft edge
    idx = ndimage.distance_transform_edt(outside, return_distances=False, return_indices=True)
    filled = a[idx[0], idx[1]]
    im = Image.fromarray(filled).crop((CROP, CROP, a.shape[1] - CROP, a.shape[0] - CROP))
    im.resize((1024, 1024), Image.LANCZOS).save(OUT, optimize=True)


if __name__ == "__main__":
    main()
