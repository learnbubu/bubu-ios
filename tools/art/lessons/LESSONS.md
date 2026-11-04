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

### 9. Hair (owner, his own head) - `2026-11-04-02-13-19.jsonl`, `owner/head-fix.svg`
- He moved one point of the tuft. The tuft is his own, from lesson 1.

### 10. Screen-right leg (owner fixing Claude's, in the puppet) - `2026-11-04-02-14-18.jsonl`, `owner/leg-r-fix-2.svg`
- **One point added at the top front of the foot,** making 12. The front of the foot rises from the leg in its own rounded bump,
  not one long curve down to the toe.
- The rest was small moves along the outer edge and the sole, about a minute's work.
- Mirrored to legL with `mirror_fix.py legR legL --turn`. Overlap where it shows: 0.992, his 0.988.
  - It's lined up using only what shows. Using the whole shape, the hidden cap pulled it 2 px off.
  - The legs aren't exact mirrors in the drawing, so it also took a 1 degree turn about the hip.

### 11. Screen-left arm (owner fixing Claude's, in the puppet) - `2026-11-04-02-16-13.jsonl`, `owner/arm-l-fix.svg`
- **Still 8 points.** He tried a ninth and took it out.
- **The hidden shoulder cap is rounder and fuller under the head.**
- **The inner edge by the strap sits on the drawing's edge where it shows,** then runs on smoothly under the strap.
- Mirrored to armR with `--turn`: 0.5 degrees about the shoulder. Overlap where it shows: 0.991, his 0.988.

## Scores (lesson_check.py, 4 Nov 2026)

| lesson | differs from the owner's | seen against the backdrop |
| --- | --- | --- |
| arm-l (rules tested on his original) | 10.0% | 347 px |
| leg-r-fix | 6.2% | 284 px |
| arm-r-fix | 8.6% | 415 px |

Most of what's left is in the hidden caps, which nobody sees at rest.

### 12. Three-quarter straps (owner fixing Claude's, in puppet-views) - `2026-11-04-09-20-27.jsonl`, `owner/q-strap-l-fix.svg`, `owner/q-strap-r-fix.svg`
- **Still 8 points each, laid out as before:** 3 round each end and 1 down each side. The fix was in where they sit, about 3.5 minutes
  of moving points, the near strap first.
- **The strap is the full drawn band.** Claude's near strap was narrower than the drawn red on its arm side; his sits on both drawn edges.
- **Both ends go under what covers them:**
  - the top in a round cap well up under the head
  - the near strap's bottom down under the arm
  - the far strap's bottom to a narrow end behind its arm
- **The near strap's bottom end is squared off,** with two corners where it goes under the arm. `part_kinks.py` flags both.
- **His notes on it:**
  - **Think where a line leads.** The near strap goes on to the backpack under the arm, so it has to make sense when he lifts his arm.
    Hidden ends aren't just tucked away: they carry on the way the real thing would.
  - **Reach far enough to stay covered when things move.** The strap's top may need more under the head, because the head tilts.
- **So for any part that goes under another:** picture the cover moved (the arm raised, the head tilted) and draw what would then show,
  carrying on where the thing really goes.
- Replayed over the three-quarter model with `lesson_replay.py <file> 16 --model out/raw/rm-rest-quarter.png`.

### 13. Three-quarter straps, backpack, belly and torso (owner, in puppet-views, three recordings) - `2026-11-04-10-15-36.jsonl` (straps, backpack, belly, about 5 min), `2026-11-04-10-22-03.jsonl` (torso), `2026-11-04-10-23-42.jsonl` (near strap touch-ups); `owner/q-*-fix*.svg`
He drew with the drawing and Codex's two pictures behind him (the view without the near arm, and without the head and near arm). For
what's hidden he followed Codex's shapes closely. So **hidden parts are drawn from a picture of what's really underneath, not guessed.**
- **Straps go up over the shoulders to the back.**
  - The near strap went from 8 to 10 points: two new ones at the top carry it over the shoulder and down towards the backpack's top.
    Its bottom end moved down into the bag's bottom.
  - The far strap went from 8 to 9 points, also on over its shoulder towards the back.
  - The far ends, hidden under the head, fold back in a narrow tip. `part_kinks.py` flags them (122 and 153 degrees). Asked about
    rather than changed.
