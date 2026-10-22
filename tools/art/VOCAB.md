# The Vocabulary room's art, with Codex

The Classroom's Vocabulary needs 7 pictures. They're all in the group `"vocab"` in `tools/art/jobs.json`, saved as `out/raw/*.png`:

- `vocab-flash`: the Flashcards tile. One cream card mid-flip with a curved arrow.
- `vocab-match`: the Match tile. Two cards with the same red lantern, snapping together.
- `vocab-seed`, `vocab-grow`, `vocab-bloom`: the word garden's three stages (new, growing, blooming). The **same pot** in all
  three: a seedling, a leafy plant, then a plant in flower.
- `vocab-bed`: a low garden bed (seedlings → leafy → flowering, left to right) for the corner of the Today's words card.
  It's faded out there, as Home's hills are, so keep it light and calm.
- `panda-searching`: Bùbù peering through a magnifying glass, holding a flashcard. He's shown when a search finds nothing.

The tiles and the garden must look like the app's Classroom tile pictures, which are attached as references: simple objects, flat
shapes with soft shading, cream cards with jade and coral. **No Bùbù in those six.**

## For each job in the group "vocab", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a reference, in order;
   - use the job's `size`.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is true:
   - it doesn't look like the attached tile pictures (too detailed, glossy, outlined or realistic);
   - the three garden pots aren't the same pot, the same size and seen the same way;
   - the blossoms are pink or magenta (they must be coral red);
   - there's anything else in it: a table, a floor, a frame, a tile behind it;
   - there's any text, letter or number (even a Chinese character on a card);
   - the backdrop isn't one flat solid magenta.

Make `vocab-flash` first, then **stop and report**. Then make the rest and report.

## When all 7 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
- Don't add anything to the app, and don't commit the images.
