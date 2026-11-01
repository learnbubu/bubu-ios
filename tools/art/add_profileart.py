"""Codex jobs for the profile page (the owner, 30 Oct 2026): new flat icons for the Overview's XP, characters and words
(two ideas each, the owner picks), and two achievement Bùbùs fixed: Flawless has lost an arm, Night Owl's hat sits
oddly. The two Bùbùs are edits of their old pictures, which move to out/raw/_superseded/. Appends and changes jobs
(group "profileart"); Codex makes only that group (PROFILEART.md)."""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_prompts as mp
from add_hudflat import FLAT, ICON

NOTE = ("Attached: icons from this app's top bar. Draw a new icon from the SAME SET: the same flat look, the same "
        "chunky proportions, the same palette.")

ICONS = [
    ("stat-xp-bolt", "A fat, chunky gold lightning bolt with rounded corners: flat gold, one hard-edged deeper gold "
     "shape down its right side, one short light highlight."),
    ("stat-xp-ingot", "A traditional Chinese gold ingot (yuanbao): a boat shape with raised rounded ends and a dome in "
     "the middle, flat gold with a hard-edged deeper gold shape along the bottom, one short light highlight."),
    ("stat-chars-grid", "A square sheet of cream practice paper, slightly rounded corners, of the kind Chinese children "
     "learn to write on (a tianzige): a bold red square border and a faint red cross dividing it into four quarters, "
     "with a flat tan shape along the bottom edge for thickness. The middle is EMPTY: nothing is written on it (the "
     "app writes the character on top)."),
    ("stat-chars-brush", "A Chinese writing brush held at a diagonal, tip down: a chunky bamboo-coloured handle and a "
     "plump charcoal bristle tip, finishing a single short bold black ink stroke beneath it. Thick shapes only."),
    ("stat-words-slips", "A small rolled-open bundle of ancient Chinese bamboo writing slips (zhujian): four or five "
     "thick upright bamboo-coloured slats side by side, bound by two bold red cords across them. Nothing written on it."),
    ("stat-words-book", "A small open book seen from the front, chunky and simple, with a teal-green cover showing "
     "around cream pages and a deeper shape down the fold. Nothing written on the pages."),
]
ICON_REFS = ["out/raw/hud-flat-coin.png", "out/raw/hud-flat-lantern-lit.png"]

FIXES = {
    "flawless": "He has lost an arm: only the arm holding the jade disc is there, and on the left of the picture there "
    "is just a dark lump under his head. ADD his other arm, a whole charcoal arm with a round paw, coming clearly from "
    "his shoulder and raised up and out on the left of the picture in a happy wave, as thick as the arm he already has. "
    "Remove the dark lump. It must look natural: two arms, one each side of his body.",
    "night-owl": "His nightcap looks wrong: it sits behind his head and ear, a moon is stuck on it, and it doesn't look "
    "like something he is wearing. REDRAW only the cap: a floppy teal nightcap pulled on TOP of his head, in front of "
    "the top of his head with a neat paler band across his forehead, his two ears poking out on either side of it in "
    "front of the cap, the tip flopping over to the right of the picture and ending in a round pale pompom just above "
    "the book. NO moon anywhere, on the cap or beside it.",
}
EDIT = ("The FIRST attached image is Bùbù from an achievement badge in this app. EDIT it and change only what is said "
        "here; keep his pose, face, proportions, colours, prop and flat sticker style exactly as they are, and keep him "
        "the same size on the canvas.\n\n")


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    for name, d in ICONS:
        f = f"out/raw/{name}.png"
        if f not in have:
            jobs.append({"file": f, "group": "profileart", "size": "1024x1024", "refs": ICON_REFS,
                         "prompt": f"{NOTE}\n\n{FLAT}\n\nCreate an icon: {d}\n\n{ICON}\n\n{mp.KEY}"})
    os.makedirs("out/raw/_superseded", exist_ok=True)
    for fam, fix in FIXES.items():
        f = f"out/raw/achv4-{fam}.png"
        old = f"out/raw/_superseded/achv4-{fam}.png"
        if os.path.exists(f) and not os.path.exists(old):
            shutil.move(f, old)
        j = next(j for j in jobs if j["file"] == f)
        j.update(group="profileart", refs=[old, "refs/panda-celebrate.png"],
                 prompt=EDIT + fix + "\n\nNOTHING behind him: no badge shape, circle, ground or scenery.\n\n" + mp.KEY)
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(j.get("group") == "profileart" for j in jobs), "profileart jobs;", len(jobs), "in all")


if __name__ == "__main__":
    main()
