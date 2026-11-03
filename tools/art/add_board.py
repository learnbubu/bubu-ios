"""A storyboard sheet for the lesson-complete moment, drawn by Codex (owner, 3 Nov 2026), to judge the idea before animating it.
It has to feel nothing like the small 五连 seal in the combo (Rig.swift): here the stamp takes over the whole screen.
Saved as out/raw/rm-board-seal.png.

From tools/art: ../sfx/.venv/Scripts/python -I add_board.py
"""
import json

jobs = json.load(open("jobs.json", encoding="utf-8"))
jobs = [j for j in jobs if j["group"] != "board"]
jobs.append({
    "file": "out/raw/rm-board-seal.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-master.png"],
    "prompt": "The attached image is Bùbù the panda, the character in this storyboard: keep his design, his big head, black chest, cream belly, "
              "and two single muted red backpack straps. Draw a professional animator's storyboard sheet for a two-second celebration in a language "
              "learning iPhone app, when a lesson is finished. Six numbered tall phone-shaped panels, in two rows of three, with thin dark panel borders on "
              "a plain light grey sheet, a few simple arrows to show movement, and no other writing except the panel numbers.\n\n"
              "1. A big sheet of cream Chinese xuan paper fills the screen. Bùbù stands small at the bottom, heaving a huge square carved stone seal, "
              "bigger than he is, up off the ground with both arms.\n"
              "2. Anticipation: he swings the giant seal up high over his head and leans back, squashed down with the strain, eyes screwed shut. The seal's "
              "underside shows wet with bright vermilion seal paste.\n"
              "3. He leaps. We are looking from the paper's side: the seal rushes toward us and fills most of the panel, Bùbù tiny and riding on top of it.\n"
              "4. The impact: the seal slams down filling the entire screen edge to edge, with thick white impact lines, the paper rippling and vermilion "
              "drops flying outward from every side.\n"
              "5. The seal lifts away and out of the top of the panel. A huge vermilion square seal print fills most of the paper, with a rough, real stamped "
              "texture and the two characters 步步 carved inside it.\n"
              "6. Bùbù pops up from the bottom edge in front of the giant print, arms thrown up, a big open happy mouth, both paws smeared red with seal paste, "
              "with a red paw print on the paper beside him.\n\n"
              "Flat, clean, simple shapes in the same style as the attached image: finished colour, not sketches."})
# the pieces for animating it (owner likes the board's style and its simpler Bùbù): each on its own, saved as out/raw/rm-seal-<name>.png
BACKDROP = " The backdrop is one flat solid magenta (#FF00FF) with nothing else on it: no shadow, no ground, no paper, no text, no lines, no panel border, no phone."
BUBU = ("The first attached image is a storyboard. Draw only Bùbù the panda, alone, in exactly the same simple style, flat shapes and proportions as he is drawn "
        "in panel {} of it, with the proportions and design checked against the second attached image: one mouth, two single muted red straps that never cross, "
        "two grey toe lines on each paw and foot. No seal, no red paste, no action lines. His whole body is in frame. The pose: {}")
for name, panel, text in (
    ("heave", 1, "standing with his feet apart, both arms straight up above his head with the paws open and flat as if holding up something heavy, eyes screwed shut, a tight strained mouth."),
    ("strain", 2, "squatting low with knees bent and apart, both arms straight up above his head with the paws open and flat as if holding up something heavy, leaning back slightly, eyes screwed shut, a tight strained mouth."),
    ("ride", 3, "sitting with his legs apart and his feet hanging down in front of him, both paws resting on his knees, wide excited eyes, a big open happy mouth."),
    ("cheer", 6, "standing, both arms thrown up and out, a big open happy mouth, happy closed eyes. Both paws are clean, plain black."),
):
    jobs.append({"file": f"out/raw/rm-seal-{name}.png", "group": "board", "size": "1024x1024", "refs": ["out/raw/rm-board-seal.png", "out/raw/rm-master.png"],
                 "prompt": BUBU.format(panel, text) + BACKDROP})
jobs.append({"file": "out/raw/rm-seal-stone.png", "group": "board", "size": "1024x1024", "refs": ["out/raw/rm-board-seal.png"],
             "prompt": "The attached image is a storyboard. Draw only the big carved stone seal from panel 1 of it, alone, in exactly the same style: a grey stone block with "
                       "cloud carvings and a guardian lion on top, seen straight from the front, perfectly level, whole and in frame. Its bottom edge is a flat, clean band of "
                       "vermilion seal paste with no drips at all. No panda, no action lines." + BACKDROP})
jobs.append({"file": "out/raw/rm-seal-paper.png", "group": "board", "size": "1024x1536", "refs": ["out/raw/rm-board-seal.png"],
             "prompt": "The attached image is a storyboard. Draw only the cream xuan paper background seen in its panels, as one tall plain sheet filling the whole image edge to edge, "
                       "with the same soft fibre texture and no marks: no border, no phone, no panda, no seal, no red, no text."})
# more like an animatic (owner, 3 Nov 2026): the in-betweens across panels 1 to 2 and 2 to 3 of the board, saved as out/raw/rm-board-seal-<name>.png
BETWEEN = ("The attached image is a storyboard, and Bùbù the panda and his seal are drawn exactly as in it. Draw a new sheet of six numbered tall phone-shaped panels, in two rows of "
           "three, showing six evenly spaced animation frames {}, as a professional animator would break down the action with weight, anticipation and follow through. Each panel "
           "changes clearly and only a little from the one before, and Bùbù and the seal stay the same design and size in every panel. Same cream paper, thin dark panel borders on a "
           "plain light grey sheet, flat clean finished colour, no drips of paste, one mouth, two single straps that never cross, and no writing except the panel numbers.\n\nThe frames: {}")
for name, span, text in (
    ("1-2", "from its panel 1 to its panel 2",
     "1. As panel 1: holding the seal up, legs straight, trembling. 2. His knees start to give and the seal dips slightly. 3. He sinks lower, the seal coming down on top of him, his head pressed down. "
     "4. Lowest point: deep squat, the seal level just above his head. 5. He drives upward and starts swinging the seal back, tilting it so its red underside begins to show. 6. As panel 2: the seal high and tilted, red underside showing, leaning back."),
    ("2-3", "from its panel 2 to its panel 3",
     "1. As panel 2. 2. He sinks into a deeper squat, the tilted seal pulled further back. 3. His legs straighten hard, his feet just leaving the ground, the seal swinging level over his head. "
     "4. In the air: he pulls himself up onto the seal, stretched between it and the ground, the seal now a little bigger and closer to us. 5. He is sitting on top of the seal, which has grown much bigger as it comes toward us. 6. As panel 3: the seal fills most of the panel, Bùbù small on top, with action lines."),
):
    jobs.append({"file": f"out/raw/rm-board-seal-{name}.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-board-seal.png"], "prompt": BETWEEN.format(span, text)})
json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("board job added")
