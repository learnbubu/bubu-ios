# Mounts: the things hanging pieces hang from

**Jobs:** the 15 jobs in `tools/art/jobs.json` with `"group": "mounts"`. Make **only** those.

- **5 lifted mounts** (carved bracket, red pole, red bracket, roof eave, bamboo pole) are EDITS of an existing
  picture. Attach the image in `refs` and follow the prompt: keep only the mount, exactly as it is and in the same
  place, and remove everything that hangs from it. Keep the canvas the same size as the attached picture.
- **10 new mounts** are drawn fresh from their prompt, with the refs attached as style references.

## For each job, in order

1. If `file` already exists, skip it.
2. Generate one image:
   - use `prompt` exactly;
   - attach every image in `refs`.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is wrong:
   - the backdrop isn't flat solid magenta;
   - anything still hangs from the mount (a cord, an object, a tassel);
   - a lifted mount has moved, changed size or changed shape from the original;
   - a new mount isn't at the top left, or has no clear tie point or ring.

## When all are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy; `../sfx/.venv/Scripts/python` has them.
- Tell the owner the mounts are in the path editor's Art Review, under **New › Mounts**.
- Don't add anything to the app, and don't commit the images.

## Why

The owner wants the things pieces hang from to match every time. Each mount is made once and picked as a master.
From then on, Codex draws only the hanging object on a cord, and processing hangs it from the master mount.
