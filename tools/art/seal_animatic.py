"""An animatic of the seal storyboards: their panels cut out and held for set times, to judge the timing before animating.

From tools/art: ../sfx/.venv/Scripts/python -I seal_animatic.py    (writes out/rigm/seal-animatic.mp4)
"""
import os
import subprocess
from PIL import Image

# panel edges as parts of a sheet of six, as (left, right) and (top, bottom)
COLS = [(0.052, 0.312), (0.372, 0.630), (0.690, 0.955)]
ROWS = [(0.036, 0.488), (0.530, 0.980)]
OUT = "out/rigm/animatic"
SHEETS = {"m": "rm-board-seal", "a": "rm-board-seal-1-2", "b": "rm-board-seal-2-3"}
# sheet and panel (1 to 6), milliseconds on screen
SHOTS = [("a", 1, 350), ("a", 2, 120), ("a", 3, 120), ("a", 4, 220), ("a", 5, 100), ("a", 6, 220), ("b", 2, 130), ("b", 3, 80), ("b", 4, 80),
         ("b", 5, 80), ("b", 6, 120), ("m", 4, 130), ("m", 5, 350), ("m", 6, 1200)]


def panel(sheet, n):
    im = Image.open(f"out/raw/{SHEETS[sheet]}.png").convert("RGB")
    (l, r), (t, b) = COLS[(n - 1) % 3], ROWS[(n - 1) // 3]
    return im.crop((int(l * im.width), int(t * im.height), int(r * im.width), int(b * im.height))).resize((400, 760), Image.LANCZOS)


os.makedirs(OUT, exist_ok=True)
lines = []
for i, (sheet, n, ms) in enumerate(SHOTS):
    panel(sheet, n).save(f"{OUT}/{i:02}.png")
    lines += [f"file '{i:02}.png'", f"duration {ms / 1000}"]
lines.append(f"file '{len(SHOTS) - 1:02}.png'")
open(f"{OUT}/list.txt", "w").write("\n".join(lines) + "\n")
subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", f"{OUT}/list.txt", "-vf", "fps=60,format=yuv420p", "out/rigm/seal-animatic.mp4"], check=True)
print("ok", sum(s[2] for s in SHOTS), "ms")
