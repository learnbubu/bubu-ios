"""Play an app avatar (Studio's app export, format 'bubu-avatar' version 2) from its files alone, as the iPhone app's native
player will, and check it against Studio's own renders. The reference for the Swift player: what it reads and how it draws.

- parts bottom first; a part shows at its opacity for the frame (0: hidden, or in a view not shown)
- a 'mesh' part's points for the frame come from the animation's `points` file (int16 tenths, frames x mesh parts x points);
  a 'skin' part's from its rest points and its bones' matrices (weights x matrix, summed)
- each triangle textured from the part's png by its uvs
- shadows, as Studio draws them: every part that casts, above a part that receives (or under it, in its `from`), throws its own
  shape `distance` away from the light (from the caster's middle: its rim's average), not on parts in its `skip`; those
  shapes together, softened by `softness`, darken the receiver by `strength`, inside the receiver. A second light with
  `instead` lights its `only` parts in place of the first

From tools/art: ../sfx/.venv/Scripts/python -I avatar_replay.py <export folder> [ms,ms,...]
Writes <folder>/play-<ms>.png and, where Studio's ref-<ms>.png is there, compare-<ms>.png and how many pixels differ.
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image

folder = sys.argv[1]
name = next(f for f in os.listdir(folder) if f.endswith(".json"))
A = json.load(open(os.path.join(folder, name), encoding="utf-8"))
W, H = A["size"]
parts = A["parts"]
anim_name, anim = next(iter(A["anims"].items()))
fps, frames = A["fps"], anim["frames"]
mesh_ix = [i for i, p in enumerate(parts) if p.get("kind", "skin") == "mesh"]
npts = {i: len(parts[i]["verts"]) // 2 for i in mesh_ix}
points = None
if anim.get("points"):
    raw = np.fromfile(os.path.join(folder, anim["points"]), dtype="<i2").astype(np.float32) / 10
    points = raw.reshape(frames, -1)
tex = {i: np.asarray(Image.open(os.path.join(folder, p["tex"])).convert("RGBA")).astype(np.float32) / 255 for i, p in enumerate(parts)}
bg = np.array([0xf8, 0xf4, 0xec], np.float32) / 255


def verts_at(f):
    out, o = {}, 0
    for i in mesh_ix:
        n = npts[i] * 2
        out[i] = points[f, o:o + n].reshape(-1, 2)
        o += n
    for i, p in enumerate(parts):
        if p.get("kind", "skin") != "skin":
            continue
        rest = np.array(p["verts"], np.float32).reshape(-1, 2)
        nb = len(A["bones"])
        mats = np.array(anim["mats"], np.float32).reshape(frames, nb, 6)[f]
        bones = np.array(p["bones"]).reshape(-1, 4)
        ws = np.array(p["weights"], np.float32).reshape(-1, 4)
        v = np.zeros_like(rest)
        for k in range(4):
            m = mats[np.maximum(bones[:, k], 0)]
            w = ws[:, k:k + 1] * (bones[:, k:k + 1] >= 0)
            v += w * np.stack([m[:, 0] * rest[:, 0] + m[:, 2] * rest[:, 1] + m[:, 4], m[:, 1] * rest[:, 0] + m[:, 3] * rest[:, 1] + m[:, 5]], 1)
        out[i] = v
    return out


def draw_part(i, v):
    """the part's picture laid on its triangles: colour and alpha, the document's size"""
    p, t = parts[i], tex[i]
    th, tw = t.shape[:2]
    uv = np.array(p["uvs"], np.float32).reshape(-1, 2) * [tw, th]
    rgba = np.zeros((H, W, 4), np.float32)
    tris = np.array(p["tris"]).reshape(-1, 3)
    for a, b, c in tris:
        src = np.float32([uv[a], uv[b], uv[c]])
        dst = np.float32([v[a], v[b], v[c]])
        if abs(cv2.contourArea(dst)) < 0.01:
            continue
        x0, y0 = np.floor(dst.min(0)).astype(int) - 1
        x1, y1 = np.ceil(dst.max(0)).astype(int) + 2
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, W), min(y1, H)
        if x1 <= x0 or y1 <= y0:
            continue
        M = cv2.getAffineTransform(src, (dst - [x0, y0]).astype(np.float32))
        warped = cv2.warpAffine(t, M, (x1 - x0, y1 - y0), flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)
        mask = np.zeros((y1 - y0, x1 - x0), np.float32)
        cv2.fillConvexPoly(mask, np.round((dst - [x0, y0]) * 16).astype(np.int32), 1, lineType=cv2.LINE_AA, shift=4)
        region = rgba[y0:y1, x0:x1]
        put = mask[..., None] > 0
        region[:] = np.where(put, np.maximum(region, warped * mask[..., None]), region)
    return rgba


def lights_for(i):
    """the light a part is shaded by: the first, or another's `instead` where it falls"""
    for L in A.get("lights", []):
        if L.get("instead") and i in L.get("only", []):
            return L
    return A.get("light")


def render(f):
    v = verts_at(f)
    op = np.array(anim["opacity"], np.float32).reshape(frames, len(parts))[f]
    shown = [i for i in range(len(parts)) if op[i] > 0.001 and i in v]
    pics = {i: draw_part(i, v[i]) for i in shown}
    sil = {i: pics[i][..., 3] for i in shown}
    out = np.dstack([np.ones((H, W)) * c for c in bg]).astype(np.float32)
    for i in shown:
        rgb, a = pics[i][..., :3], pics[i][..., 3:] * op[i]
        p = parts[i]
        L = lights_for(i)
        if p.get("receive") and L:
            shade = np.zeros((H, W), np.float32)
            casters = [j for j in shown if j > i or j in p.get("from", [])]
            for j in casters:
                q = parts[j]
                if j == i or not q.get("cast") or i in q.get("skip", []):
                    continue
                rim = v[j][q["rim"]] if q.get("kind", "skin") == "mesh" else v[j]
                mid = rim.mean(0)
                d = mid - [L["x"], L["y"]]
                d = d / (np.linalg.norm(d) or 1) * L["distance"]
                M = np.float32([[1, 0, d[0]], [0, 1, d[1]]])
                shade = np.maximum(shade, cv2.warpAffine(sil[j], M, (W, H)))
            if shade.any():
                if L.get("softness", 0) > 0:
                    shade = cv2.GaussianBlur(shade, (0, 0), L["softness"])
                rgb = rgb * (1 - L["strength"] * shade[..., None])
        out = out * (1 - a) + rgb * a
    return (np.clip(out, 0, 1) * 255).astype(np.uint8)


times = [int(t) for t in sys.argv[2].split(",")] if len(sys.argv) > 2 else [0]
for t in times:
    f = min(frames - 1, round(t * fps / 1000))
    img = render(f)
    Image.fromarray(img).save(os.path.join(folder, f"play-{t}.png"))
    ref = os.path.join(folder, f"ref-{t}.png")
    if os.path.exists(ref):
        r = np.asarray(Image.open(ref).convert("RGB").resize((W, H))).astype(int)
        diff = np.abs(r - img.astype(int)).sum(-1)
        off = (diff > 60).mean() * 100
        both = np.concatenate([r.astype(np.uint8), img, np.dstack([np.clip(diff * 2, 0, 255)] * 3).astype(np.uint8)], 1)
        Image.fromarray(both).resize((W * 3 // 3, H // 3)).save(os.path.join(folder, f"compare-{t}.png"))
        print(f"{t} ms (frame {f}): {off:.2f}% of pixels differ from Studio's render")
    else:
        print(f"{t} ms (frame {f}): drawn")
