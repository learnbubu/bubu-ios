"""Codex jobs for the hongbao's prize landing (the owner, 20 Oct 2026): a small amount of money drops in and lands; a
big amount slams down and cracks the floor a little. Group "pocket3", saved as pk3-*. Built in Studio from these:
the piles drop in, the crack and chips show where the big one hits, the dust puffs out.
"""
import json
import os

import make_prompts as mp

PIECE = ("\n\n" + mp.STYLE + "\n\nKeep it simple and bold, like the attached coin: big flat shapes, a soft sheen, no fine "
         "detail.\n\n" + mp.KEY)
COIN = "refs/ref-pk-coin.png"

JOBS = [
    ("pk3-pile-small", [COIN], "The attached image is the app's gold coin. Draw ONLY a small tidy stack of these same gold "
     "coins (round, square hole): five coins lying flat in a short stack, slightly offset, with two more leaning against it, "
     "seen from the front and a little above. Its base is flat, as if resting on a floor (no floor drawn). Centred, filling "
     "about half the width." + PIECE),
    ("pk3-pile-big", [COIN, "refs/ref-pk-coin.png"], "The attached image is the app's gold coin. Draw ONLY a big heavy "
     "heap of these same gold coins (round, square hole), about thirty, in a wide mound, with two gold ingots (yuanbao: the "
     "boat shape with raised ends and a rounded dome) on top and a few coins standing on their edges. Seen from the front and "
     "a little above, its base flat and wide, as if resting on a floor (no floor drawn). Centred, filling about 85% of the "
     "width, a few small sparkles." + PIECE),
    ("pk3-crack", [COIN], "The attached image is the app's gold coin, for the style. Draw ONLY a crack in a floor, seen from "
     "the front and a little above, so it is a wide, flat shape: a jagged dark crack line running sideways from the middle, "
     "branching into three or four smaller cracks each side, with a slightly sunken broken patch in the middle where "
     "something heavy landed. The cracks are deep dark red-brown (#3A0E0A) with a thin lighter warm edge (#E0574A) along one "
     "side, as on a lacquered red floor. Nothing else: no floor colour around it (magenta), no coins. Wide and low, about four "
     "times as wide as tall, centred." + "\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk3-chips", [COIN], "The attached image is the app's gold coin, for the style. Draw ONLY six small broken floor chips, "
     "spread out with space between them: small flat angular shards of red lacquered floor (#C02C22 with a darker edge "
     "#8E1A16 and a lighter top face #E0574A), different sizes and angles, as if flying up from a crack." + "\n\n" + mp.STYLE
     + "\n\n" + mp.KEY),
    ("pk3-dust", [COIN], "The attached image is the app's gold coin, for the style. Draw ONLY a soft puff of dust kicked up "
     "sideways from something landing: a low, wide cloud of three or four rounded puffs, warm pale cream (#F6E6D0) with a "
     "slightly darker warm shade underneath, flat soft shapes, wide and low, centred." + "\n\n" + mp.STYLE + "\n\n" + mp.KEY),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "pocket3"]
    for name, refs, prompt in JOBS:
        jobs.append({"file": f"out/raw/{name}.png", "group": "pocket3", "size": "1024x1024" if "pile" in name else "1536x1024",
                     "refs": refs, "prompt": prompt})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(JOBS), "pocket3 jobs")
