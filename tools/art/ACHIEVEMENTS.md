# Achievement badges for Bùbù, with Codex

The design is in `docs/achievements.md`. Codex draws **only Bùbù** for each badge: Bùbù doing that family's thing, big
and sticker-simple, with **nothing behind him**. The app draws the badge around him, the same for every one:
- the four-lobed window shape in the family's colour, with a thick two-tone rim;
- Bùbù standing in it, his legs inside the shape and the rest breaking out over its top;
- the tier's big number over its foot, "NEW", and the name and "3 of 5".

That's **17 images**, all in the group `"achievements4"` in `tools/art/jobs.json`, saved as `out/raw/achv4-<family>.png`.
Leave the group "achievements" (the first round medals) alone.

## The look

**Exactly as simple as Bùbù in the first two reference images** (`out/raw/achv3-*.png`, from the last try). He came
out just right there, so match him and ignore the window shape behind him. That means big flat shapes, one or two
tones a colour, no texture, no fine lines, no outlines, no shine. The third reference is the app's Bùbù, so he's
recognisably him.

**Big, lively, top-heavy.** He fills about 85% of the canvas height. His legs end up inside the badge shape, so the
action (face, paws, prop) goes in the top 60%.

## For each job in the group "achievements4", in order

1. If `file` already exists, skip it.
2. Generate one image with your image generation tool:
   - use `prompt` exactly, word for word;
   - attach every image in `refs` as a style reference, in order;
   - size 1024x1024.
3. Save it as PNG at `file`.
4. Look at it, and make it once more if any of these is true:
   - anything is drawn behind him (a shape, a circle, the ground, scenery);
   - he's more detailed, textured or glossy than in the first two references;
   - he isn't clearly Bùbù (round cream head, charcoal ears and eye patches, blush, coral-red backpack);
   - he's small, or the action is low down;
   - there's any text, letter, number or Chinese character in it;
   - the backdrop isn't one flat solid magenta.

Make the first two (lantern-keeper and step-by-step), then **stop and report**, so the owner can check them. Then
report after every 6.

## When all 17 are made

- Run `python process.py` from `tools/art`. It needs Pillow and numpy, and `../sfx/.venv/Scripts/python` has them.
  It cuts out the magenta and writes `out/review.html`.
- Tell the owner to open `out/review.html`.
- Don't add anything to the app, and don't commit the images.
