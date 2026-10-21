# The hongbao's prize landing, with Codex

When a hongbao opens, the prize drops in and lands:
- after a lesson, a small stack of coins lands lightly;
- for a milestone, a big heap lands on **lucky clouds (祥云)**. A ring of curly gold clouds bursts out from under it and
  settles as a cloud bed it rests on, as if the money came down from the heavens.

The two piles are done: `pk3-pile-small` and `pk3-pile-big`. Codex's other heap, the tall one with three ingots, is
`pk3-pile-big-2`, also done. **Don't make those again.**

Still to make are **4 cloud images**, all in the group `"pocket3"` in `tools/art/jobs.json`, saved as `out/raw/pk3-*.png`:
- `cloud-bed`: a low, wide bank of cloud lobes for the heap to sit on;
- `cloud-puff`: one round cloud with a single curl;
- `cloud-puff-2`: a double-curl cloud, two lobes;
- `cloud-wisp`: a thin ribbon of cloud ending in a tight curl.

They all match the curly swirls on the corners of the red envelope, the first reference: soft cream-gold with a warmer
gold underside and a thin gold line on the curls. They'll be shown on a dark red background.

## For each job in the group "pocket3", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is true:
   - the curls don't look like the envelope's corner swirls (a round lobe ending in a spiral);
   - it's white or grey rather than soft cream-gold;
   - it's more detailed, textured or glossy than the envelope;
   - the cloud bed isn't flat across its top, or isn't wide and low;
   - there's anything else in it: coins, the envelope, a sky, a frame;
   - there's any text, letter or number;
   - the backdrop isn't one flat solid magenta.

Make `cloud-bed` first, then **stop and report**. Then make the other three and report.

## When all 4 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
