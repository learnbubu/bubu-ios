# Path art, batch 3: more Bùbù poses and hanging pieces

**Jobs:** the 31 jobs in `tools/art/jobs.json` with `"group": "path3"` (18 Bùbù poses, 13 hanging pieces).
Make **only** those; other jobs in the file without an image are not part of this batch.

Each job gives:
- `file`: where to save the image, relative to `tools/art`;
- `size`: the canvas size;
- `refs`: existing app images to attach as style references;
- `prompt`: the full prompt, to use word for word.

## For each `path3` job, in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly;
   - attach every image in `refs` as a style reference;
   - use the `size` given (or the closest available).
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong:
   - the backdrop isn't a flat solid magenta;
   - there's text, a sign, a bubble or a symbol in it;
   - Bùbù has more than one prop or scenery around him;
   - a hanging piece is small in its corner, or has more than five of anything.

Report progress every 10 images.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.

## Why these (from the owner's art review, 28 Oct 2026)

**Kept:** one clear, real thing, big and simple. For Bùbù, one action you can read from his outline, with at
most one prop that belongs to it.

**Crossed off:**
- Abstract or busy hanging pieces: cloud swirls, the edge waterfall, chillies and garlic, the ink scroll.
- Too many of one thing (firecrackers), and too small (the ivy pot).
- A Bùbù whose sign or speech bubble was empty, whose "?" you couldn't make out, or whose prop made no sense (the
  meditation leaf, the hongbao).
- The embers, the cluttered moon, the plain idle and the two peeks.

The firecrackers and the ginkgo, which nearly worked, come back redone. So do speaking and puzzled, as "Explaining"
and "Head scratch", without the bubble and the "?".

| Bùbù | Hanging |
|---|---|
| Carrying bamboo · Munching bamboo · Watering · Book stack · Drum · Fan · Tai chi · Mooncake · Shuttlecock · Ribbon dance · Umbrella · Big stretch · Camera · Pointing the way · Ping pong · Polite bow · Explaining · Head scratch | Peach branch · Pomegranate branch · Kumquat branch · Magnolia branch · Camellia branch · Grape vine · Songbird on a branch · Paper cranes · Paper-cut flower · Swallow kite · Flower basket · Short firecracker string · Golden ginkgo branch |
