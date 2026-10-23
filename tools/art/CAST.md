# The cast, with Codex

Speaking becomes chats with the course's people, so they need faces. Mark is the player (the avatar), so these are the
five he talks to, drawn as people in the app's storybook style: the same chunky proportions as the player's avatar
(attached as the first reference), with Bùbù's flat colour and soft shading (the second).

All 6 jobs are in the group `"cast"` in `tools/art/jobs.json`, saved as `out/raw/cast-*.png`:

- `cast-xiaoyu`: 林小雨. **Done and approved** (`out/raw/cast-xiaoyu.png`, also `refs/ref-cast-xiaoyu.png`): the model
  for the others, attached to each of their jobs as the third reference. Don't make her again.
- `cast-chenming`: 陈明, 32, chef-owner of 陈家饺子. **Done and approved** (version 1, black hair, hand on hip; its head
  locked to 48% by `fit_head.py` and the sparkle added: `out/raw/cast-chenming.png`; as drawn: `cast-chenming-drawn.png`).
- `cast-chenmama`: 陈妈妈, about 58, runs the restaurant's front. Short perm, round glasses, red apron, a bowl of soup.
- `cast-chenbaba`: 陈爸爸, about 64, retired, loves Beijing opera and tea. Brown waistcoat, a tea flask, a walking stick.
- `cast-duoduo`: 朵朵, 8, cheeky. Two hair buns with red ties, striped top and dungarees, yellow wellies, dumpling backpack.
- `cast-lineup`: the five side by side, to check they belong together.

## For each job in the group "cast", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG at `file`.
4. Look at it next to the avatar (the first reference), and make it once more if any of these is true:
   - the proportions aren't the avatar's (measured on it): the head is half the figure's height (about 2 heads
     tall), wider than the shoulders; short, thick, stumpy legs, each about a quarter as wide as the head; big chunky
     shoes; small round mitten hands. Slim legs and a smaller head are the usual misses;
   - the eyes aren't plain black ovals (no white in them: the sparkle is added afterwards, step 5);
   - there's paper grain or texture (the avatar is flat colour);
   - it has outlines, or is more detailed, realistic or anime-like than the references;
   - the person doesn't match the description (age, hair, clothes, what they hold);
   - it isn't one full figure, facing the viewer, head to shoes;
   - there's any text, letter or number (none on the chef's jacket or the apron);
   - the backdrop isn't one flat solid magenta.
5. Lock the head's size: `../sfx/.venv/Scripts/python fit_head.py <file>`. It measures the head as a share of the
   figure's height and scales it about the chin to 48% (Xiaoyu's; the avatar's is 50%), so every character's head is the
   same size whatever Codex drew. (For 朵朵, the 8-year-old, give `0.52`: a child's head is bigger for her body.)
6. Put the owner's eye sparkle in: `../sfx/.venv/Scripts/python add_sparkle.py <file>`. It finds the eyes itself and
   draws the same sparkle in each (one small tilted oval high on the right). If it says it didn't find 2 eyes, report it.

Xiaoyu and Chen Ming are done. Make `cast-chenmama`, `cast-chenbaba` and `cast-duoduo` (steps 1–6 each), then the
lineup, and report. Two versions of each, as before, so the owner can choose.

## When all 6 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
