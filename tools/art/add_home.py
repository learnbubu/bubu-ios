"""Codex jobs for the calmer Home: the Classroom's island, and tab bar icons in the house style."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
# the house style, word for word, as the other jobs have it
STYLE = jobs[-1]['prompt'][jobs[-1]['prompt'].index('\n\nStyle:'):]

new = [
    {"file": "out/raw/home-classroom-island.png", "group": "home", "size": "1536x1024",
     "refs": ["refs/ref-land-hall.png", "refs/ref-land-pavilion.png", "refs/ref-rig-idle.png"],
     "prompt": "A small floating garden island for the app's home screen: the CLASSROOM, a little traditional Chinese schoolhouse (a 学堂) on a rounded grassy island with a soft earthy underside, like the path's landmark islands in the attached images. The schoolhouse is a single-storey hall with a curved teal tiled roof, red pillars and wide-open red doors showing a warm lit room inside with two little desks; a small wooden easel with a blank board stands by the steps; a stack of books and a brush pot sit on the top step; one round paper lantern hangs from the eave. A pine and a small flowering tree frame it, with a few rounded stones and grass tufts. Bùbù the panda (as in the third image, same proportions and face) stands at the open door, small, waving hello with a book under his other arm. Calm, inviting, slightly whimsical. Seen from slightly above and in front, centred, the island filling about 80% of the width, even magenta all round. Leave the board on the easel completely blank."
     + STYLE},
]
icons = [
    ("home", "a small cosy traditional Chinese house: a curved teal tiled roof with upturned eaves, cream walls and one round red door, nothing else"),
    ("learn", "a winding path of four round stepping stones curving up towards a small red pennant flag on a pole, the stones jade green, nothing else"),
    ("profile", "Bùbù the panda's head only, front on, smiling with closed happy eyes and pale blush cheeks, his own round ears"),
    ("settings", "a chunky rounded gear wheel with eight short teeth, jade green, with a small round brass centre, nothing else"),
]
for name, what in icons:
    new.append({"file": f"out/raw/tab-{name}.png", "group": "tabicons", "size": "1024x1024",
                "refs": ["out/raw/lantern-icon-lit.png", "refs/ref-land-hall.png"] + (["refs/ref-rig-idle.png"] if name == "profile" else []),
                "prompt": f"An APP TAB-BAR ICON, to be shown tiny (24 to 30 pixels) along the bottom of the app, so it must read at a glance at that size: {what}. Bold, chunky, simple silhouette with only 2 to 3 soft tones; no fine detail, no small pattern, no outline. The same simplified look as the attached lantern icon (first image), from the same set. Upright, centred, filling about 75% of the canvas, even magenta all round, nothing else on the canvas."
                + STYLE})
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', [j['file'] for j in added])
