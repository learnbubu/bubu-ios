# Path art, batch 4: hook pieces, and two brass rings

**Jobs:** the 17 jobs in `tools/art/jobs.json` with `"group": "rings"` or `"group": "path4"`. Make **only** those.

Each job gives:
- `file`: where to save the image, relative to `tools/art`;
- `size`: the canvas size;
- `refs`: images to attach;
- `prompt`: the full prompt, to use word for word.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`;
   - use the `size` given (or the closest available).
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong.

   For the 3 `rings` jobs (edits of a mount):
   - a ring job: the red loop is still there, or there's no brass ring;
   - the eave tie (`mount-roof-eave-tie`): there's still a ring or the old loop, the cord isn't tied round the upturned tip, or its end doesn't hang straight down in open air;
   - the mount has moved, changed size or changed shape;
   - anything hangs from the ring.

   For the 14 `path4` jobs (one object on a cord):
   - the backdrop isn't flat solid magenta;
   - there's a hook, bracket, ring, pole or branch above the object (only the cord may reach the top);
   - the cord doesn't reach the top edge, or isn't near the middle;
   - there's text in it;
   - it has more than five of anything.

Report progress every 5 images.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow, numpy and scipy; `../sfx/.venv/Scripts/python` has them.
  It keys the pictures, refreshes the mount masters, and hangs each object from its master.
- Tell the owner the new pieces are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.

## Why

The owner picked nine mounts as masters, so every bracket matches every time. Codex now draws only the object;
`hang.py` hangs it from the master's ring. The roof eave and bamboo pole masters ended in a red loop; the owner asked
for brass rings like the rest. On the eave the ring looked fake, so it gets a cord tied round its tip instead.
