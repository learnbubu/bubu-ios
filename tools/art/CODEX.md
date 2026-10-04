# Generating Bùbù's art (for Codex or anyone running it)

Everything runs from `tools/art/`. Python needs `requests`, `Pillow` and `numpy`
(`tools/sfx/.venv` already has them).

1. **Prompts** live in `prompts.json`, built by `make_prompts.py` from the lists in that file and
   `picture_sheets.json` (the 194 picture-card words, 16 per 4×4 sheet). Edit the lists there and
   re-run `python make_prompts.py` to change what gets drawn.
2. **Generate**: `OPENAI_API_KEY` must be set in the environment (never print it or put it in a
   file). Then:
   - `DRY=1 python generate.py` lists what will be made (63 images: 14 corners, 3 hanging pieces,
     9 landmarks, 24 panda poses, 13 picture sheets).
   - `python generate.py pandas` (a group), `ONLY=panda-trophy python generate.py` (one image), or
     `python generate.py` (everything). It skips images already in `out/raw/`, so re-running only
     makes what is missing; delete an image to redo it.
   - Each call attaches 3–4 existing app images (flattened onto magenta) as style references.
3. **Process**: `python process.py` cuts the backdrop out of every image in `out/raw/`, mirrors the
   corners and hanging pieces (`-right`), slices the picture sheets into `out/final/pictures/<word>.png`,
   and writes `out/review.html`. Open it and check:
   - pieces flagged **pink** (the model used magenta in the art), and
   - picture cells that are empty, cut in half, or have text in them.

   Redo any bad ones (delete from `out/raw/`, run `generate.py` again, then `process.py`).
4. **Do not** add the images to the app yet; the owner reviews `review.html` first.

Style rules the prompts already carry: flat soft storybook vectors, no outlines, faint paper grain,
jade/teal/sage greens, warm cream, terracotta coral, soft orange, warm stone greys, charcoal; solid
pure #FF00FF backdrop with no magenta or pink in the art; no text. Bùbù is a chubby baby panda with
a white tuft, blush cheeks and a coral-red backpack, always.
