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
# Duolingo's star is the bird, ours was half Bùbù and half seal (owner, 3 Nov 2026): he has to be the star, with the seal his prop
jobs.append({
    "file": "out/raw/rm-board-hero.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-board-seal.png", "out/raw/rm-master.png"],
    "prompt": "The first attached image is a storyboard: keep its style, its cream xuan paper and its simple Bùbù the panda, checked against the second attached image: one mouth, "
              "two single muted red straps that never cross. Draw a new storyboard sheet of six numbered tall phone-shaped panels in two rows of three, on a plain light grey sheet, with "
              "no writing except the panel numbers, for a two-second celebration when a lesson ends. Bùbù is the star: in panels 2 to 6 he is huge and fills most of the screen, far "
              "bigger than the seal, and his face and big expression are what we look at. The seal is a small prop, a simple red-based stone seal that fits in his two paws.\n\n"
              "1. Empty cream paper, nothing on it.\n"
              "2. Bùbù bursts in close to us from the bottom of the screen, huge, cropped at the waist, the small seal raised high in one paw, eyes narrowed with a big cheeky grin.\n"
              "3. Wind up: he leans far back, squashed, the seal behind his head, his mouth a tight determined line.\n"
              "4. The stamp: he lunges straight at us, his big head and arm stretching forward, the seal thrust at the viewer as if stamping the glass of the phone, with white impact lines.\n"
              "5. He pulls back, huge and beaming with a big open mouth and happy closed eyes. A small rough vermilion square print is left on the paper beside his head.\n"
              "6. He is holding the seal up proudly, one arm thrown up, leaning toward the small print, winking, with a few small sparkles round him. He still fills most of the screen."})
# the moment only gets the space above the title, about the top 45% of the screen (owner's marked-up recording, 3 Nov 2026): square panels
jobs.append({
    "file": "out/raw/rm-board-hero-square.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-board-hero.png", "out/raw/rm-master.png"],
    "prompt": "The first attached image is a storyboard of Bùbù the panda. Redraw the same six beats as six numbered SQUARE panels in two rows of three, on a plain light grey sheet, with "
              "no phones and no writing except the panel numbers. Each square is all the room this animation gets, so every pose is composed to read clearly inside a square: Bùbù is big, "
              "his head and raised arm whole and inside the square, cropped only at the belly along the bottom edge. Match the second attached image: flat shapes with no black outline, "
              "the same round eye patches, one mouth, two single muted red straps that never cross. The seal stays a small prop in his paws, with a flat, matte red base.\n\n"
              "1. Empty cream paper.\n"
              "2. He bursts up from the bottom edge, the seal raised high in one paw, eyes narrowed, a big cheeky grin.\n"
              "3. Wind up: he leans clearly back and to one side, his whole upper body tilted, the seal drawn back over his shoulder, his mouth a determined line. One arm is back, the other out for balance.\n"
              "4. The stamp: he lunges straight at us, his head big, the seal thrust at the viewer filling the lower half of the square, with white impact lines.\n"
              "5. He pulls back beaming with a big open mouth and happy closed eyes, the seal held low. A small rough vermilion square print, with no characters in it, sits on the paper in the top corner beside his head.\n"
              "6. As panel 5, but one arm thrown up holding the seal and winking, with a few small sparkles. The print stays in its corner."})
