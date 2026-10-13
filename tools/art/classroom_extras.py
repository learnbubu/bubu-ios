"""The 加油 chalk lettering and the app-style "Let's practise" button as Classroom pieces for the Layer editor
(owner, 13 Oct 2026: place and size them by hand on the board)."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from edlib import item, RIG, PAD

def placed(im, cx, cy):
    c = Image.new('RGBA', (1024 + 2 * PAD, 1024 + 2 * PAD)); c.alpha_composite(im, (round(cx - im.width / 2) + PAD, round(cy - im.height / 2) + PAD)); return c

jy = Image.open(sys.argv[1]).convert('RGBA'); s = 380 / jy.width
jy = jy.resize((380, round(jy.height * s)), Image.LANCZOS)

# the button: our app buttons' shape (rounded box, a lip below) in the board's first colours (cream face, teal
# Nunito Black words), owner 13 Oct 2026; drawn at 3x then reduced
K = 3; W, H, LIP, R = 330 * K, 74 * K, 9 * K, 22 * K
f = ImageFont.truetype(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'native', 'Bubu', 'Resources', 'Fonts', 'Nunito-Black.ttf'), 36 * K)
b = Image.new('RGBA', (W, H + LIP)); d = ImageDraw.Draw(b)
d.rounded_rectangle((0, LIP, W - 1, H + LIP - 1), R, fill='#E2D3B4')
d.rounded_rectangle((0, 0, W - 1, H - 1), R, fill='#FFF7E6')
t = "Let's practise"; tb = d.textbbox((0, 0), t, font=f)
d.text(((W - (tb[2] + tb[0])) / 2, (H - (tb[3] + tb[1])) / 2), t, font=f, fill='#1F7A6C')
b = b.resize((W // K, (H + LIP) // K), Image.LANCZOS)

out = {}
for n, im, cx, cy in [('jiayou', jy, 640, 420), ('button', b, 640, 650)]:
    p = os.path.join(RIG, f'mo-classroom-{n}-placed.png'); placed(im, cx, cy).save(p); out[n] = item(p)
L = os.path.join(RIG, 'edlib.json'); j = json.load(open(L)); j['classroom'].update(out); json.dump(j, open(L, 'w'))
print({n: (v['x'], v['y'], v['w'], v['h']) for n, v in out.items()})
