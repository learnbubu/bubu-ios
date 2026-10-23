"""Codex jobs for the course's cast (the owner, 23 Oct 2026: "we'll be talking with different people ... generate some
characters, design them"), drawn as people in the app's storybook style. Mark is the player, so he's the avatar; the
five he talks to are designed here, each a full figure. Group "cast", saved as out/raw/cast-*.png.

How their sizes are kept (the owner, 23 Oct 2026: "really need to lock in sizes", "say about the face without the hair
to keep the same", "a bald version of our char from studio we can attach to the brief", and "I want codex to fix this
not you"): each is drawn OVER the studio avatar with no hair (refs/ref-cast-base.png), so the face, ears, body and
their sizes are the avatar's; only the hair, clothes and what they hold are their own. check_head.py measures the
result (the face without its hair against the body) and Codex draws again if it's off. The eyes are drawn plain and
add_sparkle.py puts the owner's sparkle in, the same on all.

The facts are bubu-course/STYLE.md's: keep them (ages in 起步 1, jobs, what they carry).
"""
import json

import make_prompts as mp

BASE = "refs/ref-cast-base.png"            # the studio avatar, no hair, on the jobs' canvas
AV = "refs/ref-player-avatar.png"          # the studio avatar as he is
PANDA = "refs/panda-waving.png"            # Bùbù, for the palette

BRIEF = ("The FIRST attached image is the base: our studio avatar with his hair as a plain GREY shape. Draw this person "
         "ON that base, exactly: keep its head shape and size, its face (where the eyes, nose, mouth and cheeks sit, and "
         "how big), its ears, its body, arms, legs and shoes, and its size and place on the canvas. Then replace the grey "
         "with this person's own hair, covering at least the same area: the fringe comes down just as low over the "
         "forehead (only as much forehead shows as on the base), and the hair may be bigger, longer or higher. Then their "
         "own clothes and what they hold, as described. "
         "The SECOND attached image is the same avatar with his hair: the finish to match, flat colour, no paper grain "
         "or texture, at most one soft darker tone on the hair and the clothes' folds, no outlines. "
         "The THIRD is the app's mascot Bùbù, for the palette. "
         "The eyes: PLAIN tall black ovals as the base's, with no white in them (a sparkle is added to every drawing "
         "afterwards, the same on all). Do not copy the avatar's clothes. ")
POSE = ("Standing, facing the viewer, full figure from head to shoes, arms relaxed (one doing what's described), friendly "
        "and natural, as the base stands. ")
END = "\n\n" + mp.STYLE + "\n\n" + mp.KEY

# the five Mark talks to (STYLE.md: CAST)
CAST = [
    ("cast-xiaoyu", "林小雨 Lín Xiǎoyǔ, a young Chinese woman of 22 from Chengdu, a design student in London, a musician "
     "and Mark's patient teacher. Long straight black hair, half of it tied up in a small bun, a soft fringe; small gold "
     "hoop earrings. A mustard-yellow cardigan over a white T-shirt, a teal skirt to the knee, white trainers; a plain "
     "cream canvas tote bag on her shoulder (nothing on it). Kind, bright, a happy open smile; one hand holding a small "
     "sage-green spiral sketchbook to her chest."),
    ("cast-chenming", "陈明 Chén Míng, a Chinese man of 32 from Beijing, chef and owner of a dumpling restaurant in London's "
     "Chinatown. Short black hair a little messy, a warm teasing grin. A white chef's jacket with red buttons and the "
     "sleeves rolled up, dark trousers, a red kitchen towel over one shoulder, one hand on his hip; he holds up a small "
     "bamboo steamer of dumplings in the other, as if offering it."),
    ("cast-chenmama", "陈妈妈, Chén Míng's mother, a Chinese woman of about 58 from Beijing who runs the front of the "
     "family's dumpling restaurant and feeds everyone. Short permed black hair with grey at the temples, round "
     "glasses, a warm fussy smile. A floral blouse (small red and pink flowers on cream) under a red apron, dark "
     "trousers, comfortable flat shoes; she holds a steaming bowl of soup in both hands, about to make you eat it."),
    ("cast-chenbaba", "陈爸爸, Chén Míng's father, a retired Chinese man of about 64 from Beijing; he loves Beijing opera "
     "and his tea, and has bad knees. Short grey hair thinning on top, kind crinkled eyes, a calm content smile. A "
     "cream shirt under a brown knitted waistcoat, grey trousers, black cloth shoes; a glass tea flask with green tea "
     "leaves in it in one hand, a simple wooden walking stick in the other, leaning on it a little."),
    ("cast-duoduo", "朵朵 Duǒduo, a Chinese girl of 8, born in London, Chén Míng's daughter: bright, cheeky and full of "
     "questions. Black hair in two round buns on top of her head with red hair ties, a short fringe, a big happy open "
     "smile like the others' (NO teeth showing, no gap). A red and white striped top, denim dungarees, yellow wellies; "
     "a plain small coral-red backpack on both shoulders (just its straps and a bit of it showing, nothing on it); "
     "one hand raised high as if she's asking a question. She's a child: draw the base a little smaller overall (about "
     "four fifths of its height), the same shape."),
]

# the approved designs, attached last: keep each one's look, redrawn over the base
DESIGNS = {"cast-xiaoyu": "refs/ref-cast-xiaoyu.png", "cast-chenming": "refs/ref-chenming-v1.png"}
KEEP = ("The LAST attached image is this person's approved design: keep everything about it (the hair, clothes, what "
        "they hold, pose, expression, colours) and redraw it over the base, so the face and body are the base's size.")
LIKE = ("The LAST attached image is Xiaoyu, already approved: draw this person as from the same set as her.")

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "cast"]
    for name, who in CAST:
        refs = [BASE, AV, PANDA, DESIGNS.get(name, "refs/ref-cast-xiaoyu.png")]
        jobs.append({"file": f"out/raw/{name}.png", "group": "cast", "size": "1024x1536", "refs": refs,
                     "prompt": BRIEF + "Draw ONLY " + who + "\n\n" + POSE + (KEEP if name in DESIGNS else LIKE) + END})
    # the five together, one lineup, to check they belong to one world (and to each other's sizes)
    lineup = "; ".join(w.split(",")[0] for _, w in CAST)
    jobs.append({"file": "out/raw/cast-lineup.png", "group": "cast", "size": "1536x1024",
                 "refs": [BASE, AV, PANDA, "refs/ref-cast-xiaoyu.png", "refs/ref-chenming-v1.png"],
                 "prompt": BRIEF.replace("Draw this person ON that base", "Draw each person on that base") +
                 "Draw ONLY these five people standing side by side in a row, each as described, facing the viewer, full "
                 "figures, each built on the base at the same size (the 8-year-old girl a little smaller): "
                 + " ".join(w for _, w in CAST) + "\n\nIn the order: " + lineup + ". The last two attached images are "
                 "Xiaoyu's and Chén Míng's approved designs." + END})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(CAST) + 1, "cast jobs")
