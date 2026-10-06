"""Sounds for the five-in-a-row burst, third go (owner, 6 Oct 2026: the firecracker sounds
"don't fit our sound effects"). Made from the app's own instruments (make_sfx: the plucked and
wooden notes, the bell, the whoosh, in A like correct.wav), so the burst sounds like the rest of
the set: a soft whoosh as the string drops, each firecracker a note rising up A major pentatonic
with a little puff of air under it, and the seal landing on an A chord with a bell on top.

  plucked - the plucked string of correct.wav
  wooden  - the wooden marimba

Same pieces as before (drop, pop0..pop8, stamp); also keeps make_burst2's firecrackers for
comparison. Writes burst/<style>-<piece>.wav and burst/burst.json (base64, for the studio).
"""
import base64
import io
import json
import os

import numpy as np
import soundfile as sf

from make_sfx import SR, bell, karplus, marimba, reverb, whoosh
import make_burst2

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "burst")
rng = np.random.default_rng(5)
PENT = [81, 83, 85, 88, 90, 93, 95, 97, 100]          # A B C# E F# up from A5

INST = {
    "plucked": lambda m, v, d: karplus(m, d, v, bright=0.7, decay=0.9975),
    "wooden": lambda m, v, d: marimba(m, d, v),
}


def puff(d=0.05, v=0.25):
    """A little pff of air: the firecracker's pop under the note."""
    n = int(d * SR)
    x = rng.normal(0, 1, n)
    X = np.fft.rfft(x); f = np.fft.rfftfreq(n, 1 / SR) + 1e-9
    X *= 1 / (1 + (f / 3500) ** 2) / (1 + (500 / f) ** 2)
    y = np.fft.irfft(X, n)
    e = np.minimum(1, np.arange(n) / (0.002 * SR)) * np.exp(-np.arange(n) / (0.012 * SR))
    return v * y / (np.abs(y).max() + 1e-9) * e


def place(base, piece, at):
    i = int(at * SR)
    if i + len(piece) > len(base): base = np.pad(base, (0, i + len(piece) - len(base)))
    base[i:i + len(piece)] += piece
    return base


def finish(x, peak=0.85, wet=0.12):
    x = reverb(x, wet=wet, length=0.5)
    x = x / (np.abs(x).max() + 1e-9) * peak
    a = np.abs(x); end = np.nonzero(a > a.max() * 10 ** (-55 / 20))[0][-1] + 1
    x = x[:end]; f = min(len(x) // 4, int(0.04 * SR)); x[-f:] *= np.linspace(1, 0, f) ** 2
    return x


def pieces(inst):
    play = INST[inst]
    out = {"drop": finish(whoosh(0.3, 0.6), 0.45, 0.08)}
    for i, m in enumerate(PENT):
        x = place(play(m, 0.75 + 0.03 * i, 0.5), puff(), 0)
        out[f"pop{i}"] = finish(x, 0.8)
    # the seal: an A chord, rolled quickly, with the bell an octave over
    x = np.zeros(int(1.4 * SR))
    for k, m in enumerate((81, 85, 88, 93)):
        x = place(x, play(m, 0.8, 1.2), 0.02 * k)
    x = place(x, bell(105, 1.2, 0.35), 0.06)
    x = place(x, puff(0.08, 0.5), 0)
    out["stamp"] = finish(x, 0.9, 0.16)
    return out


def wav64(x):
    b = io.BytesIO(); sf.write(b, x.astype(np.float32), SR, format="WAV", subtype="PCM_16")
    return "data:audio/wav;base64," + base64.b64encode(b.getvalue()).decode()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for inst in INST:
        p = pieces(inst)
        for k, x in p.items():
            sf.write(os.path.join(OUT, f"{inst}-{k}.wav"), x, SR, subtype="PCM_16")
        data[inst] = {k: wav64(x) for k, x in p.items()}
    # the firecrackers from the second go, to compare against
    r = np.random.default_rng(11)
    fc = {"drop": make_burst2.norm(make_burst2.tail(make_burst2.fuse(r)), 0.6), "stamp": make_burst2.stamp_firecrackers(r)}
    for i in range(9):
        fc[f"pop{i}"] = make_burst2.style_firecrackers(i, r)
    data["firecrackers"] = {k: wav64(x) for k, x in fc.items()}
    json.dump(data, open(os.path.join(OUT, "burst.json"), "w"))
    print({s: sum(len(v) for v in d.values()) // 1024 for s, d in data.items()}, "KB")
