# The lucky pocket opening, with Codex

The app is getting a full-screen pocket opening, as good as Duolingo's chest:
- the pocket floats and shakes;
- the panda seal pops off and the flap swings open;
- light and coins pour out of the real opening;
- the prize fills the screen.

For that the app needs each pocket **in parts that stack back into the whole pocket**, plus a few pieces for the prize
screen. That's **14 images**, all in the group `"pocket2"` in `tools/art/jobs.json`, saved as `out/raw/pk2-*.png`.
Leave the older group `"pocket"` (`pk-*`) alone: it's kept and reused.

## The parts (9): red, jade and gold, three each

Each part is an **edit of the whole pocket**, the first reference (`refs/ref-pk2-<colour>.png`):
- `-open`: the whole pocket opened, made from its own shapes: its flap (the second reference) folded straight up,
  mirrored, joined to the sides with no gap, showing its plain darker underside; below the fold only a shallow sliver
  of back panel, and the front's top edge a gentle curve with the same gold trim. One soft storybook piece of paper,
  never a deep dark hollow and never flat clip-art. `split_open.py` cuts it into the body and the flap's underside.
- `-flap`: only the top flap, closed, in place, without the seal. Made **before** `-open`: once it's saved, copy it to
  `refs/ref-pk2-<colour>-flap.png`, the open picture's second reference.
- `-seal`: only the round panda clasp, in place.

**They must line up.** The pocket stays the same size, in the same place, on the same 1024 square as the reference, so
that the parts laid on top of each other make the reference again. The red flap and seal are done and line up: keep
them. The red open pocket is still to make.

## The prize pieces (5)

- `coin-pile`: a heap of coins with an ingot on top.
- `xp-jade`: a jade charm, for an XP prize.
- `blossom`: a plum blossom.
- `sparkle`: a four-point star.
- `month-bubu`: Bùbù hugging the gold pocket, for a round medal.

## For each job in the group "pocket2", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - size 1024x1024.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is true:
   - a part doesn't line up with its reference: lay it over the reference and check that the outline, size and position
     match;
   - a part includes something it should leave out: the seal on the flap or on the open pocket;
   - the open pocket has a deep dark hollow at the top instead of a thin slit, or anything coming out of it;
   - the open pocket's body has moved or changed size: only the flap may go up above it;
   - the character on a pocket isn't copied exactly (福 on red and gold, 吉 on jade);
   - it's more detailed or glossier than the references;
   - there's any other text, letter or number;
   - the backdrop isn't one flat solid magenta.

Make the red open pocket first (its flap is already in `refs`), then **stop and report**. Then the jade three (stop and report), the gold three, and the
five prize pieces, reporting after each.

## When all 14 are made

- Run `python split_open.py red jade gold`, then `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
  It cuts out the magenta and writes `out/review.html`.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.
