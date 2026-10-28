# Top-bar icons, flat 2D: lantern, coin, bun

**Jobs:** the 4 jobs in `tools/art/jobs.json` with `"group": "hudflat"`. Make **only** those.

Make them in this order: `hud-flat-lantern-lit` first, then `hud-flat-lantern-unlit`, which is drawn from the lit one, then
`hud-flat-coin` and `hud-flat-bun`.

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

The owner liked the shapes of Codex's painted icons (`hudicons`), but wants the top bar flat 2D like Duolingo's:
solid colours, a hard-edged darker shape for the shadow, one highlight, no gradients or texture. Each job attaches the
painted icon for its shape and a rough hand-drawn flat sketch (`refs/ref-hud-flat-sketch.png`) for the look. Make
them crisper and better made than the sketch, but no fancier.

Also look for, and remake once if wrong:
- any gradient, texture or soft airbrushed shading;
- the coin's square hole not showing the magenta through it.
