"""Codex jobs for the course's cast (the owner, 23 Oct 2026: "we'll be talking with different people ... generate some
characters, design them"), drawn as people in the app's storybook style: the same chunky proportions as the player's
avatar (a big round head, a small body, rounded hands and shoes), flat colour with soft shading, no outlines. Mark is
the player, so he's the avatar; the five he talks to are designed here, each a full-figure sheet to choose from before
their chat photos, poses and talking faces are made. Group "cast", saved as out/raw/cast-*.png.

The facts are bubu-course/STYLE.md's: keep them (ages in 起步 1, jobs, what they carry).
"""
import json

import make_prompts as mp

AV = "refs/ref-player-avatar.png"
PANDA = "refs/panda-waving.png"
# (tightened after the first try, the owner, 23 Oct 2026: "make sure it matches as close to our one we made in our
# studio": she came out taller and slimmer than the avatar, and grainy; the eyes' sparkle the owner kept: "I actually
# like the eye sparkle")
REF = ("The first attached image is the app's player avatar, made in our studio: draw this person to match it as closely "
       "as possible, as if from the same set. Its proportions exactly, measured on it: the head (top of the hair to the "
       "chin) is HALF the figure's whole height, so it's only about 2 heads tall; the head is WIDER than the shoulders, "
       "a little over half the height across; a short compact body; short, THICK, stumpy legs, each about a quarter as "
       "wide as the head, set a little apart; big chunky rounded shoes; short arms with small round mitten hands; big "
       "round flat ears. (Slim legs and a smaller head are the mistakes to avoid: the first drafts had legs half as "
       "thick and a head 15% smaller.) Its face: the eyes tall black ovals set wide apart, each with one white "
       "sparkle, a small tilted oval high on the right of the eye (the owner's pick), small arched brows, a tiny soft nose, rosy round cheeks. Its finish exactly: flat "
       "colour, no paper grain or texture, at most one soft darker tone on the hair and the clothes' folds, no outlines. "
       "The other attached image is the app's mascot Bùbù, for the palette. Do not copy the avatar's clothes or hair. ")
POSE = ("Standing, facing the viewer, full figure from head to shoes, arms relaxed (one doing what's described), friendly "
        "and natural, centred, filling about 85% of the height. ")
END = "\n\n" + mp.STYLE + "\n\n" + mp.KEY

# the five Mark talks to (STYLE.md: CAST)
CAST = [
    ("cast-xiaoyu", "林小雨 Lín Xiǎoyǔ, a young Chinese woman of 22 from Chengdu, a design student in London, a musician "
     "and Mark's patient teacher. Long straight black hair, half of it tied up in a small bun, a soft fringe; small gold "
     "hoop earrings. A mustard-yellow cardigan over a white T-shirt, a teal skirt to the knee, white trainers; a plain "
     "cream canvas tote bag on her shoulder (nothing on it). Kind, bright, a happy open smile; one hand holding a small "
     "sage-green spiral sketchbook to her chest. The last attached image is her current drawing, the owner's pick: "
     "keep EVERYTHING about it (her design, her pose, her face and smile, the sketchbook, the plain bag, the colours) "
     "and change only her proportions to the avatar's: a bigger head (half her whole height, wider than her "
     "shoulders), so she's about 2 heads tall, and shorter, much thicker legs (each a quarter as wide as her head). "
     "Eyes with the white sparkle, as in that drawing's first draft."),
    ("cast-chenming", "陈明 Chén Míng, a Chinese man of 32 from Beijing, chef and owner of a dumpling restaurant in London's "
     "Chinatown. Short black hair a little messy, a warm teasing grin, slightly tired eyes. A white chef's jacket with "
     "red buttons and the sleeves rolled up, dark trousers, a red kitchen towel over one shoulder; he holds up a small "
     "bamboo steamer of dumplings in one hand, as if offering it."),
    ("cast-chenmama", "陈妈妈, Chén Míng's mother, a Chinese woman of about 58 from Beijing who runs the front of the "
     "family's dumpling restaurant and feeds everyone. Short permed black hair with grey at the temples, round "
     "glasses, a warm fussy smile. A floral blouse (small red and pink flowers on cream) under a red apron, dark "
     "trousers, comfortable flat shoes; she holds a steaming bowl of soup in both hands, about to make you eat it."),
    ("cast-chenbaba", "陈爸爸, Chén Míng's father, a retired Chinese man of about 64 from Beijing; he loves Beijing opera "
     "and his tea, and has bad knees. Short grey hair thinning on top, kind crinkled eyes, a calm content smile. A "
     "cream shirt under a brown knitted waistcoat, grey trousers, black cloth shoes; a glass tea flask with green tea "
     "leaves in it in one hand, a simple wooden walking stick in the other, leaning on it a little."),
    ("cast-duoduo", "朵朵 Duǒduo, a Chinese girl of 8, born in London, Chén Míng's daughter: bright, cheeky and full of "
     "questions. Black hair in two round buns on top of her head with red hair ties, a short fringe, a big gap-toothed "
     "grin. A red and white striped top, denim dungarees, yellow wellies; a little backpack shaped like a dumpling; "
     "one hand raised high as if she's asking a question. Child proportions: smaller than the adults, an even bigger "
     "head for her body."),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "cast"]
    for name, who in CAST:
        refs = [AV, PANDA] + (["refs/ref-xiaoyu-v2.png"] if name == "cast-xiaoyu" else [])
        jobs.append({"file": f"out/raw/{name}.png", "group": "cast", "size": "1024x1536", "refs": refs,
                     "prompt": REF + "Draw ONLY " + who + "\n\n" + POSE + END})
    # the five together, one lineup, to check they belong to one world (and to each other's sizes)
    lineup = "; ".join(w.split(",")[0] for _, w in CAST)
    jobs.append({"file": "out/raw/cast-lineup.png", "group": "cast", "size": "1536x1024", "refs": [AV, PANDA],
                 "prompt": REF + "Draw ONLY these five people standing side by side in a row, each as described, facing the "
                 "viewer, full figures, the adults about the same height and the 8-year-old girl a head shorter: "
                 + " ".join(w for _, w in CAST) + "\n\nIn the order: " + lineup + ". " + END})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(CAST) + 1, "cast jobs")
