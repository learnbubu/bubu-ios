"""Sounds for the five-in-a-row firecracker burst, second go (owner, 6 Oct 2026: "more like
little fire cracker sounds or fire works"). Same pieces as make_burst.py, so the studio and the
app play them on the burst's own timeline: drop, pop0..pop8 (bottom firecracker first), stamp.

  firecrackers - a fizzing fuse, sharp little bangs with a touch of echo, a bigger bang
  fireworks    - a rising whistle, soft booms with a sparkly crackle trailing off, a boom and glitter
  snaps        - a quick fuse hiss, tiny cap-gun snaps, a double snap

Writes burst/<style>-<piece>.wav and burst/burst.json (base64, for the studio).
"""
import base64
import io
import json
import os

import numpy as np
import soundfile as sf
from scipy.signal import fftconvolve

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "burst")


def t(d):
    return np.arange(int(d * SR)) / SR


def noise(n, rng):
    return rng.standard_normal(n)


def shape(x, lo=None, hi=None):
    """Gentle FFT filtering: a high-pass at lo, a low-pass at hi."""
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR) + 1e-9
    if lo: X *= 1 / (1 + (lo / f) ** 4)
    if hi: X *= 1 / (1 + (f / hi) ** 4)
    return np.fft.irfft(X, len(x))


def decay(n, tau, attack=0.0002):
    x = np.arange(n) / SR
    return np.minimum(1, x / attack) * np.exp(-x / tau)


def room(x, size=0.35, mix=0.22, rng=None):
    """A little echo: convolved with a short, darkening burst of noise."""
    rng = rng or np.random.default_rng(1)
    n = int(size * SR)
    ir = noise(n, rng) * np.exp(-np.arange(n) / SR / (size / 5))
    ir = shape(ir, 200, 5000); ir /= np.abs(ir).max()
    wet = np.pad(fftconvolve(x, ir), (0, 1))[: len(x) + n]
    out = np.pad(x, (0, n)) + mix * wet / (np.abs(wet).max() + 1e-9) * np.abs(x).max()
    return out


def norm(x, peak=0.9):
    x = x - x.mean()
    return x / (np.abs(x).max() + 1e-9) * peak


def tail(x, ms=15):
    n = int(ms / 1000 * SR); x[-n:] *= np.linspace(1, 0, n) ** 2; return x


def mix_at(base, piece, at):
    i = int(at * SR)
    if i + len(piece) > len(base): base = np.pad(base, (0, i + len(piece) - len(base)))
    base[i:i + len(piece)] += piece
    return base


# ---- building blocks ----
def bang(rng, size=1.0, bright=1.0):
    """A small firecracker: a hard crack, a short thump, a burst of paper."""
    n = int(0.25 * SR)
    crack = shape(noise(n, rng), 900, 9000 * bright) * decay(n, 0.006 * size)
    thump = np.sin(2 * np.pi * (95 + 40 * rng.random()) * t(.25) * (1 + .5 * np.exp(-t(.25) / .01))) * decay(n, 0.03 * size, .001)
    paper = shape(noise(n, rng), 2500, 8000) * decay(n, 0.02, .004) * 0.25
    return crack + 0.9 * thump + paper


def crackle(rng, d=0.6, rate=45, level=0.5, start_fast=True):
    """Glittery crackle: tiny sparks, thinning out."""
    n = int(d * SR); y = np.zeros(n)
    k = int(rate * d)
    times = np.sort(rng.random(k) ** (1.8 if start_fast else 1.0)) * d
    for tt in times:
        m = int(0.006 * SR)
        spark = shape(noise(m, rng), 3000, 11000) * decay(m, 0.0012)
        g = level * (0.4 + 0.6 * rng.random()) * (1 - tt / d) ** 1.2
        i = int(tt * SR)
        y[i:i + m] += spark[: max(0, min(m, n - i))] * g
    return y


def fuse(rng, d=0.32):
    n = int(d * SR)
    hiss = shape(noise(n, rng), 3000, 10000)
    flutter = 1 + 0.5 * np.sin(2 * np.pi * 23 * t(d)) * rng.random()
    env = np.minimum(1, t(d) / 0.04) * np.minimum(1, (d - t(d)) / 0.05)
    y = hiss * flutter * env * 0.35 + crackle(rng, d, 70, 0.6, start_fast=False)
    return y


def whistle(rng, d=0.36):
    tt = t(d)
    f = 1500 + 2200 * (tt / d) ** 1.3
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * tt))
    air = shape(noise(len(tt), rng), 1500, 7000) * 0.35
    env = np.minimum(1, tt / 0.05) * np.minimum(1, (d - tt) / 0.03)
    return (tone * 0.5 + air) * env


# ---- the styles ----
def style_firecrackers(i, rng):
    return norm(tail(room(bang(rng, 1.0 - 0.03 * i, 1.0), 0.3, 0.25, rng)), 0.9)


def style_fireworks(i, rng):
    b = bang(rng, 1.6, 0.6)
    b = shape(b, None, 4000)                     # softer, further off
    y = mix_at(b * 0.8, crackle(rng, 0.45, 40, 0.55), 0.03)
    return norm(tail(room(y, 0.6, 0.35, rng)), 0.85)


def style_snaps(i, rng):
    n = int(0.08 * SR)
    snap = shape(noise(n, rng), 1800, 10000) * decay(n, 0.0035)
    snap += np.sin(2 * np.pi * (300 + 25 * i) * t(.08)) * decay(n, 0.008, .0005) * 0.35
    return norm(tail(room(snap, 0.15, 0.12, rng)), 0.8)


def stamp_firecrackers(rng):
    y = bang(rng, 2.2, 0.9)
    y = mix_at(y, bang(rng, 1.2, 1.0) * 0.6, 0.07)
    return norm(tail(room(y, 0.5, 0.3, rng), 40), 0.95)


def stamp_fireworks(rng):
    boom = shape(bang(rng, 3.0, 0.5), None, 2500)
    y = mix_at(boom, crackle(rng, 1.1, 60, 0.7), 0.06)
    return norm(tail(room(y, 0.9, 0.35, rng), 60), 0.95)


def stamp_snaps(rng):
    a = style_snaps(3, rng); b = style_snaps(5, rng)
    return norm(tail(mix_at(a.copy(), b * 0.9, 0.06)), 0.9)


STYLES = {
    "firecrackers": (lambda r: fuse(r), style_firecrackers, stamp_firecrackers),
    "fireworks": (lambda r: whistle(r), style_fireworks, stamp_fireworks),
    "snaps": (lambda r: fuse(r, 0.22) * 0.8, style_snaps, stamp_snaps),
}


def wav64(x):
    b = io.BytesIO(); sf.write(b, x.astype(np.float32), SR, format="WAV", subtype="PCM_16")
    return "data:audio/wav;base64," + base64.b64encode(b.getvalue()).decode()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    data = {}
    for style, (drop, pop, stamp) in STYLES.items():
        rng = np.random.default_rng(11)
        pieces = {"drop": norm(tail(drop(rng)), 0.6), "stamp": stamp(rng)}
        for i in range(9):
            pieces[f"pop{i}"] = pop(i, rng)
        for k, x in pieces.items():
            sf.write(os.path.join(OUT, f"{style}-{k}.wav"), x, SR, subtype="PCM_16")
        data[style] = {k: wav64(x) for k, x in pieces.items()}
    json.dump(data, open(os.path.join(OUT, "burst.json"), "w"))
    print({s: sum(len(v) for v in d.values()) // 1024 for s, d in data.items()}, "KB")
