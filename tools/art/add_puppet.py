"""Bùbù's rest pose in the new flat style (owner, 3 Nov 2026): the hero drawings (out/raw/rm-hero-1..5) are all action poses, and a puppet
is built from one neutral pose, straight on, with every limb clear of the body so its whole shape shows. Two takes, saved as
out/raw/rm-rest-a.png and rm-rest-b.png, to pick from.

From tools/art: ../sfx/.venv/Scripts/python -I add_puppet.py
"""
import json

jobs = json.load(open("jobs.json", encoding="utf-8"))
jobs = [j for j in jobs if j["group"] != "puppet"]
REST = ("The attached images are Bùbù the panda, drawn in a flat style with no black outline. Draw him once more in exactly that style, the same "
        "proportions, colours and shapes as the first three images, as a neutral rest pose for a character rig. He stands straight and faces us "
        "head on, perfectly symmetrical: his weight even on both feet, his legs a little apart with the feet flat and pointing slightly outward, "
        "his arms held away from his body and angled down, about 30 degrees out from his sides, the paws open and relaxed. No limb overlaps his "
        "body or another limb, so the whole outline of each arm and leg shows. A calm, friendly face: small round black eyes inside the round eye "
        "patches, and a small closed smile. Keep his design: the round eye patches, the tuft of hair on top of his head, his cheeks, two single "
        "muted red straps that never cross, and two grey toe lines on each paw and foot. He holds nothing: no seal. His whole body is in frame "
        "with plenty of room round him, centred. No action lines, sparkles, shadow, ground or text. The backdrop is one flat solid magenta "
        "(#FF00FF) with nothing else on it.")
for take in "ab":
    jobs.append({"file": f"out/raw/rm-rest-{take}.png", "group": "puppet", "size": "1024x1024",
                 "refs": ["out/raw/rm-hero-4.png", "out/raw/rm-hero-5.png", "out/raw/rm-hero-1.png", "out/raw/rm-master.png"], "prompt": REST})
# take A's small staring eyes read as scary (owner, 3 Nov 2026): edits of take A with only the eyes changed. The blink edit of rm-hero-5
# lost his eye patches, so the prompt holds them in place.
EYES = ("Edit the attached drawing of a panda and keep everything exactly as it is: the same pose, size, position, colours, head, ears, tuft, "
        "cheeks, nose, mouth, straps, paws and flat magenta backdrop. Keep both big black eye patches exactly as they are, the same size, shape "
        "and place. Change only the eyes inside the patches: {} Change nothing else.")
for name, eyes in (("happy", "draw each eye as a soft, happy closed upward arc in cream, like a smile, as in the second attached image."),
                   ("soft", "make each eye a big, friendly, gently tall oval in very dark brown, filling about half of its patch, set a little low, with a "
                            "large round white highlight at the top and a small one below it, so he looks warm, cute and gentle, never staring.")):
    jobs.append({"file": f"out/raw/rm-rest-a-{name}.png", "group": "puppet", "size": "1024x1024", "refs": ["out/raw/rm-rest-a.png", "out/raw/rm-hero-4.png"],
                 "prompt": EYES.format(eyes)})
# the soft eyes read as anime (owner): his open eyes are the classroom teacher's (out/raw/ref-teacher-eyes.png), the black patch
# itself with a big white crescent. Happy arcs stay his main face; this is the swap for when he looks at something.
jobs.append({"file": "out/raw/rm-rest-a-open.png", "group": "puppet", "size": "1024x1024", "refs": ["out/raw/rm-rest-a.png", "out/raw/ref-teacher-eyes.png"],
             "prompt": EYES.format("draw his eyes the way the panda's are in the second attached image: no separate eyeball, the black patch itself "
                                   "is the eye, with one big white crescent highlight curving round inside each patch, both crescents on the same "
                                   "side so he looks gently ahead and a little up, friendly and bright. Copy only the eyes from the second image: no "
                                   "glasses, nothing else from it.")})
