"""Codex jobs, second go: a much simpler Classroom island, and a simple lantern for the streak chip."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
STYLE = jobs[-1]['prompt'][jobs[-1]['prompt'].index('\n\nStyle:'):]
SIMPLE = (" Keep it VERY SIMPLE, in the same chunky, simplified look as the attached tab icons: big clear shapes, only 2 to 3 flat tones"
          " per colour, no small details, no textures or patterns, no tiny props. It must read clearly at a small size.")

new = [
    {"file": "out/raw/home-classroom-island2.png", "group": "home2", "size": "1536x1024",
     "refs": ["out/raw/tab-home.png", "out/raw/tab-settings.png", "out/raw/home-classroom-island.png"],
     "prompt": "A small floating island for the app's home screen, the CLASSROOM: a rounded grassy island with a simple earthy underside, and on it ONE little Chinese schoolhouse - a single small hall with a curved teal roof (like the house tab icon in the first image), two red pillars and an open doorway glowing warm inside - and ONE round tree beside it. Nothing else: no panda, no people, no easel, no books, no lantern, no flowers, no rocks, no path. The third image is a first try that was too detailed: same idea, but far simpler." + SIMPLE
     + " Seen slightly from above, centred, filling about 75% of the width, even magenta all round." + STYLE},
]
for state, how in [("lit", "lit and glowing warmly from inside: a bright red body with a lighter warm orange-yellow area in its middle"),
                   ("unlit", "NOT lit: the same lantern in dull muted brown-grey paper, with no glow, its gold parts a dull khaki")]:
    new.append({"file": f"out/raw/chip-lantern-{state}.png", "group": "home2", "size": "1024x1024",
                "refs": ["out/raw/tab-home.png", "out/raw/tab-settings.png"] + (["out/raw/chip-lantern-lit.png"] if state == "unlit" else []),
                "prompt": f"A tiny APP ICON of a round Chinese paper lantern, shown at 20 to 24 pixels beside a number in a small rounded chip, {how}. "
                          "As simple as it can be: a squat round body, a plain gold bar on top and on the bottom, and one short gold tassel - "
                          "no ribs or at most two faint ones, no pattern, no cloud motif, no cord or hook, no sparkles." + SIMPLE
                          + (" It must be EXACTLY the same shape, size and position as the lit lantern in the third image, only the colours changed." if state == "unlit" else "")
                          + " Upright, centred, filling about 75% of the canvas, even magenta all round, nothing else on the canvas." + STYLE})
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', [j['file'] for j in added])
