"""Two more for the profile page (the owner, 1 Nov 2026: "chars and words need to make more sense"): the app writes a
real 字 and 词 on these, so they say what they count. Appends to the group "profileart" (PROFILEART.md)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_prompts as mp
from add_hudflat import FLAT, ICON
from add_profileart import ICON_REFS, NOTE

JOBS = [
    ("stat-chars-paper", "A square sheet of cream practice paper with slightly rounded corners, as in the LAST attached "
     "image, the same shape: a bold red square border, a flat tan shape along the bottom edge for thickness, one short "
     "light highlight at the top left. Inside the border it is PLAIN flat cream: remove the red cross completely, with "
     "only four tiny pale red ticks where the cross's lines would meet the border. The middle is EMPTY: nothing is "
     "written on it (the app writes a big dark character on top).", ICON_REFS + ["out/raw/stat-chars-grid.png"]),
    ("stat-words-bubble", "A chunky rounded speech bubble, a little wider than tall, with a short stubby tail at its "
     "bottom left: flat jade green (#2E9A84), a hard-edged deeper green (#17786A) shape along the bottom for thickness, "
     "one short light highlight at the top left. The middle is a large EMPTY area of plain flat green: nothing is "
     "written on it (the app writes a big cream character on top).", ICON_REFS),
]


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    for name, d, refs in JOBS:
        f = f"out/raw/{name}.png"
        if f not in have:
            jobs.append({"file": f, "group": "profileart", "size": "1024x1024", "refs": refs,
                         "prompt": f"{NOTE}\n\n{FLAT}\n\nCreate an icon: {d}\n\n{ICON}\n\n{mp.KEY}"})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(j.get("group") == "profileart" for j in jobs), "profileart jobs")


if __name__ == "__main__":
    main()
