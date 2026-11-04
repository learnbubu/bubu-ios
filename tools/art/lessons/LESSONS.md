# Cutting lessons: the catalogue

Bùbù's puppet parts are cut the owner's way. The owner records in Studio (Record, then Note) while drawing a part or fixing one of
Claude's, and every recording is kept here as a lesson. The rules learnt from them live in `../lesson_fit.py`. The aim is that each
lesson improves on the last and none is ever lost.

## How it's used

1. **Before cutting a part, read the whole catalogue below.** Then rewatch the nearest lesson:
   `../sfx/.venv/Scripts/python -I lesson_replay.py lessons/recordings/<file> [frames]`. This draws a sheet of the shape step by step
   over the model, with its notes, to `out/lessons/<file>.png`.
2. **When a cut gets stuck, stop and rewatch before tuning numbers.** Compare with the owner's version of the nearest part:
   `lesson_compare.py <claude svg> <owner svg> <out png> [box]`. The arm in lesson 4 cost an hour of tuning that one rewatch would have
   saved.
3. **When the owner records a fix,** add an entry here and in `catalogue.json`:
   - copy the recording to `recordings/` and the owner's final SVG to `owner/` (Claude's version from before the fix as `*-before.svg`)
   - put the rule into `lesson_fit.py`, with a comment naming the lesson
   - run `lesson_check.py`. It re-cuts every part and scores each against the owner's. A rule that makes an older lesson worse is
     flagged, and gets fixed rather than accepted. `--save` keeps the new best scores in `scores.json`.
4. **Never edit the owner's layers.** Claude's attempts go in as new layers named "(Claude)".

## The lessons

### 1. Head (owner, from scratch) - `2026-11-03-23-27-18.jsonl`, `owner/head.svg`
- The head and its tuft are **one shape**.
- **4 points round the head,** at its extremes, with long handles lying along the edge. The detail goes only where there are corners:
  7 points for the tuft.
- Rough in about 30 s, then minutes refining. **As few points as possible:** one was added and taken out again.

### 2. Left arm (owner, from scratch) - `2026-11-03-23-37-39.jsonl`, `owner/arm-l.svg`
- The arm and paw are **one shape with 8 points.** The paw is the arm's rounded end, not a separate piece.
- The **hidden end is a round cap** past the visible shoulder, under the strap and head.
- **Toe lines are their own small rounded shapes** in the same layer. Colours are picked from the drawing.

### 3. Right leg (owner fixing Claude's) - `2026-11-03-23-45-50.jsonl`, `owner/leg-r-fix.svg`
- **The limb owns its whole visible outline,** up to where it goes under whatever covers it (the hip). Claude's curved in too early
  and left the black strip by the belly uncovered.
- **The hidden cap is bigger:** higher than that point, and past the inner edge.
- A **small step at the heel.**
- **Toe lines have 8 points** and bend with the drawn line.

### 4. Right arm (owner fixing Claude's) - `2026-11-03-23-58-58.jsonl`, `owner/arm-r-fix.svg`, sheet `out/lessons/2026-11-03-23-58-58.png`
- **A slanted limb's points go in its own frame,** along and across the arm. Claude had put them at the screen's lowest and rightmost,
  which bulged the paw.
- **The paw end is one point** at the end along the arm, not a tip plus a bottom.
- **The hidden inner edge runs on parallel to the seen one.** It does not follow the strap or belly that cover it.
- **The cap reaches a whole width back,** a bulb under the head.
- **His order of work:** the biggest error you can see first (the paw), then the hidden edge, then the cap, toe lines last.
- **Claude's own bugs found here:**
  - The fit was pulled by other parts' edges in its box, like the hip under the paw. Now only edges near the placed outline count.
  - The limb's line, taken from the whole picture, was skewed by the paw. It's now the outer edge's line.
- **Checked on the owner's untouched left arm too:** the same rules land within 10% of his shape there.

## Scores (lesson_check.py, 4 Nov 2026)

| lesson | differs from the owner's | seen against the backdrop |
| --- | --- | --- |
| arm-l (rules tested on his original) | 10.0% | 347 px |
| leg-r-fix | 6.2% | 284 px |
| arm-r-fix | 8.6% | 415 px |

Most of what's left is in the hidden caps, which nobody sees at rest.
