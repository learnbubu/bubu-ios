"""Codex jobs: the achievement badges (docs/achievements.md): 17 emblems, one a family, each read at a glance inside
a small round medal; and 5 medal rims, one a tier (clay, bronze, silver, gold, jade), the middle left empty for the
app to put the emblem in. The app draws the disc, the lock and the tier pips, so none of that is in the pictures."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
STYLE = [j for j in jobs if j['file'] == 'out/raw/lantern-icon-lit.png'][0]['prompt']
STYLE = STYLE[STYLE.index('\n\nStyle:'):]

# the same set: the simplified lantern icon, and the red pocket and gold ingot from the pocket's reward
ICONS = ['out/raw/lantern-icon-lit.png', 'out/raw/pk-ingot.png', 'refs/ref-pk-red.png']

EMBLEM = ("An ACHIEVEMENT BADGE EMBLEM for the app, to be shown small (48 to 64 pixels) in the middle of a round "
          "medal, so it must read at a glance at that size: {what} Bold, chunky, simple silhouette with only 2 to 3 "
          "soft tones; no fine detail, no small pattern, no outline. The same simplified look as the attached icons "
          "(first image especially), from the same set. Upright, centred, filling about 70% of the canvas, even "
          "magenta all round, nothing else on the canvas: NO disc, NO ring, NO medal or frame behind it (the app "
          "draws those).")

emblems = [
    ("lantern-keeper", "a round red paper lantern, lit and glowing warmly from inside, with a gold top cap, a gold "
                       "bottom cap and a short gold tassel."),
    ("step-by-step", "three flat round grey stepping stones crossing a small curve of teal pond water, seen from a "
                     "little above, the stones getting slightly larger towards us, one lily pad beside them."),
    ("word-garden", "a young bamboo shoot with three fresh jade-green leaves, growing from a small round cream "
                    "ceramic pot."),
    ("brush-and-ink", "a Chinese calligraphy brush with a bamboo handle and a dark tip, lying across a small "
                      "rectangular charcoal inkstone with a little pool of black ink."),
    ("copybook", "a square sheet of cream practice paper with a red tian-grid (a square divided into four by a cross "
                 "of thin red lines), and ONE thick black brush stroke across it (a single sweeping stroke, not a "
                 "character)."),
    ("mountain-climber", "a tall rounded misty jade mountain peak with a soft cloud around its middle and a small "
                         "red flag on the very top."),
    ("storyteller", "a half-unrolled cream paper scroll with a wooden roller at each end and a red ribbon, a few "
                    "soft grey lines on it standing for writing (no letters, no characters)."),
    ("seal-collector", "a traditional Chinese seal stamp: a short square stone handle in jade green with a rounded "
                       "top, standing beside a small square red seal impression on cream paper. The impression is a "
                       "simple abstract square pattern of red lines, NOT a character."),
    ("lucky-pockets", "a red envelope (red pocket) with a simple gold rim, a round gold coin with a square hole "
                      "peeking out of its top."),
    ("pathfinder", "the ancient Chinese spoon compass: a round dark-bronze ladle-shaped spoon balanced on a square "
                   "flat bronze plate with a smooth round centre, the spoon's handle pointing to the side."),
    ("rekindled", "a small red paper lantern, unlit and dim, with a bright little golden spark and a curl of warm "
                  "light touching its bottom, just catching alight."),
    ("flawless", "a round polished jade disc (a bi) with a round hole in the middle, pale glowing green with a soft "
                 "shine, a short red silk cord tied through the hole."),
    ("night-owl", "a small round owl in soft greys and cream with big friendly eyes, sitting on a short branch, a "
                  "pale gold crescent moon behind its shoulder."),
    ("early-bird", "a small round songbird in soft orange and cream on a short twig, in front of a warm golden "
                   "rising sun half above a soft horizon line."),
    ("lightning-fast", "a dark charcoal and cream swallow mid-swoop with its forked tail and wings swept back, two "
                       "soft speed curves behind it."),
    ("kung-fu-master", "a wooden practice staff crossed with a closed red folding fan, a small red tassel hanging "
                       "from the fan."),
    ("dressed-up", "a wooden coat hanger, and hanging on it a tiny green dragon-costume hood with two small yellow "
                   "horns and a cream face opening."),
]

RIM = ("A round MEDAL RIM for the app's achievement badges, the {name} tier: a single thick circular ring made of "
       "{what} The band is about 12% of the ring's width, gently bevelled with soft highlights, with a simple "
       "repeating cloud-scroll (ruyi) pattern pressed lightly into it all the way round. The MIDDLE of the ring is "
       "EMPTY: flat magenta, exactly like all round it, nothing inside. Perfectly round, centred, filling about 92% "
       "of the canvas. The five tiers are a set, so draw the ring the same size, thickness and pattern; only its "
       "material differs.")

rims = [
    ("1-clay", "Clay", "warm terracotta fired clay, matte, soft and earthy (the first, plainest tier)."),
    ("2-bronze", "Bronze", "warm antique bronze, a soft brown-gold metal sheen."),
    ("3-silver", "Silver", "bright polished silver, cool soft greys with a clean white shine."),
    ("4-gold", "Gold", "rich shining gold, warm yellow-gold with lighter gold highlights, as precious as the "
                       "attached gold ingot."),
    ("5-jade", "Jade", "polished pale-green imperial jade, smooth and glowing a little from within, with soft "
                       "lighter veins (the highest tier: it should look the most precious)."),
]

new = [{"file": f"out/raw/achv-{n}.png", "group": "achievements", "size": "1024x1024", "refs": ICONS,
        "prompt": EMBLEM.format(what=what) + STYLE} for n, what in emblems]
new += [{"file": f"out/raw/achv-rim-{n}.png", "group": "achievements", "size": "1024x1024",
         "refs": ['out/raw/pk-ingot.png', 'out/raw/lantern-icon-lit.png'],
         "prompt": RIM.format(name=name, what=what) + STYLE} for n, name, what in rims]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', len(added), [j['file'] for j in added])
