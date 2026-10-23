# The cast, with Codex

Speaking becomes chats with the course's people, so they need faces. Mark is the player (the avatar), so these are the
five he talks to, drawn as people in the app's storybook style.

**Every one is drawn over the base:** `refs/ref-cast-base.png`, the owner's studio avatar with no hair. Keep the base's
face, ears, body, legs, shoes and their sizes exactly; only the hair, clothes and what they hold are each person's own.
That's what keeps them one set. The owner wants Codex to get the sizes right, not a script afterwards.

All 6 jobs are in the group `"cast"` in `tools/art/jobs.json`, saved as `out/raw/cast-*.png`. Each job's `refs`, in order:
the base, the avatar with his hair (the finish to match), Bùbù (the palette), and a design to keep or match.

- `cast-xiaoyu`: 林小雨, 22. **Redraw** of her approved design (attached last) over the base: her face came out 8% small.
- `cast-chenming`: 陈明, 32, chef. **Redraw** of his approved design (version 1, attached last) over the base: his face
  came out 15% small.
- `cast-chenmama`: 陈妈妈, about 58, runs the restaurant's front. Short perm, round glasses, red apron, a bowl of soup.
- `cast-chenbaba`: 陈爸爸, about 64, retired, loves Beijing opera and tea. Brown waistcoat, a tea flask, a walking stick.
- `cast-duoduo`: 朵朵, 8, cheeky. Two hair buns with red ties, striped top and dungarees, yellow wellies, dumpling
  backpack. The base a little smaller overall (about four fifths), the same shape.
- `cast-lineup`: the five side by side, to check they belong together.

## For each job in the group "cast", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG at `file`.
4. Check the size: `../sfx/.venv/Scripts/python check_head.py <file>`. It measures the face without its hair (ear to
   ear) against the body below it (chin to feet), next to the avatar's. If it doesn't say OK, draw it again (up to three
   times, then report what it says).
5. Look at it next to the base, and make it once more if any of these is true:
   - the face, ears, body, legs or shoes aren't the base's shape and size;
   - the eyes aren't plain black ovals (no white in them: the sparkle comes in step 6);
   - there's paper grain or texture, outlines, or it's more detailed, realistic or anime-like than the references;
   - the person doesn't match the description (age, hair, clothes, what they hold), or for a redraw, the design
     attached last;
   - it isn't one full figure, facing the viewer, head to shoes;
   - there's any text, letter or number (none on the chef's jacket or the apron);
   - the backdrop isn't one flat solid magenta.
6. Put the owner's eye sparkle in: `../sfx/.venv/Scripts/python add_sparkle.py <file>`. It finds the eyes itself and
   draws the same sparkle in each (one small tilted oval high on the right). If it says it didn't find 2 eyes, report it.

Make `cast-chenming` first, then **stop and report**: the owner checks the base works before the rest. Then
`cast-xiaoyu`, the other three and the lineup, two versions of each so the owner can choose, and report.

## When all 6 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
