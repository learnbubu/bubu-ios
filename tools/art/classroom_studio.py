"""The Classroom board as a piece in the studio's Layer editor: the finished picture's layers (out/rig/cls-*.png, all
on its canvas, from classroom_cut.py) and the chalk marks, placed on the 1024 sticker (the board 1000 wide, centred),
for the owner to stack, mask and animate by hand."""
import base64, io, json, os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__)); RIG = os.path.join(HERE, 'out', 'rig')
PAD = 128

fin = Image.open(os.path.join(RIG, 'cls-final.png')).convert('RGBA')
bb = fin.getchannel('A').point(lambda v: 255 if v > 120 else 0).getbbox()
k = 1000 / (bb[2] - bb[0]); X0 = 12; Y0 = round(512 - (bb[3] - bb[1]) * k / 2)


def placed(im, x, y):
    c = Image.new('RGBA', (1024 + 2 * PAD, 1024 + 2 * PAD)); c.alpha_composite(im, (x + PAD, y + PAD)); return c


def layer_of(n):
    im = Image.open(os.path.join(RIG, f'cls-{n}.png')).convert('RGBA').crop(bb)
    return placed(im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS), X0, Y0)


parts = {n: layer_of(n) for n in ['final', 'board', 'body', 'base', 'head', 'head-blink', 'eyes-shut', 'arm', 'front']}
# the chalk marks, each at a modest size above his pointer (to be moved by hand)
for i, n in enumerate(['sparks', 'star-gold', 'star', 'heart', 'sparkles', 'smiley']):
    im = Image.open(os.path.join(RIG, f'chalk-{n}.png')).convert('RGBA'); s = 90 / max(im.size)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    parts['chalk-' + n] = placed(im, 300 + i * 18, Y0 + 60)
for f in os.listdir(RIG):
    if f.startswith('mo-classroom-') and f.endswith('-placed.png'): os.remove(os.path.join(RIG, f))
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
g = parts['final'].crop((PAD, PAD, PAD + 1024, PAD + 1024)).resize((512, 512), Image.LANCZOS)
j['classroom'] = {'layers': [layer('final', parts['final'])], 'ghost': enc(g)}
json.dump(j, open(P, 'w'))
print('classroom pieces:', list(parts))
