# Mounts, redrawn: the roof eave, the wood bracket and the dragon, in the branches' style

**Jobs:** the 3 jobs in `tools/art/jobs.json` with `"group": "mounts2"`. Make **only** those.

Each job is an EDIT of the mount we already use, the first image in `refs`. The other refs are two of the app's
flowering branches, attached as the style to match.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`, the mount first;
   - keep the canvas the same size as the mount picture (1122x1402).
3. Save it as PNG at `file`.
4. Look at it next to the mount picture and the branches, and make it once more if any of these is wrong:
   - the backdrop isn't flat solid magenta;
   - the mount has moved, changed size or changed its outline;
   - the ring (bracket, dragon) or the tied cord and its knot (roof) is missing or has moved;
   - anything hangs from it;
   - it still looks painted: texture, grain, blotches, brush strokes or soft edges, instead of the branches' crisp
     flat shapes with a few clean tones.

Report progress after each image.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow, numpy and scipy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner the three are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.

## Why

The mounts were painted with a soft, blotchy texture that doesn't match the branches beside them on the path (the
owner: "feels too soft and doesn't match the tree"). Cleaning them up afterwards (smoothing, tracing) either left
them soft or lost their detail, so they're redrawn in the branches' style. They keep their exact shape and place, so
the tie points and every size already set for the hanging pieces still fit.
