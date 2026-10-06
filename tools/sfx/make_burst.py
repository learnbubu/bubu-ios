"""Sounds for the five-in-a-row firecracker burst (owner, 6 Oct 2026), as pieces the burst
plays on its own timeline: the string dropping in, one pop per firecracker (rising a step each,
bottom to top), and the seal stamping down. Three styles to choose between by ear:

  cute    - bubbly blips, a soft paper thump
  snappy  - little cracks with a woody body, a wooden stamp
  musical - plucked notes up a pentatonic scale (like the app's other sounds), a drum and chime

Writes burst/<style>-<piece>.wav (mono, 44.1 kHz) and burst/burst.json (base64, for the studio).
"""
import base64
import io
import json
import os

import numpy as np
import soundfile as sf

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "burst")
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(d * SR)) / SR


def env(n, a=0.002, d=0.08):
    x = np.arange(n) / SR
    return np.minimum(1, x / a) * np.exp(-x / d)


def noise(n):
    return rng.standard_normal(n)


def bp(x, lo, hi):
    """Band-pass by FFT mask, gently edged."""
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = 1 / (1 + ((f - (lo + hi) / 2) / ((hi - lo) / 2)) ** 4)
    return np.fft.irfft(X * m, len(x))


def lp(x, fc):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    return np.fft.irfft(X / (1 + (f / fc) ** 4), len(x))


def norm(x, peak=0.9):
    x = x - x.mean()
    return x / (np.abs(x).max() + 1e-9) * peak


def fade(x, ms=8):
    n = int(ms / 1000 * SR); x[-n:] *= np.linspace(1, 0, n) ** 2; return x


# ---- the pieces ----
def drop_whoosh(d=0.32):
    n = int(d * SR); x = noise(n)
    sweep = np.linspace(0, 1, n)
    y = np.zeros(n)
    for i, (lo, hi) in enumerate([(300, 900), (700, 1800), (1500, 3500)]):
        seg = bp(x, lo, hi) * np.sin(np.pi * np.clip(sweep * 1.2 - i * .1, 0, 1)) ** 2
        y += seg
    return fade(norm(y, .5))


def drop_rattle(d=0.3):
    # the string unrolling: a quick run of tiny paper ticks over a soft whoosh
    n = int(d * SR); y = drop_whoosh(d) * .5
    for k in range(9):
        at = int((0.02 + k * 0.028 + rng.uniform(0, .008)) * SR)
        c = bp(noise(int(.012 * SR)), 2500, 6000) * env(int(.012 * SR), .0005, .003)
        y[at:at + len(c)] += c * (0.35 + 0.05 * k)
    return fade(norm(y, .55))


def pop_cute(i):
    f0 = 520 * 2 ** (i * 2 / 12)            # a whole step higher each pop
    tt = t(0.09)
    f = f0 * (1 + 1.2 * np.exp(-tt / 0.012))  # quick downward bloop
    ph = 2 * np.pi * np.cumsum(f) / SR
    y = np.sin(ph) * env(len(tt), .001, .03)
    y += bp(noise(len(tt)), 1500, 5000) * env(len(tt), .0003, .004) * .5
    return fade(norm(y, .85))


def pop_snappy(i):
    n = int(0.12 * SR)
    crack = bp(noise(n), 1800 + i * 150, 6500) * env(n, .0002, .006)
    body = np.sin(2 * np.pi * (180 + i * 12) * t(.12)) * env(n, .001, .025) * .7
    tail = bp(noise(n), 600, 2000) * env(n, .002, .03) * .25
    return fade(norm(crack + body + tail, .9))


PENT = [0, 2, 4, 7, 9, 12, 14, 16, 19]


def pluck(freq, d=0.45, bright=1.0):
    tt = t(d); n = len(tt)
    y = (np.sin(2 * np.pi * freq * tt) + .45 * bright * np.sin(2 * np.pi * freq * 2 * tt) * np.exp(-tt / .05)
         + .2 * bright * np.sin(2 * np.pi * freq * 3.01 * tt) * np.exp(-tt / .03))
    y *= env(n, .002, .16)
    y += bp(noise(n), 2000, 6000) * env(n, .0003, .003) * .15   # the mallet's tick
    return y


def pop_musical(i):
    f = 523.25 * 2 ** (PENT[min(i, len(PENT) - 1)] / 12)       # C5 up the pentatonic
    y = pluck(f, .4) + .35 * bp(noise(int(.4 * SR)), 1500, 5000) * env(int(.4 * SR), .0003, .005)
    return fade(norm(y, .8))


def stamp_cute():
    n = int(0.3 * SR); tt = t(.3)
    thump = np.sin(2 * np.pi * (110 * (1 + .6 * np.exp(-tt / .02))) * tt) * env(n, .001, .07)
    paper = bp(noise(n), 800, 3000) * env(n, .001, .025) * .5
    return fade(norm(thump + paper, .9))


def stamp_wood():
    n = int(0.35 * SR); tt = t(.35)
    body = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt / d) * a for f, d, a in ((210, .06, 1), (520, .03, .5), (930, .015, .3)))
    knock = bp(noise(n), 1200, 4000) * env(n, .0003, .006) * .6
    low = np.sin(2 * np.pi * 85 * tt) * env(n, .002, .08) * .8
    return fade(norm(body + knock + low, .9))


def stamp_musical():
    n = int(0.9 * SR); tt = t(.9)
    drum = np.sin(2 * np.pi * (75 * (1 + .8 * np.exp(-tt / .03))) * tt) * env(n, .002, .12)
    drum += lp(noise(n), 400) * env(n, .001, .03) * .6
    chime = sum(pluck(523.25 * 2 ** (s / 12), .9, .6) for s in (12, 16, 19)) * .35   # a bright C chord on top
    y = drum + np.pad(chime, (int(.03 * SR), 0))[:n]
    return fade(norm(y, .9), 40)


STYLES = {
    "cute": {"drop": drop_whoosh, "pop": pop_cute, "stamp": stamp_cute},
    "snappy": {"drop": drop_rattle, "pop": pop_snappy, "stamp": stamp_wood},
    "musical": {"drop": drop_whoosh, "pop": pop_musical, "stamp": stamp_musical},
}
POPS = 9


def wav64(x):
    b = io.BytesIO(); sf.write(b, x.astype(np.float32), SR, format="WAV", subtype="PCM_16")
    return "data:audio/wav;base64," + base64.b64encode(b.getvalue()).decode()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for style, fn in STYLES.items():
        pieces = {"drop": fn["drop"](), "stamp": fn["stamp"]()}
        for i in range(POPS):
            pieces[f"pop{i}"] = fn["pop"](i)
        for k, x in pieces.items():
            sf.write(os.path.join(OUT, f"{style}-{k}.wav"), x, SR, subtype="PCM_16")
        data[style] = {k: wav64(x) for k, x in pieces.items()}
    json.dump(data, open(os.path.join(OUT, "burst.json"), "w"))
    print({s: sum(len(v) for v in d.values()) // 1024 for s, d in data.items()}, "KB")
