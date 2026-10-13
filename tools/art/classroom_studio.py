"""The Classroom board as a piece in the studio's Layer editor: the board, Bùbù the teacher (his pose, whole, to bend
with painted weights), his head and his book arm (Codex's, lined up on the pose by align_layers.py), placed on the
1024 sticker as the home screen has them (the board 1000 wide, Bùbù over its bottom-left corner)."""
import base64, io, json, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__)); RIG = os.path.join(HERE, 'out', 'rig')
PAD = 128

# where things go on the 1024 sticker
BOARD = (12, 262, 1000, 500)                         # x, y, w, h
board = Image.open(os.path.join(RIG, 'home-board-tall.png')).convert('RGBA').resize((BOARD[2], BOARD[3]), Image.LANCZOS)
pose = Image.open(os.path.join(RIG, 'home-teacher-pose-placed.png')).convert('RGBA')
bb = pose.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
BW = 450                                             # Bùbù's width on the sticker
k = BW / (bb[2] - bb[0]); BX = BOARD[0] - 30; BBOT = BOARD[1] + BOARD[3] + 35
BY = BBOT - round((bb[3] - bb[1]) * k)


def placed(im, x, y):
    c = Image.new('RGBA', (1024 + 2 * PAD, 1024 + 2 * PAD)); c.alpha_composite(im, (x + PAD, y + PAD)); return c


def bubu_part(n):
    im = Image.open(os.path.join(RIG, f'home-teacher-{n}-placed.png')).convert('RGBA').crop(bb)
    return placed(im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS), BX, BY)


parts = {'board': placed(board, BOARD[0], BOARD[1]), 'bubu': bubu_part('pose'), 'head': bubu_part('head'), 'armbook': bubu_part('arm-book')}
for n, im in parts.items(): im.save(os.path.join(RIG, f'mo-classroom-{n}-placed.png'))


def enc(im):
    b = io.BytesIO(); im.save(b, 'WEBP', quality=86); return 'data:image/webp;base64,' + base64.b64encode(b.getvalue()).decode()


def layer(name, im):
    pad = (im.width - 1024) // 2
    b2 = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox(); c = im.crop(b2)
    c = c.resize((max(1, c.width // 2), max(1, c.height // 2)), Image.LANCZOS)
    return {'name': name, 'x': b2[0] - pad, 'y': b2[1] - pad, 'w': b2[2] - b2[0], 'h': b2[3] - b2[1], 'src': enc(c),
            'px': (b2[0] + b2[2]) / 2 - pad, 'py': b2[3] - pad}


P = os.environ['TEMP'] + '/moart.json'; j = json.load(open(P))
ghost = Image.new('RGBA', (1024, 1024)); ghost.alpha_composite(parts['board'].crop((PAD, PAD, PAD + 1024, PAD + 1024))); ghost.alpha_composite(parts['bubu'].crop((PAD, PAD, PAD + 1024, PAD + 1024)))
g = ghost.resize((512, 512), Image.LANCZOS)
j['classroom'] = {'layers': [layer('board', parts['board']), layer('bubu', parts['bubu'])], 'ghost': enc(g)}
json.dump(j, open(P, 'w'))
print('classroom placed: Bùbù at', BX, BY, 'scale', round(k, 3))
