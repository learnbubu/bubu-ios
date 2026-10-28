# Path art, batch 4: hanging pieces that aren't branches

**Jobs:** the 12 jobs in `tools/art/jobs.json` with `"group": "path4"`. Make **only** those.

Each job gives:
- `file`: where to save the image, relative to `tools/art`;
- `size`: the canvas size;
- `refs`: existing app images to attach as style references;
- `prompt`: the full prompt, to use word for word.

## For each `path4` job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs` as a style reference;
   - use the `size` given (or the closest available).
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong:
   - the backdrop isn't flat solid magenta;
   - there's text in it;
   - it hangs from a branch, or has leaves or plants;
   - it's small in its corner;
   - it has more than five of anything.

Report progress every 10 images.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner the new pictures are in the path editor's Art Review, under **New**.
- Don't add anything to the app, and don't commit the images.

## Why

The owner, on batch 3: "its just branches only.... for the hanging pieces. need more variation of stuff".

These hang the way the Chinese knot does: from a cord on a carved wooden bracket, or from the upturned corner of a
roof's eave, coming in from the top left.

The pieces: eave with a bell, brass gong, steamer stack, brush rack, straw hat, birdhouse, flag bunting, rabbit
lantern, butterfly kite, fishing basket, lucky coins, teapot on a hook.
