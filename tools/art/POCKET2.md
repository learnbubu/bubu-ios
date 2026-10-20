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
- `-body`: the front without the flap and seal. A hongbao is flat, so the open top is only a **thin slit**, never a
  deep dark hollow.
- `-flap`: only the top flap, in place, without the seal.
- `-seal`: only the round panda clasp, in place.

The flap's underside isn't drawn: `flap_inside.py` makes it from the flap.

**They must line up.** The pocket stays the same size, in the same place, on the same 1024 square as the reference, so
that body + flap + seal laid on top of each other make the reference again. The red ones are done and line up: keep
them.

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
   - a part includes something it should leave out: the flap on the body, or the seal on the flap;
   - a body has a deep dark hollow at the top instead of a thin slit;
   - the character on a pocket isn't copied exactly (福 on red and gold, 吉 on jade);
   - it's more detailed or glossier than the references;
   - there's any other text, letter or number;
   - the backdrop isn't one flat solid magenta.

The red parts are done. Make the jade three, then **stop and report**. Then the gold three, then the five prize pieces,
reporting after each.

## When all 14 are made

- Run `python flap_inside.py red jade gold`, then `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
  It cuts out the magenta and writes `out/review.html`.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.
