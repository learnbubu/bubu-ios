# Mounts, cleaned up: solid flat colour, no stripes

**Jobs:** the 3 jobs in `tools/art/jobs.json` with `"group": "mounts3"`. Make **only** those.

Each job is an EDIT of the mount you redrew last time (`mounts2`), the first image in `refs`. The other refs are two
of the app's flowering branches, for the finish to match.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`, the mount first;
   - keep the canvas the same size (1122x1402).
3. Save it as PNG at `file`.
4. Zoom in on it, and make it once more if any of these is wrong:
   - inside any shape there are still faint stripes, streaks, banding, grain, mottling or soft gradients: every
     area must be one solid flat colour, with shading as separate flat shapes with sharp edges;
   - any edge is soft or blurred;
   - the mount has moved, changed size, changed its outline or changed its colours;
   - the ring (bracket, dragon) or the tied cord and its knot (roof) is missing or has moved;
   - the backdrop isn't flat solid magenta.

Report progress after each image.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow, numpy and scipy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner the three are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.

## Why

The redrawn mounts still have faint stripes and grain inside their colours. Smoothing them out afterwards left them
looking blurry (the owner: "still feels blurry, think we need to ask codex to remove those stripes"), so the
picture itself has to be clean: solid flat fills and sharp edges, like the branches.
