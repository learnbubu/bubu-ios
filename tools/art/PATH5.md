# Path art, batch 5: hook pieces that are real hanging decorations

**Jobs:** the 13 jobs in `tools/art/jobs.json` with `"group": "path5"`. Make **only** those.

Each job gives:
- `file`: where to save the image, relative to `tools/art`;
- `size`: the canvas size;
- `refs`: images to attach as style references;
- `prompt`: the full prompt, to use word for word.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`;
   - use the `size` given (or the closest available).
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong:
   - the backdrop isn't flat solid magenta;
   - there's a hook, bracket, ring, pole or branch above the object (only the cord may reach the top);
   - the cord doesn't reach the top edge, or isn't near the middle;
   - there's text in it, including characters on a tag (the tags stay blank);
   - it has more than five of anything;
   - it's busy: lots of fine detail instead of a few big simple shapes.

Report progress every 5 images.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow, numpy and scipy; `../sfx/.venv/Scripts/python` has them.
  It keys the pictures and hangs each object from its master.
- Tell the owner the new pieces are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.

## Why

People told the owner some batch 4 pieces didn't feel culturally appropriate: everyday props strung up because they
read as "Chinese things" (a straw hat, gong, abacus, teapot...). Those are cut. Everything in this batch is something
people really hang: wind bells, a palace lantern, jade pendants, embroidered charms, seasonal blessing pendants and a
sachet, drawn simply in the app's style.
