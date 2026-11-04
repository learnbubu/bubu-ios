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
4. **Check every part for spikes, hidden ones too:** run `part_kinks.py [doc]`. A sharp turn that isn't meant, like the tuft's, gets
   fixed before the owner sees the part (lesson 8).
5. **Never edit the owner's layers.** Claude's attempts go in as new layers named "(Claude)".

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

### 5. Nose and mouth (owner fixing Claude's, in the puppet) - `2026-11-04-01-22-18.jsonl`, `owner/mouth-fix.svg`, `owner/nose-fix.svg`
- **The mouth is one continuous outline,** with 18 points for the stem and both curves. Claude had made it as three overlapping 8-point
  strokes. He deleted those and redrew it as one shape, then refined it for about 10 minutes. A part made of joined lines is drawn as
  a single outline round the whole thing, not as pieces laid over each other.
- **The nose kept its 4 points.** He only moved it to sit right.
- **Not his intent, Studio's fault:** the nose came out cut off at the bottom. An edit that went past the SVG's box was clipped,
  because Claude had sized each part's box to the shape plus 2 px. Studio now grows the box on every kept edit, in
  `src/renderer/src/shapes.ts`, `growToFit`. The layer's size and position move with it, so nothing shifts on screen.
- **His mouth is `#3a2a22`,** the pen's default brown, not the `#393a36` dark of the other parts. Ask before treating that as a choice.

### 6. Left eye (owner fixing Claude's, in the puppet) - `2026-11-04-01-59-59.jsonl`, `owner/eye-l-fix.svg`
- **Same 8 points, reshaped:** fuller, rounder ends that dip a little lower, smoother handles along the inner curve, and a more even
  top arc.
- **He shapes it to look right, not to trace the drawing exactly.** His eye overlaps the drawn eye about as much as Claude's did
  (overlap 0.825), so a refit to the drawing would undo his work.
- **Pairs:** when he fixes one side, mirror his fix about the face's middle (x 626.5), nudge it onto the other side's drawing, and
  don't refit it. Done for eyeR: his eye mirrored, shifted 0.5 px, overlap 0.836 with the drawn right eye.
- He made the mouth the same dark (`#393a36`) as the rest himself, so lesson 5's brown was not a choice.

### 7. Left brow (owner fixing Claude's, in the puppet) - `2026-11-04-02-06-33.jsonl`, `owner/brow-l-fix.svg`
- **Same 8 points;** only the end nearest the middle of the face was reshaped, into a rounder, fuller tip. That makes two parts now
  where his stroke ends are fuller than Claude's: the eye and the brow. Claude's stroke ends (lesson 3's toe-line rule) are too thin
  and pinched.
- He mirrored it to browR with `mirror_fix.py <fixed> <other>`. That's lesson 6's rule as a tool: save Studio, run it, reload without
  saving. Overlap 0.871 with the drawn right brow; his on the left is 0.879.

### 8. Screen-left strap (owner fixing Claude's, in the puppet) - `2026-11-04-02-10-11.jsonl`, `owner/strap-l-fix.svg`
- **Claude's strap had a spike on its hidden bottom end and a pointed flag on its hidden top end.** Both were covered at rest, so
  nothing flagged them, but they'd show as soon as the strap moved. He rounded both into clean round caps in under 30 s, keeping the
  same 8 points.
- **Hidden parts must be as clean as the parts that show.** `part_kinks.py` now lists every sharp turn in a document's parts. It finds
  both of the old strap's spikes, and on the puppet now it finds only the tuft's, which are meant.
- Mirrored to strapR with `mirror_fix.py`. It sits on the drawing as well as his does: 250 px of red off the drawing and 53 px
  missing, against his 235 and 140.

## Scores (lesson_check.py, 4 Nov 2026)

| lesson | differs from the owner's | seen against the backdrop |
| --- | --- | --- |
| arm-l (rules tested on his original) | 10.0% | 347 px |
| leg-r-fix | 6.2% | 284 px |
| arm-r-fix | 8.6% | 415 px |

Most of what's left is in the hidden caps, which nobody sees at rest.
