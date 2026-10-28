"""Hanging pieces that hang from a hook: Codex draws only the object, and hang.py hangs it from a master mount.

The owner, 28 Oct 2026, on batch path3: "its just branches only.... for the hanging pieces. need more variation of
stuff"; then "not the things hanging, but the things its hanging from ... make them masters, so it matches every
time". With nine masters picked from the mounts batch (masters.py), the owner: "think bubu and branches are good,
thinking the hook ones". So each job here is ONE object on a single cord that runs straight up to the top edge, and
nothing else: no hook, no bracket, no branch. Processing keys it, finds the cord's top, and hangs it from the ring of
the master named in the job's "mount" (hang.py), so every bracket is the master itself.

Also the two ring swaps (group "rings"): the roof eave and bamboo pole masters end in a red loop where the other seven
have a brass ring; the owner: "swap the red loops for brass rings too".

Replaces any path4 and rings jobs made before; Codex makes only those two groups (PATH4.md).
"""
import json
import make_prompts as mp
from add_path3 import NOTE, slug

SIMPLE = ("Keep it SIMPLE, like the attached references: a few big simple shapes, each a flat fill with at most one soft "
          "lighter tone; no fine texture, no tiny repeated details; generous empty space.")
SHAPE = ("Draw ONLY this one object, hanging on a single thin red cord. The cord runs STRAIGHT UP from the top of the object "
         "to the very TOP EDGE of the canvas, exactly at the horizontal CENTRE, and is cut off by the edge. Nothing else: no "
         "hook, no bracket, no ring, no pole, no branch, no leaves above it; the cord is the only thing that touches the top "
         "edge. The object hangs in the middle of the canvas, centred left to right, about 55% of the canvas wide, its top "
         "about a fifth of the way down; everything around it is empty magenta. A small tassel or bead under it is fine. "
         "Portrait canvas, 4:5.")
AVOID = ("Avoid: text, letters or characters of any kind; more than five of anything; tiny fiddly parts; plants or leaves "
         "unless asked for; a second cord or anything hanging beside it; shadows on the backdrop.")

# (name, what it is, the master it hangs from)
OBJECTS = [
    ("Bronze bell", "one small round bronze temple bell with a little striker under it", "roof-eave"),
    ("Brass gong", "a small round brass gong with a raised boss in the middle", "dragon-head"),
    ("Steamer stack", "a stack of three round bamboo steamer baskets with a domed lid, tied up with the cord", "bamboo-pole"),
    ("Straw hat", "a round woven conical straw hat hanging by its chin cord", "fishing-rod"),
    ("Birdhouse", "a little wooden birdhouse with a curved Chinese-style roof and a round door", "cloud-bracket"),
    ("Rabbit lantern", "a white and coral paper rabbit lantern, the Mid-Autumn kind, with a short tassel", "jade-bracket"),
    ("Butterfly kite", "a butterfly-shaped paper kite in coral, gold and jade, hung by its string, two short tail streamers", "bamboo-pole"),
    ("Fishing basket", "a small woven bamboo fishing basket with a lid", "fishing-rod"),
    ("Lucky coins", "three round gold coins with square holes threaded on the cord in a short vertical line, a red tassel under them", "brass-rod"),
    ("Clay teapot", "a round brown clay teapot hanging by its handle", "iron-scroll"),
    ("Cricket cage", "a small round woven bamboo cricket cage with a little door", "stone-corbel"),
    ("Embroidered sachet", "a small red silk sachet (a xiangnang) embroidered with a gold flower, a long red tassel under it", "jade-bracket"),
    ("Lotus lantern", "a pink and cream paper lotus-flower lantern with a short gold tassel", "dragon-head"),
    ("Wooden abacus", "a small wooden abacus with a few rows of round coloured beads, hung by one corner loop", "iron-scroll"),
]

RING_PROMPT = ("The FIRST attached image is a mount for hanging decorations. EDIT it: replace ONLY the small red cord loop at "
               "its outer end with ONE round brass ring, exactly like the brass ring in the SECOND attached image (the same "
               "colour, thickness and size relative to the mount), hanging straight down from that same spot on a short "
               "brass link. Keep everything else EXACTLY as it is: the same size, the same place on the canvas, the same "
               "shapes and colours. Nothing hangs from the ring. No text, no letters.")
RINGS = [("roof-eave", "mount-roof-eave-take2"), ("bamboo-pole", "mount-bamboo-pole")]


def main():
    jobs = [j for j in json.load(open("jobs.json", encoding="utf-8")) if j["group"] not in ("path4", "rings")]
    add = []
    for name, src in RINGS:
        add.append({"file": f"out/raw/mount-{name}-ring.png", "group": "rings", "size": "1122x1402",
                    "refs": [f"out/raw/{src}.png", "out/raw/mount-iron-scroll-take2.png"],
                    "prompt": RING_PROMPT + "\n\n" + mp.KEY})
    for t, d, mount in OBJECTS:
        s = slug(t)
        add.append({"file": f"out/raw/obj-{s}.png", "out": f"hang-{s}", "mount": mount, "group": "path4", "size": "1024x1536",
                    "refs": ["refs/ref-hang-hanging-lanterns.png", "refs/ref-hang-chinese-knot.png"],
                    "prompt": f"{NOTE}\n\n{mp.STYLE}\n\n{SIMPLE}\n\nCreate a hanging decoration: {d}. {SHAPE}\n\n{AVOID}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs (2 rings, %d objects);" % len(OBJECTS), len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
