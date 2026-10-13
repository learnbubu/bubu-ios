"""Codex jobs: Bùbù the teacher (out/raw/home-teacher-pose.png) split into layers for Home's idle animation: his body,
his head, his head blinking, the arm with the pointer, the arm with the book. Each an edit of that picture, the same
size and place on the canvas, so the layers stack back into it exactly."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
STYLE = [j for j in jobs if j['file'] == 'out/raw/home-teacher-pose.png'][0]['prompt']
STYLE = STYLE[STYLE.index('\n\nStyle:'):]
SRC = "out/raw/home-teacher-pose.png"
KEEP = ("Keep it EXACTLY as it is in the picture - the SAME size, the SAME place on the canvas (do not move, re-centre or resize it), the same "
        "shapes, colours and lighting - and remove everything else, leaving flat magenta (#FF00FF) where it was. No text, no letters.")
INTRO = "The attached image is Bùbù the panda teacher, a finished picture from the app. EDIT it to make ONE LAYER of it for animation: keep ONLY "

layers = [
    ("body", "his BODY: his torso and tummy down to the bottom edge, his shoulders, and his red backpack and its straps - WITHOUT his head, WITHOUT "
             "either arm, WITHOUT the book and WITHOUT the pointer. Where his head, arms or the book covered his body, draw that part in, whole and "
             "continuous (his white tummy and black shoulders, the backpack behind), so the body is complete under them. At the neck, continue the "
             "body a little way up under where the head was, in a soft rounded shape, so the head can tilt over it without a gap. At each shoulder, "
             "end the black fur in a soft rounded shape where the arm joined, so each arm can turn there without a gap."),
    ("head", "his HEAD: his whole head with his ears, his round glasses, his face exactly as it is (eyes, cheeks, open smiling mouth) - WITHOUT his "
             "body, arms, book or pointer. Where the pointer or a paw covered part of his head, draw that part in, whole. Give the bottom of his head "
             "a soft rounded edge where it met his body."),
    ("head-blink", "his HEAD, exactly as in the head on its own, but BLINKING: his eyes closed as two gentle downward-curved lines (happy closed "
                   "eyes) behind the SAME glasses, everything else the same - ears, glasses, cheeks, open smiling mouth - WITHOUT his body, arms, "
                   "book or pointer. Give the bottom of his head a soft rounded edge where it met his body."),
    ("arm-pointer", "his RAISED ARM holding the POINTER (the arm on our right): from where it joins his shoulder to his paw, with the thin wooden "
                    "pointer in his paw, exactly as it is - WITHOUT the rest of him. At the shoulder, draw the arm continuing a little way into "
                    "where the body was, ending in a soft ROUNDED end of black fur, so it can swing there without a gap."),
    ("arm-book", "his ARM HOLDING THE BOOK (the arm on our left) and the open green BOOK: from where the arm joins his shoulder, his paw and the "
                 "book, exactly as they are - WITHOUT the rest of him. At the shoulder, draw the arm continuing a little way into where the body "
                 "was, ending in a soft ROUNDED end of black fur."),
]
new = [{"file": f"out/raw/home-teacher-{n}.png", "group": "home7", "size": "1024x1024",
        "refs": [SRC, "refs/ref-rig-idle.png"] + (["out/raw/home-teacher-head.png"] if n == "head-blink" else []),
        "prompt": INTRO + what + " " + KEEP + STYLE} for n, what in layers]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', [j['file'] for j in added])
