# Profile page art: eight icons and two Bùbù fixes

**Jobs:** the 10 jobs in `tools/art/jobs.json` with `"group": "profileart"`. Make **only** those.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`, in order;
   - use `size` 1024x1024.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong.

Icons (`stat-*`):
- any gradient, texture or soft shading; it should sit beside the top bar's coin and lantern as one set;
- any text, character or marks on it;
- small in the canvas, or with thin parts that would vanish at 22 points;
- the backdrop isn't flat solid magenta.

Bùbùs (`achv4-*`):
- Flawless: his arms are still long or thin, or the paws have pads;
- Night Owl: the cap isn't on top of his head with both ears in front of it, or there's a moon;
- anything else about him has changed, or anything is drawn behind him.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner they are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.