- **The backpack** went from 6 to 7 points, traced round Codex's whole bag: its top under the near strap's top, its bottom under the
  strap's end.
- **The belly went from 4 points to 9,** onto the drawn belly exactly, with its colour picked from the drawing (`#fef9e3`, not
  `#fef8e8`).
  - Its left side runs up to a corner where it meets the near strap (73 degrees, drawn).
  - Claude's 4-point oval was the round-pieces rule used on a shape that isn't an oval. **Points at the extremes only suits a part that
    really is round:** the belly in this view isn't.
- **The torso kept its 8 points, reshaped.**
  - Its top follows the shoulders' rounded line, from Codex's no-head picture.
  - Its left side goes out to the backpack.
  - It has no box corners: Claude's was a convex hull, square on top and straight down the sides.
- **Order of work:** near strap, backpack, far strap, belly, then the torso in its own recording, then touch-ups to the near strap.

### 14. Three-quarter shoulder and head (owner, in puppet-views) - the near arm fixed without a recording (`owner/q-arm-l-fix.svg`); the head recorded, `2026-11-04-10-48-31.jsonl` (`owner/q-head-fix.svg`)
- **The near arm's shoulder** (his words: "the shoulder shape needs fixing"). Still 8 points.
  - Claude's cap reached a whole width back and out (lesson 4's rule from the front). In this view that pushed the shoulder out over
    the backpack.
  - His outer edge follows the drawn arm all the way up, and the top is a neat round end tucked under the strap at the shoulder.
  - **A hidden cap goes under what really covers it in that view:** here the strap, now over the upper arm. It doesn't bulge out
    where the backpack shows.
  - His pins all stayed where they were.
- **The head went from 11 points to 14.** He added two on the far side, at about (802, 171) and (874, 298), where the head turns from
  the forehead into the cheek, plus one by the tuft.
  - In the three-quarter view the far side of the head isn't an oval's quarter: it has its own shape.
  - He also tightened the outline onto the drawing at the top left, by the ear, and at the bottom.
  - He picked the colour from the drawing (`#fdf6e0`).
  - `part_kinks.py` finds only his tuft's corners.
- After the arm changed, `strap_over.py` was re-run, so the strap copy's paw cutout follows his arm.

## Other views (the three-quarter, 4 Nov 2026)

The owner: "make sure we're following what we learnt from those recordings and apply it to these turns". A view's parts aren't cut
afresh by rule. Each starts from his finished front part, carried onto that view's drawing by `owner_transfer.py`, so it keeps his
point count, handles, stroke ends and hidden caps:
- moved, turned, sized and slanted whole, never sheared
- then only his points on the seen edge are nudged onto the drawing
- eyes and brows keep his proportions and aren't refitted (lesson 6)

`puppet_quarter.py` uses it for these parts, all checked with `part_kinks.py`, which finds only his tuft corners and his foot step:
- the head (lesson 1)
- the mouth, as one outline (lesson 5)
- the eyes and brows (lessons 6 and 7)
- the arms (lessons 2, 4 and 11)
- the legs, both from his right leg (lessons 3 and 10)

The straps didn't carry over well from the front. The owner fixed the three-quarter's himself (lesson 12), and his are kept.

**To see what's hidden, ask Codex** for the view with the covering parts taken away. The owner's idea; `out/codex/quarter-no-arm` and
`quarter-no-head` are the first. Show them to him as reference layers, switched off. Lesson 13 was drawn over them.

A part he has edited is never rebuilt.

**Over and under at once** (after lesson 13). The owner: "upper arm under strap, bottom part over", and "look at the ref":
- In the drawing the strap lies over the whole upper arm, its own edge showing, and only the paw comes over it at the bottom.
- `strap_over.py` adds a copy of his strap just above the arm, masked to leave out the paw: the arm below y 770. His strap stays under
  the arm.
- Claude first masked it to only the shoulder, so as to change nothing at rest. That was wrong: the drawing is the authority, and it
  shows the strap over the arm.
- **Studio's mask handles are positions in the layer, not offsets.** Zero handles pull every curve to the corner and the mask shows
  nothing.
- The copy uses his strap's file: if he edits the strap, re-run it.

