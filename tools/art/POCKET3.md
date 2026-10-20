# The hongbao's prize landing, with Codex

When a hongbao opens, the prize drops in and lands:
- a small amount of money lands lightly;
- a big amount slams down and cracks the floor a little.

The app builds that in Studio from **5 images**. They're all in the group `"pocket3"` in `tools/art/jobs.json`, saved as
`out/raw/pk3-*.png`:
- `pile-small`: a short stack of coins;
- `pile-big`: a big heap with two gold ingots;
- `crack`: the crack the big one leaves;
- `chips`: broken floor chips that fly up;
- `dust`: a puff of dust.

## For each job in the group "pocket3", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is true:
   - the coins aren't the app's coin (round and gold, with a square hole);
   - it's more detailed or glossier than the coin;
   - a pile has a floor or shadow drawn under it;
   - the crack has a floor colour around it;
   - there's any text, letter or number;
   - the backdrop isn't one flat solid magenta.

Make the two piles first, then **stop and report**. Then make the other three and report.

## When all 5 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
