# The cast, with Codex

Speaking becomes chats with the course's people, so they need faces. Mark is the player (the avatar), so these are the
five he talks to, drawn as people in the app's storybook style.

**Every one is drawn over the base:** `refs/ref-cast-base.png`, the owner's studio avatar with his hair as a plain grey
shape. Keep the base's face, ears, body, legs, shoes and their sizes exactly, and replace the grey with each person's own
hair covering at least the same area (the fringe as low: no more forehead than the base shows). Only the hair, clothes
and what they hold are each person's own. (The first base was bald, and everyone drawn on it had a huge forehead.)
That's what keeps them one set. The owner wants Codex to get the sizes right, not a script afterwards.

All 6 jobs are in the group `"cast"` in `tools/art/jobs.json`, saved as `out/raw/cast-*.png`. Each job's `refs`, in order:
the base, the avatar with his hair (the finish to match), Bùbù (the palette), and a design to keep or match.

- `cast-xiaoyu`: 林小雨, 22. **Redraw** of her approved design (attached last) over the base: her face came out 8% small.
- `cast-chenming`: 陈明, 32, chef. **Done and approved** on the grey-hair base (`out/raw/cast-chenming.png`, sparkle in).
  Don't make him again.
- `cast-chenmama`: 陈妈妈, about 58, runs the restaurant's front. Short perm, round glasses, red apron, a bowl of soup.
- `cast-chenbaba`: 陈爸爸, about 64, retired, loves Beijing opera and tea. Brown waistcoat, a tea flask, a walking stick.
- `cast-duoduo`: 朵朵, 8, cheeky. Two hair buns with red ties, striped top and dungarees, yellow wellies, dumpling
  backpack. The base a little smaller overall (about four fifths), the same shape.
- `cast-lineup`: the five side by side, to check they belong together.

## For each job in the group "cast", in order

1. **Keep every attempt.** Never overwrite or delete an image: save each one under the next free number,
   `cast-<name>-1.png`, `cast-<name>-2.png`, … (the job's `file` with `-1`, `-2` before `.png`), including ones drawn
   again after a failed check. The owner compares them all and picks; the pick becomes `cast-<name>.png` later.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG under its number (step 1).
4. Check the size: `../sfx/.venv/Scripts/python check_head.py <file>`. It measures the face without its hair (ear to
   ear) against the body below it (chin to feet), next to the avatar's. If it doesn't say OK, draw it again as a new
   numbered attempt, keeping the first (up to three tries, then report what it says). (A hand or something held right against an ear can make it read a few percent
   big when it isn't: then judge by eye against the base. The approved Chén Míng read 1.14 for that reason.)
5. Look at it next to the base, and make it once more (a new numbered attempt, keeping this one) if any of these is
   true:
   - the face, ears, body, legs or shoes aren't the base's shape and size;
   - more forehead shows than on the base: the hair must cover the grey's area, the fringe as low (the owner found the
     big-forehead Chén Míngs ridiculous);
   - the eyes aren't plain black ovals (no white in them: the sparkle comes in step 6);
   - there's paper grain or texture, outlines, or it's more detailed, realistic or anime-like than the references;
   - the person doesn't match the description (age, hair, clothes, what they hold), or for a redraw, the design
     attached last;
   - it isn't one full figure, facing the viewer, head to shoes;
   - there's any text, letter or number (none on the chef's jacket or the apron);
   - the backdrop isn't one flat solid magenta.
6. Put the owner's eye sparkle in: `../sfx/.venv/Scripts/python add_sparkle.py <file>`. It finds the eyes itself and
   draws the same sparkle in each (one small tilted oval high on the right). If it says it didn't find 2 eyes, report it.

Chén Míng is done and the sizing works. Make **all the rest in one batch**, without stopping: `cast-xiaoyu`,
`cast-chenmama`, `cast-chenbaba`, `cast-duoduo` (at least two versions of each, numbered as in step 1, plus any
redrawn tries, steps 2–6 for every one), then `cast-lineup`. Then report: every file made, with its `check_head.py`
result and what (if anything) was wrong with it.

## When all 6 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
