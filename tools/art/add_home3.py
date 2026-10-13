"""Codex jobs, third go: Bùbù the teacher at his chalkboard (Home's way in to the Classroom), and the tab icons
again as one matched sheet."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
have = {j['file'] for j in jobs}
STYLE = jobs[-1]['prompt'][jobs[-1]['prompt'].index('\n\nStyle:'):]

new = [
    {"file": "out/raw/home-teacher-board.png", "group": "home3", "size": "1536x1024",
     "refs": ["out/raw/panda-teacher.png", "out/raw/tab-home.png"],
     "prompt": "A WIDE, LOW classroom chalkboard with Bùbù the panda as the teacher, for the bottom of the app's home screen. "
               "The chalkboard: a dark green slate, about three times as wide as it is tall, in a simple warm wooden frame, with a wooden ledge along "
               "its bottom holding one stick of white chalk and a small felt eraser. The slate is COMPLETELY BLANK and clean: no writing, no marks, "
               "no smudges - the app writes on it. Bùbù (the panda in the first image, same face and proportions, with his round glasses and red backpack) "
               "stands IN FRONT of the LEFT end of the board, full body, about as tall as the board, facing us happily and pointing at the board with a "
               "thin wooden pointer stick in his right paw. He covers only the left fifth of the board, so the rest of the slate is clear for words. "
               "Seen straight on, no floor or room, nothing else in the picture. The whole group centred and filling about 90% of the width, even magenta all round."
               + STYLE},
    {"file": "out/raw/tab-icons-sheet.png", "group": "home3", "size": "1536x1024",
     "refs": ["out/raw/tab-home.png", "out/raw/tab-profile.png", "out/raw/tab-settings.png"],
     "prompt": "A matched SET of four APP TAB-BAR ICONS on one sheet, in a 2 by 2 grid with plenty of even magenta space round each, all drawn at the same size and "
               "with the same weight, so they sit together along the bottom of the app at 24 to 30 pixels. In order, left to right then top to bottom: "
               "(1) HOME: a small cosy Chinese house seen front on, a curved teal roof with two upturned ends, cream walls and a round red door; "
               "(2) LEARN: a short winding path climbing a little rounded green hill to a small red flag on the top; "
               "(3) PROFILE: Bùbù the panda's head, front on, smiling with closed happy eyes; "
               "(4) SETTINGS: a chunky rounded gear wheel in jade green with a gold centre. "
               "Each icon bold, chunky and rounded, ONE simple silhouette, only 2 to 3 soft flat tones per colour, no outline, no thin parts, no small details, "
               "no texture - like polished game-app icons. The attached images are a first set: keep their colours and friendliness but make them bolder, "
               "rounder, simpler and more alike in size and weight. No text, no labels, no grid lines." + STYLE},
]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', [j['file'] for j in added])