# the turnaround (owner, 3 Nov 2026: "start building the 3 angles"): the front is rm-rest-a-happy; three-quarter and side are drawn from it at
# the same height and place, so the views swap on one rig
TURN = ("The first attached image is Bùbù the panda's front rest pose for a character rig. Draw the same character, in exactly the same flat style, "
        "colours, proportions and size, turned {}, as the next view of a professional character turnaround sheet. Same height on the canvas, the soles "
        "of his feet on the same line, his body centred in the same place. The same neutral stance: standing straight, weight even, arms held a little "
        "away from his body and angled down, paws open and relaxed. {} The same happy face: closed eyes drawn as soft cream upward arcs inside the black "
        "eye patches, and a small closed smile. Keep his design: the round black ears, the tuft of hair, the pink cheek, his black chest and limbs, the "
        "cream belly, two single muted red backpack straps that never cross, and two grey toe lines on each paw and foot. He holds nothing. No outline, "
        "shadow, ground, lines or text. The backdrop is one flat solid magenta (#FF00FF) with nothing else on it.")
for name, turn, extra in (("quarter", "three-quarters to our right (his left side toward us, turned about 45 degrees)",
                           "We see his face from three-quarters: the near eye patch and cheek larger, the far ones narrower and partly round the curve of his head, "
                           "his nose and mouth moved toward the far side. Both ears show. The far arm and leg are partly behind his body but still show."),
                          ("side", "fully side on, facing to our right, a true profile",
                           "We see one eye patch, one cheek, his nose at the front edge of his face and the smile in profile. One round ear on top of his head, "
                           "just behind the middle, with the far ear barely peeking out behind it. His near arm starts at his shoulder, right under his head, "
                           "and hangs straight down along his side, clearly in front of everything, its paw by his hip; his far arm is hidden. A small backpack "
                           "sits flat on his back, behind the arm and the strap, never in front of the arm. His near leg is in front of the far one, both "
                           "feet pointing right, his round belly toward the right.")):
    jobs.append({"file": f"out/raw/rm-rest-{name}.png", "group": "puppet", "size": "1024x1024",
                 "refs": ["out/raw/rm-rest-a-happy.png", "out/raw/rm-hero-5.png", "out/raw/rm-master.png"], "prompt": TURN.format(turn, extra)})
# the front face set: edits of rm-rest-a-happy with only the face changed, the expressions he uses in the hero board plus the two a lesson needs
FACE = ("Edit the attached drawing of a panda and keep everything exactly as it is: the same pose, size, position, colours, head, ears, tuft, cheeks, "
        "nose, body, straps, paws and flat magenta backdrop. Keep both big black eye patches the same size, shape and place. Change only his eyes and "
        "mouth: {} Draw them in the same flat style as the second attached image. Change nothing else.")
for name, ref, face in (
        # the owner isn't keen on this big open grin but it'll do for now (3 Nov 2026); the teacher's small open smile is the replacement
        ("grin", "rm-hero-4", "the same happy closed arc eyes, and a big open happy grin with a pink tongue, as in the second image."),
        ("wink", "rm-hero-5", "his left eye a happy closed arc, his right eye a tight wink, and a big open happy grin, as in the second image."),
        ("strain", "rm-hero-2", "both eyes screwed tightly shut as sideways chevrons, and a small tight determined mouth, as in the second image."),
        ("cross", "rm-hero-3", "fierce determined eyes, the white eyes narrowed and slanted inside the patches, and a small set frown, as in the second image."),
        ("oh", "ref-teacher-eyes", "open eyes as in the second image (the black patch with a big white crescent highlight; no glasses), and a small round "
                                   "surprised 'oh' mouth."),
        ("oops", "ref-teacher-eyes", "open eyes as in the second image: no pupil or eyeball, the black patch itself is the eye, with one big white crescent "
                                     "highlight curving round inside it (no glasses). The patches' top "
                                     "edges tipped down at the outside a little so he looks sorry, and a small wobbly unsure mouth. Gentle, never sad or "
                                     "upset.")):
    jobs.append({"file": f"out/raw/rm-face-{name}.png", "group": "puppet", "size": "1024x1024", "refs": ["out/raw/rm-rest-a-happy.png", f"out/raw/{ref}.png"],
                 "prompt": FACE.format(face)})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("puppet jobs added")
