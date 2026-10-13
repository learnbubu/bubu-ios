"""The new Home and Classroom screens' art into the app (owner's studio save, 13 Oct 2026):
- the Classroom board as the Layer editor has it (editor/classroom, saved to a JSON file by Claude), each layer
  drawn with its mask, size, turn and flip into one frame (the sticker's board area, x 12-1012, y 227-797):
  a still back (the board and what's drawn on it), and the swinging pieces each in their own picture
- the Home pieces (lantern chips, coin, buns, hills, pouch, tab icons, chalk marks) and the Classroom's
  (eight practice pictures, Bùbù peeking) from the studio's packed art
- Model/HomeArt.swift: where each swinging piece turns, how far, how fast, the blink, the button's box

  python install_home.py <editor-classroom.json> <homeart.json> <tuning-home.json>
"""
import base64, io, json, math, os, sys
from PIL import Image, ImageDraw, ImageFilter
from install import imageset

HERE = os.path.dirname(os.path.abspath(__file__))
RIG = os.path.join(HERE, 'out', 'rig')
MODEL = os.path.join(HERE, '..', '..', 'native', 'Bubu', 'Model', 'HomeArt.swift')
X0, Y0, FW, FH = 12, 227, 1000, 570      # the board's area of the 1024 sticker
SS = 2                                    # drawn at twice the frame, then reduced


def dec(s): return Image.open(io.BytesIO(base64.b64decode(s.split(',', 1)[1]))).convert('RGBA')


def bez(p0, p1, p2, p3, n=24):
    return [tuple((1 - t) ** 3 * a + 3 * (1 - t) ** 2 * t * b + 3 * (1 - t) * t * t * c + t ** 3 * d
                  for a, b, c, d in zip(p0, p1, p2, p3)) for t in (i / n for i in range(n + 1))]


def masked(im, L, w, h):
    """The layer's picture with its pen mask (the studio's edComposite)."""
    V = L.get('vmask')
    if not (V and V.get('on', True) is not False and V.get('closed') and len(V['pts']) > 2): return im
    fx, fy = im.width / w, im.height / h; P = V['pts']; pts = []
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        pts += bez((a['x'] * fx, a['y'] * fy), (a['ox'] * fx, a['oy'] * fy), (b['ix'] * fx, b['iy'] * fy), (b['x'] * fx, b['y'] * fy))
    m = Image.new('L', im.size, 0); ImageDraw.Draw(m).polygon(pts, fill=255)
    if V.get('feather', 0) > 0: m = m.filter(ImageFilter.GaussianBlur(V['feather'] * fx / L['s']))
    if V.get('mode') == 'hide': m = m.point(lambda v: 255 - v)
    out = im.copy(); out.putalpha(Image.fromarray(__import__('numpy').minimum(__import__('numpy').asarray(im.getchannel('A')), __import__('numpy').asarray(m))))
    return out


def draw(frame, lib, L):
    """Place one layer on the frame: centre (cx, cy), scale s, turn r, flip fx (the studio's edMat)."""
    it = lib[L['ref'][4:]]; im = masked(dec(it['src']), L, it['w'], it['h'])
    w, h = it['w'] * L['s'] * SS, it['h'] * L['s'] * SS
    im = im.resize((max(1, round(w)), max(1, round(h))), Image.LANCZOS)
    if L.get('fx', 1) < 0: im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if L.get('op', 1) < 1: im.putalpha(im.getchannel('A').point(lambda v: round(v * L['op'])))
    if L.get('r'): im = im.rotate(-L['r'], Image.BICUBIC, expand=True)
    frame.alpha_composite(im, (round((L['cx'] - X0) * SS - im.width / 2), round((L['cy'] - Y0) * SS - im.height / 2)))


