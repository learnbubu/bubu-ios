"""The wooden burst, refined (owner, 6 Oct 2026: "the wooden sound is almost working, needs
refinement"). Three takes on make_burst3's wooden, same pieces (drop, pop0..pop8, stamp):

  wooden-tight - shorter, drier notes and a lighter puff, so the run is crisp; a short chord
  wooden-crack - each note with a small firecracker snap at its start instead of the puff
  wooden-warm  - an octave lower and softer, a rounder chord with less bell

Adds them to burst/burst.json beside the plucked and wooden from make_burst3.
"""
import json
import os

import numpy as np
import soundfile as sf

from make_sfx import SR, bell, marimba, whoosh
import make_burst2
from make_burst3 import OUT, PENT, finish, place, puff, wav64

LOW = [m - 12 for m in PENT]


def snap(rng, v=0.35):
    n = int(0.05 * SR)
    x = make_burst2.shape(rng.standard_normal(n), 1500, 9000) * make_burst2.decay(n, 0.004)
    return v * x / (np.abs(x).max() + 1e-9)


def take(kind):
    rng = np.random.default_rng(3)
    out = {"drop": finish(whoosh(0.26 if kind == "tight" else 0.3, 0.5), 0.4, 0.06)}
    for i in range(9):
        if kind == "tight":
            x = place(marimba(PENT[i], 0.22, 0.8 + 0.02 * i), puff(0.035, 0.15), 0)
            out[f"pop{i}"] = finish(x, 0.8, 0.06)
        elif kind == "crack":
            x = place(marimba(PENT[i], 0.35, 0.8 + 0.02 * i), snap(rng), 0)
            out[f"pop{i}"] = finish(x, 0.82, 0.1)
        else:
            x = place(marimba(LOW[i], 0.5, 0.75 + 0.02 * i), puff(0.05, 0.18), 0)
            out[f"pop{i}"] = finish(x, 0.75, 0.14)
    x = np.zeros(int(1.2 * SR))
    if kind == "tight":
        for k, m in enumerate((81, 85, 88)):
            x = place(x, marimba(m, 0.5, 0.85), 0.015 * k)
        x = place(x, bell(105, 0.6, 0.2), 0.04)
        out["stamp"] = finish(x, 0.88, 0.08)
    elif kind == "crack":
        for k, m in enumerate((81, 85, 88, 93)):
            x = place(x, marimba(m, 0.9, 0.8), 0.02 * k)
        x = place(x, snap(rng, 0.6), 0)
        x = place(x, bell(105, 1.0, 0.3), 0.06)
        out["stamp"] = finish(x, 0.9, 0.14)
    else:
        for k, m in enumerate((69, 73, 76, 81)):
            x = place(x, marimba(m, 1.1, 0.8), 0.025 * k)
        x = place(x, bell(93, 1.0, 0.15), 0.08)
        out["stamp"] = finish(x, 0.88, 0.18)
    return out


if __name__ == "__main__":
    path = os.path.join(OUT, "burst.json")
    data = json.load(open(path))
    for kind in ("tight", "crack", "warm"):
        p = take(kind)
        for k, x in p.items():
            sf.write(os.path.join(OUT, f"wooden-{kind}-{k}.wav"), x, SR, subtype="PCM_16")
        data[f"wooden-{kind}"] = {k: wav64(x) for k, x in p.items()}
    json.dump(data, open(path, "w"))
    print({s: sum(len(v) for v in d.values()) // 1024 for s, d in data.items()}, "KB")
