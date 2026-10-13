"""The finished Classroom board in layers (Codex's edits of home-classroom-final.png), lined up on it: the base takes
the finished picture's outline; the head, its blink and the pointer arm are matched onto it (Codex drew them a little
off); the chalk doodles are lifted off their slate patches. Out: out/rig/cls-*.png on the final's canvas."""
import os, sys, json
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from align_layers import cutout, place

R, O = 'out/raw/', 'out/rig/'
fin = cutout(R + 'home-classroom-final.png'); fin[..., 3] = np.where(fin[..., 3] < 16, 0, fin[..., 3])
H, W = fin.shape[:2]
save = lambda a, n: Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA').save(O + f'cls-{n}.png')
save(fin, 'final')
# the base: its own pixels inside the finished picture's outline
b = np.array(Image.open(R + 'home-classroom-base.png').convert('RGBA').resize((W, H))).astype(np.float32)
b[..., 3] = fin[..., 3]; save(b, 'base')
# the head, matched; the blink given the same scale and place (it's an edit of the head)
def matched(n, ref=None):
    part = cutout(R + f'home-classroom-{n}.png'); part[..., 3] = np.where(part[..., 3] < 16, 0, part[..., 3])
    out, score, s, at = place(part, fin); print(n, 'match', score, 'scale', s, 'at', at); return out, s, at, part
head, s, at, hp = matched('head'); save(head, 'head')
bl = cutout(R + 'home-classroom-head-blink.png'); bl[..., 3] = np.where(bl[..., 3] < 16, 0, bl[..., 3])
import cv2
x, y, w, h = cv2.boundingRect((hp[..., 3] > 128).astype(np.uint8))
crop = bl[y:y + h, x:x + w]; t = cv2.resize(crop, (int(round(w * s)), int(round(h * s))), interpolation=cv2.INTER_AREA)
blo = np.zeros_like(fin); x1, y1 = at; blo[y1:y1 + t.shape[0], x1:x1 + t.shape[1]] = t[:H - y1, :W - x1]; save(blo, 'head-blink')
arm, *_ = matched('arm'); save(arm, 'arm')
# the doodles: the chalk marks off their patches (chalk is much lighter than the slate)
d = cutout(R + 'home-chalk-doodles.png'); rgb = d[..., :3]
lum = rgb.mean(2); slate = np.median(lum[d[..., 3] > 200]) if (d[..., 3] > 200).any() else 60
al = np.clip((lum - slate - 35) / 60, 0, 1) * (d[..., 3] / 255)
dd = d.copy(); dd[..., 3] = al * 255
lab, n = None, 0
m = (al > 0.15).astype(np.uint8)
cnt, lab = cv2.connectedComponents(cv2.dilate(m, np.ones((25, 25), np.uint8)))
pieces = []
for i in range(1, cnt):
    ys, xs = np.where((lab == i) & (m > 0))
    if len(xs) < 200: continue
    pieces.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
pieces.sort(key=lambda r: (round(r[1] / (H / 3)), r[0]))
names = ['sparks', 'star', 'star-gold', 'heart', 'swirl', 'sparkles', 'wave', 'smiley']
for nm, (x0, y0, x1, y1) in zip(names, pieces):
    Image.fromarray(np.clip(dd[y0 - 4:y1 + 4, x0 - 4:x1 + 4], 0, 255).astype(np.uint8), 'RGBA').save(O + f'chalk-{nm}.png')
print('doodles', len(pieces))

# --- second pass: the arm from the finished picture itself (Codex's was drawn too small): where the finished picture
# differs from the base, right of his head; the base without its magenta fringe; the doodles by their grid cells
fin = np.array(Image.open(O + 'cls-final.png')).astype(np.float32); base = np.array(Image.open(O + 'cls-base.png')).astype(np.float32)
mag = (base[..., 0] > 180) & (base[..., 2] > 180) & (base[..., 1] < 120)
base[..., 3] = np.where(mag, 0, base[..., 3]); save(base, 'base')
diff = np.abs(fin[..., :3] - base[..., :3]).mean(2) * (fin[..., 3] > 128)
headA = np.array(Image.open(O + 'cls-head.png'))[..., 3] > 40
m = ((diff > 28) & ~cv2.dilate(headA.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)).astype(np.uint8)
m[:, :int(W * 0.12)] = 0
m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
cnt, lab, st, _ = cv2.connectedComponentsWithStats(m)
keep = np.zeros_like(m)
for i in range(1, cnt):
    if st[i, cv2.CC_STAT_AREA] > 1500: keep[lab == i] = 1
soft = cv2.GaussianBlur(keep.astype(np.float32), (5, 5), 0)
arm = fin.copy(); arm[..., 3] = np.minimum(fin[..., 3], soft * 255); save(arm, 'arm')
print('arm px', int(keep.sum()))
d = cutout(R + 'home-chalk-doodles.png'); lum = d[..., :3].mean(2)
al = np.clip((lum - 95) / 60, 0, 1) * (d[..., 3] / 255); dd = d.copy(); dd[..., 3] = al * 255
DH, DW = dd.shape[:2]
names = ['sparks', 'star', 'star-gold', 'heart', 'swirl', 'sparkles', 'wave', 'smiley']
for i, nm in enumerate(names):
    cx, cy = i % 4, i // 4
    cell = dd[cy * DH // 2:(cy + 1) * DH // 2, cx * DW // 4:(cx + 1) * DW // 4]
    ys, xs = np.where(cell[..., 3] > 30)
    c = cell[ys.min() - 4:ys.max() + 5, xs.min() - 4:xs.max() + 5]
    Image.fromarray(np.clip(c, 0, 255).astype(np.uint8), 'RGBA').save(O + f'chalk-{nm}.png')
print('doodles by cell')
