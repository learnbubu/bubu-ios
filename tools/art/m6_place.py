"""Places the rig6 pieces in their stickers (Codex centred each on its own canvas). Pieces that appear
in the sticker are matched to it by SIFT features (one even scale, a little turn); the swapped poses,
which don't appear in it, take the scale of the piece they swap with and the place given here.
Writes out/rig/m6-<k>-<piece>.png on a padded canvas (PAD round the sticker's 1024), and
out/rig/m6.json with each piece's box and pivot."""
import json
import os

import cv2
import numpy as np
from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
RAW, RIG = os.path.join(HERE, "out", "raw"), os.path.join(HERE, "out", "rig")
PAD = 128
S = 1024 + 2 * PAD

# pieces matched straight to the sticker; then the ones placed relative to another piece
MATCH = {"flawless": ["body", "arms-down", "paper"], "kungfu": [], "sweep": ["body", "arms-broom"],
         "nightowl": ["body", "lantern"], "earlybird": ["body", "arms-lap"], "brain": ["body", "arm-left", "arm-right", "books"]}


def load(p, size=1024):
    return np.asarray(process.key_full(Image.open(p).convert("RGBA")).resize((size, size), Image.LANCZOS))


def flat(a):
    rgb = a[:, :, :3] * (a[:, :, 3:] / 255) + 128 * (1 - a[:, :, 3:] / 255)
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY), (a[:, :, 3] > 128).astype(np.uint8) * 255


def warp(a, M):
    Mp = np.array(M, np.float32).copy(); Mp[0, 2] += PAD; Mp[1, 2] += PAD
    return cv2.warpAffine(a, Mp, (S, S), flags=cv2.INTER_LANCZOS4, borderValue=(0, 0, 0, 0))


def box(a):
    ys, xs = np.where(a[:, :, 3] > 128)
    return np.array([xs.min(), ys.min(), xs.max(), ys.max()], float)


def sim(scale, angle, cx, cy, tx, ty):
    """scale and turn about (cx, cy) in the piece, landing it at (tx, ty) in the sticker."""
    M = cv2.getRotationMatrix2D((cx, cy), angle, scale)
    M[0, 2] += tx - cx; M[1, 2] += ty - cy
    return M


