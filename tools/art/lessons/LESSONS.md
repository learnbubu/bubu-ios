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
4. **For every recording, also run `lesson_process.py <rec> [--model <png>]`.** It shows how he worked: the order he visited the
   points, how big the moves were, and which ended on the drawn edge. The lessons keep his method as well as his shapes.
5. **Check every part for spikes, hidden ones too:** run `part_kinks.py [doc]`. A sharp turn that isn't meant, like the tuft's, gets
   fixed before the owner sees the part (lesson 8).
6. **Never edit the owner's layers.** Claude's attempts go in as new layers named "(Claude)".

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

### 15. Three-quarter ears (owner fixing Claude's, in puppet-views) - `2026-11-04-10-51-17.jsonl`, `owner/q-ear-l-fix.svg`, `owner/q-ear-r-fix.svg`
- **The near ear went from 4 points to 5, and isn't a whole circle any more.**
  - Its top is still the drawn round ear.
  - Its bottom now runs just inside the head's edge, in a curve along it, with a point added there. That goes with his head fix
    (lesson 14), which showed the dark band of ear along the head's top left as drawn.
  - Lesson 7 had the ears drawn whole behind the head so they can turn without a gap. Whether the cut-off bottom shows when the ear
    turns is asked about, not assumed; `cover_check.py` now turns the ears 20 degrees each way to see.
- **The far ear kept 4 points,** made a bit smaller and moved down and right onto the drawn ear; its bottom stays hidden behind the head.
- Both ears' pivots stayed where they were.

### 16. Three-quarter legs (owner fixing Claude's, in puppet-views) - `2026-11-04-10-53-16.jsonl` (the one before it is a start that stopped at once), `owner/q-leg-l-fix.svg`, `owner/q-leg-r-fix.svg`; how he worked: `out/lessons/2026-11-04-10-53-16-process.json`
- **The shapes:**
  - Both hidden caps were raised much higher, in a round dome well up under the belly. Claude's were low and flat. It's lesson 3's
    "the hidden cap is bigger" again, which Claude's carried-over legs still didn't do enough.
  - The near leg keeps 12 points. The far leg went to 11: he took out a point at the heel, where its heel is simpler.
  - The feet only moved a pixel or two.
- **How he worked it out**, from `lesson_process.py`, about 50 s a leg:
  - **Near leg.** The big hidden ones first: the cap's top and side, moved 56 to 68 px in one go each. Then he walked round the foot
    in order (toe, sole, heel: points 4, 3, 5, 6, 7, 8, 9), each move 1 to 3 px. He went back and forth on the heel point, off the line
    and back on, until it looked right. Moves shrank from about 25 px to 2 px; 16 of 22 ended on a drawn edge.
  - **Far leg.** He started at the hidden inner top, then went backwards round the outline. He used the handles far more: 8 of 21
    steps changed only handles, to bend a curve rather than move a point. He took out the heel point once it wasn't needed. He ended
    on the hidden cap with big handle pulls (24 to 26 px).
- **Points he left off the drawn edge** were all hidden: the caps and the top of the inside edge.

**How he works by eye** (from all the recordings so far; `lesson_process.py` reads any recording this way):
1. **Biggest error first, roughly:** whole points moved tens of pixels at once, often the hidden parts (lessons 4 and 16).
2. **Then round the outline in order, point by point,** each move a pixel or a few. Every visible point lands on the drawn edge.
3. **Overshoot and correct:** a point moved off and back on until it looks right. He judges by eye, not by measuring.
4. **Handles for curves, points for corners.** Where a curve is wrong but its ends are right, he bends the handles.
5. **As few points as hold the shape:** he adds one where a turn needs it (the head's far side, the foot's bump) and takes one out
   where it isn't needed (the far heel). He has also tried one and taken it out again (lessons 1 and 11).
6. **Hidden parts are generous:** caps high and round, ends tucked well under, shaped from a picture of what's really there
   (lesson 13).

### 17. Three-quarter far eye and brow (owner fixing Claude's, in puppet-views) - `2026-11-04-10-56-01.jsonl`, `owner/q-eye-r-fix.svg`, `owner/q-brow-r-fix.svg`; how he worked: `out/lessons/2026-11-04-10-56-01-process.json`
- **Both kept 8 points.**
- **The far eye's arc is fuller and more peaked,** like the drawn far eye, with round ends as thick as the near eye's. The **far brow is
  thicker** too. He also picked the eye's colour from the drawing (`#fdf6e4`).
