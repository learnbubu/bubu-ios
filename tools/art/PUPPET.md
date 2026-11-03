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

## Where it stands (3 Nov 2026, paused by the owner)

- **Done:**
  - Front rest pose, the three-quarter view and the redrawn side view (`rm-rest-side.png`).
  - Six faces (`rm-face-*.png`). The grin is accepted for now; the oops face came back neutral, not sorry.
- **puppet_trace.py:** the front traced into 25 vector parts, written to the Studio document `bubu-puppet`, with checks in
  `out/puppet/` (rebuilt.png, joints.png, parts.png).
  - The rebuilt puppet matches the drawing to within 0.5% of pixels, and parenting works in Studio.
  - Studio only carries a child with its parent when the move is keyed. Changing a part's resting value moves it alone.
- **Not clean yet (owner: "make sure the arms and legs take into consideration what's underneath"):** parts.png shows ragged limb
  pieces: a spike on top of each leg, a clipped blob at each shoulder, notches on the paws and feet, crescent ears and a spiked strap
  top. They come from bolting hidden areas on by mask arithmetic.
- **Next:**
  - Rebuild the arms and legs as swept shapes: circles along the limb's axis, sized to the drawing's width at each point, with
    round ends. Paws and feet become one smooth blob each (the convex hull of the drawn part plus the wrist or ankle circle).
  - Ears become whole fitted circles.
  - The torso becomes one smooth convex body that covers everything under the arms and legs.
  - Check every part alone (parts.png) and zoom on each joint at ±45° before moving on.
