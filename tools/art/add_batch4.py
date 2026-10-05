"""Batch 4 (owner, 5 Oct 2026): side fillers in the hanging-willow shape, but not trees: things
that hang in from the top-left edge, long and narrow. Jobs for Codex, saved as hang-*."""
import json
import re

import make_prompts as mp

HANG = [
    ("Chinese knot", "a red Chinese knot (zhongguo jie) hanging on a long red cord, with a long red tassel"),
    ("Firecracker string", "a long string of small red firecrackers hanging down on a cord, with a red tassel at the bottom"),
    ("Red envelopes on a cord", "small red envelopes and little red lucky bags tied at intervals along a hanging red cord"),
    ("Lantern cluster", "three small red lanterns hanging at different heights on thin cords from a short bamboo pole"),
    ("Bird cage", "a round bamboo bird cage with a small cream songbird inside, hanging on a cord"),
    ("Gourd", "a golden calabash gourd tied with red cord, hanging on a long cord"),
    ("Trailing ivy pot", "a small hanging teal pot with ivy trailing down in long strands"),
    ("Bamboo wind chimes", "bamboo wind-chime tubes hanging on cords from a small bamboo bar"),
    ("Ink scroll", "a hanging scroll with a simple ink painting of misty mountains (no writing, no seals with letters), wooden rods top and bottom"),
    ("Round silk fan", "a round silk fan painted with soft misty mountains, hanging by its handle from a cord with a tassel"),
    ("Jade pendant", "a green jade pendant (a round disc) on a red cord with a red tassel"),
    ("Fish kite", "a red-and-gold fish kite with a long flowing tail trailing down from the top"),
    ("Dried persimmons", "a string of dried orange persimmons hanging down on a cord"),
    ("Chillies and garlic", "a string of red chillies with a few white garlic bulbs, hanging down on a cord"),
    ("Cloud swirls", "auspicious cloud swirls (xiangyun) in soft cream and pale jade drifting down the edge in a loose column"),
    ("Edge waterfall", "a thin waterfall spilling from a mossy ledge at the top-left and falling straight down in a narrow ribbon, a little mist at the bottom"),
]
# (first try hung everything from a blossom branch, copied from the willow reference: jobs.json
# now has the no-branch wording and branch-free references for this group)
SHAPE = ("SHAPE, like the attached hanging willow: it hangs in from the TOP-LEFT corner, straight down along the left edge, "
         "long and narrow - about a third of the canvas width and most of its height - with plenty of empty magenta to the right. "
         "Portrait canvas, 4:5.")

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    note = jobs[0]["prompt"].split("\n\n")[0]
    have = {j["file"] for j in jobs}
    add = 0
    for t, d in HANG:
        f = "out/raw/hang-" + re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-") + ".png"
        if f in have:
            continue
        jobs.append({"file": f, "group": "hangers3", "size": "1024x1536",
                     "refs": ["refs/ref-hang-hanging-willow-fronds.png", "refs/ref-hang-hanging-lanterns.png"],
                     "prompt": f"{note}\n\n{mp.STYLE}\n\n{mp.SIMPLE}\n\nCreate a hanging decoration: {d}. {SHAPE}\n\n{mp.KEY}"})
        add += 1
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(add, "jobs added")