def main(doc_p, art_p, home_p):
    doc = json.load(open(doc_p, encoding='utf-8')); layers = [L for L in json.loads(doc['layers']) if L.get('vis')]
    lib = json.load(open(os.path.join(RIG, 'edlib.json')))['classroom']
    art = json.load(open(art_p)); home = json.loads(json.load(open(home_p, encoding='utf-8'))['settings'])
    # bottom to top; consecutive still layers share one picture, each moving layer gets its own
    groups = []
    for L in reversed(layers):
        mo = (L.get('motion') or {}).get('type', 'none')
        moving = mo in ('swing', 'bob') or L.get('blink') or L['ref'] == 'lib:button'
        if moving or not groups or groups[-1]['moving']: groups.append({'moving': moving, 'layers': [L]})
        else: groups[-1]['layers'].append(L)
    pieces = []
    for i, g in enumerate(groups):
        L = g['layers'][0]; mo = L.get('motion') or {}
        if L['ref'] == 'lib:button':
            it = lib['button']; w, h = it['w'] * L['s'], it['h'] * L['s']
            pieces.append(('button', L, (L['cx'] - X0 - w / 2, L['cy'] - Y0 - h / 2, w, h))); continue
        f = Image.new('RGBA', (FW * SS, FH * SS))
        for l in g['layers']: draw(f, lib, l)
        name = f'class-board-{i}'
        imageset(name, f, FW * SS)
        pieces.append((name, L, None))
    # Swift: the board's pieces bottom to top
    rows = []
    for name, L, box in pieces:
        if name == 'button':
            rows.append(f'    static let button = CGRect(x: {box[0]:.1f}, y: {box[1]:.1f}, width: {box[2]:.1f}, height: {box[3]:.1f})'); continue
        mo = L.get('motion') or {}; t = mo.get('type', 'none')
        rows.append(f'        Piece(image: "{name}", swing: {mo.get("amp", 0) if t == "swing" else 0}, bob: {mo.get("amp", 0) if t == "bob" else 0}, '
                    f'period: {mo.get("ms", 900) / 1000}, phase: {mo.get("phase", 0)}, pivot: CGPoint(x: {L["pv"][0] - X0}, y: {L["pv"][1] - Y0}), blink: {(L.get("blink") or 0) / 1000}),')
    btn = [r for r in rows if r.startswith('    static let button')]; ps = [r for r in rows if not r.startswith('    static let button')]
    # the chalk marks that are on, each where it was placed (% of the board), from the Home tab
    marks = [(k, v) for k, v in home['dd'].items() if v.get('on')]
    for k, v in marks:
        src = {'stargold': 'star-gold'}.get(k, k)
        imageset(f'chalk-{src}', Image.open(os.path.join(RIG, f'chalk-{src}.png')).convert('RGBA'), 360)
    mrows = [f'        Mark(image: "chalk-{ {"stargold": "star-gold"}.get(k, k)}", x: {v["x"]}, y: {v["y"]}, w: {v["w"]}, r: {v.get("r", 0)}),' for k, v in marks]
    # Home's and the Classroom's pictures
    for k, n, size in [('chipun', 'chip-lantern-unlit', 120), ('chiplit', 'chip-lantern-lit', 120), ('hills', 'home-hills', 900),
                       ('ci_peek', 'class-peek', 600)] + [(f'tab2_{t}', f'tab2-{t}', 192) for t in ('home', 'learn', 'profile', 'settings')] \
            + [(f'ci_{t}', f'class-{t}', 440) for t in ('listen', 'vocab', 'speak', 'write', 'quiz', 'chars', 'read', 'tones')]:
        imageset(n, dec(art[k]), size)
    for t in ('home', 'learn', 'profile', 'settings'):    # the tabs you're not on: grey and faded, as the studio has them
        im = dec(art[f'tab2_{t}']); g = im.convert('LA').convert('RGBA'); g.putalpha(im.getchannel('A').point(lambda v: v // 2))
        imageset(f'tab2-{t}-off', g, 192)
    imageset('quest-pouch', Image.open(os.path.join(RIG, 'quest-pouch-keyed.png')).convert('RGBA'), 330)
    open(MODEL, 'w', encoding='utf-8').write(f'''// Generated by tools/art/install_home.py from the studio's Layer editor (Classroom (home)) and Home tab.
import CoreGraphics

/// The Classroom board on Home, as placed in the studio: pictures in a {FW} x {FH} frame, bottom to top.
enum HomeArt {{
    static let frame = CGSize(width: {FW}, height: {FH})
    struct Piece {{ let image: String; let swing: Double; let bob: Double; let period: Double; let phase: Double; let pivot: CGPoint; let blink: Double }}
    struct Mark {{ let image: String; let x: Double; let y: Double; let w: Double; let r: Double }}
    static let pieces: [Piece] = [
{chr(10).join(ps)}
    ]
{chr(10).join(btn)}
    static let marks: [Mark] = [
{chr(10).join(mrows)}
    ]
}}
''')
    print('pieces', [p[0] for p in pieces], 'marks', [m[0] for m in marks])


if __name__ == '__main__': main(*sys.argv[1:4])
