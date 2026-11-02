"""A contact sheet for checking rig parts against the master: each part alone, each over the faded master, then the parts
stacked in order beside the master. Writes the sheet to the path given first; the rest are parts, back to front.

From tools/art: ../sfx/.venv/Scripts/python -I rig_stack_check.py out/stack.png arm-l torso head
"""
import sys
from PIL import Image

out, names = sys.argv[1], sys.argv[2:]


def cut(name):
    im = Image.open(f"out/raw/rm-{name}.png").convert("RGB").resize((1024, 1024), Image.LANCZOS).convert("RGBA")
    px = im.load()
    for y in range(1024):
        for x in range(1024):
            r, g, b, _ = px[x, y]
            if r > 180 and g < 90 and b > 180:
                px[x, y] = (r, g, b, 0)
    print(name, "bbox", im.getchannel("A").getbbox())
    return im


parts = [cut(n) for n in names]
master = Image.open("out/raw/rm-master.png").convert("RGB")
sheet = Image.new("RGB", (400 * (len(parts) + 1), 800), (255, 255, 255))
for i, part in enumerate(parts):
    alone = Image.new("RGB", (1024, 1024), (235, 235, 235))
    alone.paste(part, (0, 0), part)
    sheet.paste(alone.resize((400, 400)), (i * 400, 0))
    over = Image.blend(master, Image.new("RGB", (1024, 1024), (255, 255, 255)), 0.55)
    faded = part.copy()
    faded.putalpha(faded.getchannel("A").point(lambda v: v * 3 // 4))
    over.paste(faded, (0, 0), faded)
    sheet.paste(over.resize((400, 400)), (i * 400, 400))
stack = Image.new("RGB", (1024, 1024), (235, 235, 235))
for part in parts:
    stack.paste(part, (0, 0), part)
sheet.paste(stack.resize((400, 400)), (len(parts) * 400, 0))
sheet.paste(master.resize((400, 400)), (len(parts) * 400, 400))
sheet.save(out)