- **Why Claude's were wrong:** they were his front eye and brow carried over, kept to his proportions and shrunk to the far side's size
  (about half). That shrank their thickness too. **Turned away, a feature gets shorter, not thinner:** a line drawn with the same pen
  keeps its width. Carry a far-side stroke over at the near side's thickness and shorten only its length.
- **How he worked:**
  - The eye took 70 s. Nearly half the steps (17 of 37) changed only handles. Every point move was 2 to 3 px and landed on the drawn
    edge.
  - He went round the points in order, then came back to the ones that still looked off (5, 6, 4 again at the end).
  - The brow took 30 s, the same way.
  - For small strokes he works mostly with the handles.

### 18. Three-quarter mouth, nose and far cheek (owner fixing Claude's, in puppet-views) - `2026-11-04-11-03-40.jsonl`, `owner/q-mouth-fix.svg`, `owner/q-nose-fix.svg`, `owner/q-cheek-r-fix.svg`; how he worked: `out/lessons/2026-11-04-11-03-40-process.json`
- **The mouth kept his 18 points** (lesson 5's one outline).
  - The stem's top now runs up under the nose. Claude's stopped just below the nose in a little round end of its own, which showed.
  - The two points at the stem's top were left off the drawn edge on purpose: under the nose, hidden.
  - **Where one part meets another, the end tucks under it** (the nose here), as the limbs go under the body.
- **The nose kept 4 points.** Its bottom point came down about 4 px, over the stem's join, so the two meet with no seam.
- **The far cheek went from 4 points to 5.** The added point lets its outer side follow the head's edge, where the cheek runs off the
  head in this view.
- **How he worked:**
  - The mouth took 2 minutes. He started at the near curve's end and went round (4, 5, 3, 6, 8, 7...) to the far curve.
  - He spent the longest on the far curve's end (points 11, 12 and 13, revisited six times), moving them under 1 px a time. The far
    end is where the turned mouth reads most.
  - The stem came last, with bigger moves (5 to 9 px).
  - 24 of 58 steps changed only handles, and 31 of 34 point moves ended on the drawn edge.
  - The nose took 19 s and the cheek 17 s.

**Shapes don't carry between views; the principles do** (the owner on the side view, 4 Nov 2026: "side is kinda bad... follow how
we made things from the recording. Things will be different shapes etc but the same principles apply"):
- Carrying his three-quarter shapes onto the side gave the wrong shapes. Each part is now cut fresh by `principle_cut.py`:
  - from its whole shape (the drawing, plus Codex's pictures of what's hidden)
  - points at its extremes in its own frame, and its corners kept
  - more points only where the shape needs them, up to his count for that kind of part
  - visible edges within about 2 px, hidden ones generous
- Carrying shapes over is still right between near-identical views: the three-quarter's near brow, approved as it was.

**Approved as they are** (the owner looked and said they were good, unchanged):
- the three-quarter's near brow, Claude's carry-over of his front brow (4 Nov 2026: "brows are good")
- they're kept, and never re-cut (`APPROVED` in puppet_quarter.py)

### 19. Side: near strap, backpack, torso, belly and far leg (owner fixing Claude's second side cut, in puppet-views, 5 Nov 2026) - `2026-11-05-00-27-27.jsonl` (far leg, torso, belly), `2026-11-05-00-34-55.jsonl` (strap, backpack); `owner/*-side--edit-*.svg`, Claude's as `owner/s*-claude-before.svg`; overlays `out/lessons/side/overlay-parts.png` (Claude red, his blue); how he worked: `out/lessons/2026-11-05-00-*-process.json`

He asked: "have a look if that helps cleaning up other pieces". What he did:
- **Far leg** (3 min, the longest): Claude's was the near leg shrunk. His is a **whole leg with a big round thigh**, as wide as the
  hip, reaching high up under the belly (y 810, 150 px over the hip). The far limb isn't smaller; it's the same limb, behind.
- **Backpack**: Claude's hull bulged. His is a plain **rounded block**, 6 points (one taken out). Its hidden side runs straight down
  under the arm and the strap, to x 490 at the top.
- **Torso**: rounder all round, a body not a box. The top follows under the head, the back comes in from the bag, the bottom is one
  round sweep under the belly. Big moves first (215 px), then small ones and handles.
- **Belly**: as cut, but for its one hidden point, under the arm, pulled into the hidden part.
- **Near strap**: a **slim band hugging the drawn strap's edges**, round the shoulder; its back run goes down to the bag's bottom
  corner (x 430, y 850 to 875). He added one point at the shoulder (11).
- His way, again: biggest error first, then round the outline; handle-only steps are about half of all steps; hidden points are
  placed by eye, off any drawn edge.

The rule it gives: **hidden parts are simple, round, generous forms**, a full thigh or a plain block, never a scrap that only just
fills the gap. **A far limb is whole**, the near one's equal.

Applied (puppet_side.py):
- the near leg takes his thigh (it's the same leg in front)
- the far arm is the near arm whole, a little back, not shrunk
- the over-the-arm strap copy remade from his strap: `strap_over.py sStrapL sArmL 900 --ref out/raw/rm-rest-side.png`. The copy shows
  over the arm only where the drawing's red is. The old height cut-off (650) hid the strap down his front ("strap not showing? a
  bug?" No: the copy was still my old strap, cut off at 650). Without the cut-off, the loop's bottom showed over the arm, where the
  drawing has it under. **The drawing decides.**

Then, starting to fix the near leg himself (5 Nov 2026): "not sure why we're not just copying the LegR as they'll be the same".
**In profile the near and far limb are the same shape: copy his finished one, don't cut the other.** The near leg is now his far
leg (`LegL-side--from-LegR.svg`): same box and pins, with the near leg's toe lines on top. His half-done near-leg edit is left in
the art folder.

Studio, from the same session ("got some vector bugs too"):
- a puppet layer's points dragged past its old outline were cut off while dragging (the mesh was the old outline's); now it's drawn
  flat while dragging
- a double-click on the edge for a new point: the first click picked the layer under the edge; now a press on the edited shape's
  edge keeps it

### 20. Side face, head, ears and torso (owner fixing Claude's, in puppet-views, 5 Nov 2026) - `2026-11-05-02-11-34.jsonl` (head, ears, brow, eye, nose, mouth, 6 min); `2026-11-05-01-38-55.jsonl` is his near-leg start, dropped when the near leg became a copy of his far leg (lesson 19); his files `owner/*-side--edit-*.svg`, Claude's `owner/s*-claude-before.svg`; overlay `out/lessons/side/face-fixes.png` (Claude red, his blue); how he worked: `out/lessons/2026-11-05-02-11-34-process.json`

What he changed:
- **Far ear**: Claude's was a small circle, only the bit that peeks over the head. His is **the whole ear**, an oval about half
  the near ear's size, most of it hidden behind the head. Lesson 19's rule again: a hidden part is whole, not the scrap that shows.
- **Brow, eye, nose**: the same points, each pulled 1 to 2 px **in, onto the drawn edge**. Claude's small features sat just outside
  the edge all round (a stroke's outer pixels, the soft anti-aliased ones, were counted as the stroke). Fit small features to the
  edge's middle, where the shade is half way.
- **Mouth**: one point added (8), the stem's tip and the right end tidied.
- **Head**: 22 points (3 added, 1 taken out); the line under the ear eased.
- **Near ear**: two handle tweaks only.
- **Torso** (fixed outside the recording): 9 points, its top wider and flatter under the head, like shoulders.
- His way, again: tiny moves on visible features (about 1 to 2 px each, nearly all ending on the drawn edge); handle-only steps are
  a third to a half of all steps.

Studio, from the same recording: 11 of his steps were undone within a second. Each time, a press near a point had grabbed a short
handle beside it instead (handles were tried first, the first in reach taken). Pulled past its point, the handle flipped, and the
long handle opposite swung right round with it, 214 px once. Small points also got nudged by a click's own wobble. Now the nearest
point or handle is taken, points favoured, and a click must move 4 screen px before anything moves.

### 21. Where joints and pins go (the owner, 5 Nov 2026, on the side's rig: "arm pins/bones need to follow the shape of the arm more too", "legs as well", "normally takes the centre point along the thickest width where it gets placed")

- Every joint and pin sits on the limb's **centre line**, the middle of its width at that height, read off his outline. Not a
  straight line from a guessed shoulder or hip.
- A round top or end: the joint is in its middle, half the limb's widest width in from the end. The hip is in the middle of his round
  thigh; the shoulder in the middle of the arm's cap.
- A neck (the leg above the foot) is the ankle; an arm with no neck has its wrist where the paw's round end begins.
- The knee and elbow are half way between, on the centre line, with two short bones there so the bend gathers at the joint
  (Studio shares a bend evenly between a chain's joints); the foot is a level bone.
- `side_limbs.py` does this from his shapes; `puppet_side.py` uses it on a rebuild.

### 22. Which way elbows bend (the owner, 5 Nov 2026: "you keep changing the elbows for all of them... check all and make sure you know what way they bend - default elbow down when arm up")

- **The rule: with the hand raised, the elbow points down.** Knees point forward.
- Don't reason it out from bend signs. Claude flipped them by rule ("forearm forward", "out from the middle") and got different
  arms wrong each time. **Measure it**: raise the hand (up and out to its own side; in profile, up in front) with Studio's own
  IK at bend -1 and +1, and keep the one with the elbow below the shoulder-to-hand line.
- **"Arm up" in a turned view means up in front of him, the way he faces**, not out to the side. Measured with the arm raised to
  the side, the three-quarter near arm came out +1; the owner set it to -1 in Studio ("have the directions of the elbows set up
  how i have it now"), which is elbow down raised in front.
- His bends (5 Nov 2026): front screen-right -1, screen-left +1; three-quarter both -1; side both -1; knees +1 (the front's legs
  mirrored, +1 and -1). When he sets them himself in Studio, take his; don't re-derive.
- Bend keys in an animation count too: the front's right arm had keys flipping it to +1, elbow up, for most of its first second.
- **Rest pose sets each bend to how its chain is drawn.** A chain drawn leaning against its bend (the centre line curving the other
  way) got its elbow or knee flipped on every reset; the owner: "the elbow should be the other way round... by default". Now the
  joint goes on the straight line when the centre line leans the wrong way (side_limbs.chain).
- bubu-studio's `tests/unit/puppet-elbows.test.ts` checks every arm of every view, at its bend and every bend key, and that no
  arm or leg is drawn leaning against its bend.

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


### 23. Sitting leg, front (owner fixing Claude's, in the scratch lesson project's `bubu-lesson-sitd`, 8 Nov 2026) - `2026-11-08-07-52-05.jsonl` (5 min), `owner/sit-leg-l-fix.svg`, Claude's `owner/sit-leg-l-claude-before.svg`; sheet `out/lessons/2026-11-08-07-52-05.png`; how he worked: `out/lessons/2026-11-08-07-52-05-process.json` (and `.txt`); model `out/raw/rm-sit-front.png` (Codex's sit, `out/codex/sit/`, placed in the hips' rest frame)

Claude's cut (principle_cut from Codex's legs-only picture) was one 11-point outline with a tall round thigh up under the strap.
What he did:
- **Two pieces, not one.** A **round foot of 6 points** on top (the sole facing us), and behind it a **short stub of 6 points**
  running in from the foot's inner side to under the belly. Claude's tall thigh dome is gone: sitting, the leg barely shows, so the
  hidden part is only the stub that tucks under the belly, not a whole thigh.
- The stub got its own dark (`#3c3c38`, picked at 259 s), a touch off the foot's `#393a36`.
- **The sole pad and toe pads** kept as round 4-point pieces, the sole pad redrawn as an oval and the toe pads moved and resized.
- **The whole layer sized down to 0.891** and moved: the feet were too big against the body.
- His way, again: deletes first (9 points taken out, 4 added), biggest moves first (about 21 px), then down to 3 px; 36 of 91
  steps were handle-only. Most of his points sit off any drawn edge: he shaped it by eye against the reference rather than tracing.

The rule it gives: **a limb seen end-on (a sole facing us) is its end as its own round piece, with only a short stub behind it**,
not the standing leg's outline with a thigh. Fewer points than a standing leg (6 + 6, not 12).

Mirrored to sitLegR exactly (same shapes, pads and scale, flipped about 626.5, the pivot mirrored); nothing refitted.
part_kinks: the stub has a sharp tuck at each end (163 degrees), where it goes under the foot: asked whether it's meant.