# with no frame round him a straight crop across his body looks odd (owner, 3 Nov 2026): his whole body, floating and compact like Duolingo's bird
jobs.append({
    "file": "out/raw/rm-board-hero-whole.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-board-hero-square.png", "out/raw/rm-master.png"],
    "prompt": "The first attached image is a storyboard of Bùbù the panda. Redraw its beats as five numbered SQUARE panels, three on the top row and two on the bottom, with a plain soft grey sheet "
              "and no border, frame, paper or background behind him. His WHOLE body is always in the square and never cropped: he floats in mid-air, tilted, in a compact, chunky pose with his "
              "big head taking up about half his size and his short legs tucked in or kicking, so he stays large in the square. Keep the same expressions as the first image. Match the second "
              "attached image: flat shapes with no black outline, the same round eye patches, one mouth, two single muted red straps that never cross. The seal stays a small prop with a flat, matte red base. No writing except the panel numbers.\n\n"
              "1. He bursts up into the square at a tilt, seal raised high in one paw, the other arm out, legs kicking below him, eyes narrowed, a big cheeky grin.\n"
              "2. Wind up: he curls and leans far back, tilted the other way, knees pulled up, the seal drawn back over his shoulder, a determined mouth.\n"
              "3. The stamp: he lunges straight at us, foreshortened, the seal thrust at the viewer and big in the front, his head just behind it, his body and feet small behind that, with white impact lines.\n"
              "4. He bounces back, tilted, beaming with a big open mouth and happy closed eyes, the seal held in both paws at his belly, legs kicked out. A small rough vermilion square print with no characters floats beside his head.\n"
              "5. As panel 4, settled, one arm thrown up holding the seal and winking, with a few small sparkles round him."})
# the legs were round stubs flung anywhere (owner, 3 Nov 2026: "legs look bad, need better posing"): every leg posed on purpose
jobs.append({
    "file": "out/raw/rm-board-hero-legs.png", "group": "board", "size": "1536x1024", "refs": ["out/raw/rm-board-hero-whole.png", "out/raw/rm-master.png"],
    "prompt": "The first attached image is a storyboard of Bùbù the panda: keep its five panels, layout, upper bodies, faces, arms, seal and plain soft grey sheet exactly, and redraw only "
              "his legs, which are badly posed: round stubs flung about. His legs are like those in the second attached image: thick and short, joined to his body at the hips under the "
              "belly, each bending at a clear knee, with rounded feet seen from the front or the side with two grey toe lines. The two legs always do different but related things, and they "
              "follow the line of action of his whole body, like a professional animator's poses.\n\n"
              "1. Bursting up: his line of action curves up to the raised seal. The leg on the side of the raised arm is straight and stretched down, pointing its toe; the other is bent with the knee up toward his belly.\n"
              "2. Wind up: both knees pulled up tight together toward his chest, feet tucked under him, the whole body curled back like a spring.\n"
              "3. The stamp: his legs stream out straight behind him, small, side by side, feet trailing, because he is diving at us.\n"
              "4. Bouncing back: he sits in the air, knees apart and bent, feet out in front and turned slightly outward, soles toward each other, like a happy toddler sitting.\n"
              "5. As 4 but one leg kicked out straight to the side, the other knee bent up, for a jaunty pose with the wink.\n\n"
              "Flat shapes, no black outline, one mouth, two single muted red straps that never cross, no writing except the panel numbers."})
# the owner took that board ("Ye this works"): each panel drawn alone, clean, to animate. Saved as out/raw/rm-hero-<n>.png
HERO = ("The first attached image is a storyboard of Bùbù the panda. Draw only the pose of its panel {}, alone and large, as a clean final drawing for animation, in the same flat style. "
        "Keep its pose and expression, but check his design against the second attached image: the same round eye patches, the tuft of hair on top of his head, one mouth, two single "
        "muted red straps that never cross, two grey toe lines on each paw and foot, and no black outline. The seal is the same small grey stone seal with a guardian lion on top and a "
        "flat, matte vermilion base, with no drips. His whole body is in frame with room round him. No action lines, sparkles, print, shadow or ground.{} The backdrop is one flat solid "
        "magenta (#FF00FF) with nothing else on it.")
for n, extra in ((1, ""), (2, " Make the wind up a clear coil: his whole body tilted back, knees pulled tight to his chest, the seal drawn back over his shoulder, his face turned toward us with screwed-shut eyes and a determined mouth."),
                 (3, " His legs are hidden behind the seal and his body: we only see the seal thrust at us, big at the front, his paws gripping its sides, and his cross face just behind it."), (4, ""), (5, "")):
    jobs.append({"file": f"out/raw/rm-hero-{n}.png", "group": "board", "size": "1024x1024", "refs": ["out/raw/rm-board-hero-legs.png", "out/raw/rm-master.png"], "prompt": HERO.format(n, extra)})
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
