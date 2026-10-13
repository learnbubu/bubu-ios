"""Codex jobs for the new Home (from the owner's mock-up, 13 Oct 2026): Bùbù the teacher in the board's corner (whole,
to be split into layers for an idle animation afterwards), the chalkboard on its own, misty hills for Up next, and a
lucky money pouch for the daily quests. Replaces the earlier board-alone jobs."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
# the earlier board-alone jobs go: the board is redone to the mock-up's shape below
jobs = [j for j in jobs if j['file'] not in ('out/raw/home-board-blank.png', 'out/raw/home-board-enter.png')]
have = {j['file'] for j in jobs}
STYLE = [j for j in jobs if j['file'] == 'out/raw/home-teacher-board2.png'][0]['prompt']
STYLE = STYLE[STYLE.index('\n\nStyle:'):]

new = [
    {"file": "out/raw/home-teacher-pose.png", "group": "home6", "size": "1024x1024",
     "refs": ["refs/ref-rig-idle.png", "out/raw/panda-teacher.png", "refs/ref-classroom-mock.png"],
     "prompt": "Bùbù the panda as a friendly TEACHER, on his own, for the corner of a chalkboard on the app's home screen. Draw him in the app's own style, "
               "exactly like the first two attached images (the same Bùbù: his face, ears, fur tones, round cheeks and red backpack straps; the second image "
               "shows his round glasses). Use the THIRD image ONLY for his POSE and framing, not its drawing style: a big friendly head with round glasses, "
               "smiling with his mouth open, his body turned slightly to our right; his LEFT arm (on our left) holds an open green book against his tummy; "
               "his RIGHT arm (on our right) is raised, holding a thin wooden pointer that points up and to the right; his red backpack shows behind his shoulder. "
               "Cut off just below the waist - the bottom of the picture cuts across his tummy and the book - so he can sit in the bottom-left corner of a board. "
               "He fills most of the canvas, his cut-off bottom edge running straight along the very bottom of the canvas, magenta everywhere else. "
               "Keep his arms, the book and the pointer clearly separate from his body and head (with small gaps of fur between them where possible), "
               "as he will be split into layers to animate. No board, nothing else in the picture." + STYLE},
    {"file": "out/raw/home-board-blank.png", "group": "home6", "size": "1536x1024",
     "refs": ["out/raw/home-teacher-board2.png", "refs/ref-classroom-mock.png"],
     "prompt": "A classroom CHALKBOARD on its own, for the app's home screen: a dark green slate about 2.2 times as wide as it is tall, in a warm wooden frame "
               "with softly rounded corners, and a wooden ledge along its bottom with one stick of white chalk and a small felt eraser near the RIGHT end. "
               "The same board as in the first attached image (its colours, frame, ledge, chalk and eraser), drawn whole, with NOBODY in front of it; the "
               "second image shows the shape and proportions wanted (ignore the panda in it). The slate is COMPLETELY BLANK and clean: no writing, no marks, "
               "no smudges. The LEFT end of the board must be clean and complete too (a panda will be placed over it later). Seen straight on, no wall, floor "
               "or room. Centred, filling about 94% of the width, even magenta all round." + STYLE},
    {"file": "out/raw/home-upnext-hills.png", "group": "home6", "size": "1536x1024",
     "refs": ["out/raw/home-teacher-board2.png"],
     "prompt": "Soft, misty Chinese mountains, to sit very faintly in the corner of a pale mint card behind text: three or four layered rounded peaks, the "
               "nearest a soft pale sage green, the farther ones paler and fading into mist, in a gentle ink-wash feel; a few wisps of mist between them. "
               "VERY LOW CONTRAST and light - all pale mint, sage and misty white-green, nothing dark, no outlines, no trees, no buildings, no sun, no birds. "
               "The hills sit along the bottom of the canvas, their bases fading out softly, filling about 85% of the width, even magenta above and around." + STYLE},
    {"file": "out/raw/quest-pouch.png", "group": "home6", "size": "1024x1024",
     "refs": ["out/raw/lantern-icon-lit.png", "out/raw/tab-home.png"],
     "prompt": "A small APP ICON of a Chinese lucky MONEY POUCH, shown at about 34 pixels beside 'Daily quests': a plump round red silk drawstring bag, "
               "gathered at the top with a gold cord tied in a small bow, the top frilled where it's drawn closed. On its front, a round gold patch with the "
               "Chinese character 福 in red - the ONE exception to 'no text': draw 福 clearly and correctly, nothing else written anywhere. Bold, chunky and "
               "simple like the attached icons: 2 to 3 soft tones, no small pattern, no fine detail. Upright, centred, filling about 75% of the canvas, even "
               "magenta all round." + STYLE.replace(' No text, no letters, no numbers,', ' Apart from the 福 on the pouch, no text, no letters, no numbers,')},
]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', [j['file'] for j in added])
