"""Bùbù the teacher's layers, lined up on his pose: Codex redrew each part at its own scale and place (on a light
grey ground), so each is cut out, then matched onto the pose (the scale and offset where it fits best) and saved on
the pose's canvas as out/rig/home-teacher-<part>-placed.png."""
import os, sys
import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, 'out', 'raw'), os.path.join(HERE, 'out', 'rig')


def cutout(path):
    """Alpha from magenta, or from the plain ground colour at the corners."""
    a = np.array(Image.open(path).convert('RGBA')).astype(np.float32)
    rgb = a[..., :3]
    if a[..., 3].min() < 250:            # already transparent
        return a
    corners = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3), rgb[-8:, :8].reshape(-1, 3), rgb[-8:, -8:].reshape(-1, 3)])
    g = np.median(corners, 0)
    if g[0] > 200 and g[1] < 60 and g[2] > 200:      # magenta
        r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        al = 1 - np.clip(((r + b) / 2 - gg - 60) / 80, 0, 1) * np.clip(1 - np.abs(r - b) / 90, 0, 1)
    else:                                             # a plain light ground: distance from it
        d = np.sqrt(((rgb - g) ** 2).sum(2))
        al = np.clip((d - 10) / 22, 0, 1)
    a[..., 3] = al * 255
    return a


def place(part, pose):
    """The scale and offset that put `part` (cut out) onto `pose`, by matching its pixels (masked) at many scales."""
    P = pose[..., :3].astype(np.float32); ph, pw = P.shape[:2]
    bb = cv2.boundingRect((part[..., 3] > 128).astype(np.uint8))
    x, y, w, h = bb
    crop = part[y:y + h, x:x + w]
    best = (-1, None)
    small = 0.35                                     # search on a smaller copy first
    Ps = cv2.resize(P, None, fx=small, fy=small, interpolation=cv2.INTER_AREA)
    for s in np.arange(0.40, 1.80, 0.02):
        tw, th = int(w * s * small), int(h * s * small)
        if tw < 8 or th < 8 or tw >= Ps.shape[1] or th >= Ps.shape[0]: continue
        t = cv2.resize(crop, (tw, th), interpolation=cv2.INTER_AREA)
        m = (t[..., 3] > 160).astype(np.float32)
        if m.sum() < 30: continue
        r = cv2.matchTemplate(Ps, t[..., :3].astype(np.float32), cv2.TM_CCORR_NORMED, mask=np.dstack([m] * 3))
        r[~np.isfinite(r)] = -1
        _, v, _, loc = cv2.minMaxLoc(r)
        if v > best[0]: best = (v, (s, loc))
    v, (s, loc) = best
    # refine at full size near the coarse answer
    best2 = (-1, None)
    for s2 in np.arange(s - 0.03, s + 0.031, 0.005):
        tw, th = int(round(w * s2)), int(round(h * s2))
        t = cv2.resize(crop, (tw, th), interpolation=cv2.INTER_AREA)
        m = (t[..., 3] > 160).astype(np.float32)
        x0, y0 = int(loc[0] / small) - 24, int(loc[1] / small) - 24
        x0, y0 = max(0, x0), max(0, y0)
        reg = P[y0:min(ph, y0 + th + 48), x0:min(pw, x0 + tw + 48)]
        if reg.shape[0] < th or reg.shape[1] < tw: continue
        r = cv2.matchTemplate(reg, t[..., :3].astype(np.float32), cv2.TM_CCORR_NORMED, mask=np.dstack([m] * 3))
        r[~np.isfinite(r)] = -1
        _, v2, _, l2 = cv2.minMaxLoc(r)
        if v2 > best2[0]: best2 = (v2, (s2, (x0 + l2[0], y0 + l2[1]), t))
    v2, (s2, at, t) = best2
    out = np.zeros_like(pose)
    x1, y1 = at; h1, w1 = t.shape[:2]
    out[y1:y1 + h1, x1:x1 + w1] = t[:max(0, min(h1, ph - y1)), :max(0, min(w1, pw - x1))]
    return out, round(float(v2), 4), round(float(s2), 3), at


if __name__ == '__main__':
    pose = cutout(os.path.join(RAW, 'home-teacher-pose.png'))
    Image.fromarray(np.clip(pose, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(RIG, 'home-teacher-pose-placed.png'))
    parts = sys.argv[1:] or ['body', 'head', 'head-blink', 'arm-pointer', 'arm-book']
    for n in parts:
        part = cutout(os.path.join(RAW, f'home-teacher-{n}.png'))
        out, score, s, at = place(part, pose)
        Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA').save(os.path.join(RIG, f'home-teacher-{n}-placed.png'))
        print(n, 'match', score, 'scale', s, 'at', at)
