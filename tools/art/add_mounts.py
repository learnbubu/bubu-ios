"""The things the hanging pieces hang from, made once as masters.

The owner, 28 Oct 2026: "not the things hanging, but the things it's hanging from, then we can do some generations
to get the look and make them masters, so it matches every time", and "we have some already that look nice, but need
to make masters and maybe 10 more to choose from". So:
  - the five mounts already in kept pieces are lifted out of them exactly as they are (Codex keeps only the mount and
    removes what hangs from it), to become masters as they stand;
  - ten new mounts are drawn on their own, to choose from.
From then on Codex draws only the hanging object (on a cord, nothing above it) and process.py hangs it from a master,
so every bracket is the same bracket.

Every mount comes in from the top-left on a portrait 4:5 canvas, the same canvas as a hanging piece, so a master
lines up with the pieces hung from it; each ends in the one point a cord is tied to. Appends jobs (group "mounts") to
jobs.json, replacing any made before; Codex makes only that group (MOUNTS.md).
"""
import json
import make_prompts as mp
from add_path3 import slug

# lifted from the kept pieces: (master's name, the piece it's in, what the mount is)
LIFT = [
    ("Carved bracket", "hang-chinese-knot", "the carved dark-wood scroll bracket at the top left"),
    ("Red pole", "hang-lantern-cluster", "the red-lacquered pole at the top"),
    ("Red bracket", "hang-fish-kite", "the red bracket with its gold cap at the top left"),
    ("Roof eave", "hang-gourd", "the grey-tiled roof eave corner and its red woodwork at the top left"),
    ("Bamboo pole", "hang-jade-pendant", "the green bamboo pole at the top"),
]
LIFT_PROMPT = ("The attached image is a finished hanging decoration from the app. EDIT it to make its MOUNT on its own: keep "
               "ONLY {what} EXACTLY as it is - the same size, the same place on the canvas, the same shapes and colours - and "
               "remove everything that hangs from it (the cord, the knots, the hanging object, any tassels), leaving flat "
               "magenta (#FF00FF) where they were. Where the cord was tied, keep a small neat tie point or ring on the mount, "
               "so it's clear where a cord would hang from. Where something removed was covering part of the mount, draw "
               "that hidden part in, continuing it naturally. No text, no letters.")

NOTE = ("The attached images are existing art from the same app: match their illustration style, palette, texture and level "
        "of detail exactly. Do not copy their subjects or composition; draw only what is described below.")
SHAPE = ("Draw ONLY the mount, with nothing hanging from it: it comes in from the LEFT edge of the canvas near the TOP, "
         "reaching about 40–45% of the way across, and sits in the top fifth of the canvas; everything below and to the "
         "right is empty magenta. Under its outer end is ONE small round brass ring, clearly visible, where a cord will be "
         "tied later; nothing hangs from the ring. Simple and bold like the attached art: a few big shapes, flat fills with "
         "one soft lighter tone, no fine texture. Portrait canvas, 4:5.")
NEW = [
    ("Iron scroll", "a black wrought-iron bracket fixed to the edge, its arm curling into one neat scroll underneath"),
    ("Cloud bracket", "a carved dark-wood bracket whose support is shaped like a rounded ruyi cloud"),
    ("Dragon head", "a carved wooden bracket ending in a small friendly stylised dragon head, gold and red, the ring held in its mouth"),
    ("Archway beam", "the corner of a Chinese memorial archway: a red-lacquered crossbeam with a gold-trimmed end and a little "
     "grey-tiled cap above it"),
    ("Jade bracket", "a carved wooden bracket painted soft jade green with a cream trim, a simple scrolled support underneath"),
    ("Bamboo frame", "a green bamboo pole lashed with a few turns of brown rope to a short upright bamboo post at the edge"),
    ("Brass rod", "a slim polished brass rod coming in from the edge, a round brass knob on its end"),
    ("Wall coping", "the top of a white plastered garden wall with grey tile coping, a short wooden peg sticking out from it"),
    ("Stone corbel", "a smooth grey stone bracket (a corbel) set into the edge, rounded and chunky"),
    ("Fishing rod", "a slim bamboo fishing rod reaching in from the left at a gentle upward angle, its tip bending slightly"),
]


def main():
    jobs = [j for j in json.load(open("jobs.json", encoding="utf-8")) if j["group"] != "mounts"]
    add = []
    for t, src, what in LIFT:
        # (the same canvas as the piece it's lifted from, so the mount stays exactly where it was)
        add.append({"file": f"out/raw/mount-{slug(t)}.png", "group": "mounts", "size": "1122x1402",
                    "refs": [f"out/raw/{src}.png"], "prompt": LIFT_PROMPT.format(what=what) + "\n\n" + mp.KEY})
    for t, d in NEW:
        add.append({"file": f"out/raw/mount-{slug(t)}.png", "group": "mounts", "size": "1024x1536",
                    "refs": ["refs/ref-hang-chinese-knot.png", "refs/ref-hang-hanging-lanterns.png"],
                    "prompt": f"{NOTE}\n\n{mp.STYLE}\n\nCreate a mount for hanging things from: {d}. {SHAPE}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "mount jobs;", len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