if __name__ == "__main__":
    sift = cv2.SIFT_create(nfeatures=8000); bf = cv2.BFMatcher()
    info = {}
    for k, names in MATCH.items():
        full = load(os.path.join(RAW, f"mo-{k}.png"))
        kf, df = sift.detectAndCompute(*flat(full))
        placed = {}
        for n in names:
            lay = load(os.path.join(RAW, f"m6-{k}-{n}.png"))
            kl, dl = sift.detectAndCompute(*flat(lay))
            good = [m for m, q in bf.knnMatch(dl, df, k=2) if m.distance < 0.78 * q.distance]
            M, inl = cv2.estimateAffinePartial2D(np.float32([kl[m.queryIdx].pt for m in good]),
                                                 np.float32([kf[m.trainIdx].pt for m in good]),
                                                 method=cv2.RANSAC, ransacReprojThreshold=6)
            s = float(np.hypot(M[0, 0], M[1, 0])) if M is not None else 0
            ang = np.degrees(np.arctan2(M[1, 0], M[0, 0])) if M is not None else 0
            if M is None or not (0.3 < s < 1.5) or abs(ang) > 25 or inl.sum() < 12:
                # too plain for features (black arms): match by shape and colour against the sticker
                from layers_fit import best_place, N
                lb, (score, (s, dx, dy, w, h)) = best_place(Image.fromarray(full), Image.fromarray(lay))
                sc = 1024 / N; ls = (w * sc) / (lb[2] - lb[0]); ang = 0
                M = np.float32([[ls, 0, dx * sc - lb[0] * ls], [0, ls, dy * sc - lb[1] * ls]]); inl = np.ones(1)
                print(f"{k:10s} {n:12s} by shape: scale {ls:.2f}")
            print(f"{k:10s} {n:12s} {int(inl.sum()) if M is not None else 0}/{len(good)}  scale {s:.2f} turn {ang:.0f}")
            placed[n] = (lay, M)
        info[k] = placed
    # the swapped poses and extras
    def put(k, n, M):
        info.setdefault(k, {})[n] = (load(os.path.join(RAW, f"m6-{k}-{n}.png")), M)

    # flawless arms-high: arms-down's scale, raised so the stamp sits just above his head
    lay_d, Md = info["flawless"]["arms-down"]
    s = float(np.hypot(Md[0, 0], Md[1, 0]))
    hi = load(os.path.join(RAW, "m6-flawless-arms-high.png")); b = box(hi)
    lay_b, Mb = info["flawless"]["body"]; bb = box(warp(lay_b, Mb)) - PAD
    put("flawless", "arms-high", sim(s, 0, (b[0] + b[2]) / 2, b[3], (bb[0] + bb[2]) / 2 - 10, bb[1] + (bb[3] - bb[1]) * 0.55))
    put("flawless", "paper-blank", info["flawless"]["paper"][1])
    # earlybird arms-sip: arms-lap's scale, the cup up at his mouth
    lay_l, Ml = info["earlybird"]["arms-lap"]; s = float(np.hypot(Ml[0, 0], Ml[1, 0]))
    sp = load(os.path.join(RAW, "m6-earlybird-arms-sip.png")); b = box(sp)
    lay_b, Mb = info["earlybird"]["body"]; bb = box(warp(lay_b, Mb)) - PAD
    lap = box(warp(lay_l, Ml)) - PAD
    put("earlybird", "arms-sip", sim(s, 0, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, (lap[0] + lap[2]) / 2, bb[1] + (bb[3] - bb[1]) * 0.42))
    # kungfu ready: Bùbù's head the size and place it is in the kick sticker
    full = load(os.path.join(RAW, "mo-kungfu.png")); rd = load(os.path.join(RAW, "m6-kungfu-ready.png"))
    kf, df = sift.detectAndCompute(*flat(full)); kl, dl = sift.detectAndCompute(*flat(rd))
    good = [m for m, q in bf.knnMatch(dl, df, k=2) if m.distance < 0.78 * q.distance]
    M, inl = cv2.estimateAffinePartial2D(np.float32([kl[m.queryIdx].pt for m in good]), np.float32([kf[m.trainIdx].pt for m in good]),
                                         method=cv2.RANSAC, ransacReprojThreshold=6)
    print("kungfu     ready (by the head)", int(inl.sum()), "/", len(good), "scale", round(float(np.hypot(M[0, 0], M[1, 0])), 2))
    put("kungfu", "ready", M)
    wh = load(os.path.join(RAW, "m6-kungfu-whoosh.png")); b = box(wh)
    put("kungfu", "whoosh", sim(0.55, 0, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2, 330, 470))
    # write them, with boxes; pivots (sticker px): where a turning piece meets its body
    out = {}
    for k, ps in info.items():
        out[k] = {}
        for n, (lay, M) in ps.items():
            w = warp(lay, M)
            Image.fromarray(w).save(os.path.join(RIG, f"m6-{k}-{n}.png"))
            bx = box(w) - PAD
            out[k][n] = {"box": [float(v) for v in bx]}
    def joint(k, n, body="body", end="low"):
        a = np.asarray(Image.open(os.path.join(RIG, f"m6-{k}-{n}.png"))); bdy = np.asarray(Image.open(os.path.join(RIG, f"m6-{k}-{body}.png")))
        over = (a[:, :, 3] > 128) & (bdy[:, :, 3] > 128); ys, xs = np.where(over)
        if not len(xs): ys, xs = np.where(a[:, :, 3] > 128)
        return [float(xs.mean()) - PAD, float(ys.mean()) - PAD]
    for n in ("arm-left", "arm-right"): out["brain"][n]["pivot"] = joint("brain", n)
    lb = out["brain"]["books"]["box"]; out["brain"]["books"]["pivot"] = [(lb[0] + lb[2]) / 2, lb[3]]
    lt = out["nightowl"]["lantern"]["box"]; out["nightowl"]["lantern"]["pivot"] = [(lt[0] + lt[2]) / 2, lt[1] + 6]
    out["sweep"]["arms-broom"]["pivot"] = joint("sweep", "arms-broom")
    json.dump(out, open(os.path.join(RIG, "m6.json"), "w"), indent=1)
    print("written")
