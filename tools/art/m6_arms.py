"""Places the rig6 arm pieces by outline (plain black arms have no features to match): each new piece's
silhouette fitted to the original sticker's limb (cut by limbs_cut.py, exact), over scale, a little
turn and position, by best overlap (IoU). The swapped poses then take the matched piece's scale.
Rewrites out/rig/m6-<k>-<piece>.png and updates out/rig/m6.json."""
import json
import os

import cv2
import numpy as np
from PIL import Image
from scipy.signal import fftconvolve

from m6_place import RAW, RIG, PAD, S, load, box, sim, warp

N = 320          # search size


def mask(a):
    return (a[:, :, 3] > 128).astype(np.float32)


def fit(piece, target):
    """best (scale, angle, M) putting `piece` (1024 canvas) onto `target` (the padded 1280 canvas mask)."""
    T = cv2.resize(target, (N, N), interpolation=cv2.INTER_AREA)
    tsum = T.sum()
    pb = box(piece); P0 = piece[int(pb[1]):int(pb[3]) + 1, int(pb[0]):int(pb[2]) + 1]
    best = (-1, None)
    for ang in range(-20, 21, 4):
        R = cv2.getRotationMatrix2D((P0.shape[1] / 2, P0.shape[0] / 2), ang, 1)
        Pr = cv2.warpAffine(P0, R, (P0.shape[1], P0.shape[0]), borderValue=(0, 0, 0, 0))
        for sc in np.linspace(0.3, 1.4, 34):
            w, h = int(Pr.shape[1] * sc * N / S), int(Pr.shape[0] * sc * N / S)
            if w < 4 or h < 4 or w >= N or h >= N: continue
            m = cv2.resize(mask(Pr), (w, h), interpolation=cv2.INTER_AREA)
            inter = fftconvolve(T, m[::-1, ::-1], mode="valid")
            iou = inter / (tsum + m.sum() - inter)
            i = np.unravel_index(np.argmax(iou), iou.shape)
            if iou[i] > best[0]:
                best = (iou[i], (sc, ang, i[1] * S / N, i[0] * S / N, w * S / N, h * S / N))
    iou, (sc, ang, x, y, w, h) = best
    # M: rotate the piece about its box centre, scale, and put that box's centre at the found place's centre
    M = sim(sc, ang, (pb[0] + pb[2]) / 2, (pb[1] + pb[3]) / 2, x + w / 2 - PAD, y + h / 2 - PAD)
    return iou, sc, ang, M


if __name__ == "__main__":
    info = json.load(open(os.path.join(RIG, "m6.json")))
    jobs = [("sweep", "arms-broom", "mo-sweep-limb-placed.png", None),
            ("earlybird", "arms-lap", "mo-earlybird-limb-placed.png", None),
            ("brain", "arm-left", "mo-brain-limb-placed.png", "L"), ("brain", "arm-right", "mo-brain-limb-placed.png", "R")]
    found = {}
    for k, n, tgt, side in jobs:
        t = mask(np.asarray(Image.open(os.path.join(RIG, tgt))))
        if t.shape[0] != S:                                  # (placed on the plain 1024 canvas)
            tt = np.zeros((S, S), np.float32); tt[PAD:PAD + t.shape[0], PAD:PAD + t.shape[1]] = t; t = tt
        if side:
            xs = np.where(t.any(0))[0]; mid = (xs.min() + xs.max()) // 2
            if side == "L": t[:, mid:] = 0
            else: t[:, :mid] = 0
        piece = load(os.path.join(RAW, f"m6-{k}-{n}.png"))
        iou, sc, ang, M = fit(piece, t)
        print(f"{k:10s} {n:11s} overlap {iou:.2f}  scale {sc:.2f}  turn {ang}")
        Image.fromarray(warp(piece, M)).save(os.path.join(RIG, f"m6-{k}-{n}.png"))
        found[(k, n)] = (sc, M)
    # early bird's sip: the lap arms' scale, the cup up by his mouth
    sc, _ = found[("earlybird", "arms-lap")]
    lap = box(np.asarray(Image.open(os.path.join(RIG, "m6-earlybird-arms-lap.png")))) - PAD
    body = box(np.asarray(Image.open(os.path.join(RIG, "m6-earlybird-body.png")))) - PAD
    sp = load(os.path.join(RAW, "m6-earlybird-arms-sip.png")); b = box(sp)
    M = sim(sc, 0, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, (lap[0] + lap[2]) / 2, body[1] + (body[3] - body[1]) * 0.40)
    Image.fromarray(warp(sp, M)).save(os.path.join(RIG, "m6-earlybird-arms-sip.png"))
    for k, n in [("sweep", "arms-broom"), ("earlybird", "arms-lap"), ("earlybird", "arms-sip"), ("brain", "arm-left"), ("brain", "arm-right")]:
        a = np.asarray(Image.open(os.path.join(RIG, f"m6-{k}-{n}.png")))
        info[k][n]["box"] = [float(v) for v in box(a) - PAD]
    def joint(k, n):
        a = np.asarray(Image.open(os.path.join(RIG, f"m6-{k}-{n}.png"))); b = np.asarray(Image.open(os.path.join(RIG, f"m6-{k}-body.png")))
        ys, xs = np.where((a[:, :, 3] > 128) & (b[:, :, 3] > 128))
        if not len(xs): ys, xs = np.where(a[:, :, 3] > 128)
        return [float(xs.mean()) - PAD, float(ys.mean()) - PAD]
    for n in ("arm-left", "arm-right"): info["brain"][n]["pivot"] = joint("brain", n)
    info["sweep"]["arms-broom"]["pivot"] = joint("sweep", "arms-broom")
    json.dump(info, open(os.path.join(RIG, "m6.json"), "w"), indent=1)
