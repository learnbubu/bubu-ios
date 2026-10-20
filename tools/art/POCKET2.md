# The lucky pocket opening, with Codex

The app is getting a full-screen pocket opening, as good as Duolingo's chest:
- the pocket floats and shakes;
- the panda seal pops off and the flap swings open;
- light and coins pour out of the real opening;
- the prize fills the screen.

For that the app needs each pocket **in parts that stack back into the whole pocket**, plus a few pieces for the prize
screen. That's **17 images**, all in the group `"pocket2"` in `tools/art/jobs.json`, saved as `out/raw/pk2-*.png`.
Leave the older group `"pocket"` (`pk-*`) alone: it's kept and reused.

## The parts (12): red, jade and gold, four each

Each part is an **edit of the whole pocket**, the first reference (`refs/ref-pk2-<colour>.png`):
- `-body`: the front without the flap and seal, showing the open top with the dark inside.
- `-flap`: only the top flap, in place, without the seal.
- `-flap-inside`: the flap's underside, folded up and standing above the top edge.
- `-seal`: only the round panda clasp, in place.

**They must line up.** The pocket stays the same size, in the same place, on the same 1024 square as the reference, so
that body + flap + seal laid on top of each other make the reference again.

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
   - a part includes something it should leave out: the flap on the body, the seal on the flap, the body behind the
     flap's inside;
   - the character on a pocket isn't copied exactly (福 on red and gold, 吉 on jade);
   - it's more detailed or glossier than the references;
   - there's any other text, letter or number;
   - the backdrop isn't one flat solid magenta.

First make the four red parts, then **stop and report**, so the owner can check them before jade and gold. Then report
after each colour, and after the five prize pieces.

## When all 17 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
  It cuts out the magenta and writes `out/review.html`.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.
