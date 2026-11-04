# Bùbù's puppet: the template we follow

Started 3 Nov 2026, after the owner asked for a real method ("last time didn't work very well"). The earlier rigs failed because parts were cut
from finished paintings with no art under the joints, each limb was one bone, and whole bodies were swapped. This follows the studio
cut-out method:
- [Toon Boom: How to Rig a Cut-out Character](https://docs.toonboom.com/help/harmony-24/premium/getting-started/character-building.html)
- [Toon Boom: Character prep for a multi-pose rig](https://docs.toonboom.com/help/harmony-20/premium/deformation/about-character-prep-multi-pose-deformation-rig.html)
- [Spine: How to cut your assets for animation](https://esotericsoftware.com/blog/How-to-cut-your-assets-for-animation)

## 1. The model (done)

- **Front rest pose:** `out/raw/rm-rest-a-happy.png`, in the new flat style, standing straight with limbs clear of the body. Spine: start
  from straight limbs, because a bent drawing bends badly the other way.
- **Open-eye swap:** `rm-rest-a-open.png`, in the teacher's eye style.
- **Other views:** three-quarter and side (`rm-rest-quarter.png`, `rm-rest-side.png`) at the same height and foot line, each rigged as its
  own chain on the same master (Toon Boom: one character, several chains, not separate puppets).

## 2. Breaking it down: trace the model, don't cut it

Toon Boom's method is to trace the model. Each part is redrawn whole on its own layer over the rest pose, never cut out of the picture.
Bùbù is flat shapes, so the trace is vector (Studio `vectorise`, then `shapes`), and every part is a complete closed shape.

- **Draw the hidden part in full (Spine):** the top of the arm continues under the shoulder, the leg tops continue up under the belly, and
  the head is a whole circle behind the ears and tuft. Rotating a part must never show a gap.
- **Round joint ends (Spine):** where two parts overlap, the end is as close to a circle as possible, centred on the pivot, so it looks the
  same at any angle. This applies to shoulders, hips and wrists.
- **Overlap without merging (Spine):** the paw overlaps the arm and the foot overlaps the leg. Each is its own shape, stacked.
- **Keep extremities off the limbs (Toon Boom):** the head, paws, feet and face parts are on their own layers. A stretched or bent limb
  never distorts them, and they can be swapped.
- **Few points per shape (Toon Boom):** smooth outlines with few points bend cleanly.

## 3. Bùbù's parts, back to front

| layer | part | pivot (where it turns) | parent |
| --- | --- | --- | --- |
| 1 | backpack | top centre, on the straps | chest |
| 2 | far ear (and the near ear, both behind the head) | ear base | head |
| 3 | arm L / arm R (shoulder to wrist, top end rounded) | shoulder circle centre | chest |
| 4 | leg L / leg R (hip to ankle, top end rounded) | hip circle centre | hips |
| 5 | body: black chest and lower body | hips (root) | master |
| 6 | belly (cream oval) | belly centre | body |
| 7 | straps | on the body | body |
| 8 | foot L / foot R (with toe lines) | ankle | leg |
| 9 | paw L / paw R (with toe lines): swap open, fist, grip | wrist | arm |
| 10 | head: cream circle, whole | neck (bottom centre of the head) | chest |
| 11 | tuft | its base | head |
| 12 | cheeks | on the head | head |
| 13 | eye patches L/R | on the head | head |
| 14 | eyes L/R: swap happy arc, open, wink, chevron, cross | patch centre | patch |
| 15 | nose | on the head | head |
| 16 | mouth: swap smile, grin, oh, tight, frown, wobble | under the nose | head |

The layer order follows Toon Boom: the top of the list draws over the bottom. Any part can be nudged forward or back for a pose; for
example, an arm reaching across his front goes in front of the belly.

## 4. Putting it back together: the hierarchy

Toon Boom's rule is a parent for every part, one chain per limb, and a master that holds everything:

    master (position and scale the whole character)
      hips
        leg L > foot L
        leg R > foot R
        body > belly, straps, backpack
          chest
            arm L > paw L
            arm R > paw R
            head > ears, tuft, cheeks, patches > eyes, nose, mouth

Each limb gets two bones (upper and lower) and skins on its mesh, so it bends at the elbow or knee instead of pivoting like a plank.

## 5. Swap sets, the drawing substitutions

These are whole drawings swapped on one part, never on the whole body:
- **Eyes:** happy arc, open (crescent), wink, chevron (strain), cross.
- **Mouths:** smile, grin, oh, tight, frown, wobble.
- **Paws:** open, fist, grip.
- **Views:** front, three-quarter, side, each a complete chain.

The face sets Codex draws as whole faces (`rm-face-*.png`) are the source: each face is traced into its eye and mouth swaps.

## 6. Checks before animating anything

1. The reassembled puppet at rest matches `rm-rest-a-happy.png` when laid over it.
2. Each joint turned 45° both ways shows no gap or seam.
3. A test pose (arms up, one knee up, head tilted) is shown to the owner as a still before any motion is made.

## The owner's method, from recordings (Studio's Record button, `projects/bubu/recordings/`)

The full catalogue, kept up to date, is **`lessons/LESSONS.md`**. It holds every recording, the owner's shapes, the rule each one
taught, and how to rewatch and re-score them. Read it before cutting anything. The notes below are the first three lessons as they
were written at the time.

**Head** (`2026-11-03-23-27-18.jsonl`, overlay in `out/puppet/lesson-head.png`):
- **One pen shape for the head and its tuft.** The tuft is part of the head's outline, not a separate piece.
- **Four points for the whole round head:** left, bottom and right, each at the outline's extreme, plus where the tuft starts. Each point has
  long curve handles that run along the edge: level at the bottom, upright at the sides. The detail goes where the shape has corners: 7
  points for the tuft's three spikes.
- **Rough first, then refined:** the shape was placed in about 30 s. About 4 minutes then went on dragging points and handles until the
  edge sat exactly on the drawing's edge. One point was added and taken back again, so he kept to as few points as possible.
- The model layer was made a guide, so it can't be picked while drawing. The colour was set last (cream `#FEF8E8`).
- The bottom of the head follows the visible edge. The head sits on top of the body, so nothing is hidden under it. The ears are not in
  the head shape: they go behind it.

**Arm** (`2026-11-03-23-37-39.jsonl`, overlay in `out/puppet/lesson-arm.png`):
- **The arm and paw are one shape, 8 points.** The paw isn't a separate piece, which goes against the Toon Boom rule in section 2. His
  choice for this design is that the paw is the arm's rounded end.
- **The hidden end is a round cap about the arm's width.** It goes past the visible shoulder, up under the strap and the bottom of the
  head, so the arm can swing without a gap.
- **Each toe line is its own small rounded shape (6 points) in the same layer.** It is drawn on top of the arm, in the grey picked from
  the drawing.
- The colours are picked from the drawing (`#393a36` dark, `#959491` grey).
- The workflow was the same as the head: placed in about 30 s, refined for about 3 minutes, with one point added.

**Claude's leg, by the same rules** (`lesson_fit.py`, layer "Leg_R (Claude)" in cut-lesson, check `out/puppet/lesson-leg.png`):
- The leg and foot are one shape with 9 points: a round cap under the belly, then outer edge, foot top, toe, sole and heel, inner edge.
- The toe lines are 6-point rounded shapes.
- The points are placed by hand, then nudged by least-squares onto the drawing's edge. The fit only counts edges against the backdrop:
  where the leg meets the belly is an overlap, not its outline. The points are bounded, which stops loops. The result sits 0.7 px off
  the drawing's edge on average.

**The owner's clean-up of that leg** (`2026-11-03-23-45-50.jsonl`, final `Leg_R-Claude--edit-60.svg`, check `out/puppet/lesson-leg-fix.png`):
- **The limb owns its whole visible outline, right up to where it goes under the covering part.** My cap started curving in at y≈1000.
  That left the strip of black between the belly and the outer edge (y 925–1000) uncovered. His outer edge follows the silhouette up
  to the hip, where it meets the belly at (850, 928). Only then does it round over, with an extra point there.
- **The cap is bigger and fully hidden.** It rises about 35 px above the hip and reaches about 8 px past the visible inner edge, so a
  turn never shows its edge.
- **The heel has a small step.** An extra point where the inner leg meets the foot makes a slight corner, not one smooth curve.
- **The toe lines have 8 points and bend with the drawn line.** Each end has a tip and two shoulders, and each side has a point
  halfway along. My 6-point straight capsules were too stiff.
- The result: 11 points on the leg (mine had 9).

After the fixes went into lesson_fit.py, the new leg matches his to within 5% of its area. Most of the gap is in the hidden cap; only
828 px differ where the leg can be seen.

What it changes for puppet_trace.py: hand-placed points at the extremes with tangent handles, not a dense traced contour smoothed
afterwards.

## Where it stands (4 Nov 2026, evening)

- **The master front puppet, `bubu-puppet-front` in Studio, is the owner's.** He cleaned it up himself:
  - nose, mouth, left eye, left brow, screen-left strap, hair, right leg and screen-left arm
  - each other side mirrored with `mirror_fix.py`
  - recorded as lessons 5-11 in `lessons/LESSONS.md`
  - `puppet_build.py` won't rebuild over his edits.
- **Motion test, `puppet-test`:** a copy of the master, made by `puppet_test.py` with `puppet_test_bones.py`, exports in
  `out/puppet/`.
  - **First clip, one-piece limbs** (`puppet-test.mp4`). The joints held. The owner's notes:
    - the wave's elbow looks broken; it should come out to the side and curve up, as his sketch (`_sketch.json`)
    - the face looks detached (open question: sliding, or flat when the head tilts?)
    - the ear looks a bit detached
  - **Ears:** now hinge on the head's edge (`puppet_elbow.py --ears`). The hinge was deep inside the head.
  - **A two-piece hinged elbow was tried and dropped:** it reads as a corner.
  - **Bones, Spine style:** each limb is one shape bound to bones. The waving arm is a 4-bone chain (armR1-4) bending 35 degrees
    each, plus a slide out from under the head. Shaped to his sketch: 68% of the sketched arm covered (`sketch_match.py`).
    Clips: `puppet-test-bend.mp4`, and `puppet-test-bend-fine.mp4` with a finer grid (cell 3, softness 5).
  - **The owner: "super crunchy and unsmooth"** on the inside of the bend and the outside of the elbow. The cause is Studio's
    skinning: a square grid over a bitmap, blended linearly, so the squeezed inside folds. A finer grid helps the outside but
    can't fix the cause.
- **Next: a Puppet tool in Studio,** like After Effects' and Photoshop's (owner, 4 Nov):
  - a triangle mesh fitted inside the part's outline
  - pins placed and keyed
  - an as-rigid-as-possible solve each frame (Igarashi et al. 2005), so a bend squashes evenly instead of folding
  - the vector outline bent itself, so edges stay crisp
  - Then redo the wave with pins (shoulder, elbow, wrist, paw) against his sketch, and give all four limbs the same.
- **Studio export with bones** takes about 2 minutes. The MCP tool times out first, but the file still lands; wait for it.
- **Studio change left for the owner to commit:** `src/renderer/src/shapes.ts` `growToFit`. An edit past an SVG's box grows the
  box instead of being clipped (the nose).

## Where it stands (4 Nov 2026)

- **Done before:**
  - Front rest pose, the three-quarter view and the redrawn side view (`rm-rest-side.png`).
  - Six faces (`rm-face-*.png`). The grin is accepted for now; the oops face came back neutral, not sorry.
- **The front puppet, cut the owner's way: `puppet_build.py`.** It makes the Studio document `bubu-puppet-front`, with 21 parts and a
  hips null. It replaces `puppet_trace.py` and the ragged `bubu-puppet` document.
  - The limbs and ears come from `lesson_fit.py`, which holds the rules from the owner's recordings (`lessons/LESSONS.md`). The head
    is the owner's own.
  - Round pieces (belly, patches, cheeks, nose) have 4 points at their extremes in their own frame.
  - Strokes (eye arcs, brows, mouth, straps) have 8 points bent along the line. The straps' hidden ends bend in under the belly,
    because running straight on they showed past its side.
  - The torso has no outline of its own from the front. It's one smooth body that fills the chest and reaches each shoulder and hip
    joint.
- **Checks** (in `out/puppet/`):
  - `front-rebuilt.png` / `front-diff.png`: 0.63% of pixels differ from the drawing, almost all of it anti-aliasing on edges. What's
    left is a sliver of 2-4 px along the arms' inner edges by the straps.
  - `front-parts.png`: every part alone is a whole, clean shape.
  - `front-joints.png`: arms out, up and in, legs out, head tilt and a wave, with no gaps at the joints. Arms raised straight up go
    behind the head, which is the layer order working.
  - `front-studio-wave.png`: the same wave keyed in Studio. Parenting carries the parts correctly there.
- **Next:**
  - The owner reviews the puppet.
  - Elbows and knees: limbs are one piece each, so they bend only at the shoulder and hip for now.
  - The face swaps (open eyes and the mouths from `rm-face-*.png`), cut by the same rules.
  - The three-quarter and side views, each as its own chain.
