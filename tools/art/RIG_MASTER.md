# Bùbù's master rig, with Codex

We're cutting Bùbù the panda into every part an animator needs, so new moments can be posed instead of drawn from scratch. All the images are in the group `"rigm"` in `tools/art/jobs.json`, saved as `out/raw/rm-*.png`.

## First: only the master

1. Make only `out/raw/rm-master.png`. Use `prompt` exactly, word for word, attach every image in `refs` in order, and use the job's `size`. Save it as PNG at `file`.
2. Look at it. Make it once more if any of these is true:
   - he has more or fewer than two round black ears, or his proportions or face differ from the references;
   - any limb overlaps his body or another limb;
   - his feet, ears or paws are cut off by the frame;
   - it's more detailed, textured or realistic than the references;
   - there's any shadow, ground, text or frame;
   - the backdrop isn't one flat solid magenta.
3. **Stop and report.** Don't make any parts until the master is approved, because every part is drawn over it.

## Then: the parts, once told to go on

For each other job in the group, in order:

1. If `file` already exists, skip it.
2. Generate one image the same way: exact `prompt`, every image in `refs` in order, the job's `size`. Save it as PNG at `file`.
3. Look at it, and make it once more if any of these is true:
   - it isn't at the same size and place as on the master;
   - anything is there besides the piece described, such as a second part, his body, or a shadow;
   - a blank head has any face on it;
   - the joint end is cut flat rather than a soft rounded end;
   - the backdrop isn't one flat solid magenta.

Make `torso`, `head` and `arm-l` first, then **stop and report**, so the stacking can be checked before the rest. Then make the others and report.

## When all are made

- Don't run anything else, don't add anything to the app, and don't commit the images.
