# Top-bar icons: lantern, coin, bun

**Jobs:** the 4 jobs in `tools/art/jobs.json` with `"group": "hudicons"`. Make **only** those.

Make them in this order: `hud-lantern-lit` first, then `hud-lantern-unlit`, which is drawn from the lit one, then
`hud-coin` and `hud-bun`.

## For each job

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs` as a reference;
   - use `size` 1024x1024.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong:
   - the backdrop isn't flat solid magenta;
   - there's text or marks on it;
   - the lantern has any cord, hook, tassel or fringe;
   - the icon is small in the canvas, or has thin bits sticking out;
   - the unlit lantern isn't the same shape as the lit one.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.

## Why

The owner chose the "open strip" top bar on 28 Oct 2026: bold icons and numbers with no box, like Duolingo's. They
asked for all three icons redrawn, and for the lantern to have nothing hanging below it. At 22 pt, the old lantern's
cord and tassel made it tall and thin. These are drawn as icons first: one chunky shape that reads at a glance beside
its number.
