# Generating Bùbù's art with Codex

**Job list:** `tools/art/jobs.json` has 63 jobs. Each one gives:
- `file`: where to save the image, relative to `tools/art`;
- `size`: the canvas size;
- `refs`: 3–4 existing app images (already on magenta) to attach as style references;
- `prompt`: the full prompt, to use word for word.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly;
   - attach every image in `refs` as a style reference;
   - use the `size` given (or the closest available).
3. Save it as PNG at `file`.
4. Look at it. If the backdrop isn't a flat solid magenta, there's text in it, or (for the picture
   sheets) the grid isn't the listed icons in order, make it once more.

Do the jobs in this order: **pandas, corners, hangers, scenes, then sheets**. Report progress
every 10 images.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python`
  has them. It cuts out the backdrops, mirrors the corners, slices the picture sheets into
  `out/final/pictures/<word>.png`, and writes `out/review.html`.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.
