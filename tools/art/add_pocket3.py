"""Codex jobs for the hongbao's prize landing (the owner, 20-21 Oct 2026): a small amount of money drops in and lands; a
big amount (a milestone) lands on lucky clouds that burst out from under it and settle as a bed. Group "pocket3", saved
as pk3-*. Built in Studio from these: the piles drop in; under the big one, cloud puffs and wisps burst out and a cloud
bed settles under it.
"""
import json
import os

import make_prompts as mp

PIECE = ("\n\n" + mp.STYLE + "\n\nKeep it simple and bold, like the attached coin: big flat shapes, a soft sheen, no fine "
         "detail.\n\n" + mp.KEY)
COIN = "refs/ref-pk-coin.png"
POCKET = "refs/ref-pk2-red.png"
CLOUD = ("The attached images are the app's red envelope and gold coin: match their style exactly (soft storybook vector, "
         "flat shapes with a little soft shading, no outlines but the gold trim, simple). ")
END3 = ("\n\nKeep it simple and bold, big soft shapes, no fine detail, no texture. It must read clearly on a dark red "
        "background.\n\n" + mp.KEY)

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
    # the big prize lands on lucky clouds (xiangyun), not cracked ground (the owner, 21 Oct 2026: Duolingo's gems break the
    # floor; ours come down from the heavens): a ring of cloud puffs bursts out from under it and settles as a bed
    ("pk3-cloud-bed", [POCKET, COIN], CLOUD + "Draw ONLY a low, wide bank of auspicious clouds (xiangyun) for something to "
     "rest on, seen from the front: five or six rounded cloud lobes side by side, the middle ones a little taller, each "
     "ending in the classic curled spiral like the corner swirls on the attached red envelope, soft cream-gold with a warmer "
     "gold underside and a thin gold outline on the curls. Flat across the top so a heap of coins can sit on it. Wide and "
     "low, about five times as wide as tall, centred." + END3),
    ("pk3-cloud-puff", [POCKET, COIN], CLOUD + "Draw ONLY one single auspicious cloud puff (xiangyun): a round soft cloud "
     "body with one curled spiral tail, like a corner swirl on the attached red envelope, soft cream-gold with a warmer gold "
     "underside and a thin gold line on the curl. Centred, filling about 70% of the canvas, its tail curling to the right."
     + END3),
    ("pk3-cloud-puff-2", [POCKET, COIN], CLOUD + "Draw ONLY one single auspicious cloud puff (xiangyun), different from a "
     "plain round one: two overlapping round lobes with a curl at each end (a double swirl), like the swirls on the attached "
     "red envelope, soft cream-gold with a warmer gold underside and a thin gold line on the curls. Centred, filling about "
     "70% of the canvas." + END3),
    ("pk3-cloud-wisp", [POCKET, COIN], CLOUD + "Draw ONLY one small curling wisp of auspicious cloud: a thin ribbon of "
     "cloud ending in a tight spiral curl, soft cream-gold with a thin gold line, like the smallest curl on the attached red "
     "envelope. Centred, filling about 60% of the width." + END3),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "pocket3"]
    for name, refs, prompt in JOBS:
        jobs.append({"file": f"out/raw/{name}.png", "group": "pocket3", "size": "1536x1024" if name in ("pk3-cloud-bed", "pk3-cloud-wisp") else "1024x1024",
                     "refs": refs, "prompt": prompt})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(JOBS), "pocket3 jobs")
