"""Effects art (owner, 6 Oct 2026): the pieces for the firecracker combo burst and the
right-answer flourish, so they match the app's painted art instead of being drawn in code.
Each is one small piece, alone on magenta; the app animates them. Jobs for Codex, saved as fx-*.
"""
import json
import shutil

import make_prompts as mp

# style references: the firecracker string and bamboo leaves already drawn for the path
REFS = {"refs/ref-fx-firecracker-string.png": "out/raw/hang-firecracker-string.png",
        "refs/ref-fx-bamboo-leaves.png": "out/raw/hang-hanging-bamboo-leaves.png"}
CRACK = ["refs/ref-fx-firecracker-string.png", "refs/ref-simple-blossom.png"]
LEAF = ["refs/ref-fx-bamboo-leaves.png", "refs/ref-fx-firecracker-string.png"]

ONE = ("It is a single small piece for an app animation: draw ONLY this one object, centred, filling about "
       "two thirds of the canvas, nothing else in the picture (no ground, no shadow, no scenery). Square canvas.")

FX = [
    ("fx-firecracker", CRACK, "one single red Chinese firecracker standing upright: a short red paper tube with a gold "
     "paper band at the top and bottom, and a short twisted fuse at the top. The same firecracker as in the attached string."),
    ("fx-firecracker-knot", CRACK, "the top of a firecracker string: a red Chinese knot with a short red tassel either "
     "side, and a plain red cord hanging straight down from it to the bottom of the canvas (no firecrackers on it)."),
    ("fx-pop-1", CRACK, "the first instant of a little firecracker pop: a small, round, soft golden-orange flash with "
     "four short stubby rays, and two or three tiny torn scraps of red paper just starting to fly out."),
    ("fx-pop-2", CRACK, "a little firecracker pop at its biggest: a soft golden flash, wider, with six or seven torn "
     "scraps of red paper (some with a gold edge) flying outwards in a ring, and two small curls of pale grey smoke."),
    ("fx-pop-3", CRACK, "the end of a little firecracker pop: no flash, just a few torn scraps of red paper drifting "
     "apart and two soft curls of pale grey smoke fading out."),
    ("fx-seal", CRACK, "a square red Chinese seal stamp, as pressed on paper: a slightly uneven square of warm red "
     "with soft rounded corners and gently worn, imperfect edges, a thin cream border line just inside the edge, and the "
     "middle left completely EMPTY (plain red, no characters or marks at all, the app writes in it)."),
    ("fx-bamboo-leaf-1", LEAF, "one single bamboo leaf, long and slim with a pointed tip and a short stem, lying at a "
     "slight diagonal, in the jade green of the attached bamboo leaves, with one lighter tone along its middle."),
    ("fx-bamboo-leaf-2", LEAF, "two small bamboo leaves joined at a short stem, spreading in a little V, in the jade "
     "green of the attached bamboo leaves, one leaf a shade lighter than the other."),
    ("fx-paper-1", CRACK, "one small torn scrap of red firecracker paper, roughly a curled rectangle with ragged "
     "edges and a thin gold stripe along one side."),
    ("fx-paper-2", CRACK, "one small torn scrap of red firecracker paper, a twisted triangular shred with ragged "
     "edges, a slightly darker red on its underside where it curls."),
    ("fx-paper-3", CRACK, "one tiny curl of red firecracker paper, like a little ribbon of paper twisted once."),
]

if __name__ == "__main__":
    for ref, src in REFS.items():
        shutil.copyfile(src, ref)
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    note = ("The attached images are existing art from the same app: match their illustration style, palette and "
            "texture exactly. Do NOT copy their subjects; draw only what is described below.")
    have = {j["file"] for j in jobs}
    add = 0
    for name, refs, d in FX:
        f = f"out/raw/{name}.png"
        if f in have:
            continue
        jobs.append({"file": f, "group": "fx", "size": "1024x1024", "refs": refs,
                     "prompt": f"{note}\n\n{mp.STYLE}\n\nKeep it SIMPLE: big simple shapes with flat fills and at most "
                               f"one soft lighter tone, no fine texture or tiny details.\n\nDraw {d} {ONE}\n\n{mp.KEY}"})
        add += 1
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(add, "jobs added")
