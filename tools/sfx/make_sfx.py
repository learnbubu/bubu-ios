"""Bùbù's own sound effects, synthesised from scratch (no samples, no AI: ours outright).

One set of pentatonic motifs (the sound's identity), played by three instrument families:
  jade     - a plucked-string sound, like a guzheng, with a small bell on the big moments
  lantern  - a warm wooden marimba
  bubble   - a soft, bouncy synth pop, cartoonish

    python make_sfx.py            -> out/<family>/<sound>.wav and .mp3
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "out")
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


# ---------- instruments: (midi, dur, vel) -> mono array ----------

def karplus(midi, dur=1.0, vel=1.0, bright=0.5, decay=0.996):
    """Plucked string (Karplus-Strong), with a touch of pick noise: a guzheng-ish pluck."""
    f = hz(midi)
    n = int(dur * SR)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    # soften the excitation for a rounder pluck
    for _ in range(int((1 - bright) * 4)):
        buf = 0.5 * (buf + np.roll(buf, 1))
    out = np.empty(n)
    b = buf.copy()
    idx = 0
    for i in range(n):
        j = idx % period
        out[i] = b[j]
        b[j] = decay * 0.5 * (b[j] + b[(j + 1) % period])
        idx += 1
    # a little bend down at the attack, like a plucked zither string settling
    return vel * out * env(n, 0.002, None)


def env(n, attack, tau):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(attack, 1e-4))
    if tau:
        e = e * np.exp(-np.maximum(0, t - attack) / tau)
    return e


def bell(midi, dur=1.6, vel=1.0):
    t = t_axis(dur)
    f = hz(midi)
    parts = [(1, 1.0, 0.9), (2.0, 0.5, 0.6), (2.76, 0.35, 0.4), (5.4, 0.2, 0.2), (8.93, 0.1, 0.12)]
    s = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau) for r, a, tau in parts)
    return vel * 0.55 * s * env(len(t), 0.002, None)


def marimba(midi, dur=0.9, vel=1.0):
    t = t_axis(dur)
    f = hz(midi)
    # a marimba bar's partials sit near 1 : 4 : 10, the upper ones dying fast
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.32)
         + 0.25 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / 0.05)
         + 0.08 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / 0.015))
    click = rng.normal(0, 1, len(t)) * np.exp(-t / 0.002) * 0.15
    return vel * 0.8 * (s + click) * env(len(t), 0.001, None)


def pop(midi, dur=0.45, vel=1.0):
    """A soft synth 'bloop': the pitch drops into the note, round and bouncy."""
    t = t_axis(dur)
    f = hz(midi)
    glide = f * (1 + 0.45 * np.exp(-t / 0.018))
    phase = 2 * np.pi * np.cumsum(glide) / SR
    s = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    return vel * 0.75 * s * env(len(t), 0.003, 0.11)


def gong(midi, dur=2.2, vel=1.0):
    t = t_axis(dur)
    f = hz(midi)
    ratios = [1, 1.52, 2.03, 2.71, 3.4, 4.17]
    s = sum((0.7 / (k + 1)) * np.sin(2 * np.pi * f * r * t + k) * np.exp(-t / (1.2 / (k + 1) ** 0.5))
            for k, r in enumerate(ratios))
    swell = np.minimum(1, t / 0.06)
    return vel * 0.6 * s * swell


def whoosh(dur=0.45, vel=1.0):
    n = int(dur * SR)
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    y = 0.0
    for i in range(n):
        a = 0.02 + 0.35 * (i / n) ** 2          # cutoff rising: a lowpass opening up
        y += a * (noise[i] - y)
        out[i] = y
    e = np.sin(np.pi * np.arange(n) / n) ** 1.5
    return vel * 0.9 * out * e


FAMILIES = {
    "jade": {"note": lambda m, v=1.0, d=1.2: karplus(m, d, v, bright=0.55, decay=0.9965),
             "big": lambda m, v=1.0: bell(m, 1.8, v),
             "tick": lambda m, v=1.0: karplus(m, 0.12, v * 0.5, bright=0.9, decay=0.97)},
    "lantern": {"note": lambda m, v=1.0, d=0.9: marimba(m, d, v),
                "big": lambda m, v=1.0: marimba(m, 1.4, v),
                "tick": lambda m, v=1.0: marimba(m, 0.1, v * 0.55)},
    "bubble": {"note": lambda m, v=1.0, d=0.45: pop(m, d, v),
               "big": lambda m, v=1.0: pop(m, 0.9, v) * 0.9 + bell(m + 12, 0.9, v * 0.25)[: int(0.9 * SR)],
               "tick": lambda m, v=1.0: pop(m, 0.07, v * 0.5)},
}

# ---------- motifs (C major pentatonic: C D E G A), shared by every family ----------
# each: list of (time s, midi, velocity, kind) with kind note | big | tick | gong | whoosh
MOTIFS = {
    "tap":       [(0.0, 84, 0.6, "tick")],
    "correct":   [(0.0, 76, 0.8, "note"), (0.085, 81, 1.0, "note")],
    "wrong":     [(0.0, 62, 0.55, "note"), (0.12, 57, 0.5, "note")],
    "combo":     [(0.0, 76, 0.7, "note"), (0.07, 79, 0.8, "note"), (0.14, 84, 1.0, "note")],
    "goal":      [(0.0, 72, 0.7, "note"), (0.08, 76, 0.75, "note"), (0.16, 79, 0.85, "note"), (0.24, 84, 1.0, "big")],
    "complete":  [(0.0, 72, 0.7, "note"), (0.1, 74, 0.7, "note"), (0.2, 76, 0.8, "note"), (0.3, 79, 0.85, "note"),
                  (0.46, 81, 0.8, "big"), (0.46, 84, 0.8, "big"), (0.46, 88, 0.7, "big")],
    "levelup":   [(0.06 * i, m, 0.6 + 0.04 * i, "note") for i, m in enumerate([67, 69, 72, 74, 76, 79, 81, 84])]
                 + [(0.56, 84, 0.9, "big"), (0.56, 88, 0.8, "big"), (0.56, 91, 0.7, "big")],
    "milestone": [(0.0, 48, 0.8, "gong"), (0.25, 76, 0.8, "note"), (0.37, 79, 0.85, "note"), (0.49, 84, 0.9, "note"),
                  (0.7, 88, 0.8, "big"), (0.7, 91, 0.7, "big"), (0.7, 96, 0.5, "big")],
    "chest":     sorted([(0.05 * i, int(m), 0.35, "tick") for i, m in
                         enumerate(rng.choice([84, 86, 88, 91, 93, 96, 98, 100], 12)[::-1])])
                 + [(0.66, 79, 0.9, "big"), (0.66, 84, 0.8, "big")],
    "relight":   [(0.0, 0, 0.7, "whoosh"), (0.34, 72, 0.8, "big"), (0.34, 79, 0.7, "big")],
}


def reverb(x, wet=0.16, length=0.7):
    t = t_axis(length)
    ir = rng.normal(0, 1, len(t)) * np.exp(-t / 0.16)
    ir /= np.sqrt(np.sum(ir ** 2))
    n = len(x) + len(ir)
    y = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[:n]
    out = np.zeros(n)
    out[: len(x)] += x
    return out + wet * y


def render(family, motif):
    inst = FAMILIES[family]
    events = []
    for at, m, v, kind in motif:
        if kind == "whoosh":
            s = whoosh(0.45, v)
        elif kind == "gong":
            s = gong(m, 2.2, v)
        elif kind == "big":
            s = inst["big"](m, v)
        elif kind == "tick":
            s = inst["tick"](m, v)
        else:
            s = inst["note"](m, v)
        events.append((int(at * SR), s))
    n = max(i + len(s) for i, s in events)
    mix = np.zeros(n)
    for i, s in events:
        mix[i:i + len(s)] += s
    mix = reverb(mix)
    # trim the silent tail, fade the last 30 ms, peak at -1 dBFS
    a = np.abs(mix)
    last = np.nonzero(a > a.max() * 0.002)[0][-1] + 1
    mix = mix[:last]
    fade = min(len(mix), int(0.03 * SR))
    mix[-fade:] *= np.linspace(1, 0, fade)
    return mix / np.abs(mix).max() * 0.89


def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


if __name__ == "__main__":
    for fam in FAMILIES:
        d = os.path.join(OUT, fam)
        os.makedirs(d, exist_ok=True)
        for name, motif in MOTIFS.items():
            p = os.path.join(d, name + ".wav")
            write(p, render(fam, motif))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-b:a", "128k", p[:-4] + ".mp3"], check=True)
            print(fam, name)
