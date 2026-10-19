"""Codex jobs, take two (the owner: "can use bubu the panda as our main guy"): the achievement badges as Bùbù doing each
family's thing, standing on a plaque, as Duolingo's badges are a character on a plaque, but ours: Bùbù, and the plaque a
Chinese garden window (a four-lobed begonia window), one a tier: clay, bronze, silver, gold, jade. The app lays Bùbù
over the tier's plaque (a little bigger, so he breaks out of its top) and writes the tier's number at the bottom, the
name and "3 of 5" under it; so no number or text in any picture. Supersedes add_achievements.py (round medals)."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
# the house style, Bùbù himself and the backdrop, word for word from his poses; only the pose is new
BASE = [j for j in jobs if j['file'] == 'out/raw/panda-lantern-festival.png'][0]['prompt']
HEAD, TAIL = BASE[:BASE.index('Pose:')], BASE[BASE.index('\n\nBackground:'):]
PANDAS = ['refs/panda-celebrate.png', 'refs/panda-waving.png', 'refs/panda-reading.png', 'refs/panda-teacher.png']

POSE = ("Pose: an ACHIEVEMENT BADGE of Bùbù {what} Lively and proud, a clear readable pose with ONE main prop, so it "
        "reads at a glance when shown small (80 to 100 pixels). Full body, centred, filling about 80% of the canvas "
        "height, his feet near the bottom; nothing else on the canvas: no ground, no scenery, no frame, no badge shape "
        "behind him (the app puts him on the badge). Square canvas.")

poses = [
    ("lantern-keeper", "holding a glowing round red lantern high above his head with both paws, beaming, the lantern "
                       "lit warmly from inside with a gold tassel."),
    ("step-by-step", "mid-hop from one flat round grey stepping stone to the next, one foot up, arms out for balance, "
                     "a second stone under him (just the two stones, no water)."),
    ("word-garden", "watering a young bamboo shoot in a small cream pot with a little teal watering can, the shoot "
                    "with three fresh green leaves, Bùbù smiling at it."),
    ("brush-and-ink", "holding a big calligraphy brush upright in both paws like a proud artist, a dab of black ink "
                      "on his cheek, the brush tip black."),
    ("copybook", "sitting with a sheet of cream practice paper with a red square grid on his lap, tongue poking out "
                 "in concentration, drawing ONE black brush stroke on it (a single stroke, not a character)."),
    ("mountain-climber", "standing on a small rounded jade-green mountain top, planting a little red flag, his "
                         "backpack on, one fist raised."),
    ("storyteller", "reading aloud from a half-unrolled cream scroll held in one paw, the other paw raised "
                    "dramatically, mouth open mid-story (grey lines on the scroll for writing, no letters)."),
    ("seal-collector", "pressing a big jade-green seal stamp down with both paws onto a sheet of cream paper, a red "
                       "square seal mark beside it (an abstract square pattern of red lines, NOT a character)."),
    ("lucky-pockets", "hugging an armful of red envelopes with gold rims, a couple of round gold coins with square "
                      "holes tumbling out, delighted."),
    ("pathfinder", "wearing a little explorer's straw hat, peering at an ancient Chinese spoon compass (a bronze "
                   "spoon on a square bronze plate) held out in front of him."),
    ("rekindled", "kneeling and gently blowing on a small DIM, unlit red paper lantern on the ground, a tiny golden "
                  "spark just catching at its bottom, Bùbù hopeful."),
    ("flawless", "holding a round pale-green jade disc (a bi, with a round hole) up above his head in both paws, a "
                 "few small sparkles round it, eyes shut with pride."),
    ("night-owl", "in soft teal pyjamas and a floppy nightcap, reading a small book by the light of a little hand "
                  "lantern, a pale crescent moon floating behind his shoulder."),
    ("early-bird", "doing a slow tai chi stretch, one leg raised and both arms out, a warm golden rising sun behind "
                   "him, eyes calm."),
    ("lightning-fast", "sprinting flat out, a red headband streaming behind him, ears back, soft speed curves "
                       "behind him."),
    ("kung-fu-master", "in a confident kung fu stance, one paw forward, holding a wooden practice staff behind him "
                       "in the other, a red sash round his middle."),
    ("dressed-up", "wearing a green dragon-costume hood with two little yellow horns and a red crest over his own "
                   "head, striking a cheeky roaring pose with his paws up like claws."),
]

PLAQUE = ("An ACHIEVEMENT BADGE PLAQUE, the {name} tier: a flat badge in the shape of a traditional Chinese garden "
          "window, a four-lobed begonia (crabapple) window: four soft rounded lobes, wider than tall a little, "
          "symmetrical. A thick raised rim made of {what} The inside is a smooth flat panel of a lighter, softer shade "
          "of the same material, empty (the app puts Bùbù on it). Seen straight on, centred, filling about 88% of the "
          "canvas width. The five tiers are a set: draw the SAME shape, size and rim thickness; only the material "
          "differs. ")

plaques = [
    ("1-clay", "Clay", "warm terracotta fired clay, matte and earthy, the plainest."),
    ("2-bronze", "Bronze", "warm brown antique bronze with a soft dull sheen (clearly browner and darker than the clay)."),
    ("3-silver", "Silver", "soft polished silver in cool light greys."),
    ("4-gold", "Gold", "soft warm gold, muted and buttery rather than bright yellow, with gentle highlights."),
    ("5-jade", "Jade", "polished pale-green jade with soft lighter veins, glowing a little from within: the most "
                       "precious."),
]
STYLE = HEAD[HEAD.index('Style:'):HEAD.index('Character:')].strip()

new = [{"file": f"out/raw/achv2-{n}.png", "group": "achievements2", "size": "1024x1024", "refs": PANDAS,
        "prompt": HEAD + POSE.format(what=what) + TAIL} for n, what in poses]
new += [{"file": f"out/raw/achv2-plaque-{n}.png", "group": "achievements2", "size": "1024x1024",
         "refs": ['out/raw/pk-ingot.png', 'refs/ref-land-pavilion.png'],
         "prompt": PLAQUE.format(name=name, what=what) + "Flat, soft storybook vector style, no outlines, 2 to 3 "
                   "soft tones, a faint paper grain, matching the attached art." + "\n\n" + STYLE + TAIL}
        for n, name, what in plaques]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', len(added))
