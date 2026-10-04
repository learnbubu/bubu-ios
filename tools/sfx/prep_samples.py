"""Turns the downloaded VCSL samples (CC0) into a small playable kit for the lab and the renderer.

For each pitched instrument: one clean hit per note (a middle velocity, the first round-robin),
trimmed to its onset, faded, peak-normalised. Saved as
    kit/wav/<inst>/<midi>.wav     full quality, for render_set.py
    kit/mp3/<inst>/<midi>.mp3     small, for the lab in the browser
plus kit/manifest.json: {inst: {"notes": [midi...], "kind": "pitched"|"hit"}}.
"""
import json
import os
import re
import subprocess

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "samples", "vcsl")
KIT = os.path.join(HERE, "kit")
SR = 44100

S = "Idiophones/Struck Idiophones/"
P = "Idiophones/Plucked Idiophones/"
PITCHED = {
    "marimba": S + "Marimba",
    "glockenspiel": S + "Glockenspiel",
    "xylophone": S + "Xylophone",
    "vibraphone": S + "Vibraphone",
    "handchimes": S + "Hand Chimes",
    "tubularglock": S + "Tubular Glockenspiel",
    "kalimba": P + "Kalimba, Kenya",
    "mbira": P + "Kalimba, Tanzania",
    "dantranh": "Chordophones/Zithers/Dan Tranh/Normal",
}
# unpitched layers: (name, folder, regex picking the file)
HITS = [
    ("woodblock", S + "Woodblock", r""),
    ("claves", S + "Claves", r"Claves1_Hit_v2"),
    ("fingercymbal", S + "Finger Cymbals", r""),
    ("marktree", S + "Mark Trees", r""),
    ("belltree", S + "Bell Tree", r""),
]
NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NOTE = re.compile(r"(?:^|[_\s-])([A-Ga-g])([#b]?)(-?\d)(?=$|[_\s.-])")
# which velocity to prefer, best first
PREF = ["med", "mf", "_vl2", "v2", "mid", "_vl3", "loud", "ff", "50_100", ""]


def midi_of(name):
    m = NOTE.search(os.path.splitext(name)[0])
    if not m:
        return None
    n = NAMES[m.group(1).upper()] + {"#": 1, "b": -1, "": 0}[m.group(2)]
    return 12 * (int(m.group(3)) + 1) + n


def rank(name):
    low = name.lower()
    for i, p in enumerate(PREF):
        if p and p in low:
            break
    else:
        i = len(PREF)
    rr = 0 if re.search(r"(rr1|_01|r01|_1\.wav)", low) else 1
    bad = 1 if re.search(r"(trem|gliss|fx|vib_|dead|mute|roll|bow)", low) else 0
    return (bad, i, rr, len(name))


def load(path, max_s=3.0):
    x, sr = sf.read(path, always_2d=True)
    x = x.mean(axis=1)
    if sr != SR:
        import scipy.signal as ss
        x = ss.resample_poly(x, SR, sr)
    a = np.abs(x)
    on = np.nonzero(a > a.max() * 0.02)[0]
    start = max(0, on[0] - int(0.002 * SR)) if len(on) else 0
    x = x[start:start + int(max_s * SR)]
    a = np.abs(x)
    last = np.nonzero(a > a.max() * 10 ** (-60 / 20))[0][-1] + 1
    x = x[:last]
    fade = min(len(x) // 4, int(0.08 * SR))
    x[-fade:] *= np.linspace(1, 0, fade) ** 2
    return x / np.abs(x).max() * 0.9


def save(x, inst, key):
    w = os.path.join(KIT, "wav", inst)
    m = os.path.join(KIT, "mp3", inst)
    os.makedirs(w, exist_ok=True)
    os.makedirs(m, exist_ok=True)
    pw = os.path.join(w, f"{key}.wav")
    sf.write(pw, x, SR)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", pw, "-ac", "1", "-b:a", "96k",
                    os.path.join(m, f"{key}.mp3")], check=True)


def walk(folder):
    for root, _, files in os.walk(os.path.join(SRC, folder)):
        for f in files:
            if f.lower().endswith(".wav"):
                yield root, f


if __name__ == "__main__":
    manifest = {}
    for inst, folder in PITCHED.items():
        best = {}
        for root, f in walk(folder):
            m = midi_of(f)
            if m is None:
                continue
            if m not in best or rank(f) < rank(best[m][1]):
                best[m] = (root, f)
        notes = []
        for m, (root, f) in sorted(best.items()):
            save(load(os.path.join(root, f), 3.0), inst, m)
            notes.append(m)
        manifest[inst] = {"kind": "pitched", "notes": notes}
        print(inst, len(notes), "notes", notes[:1], "-", notes[-1:])
    for name, folder, pat in HITS:
        cands = sorted((f for _, f in walk(folder) if re.search(pat, f)), key=rank)
        if not cands:
            print("no", name)
            continue
        root = next(r for r, f in walk(folder) if f == cands[0])
        save(load(os.path.join(root, cands[0]), 2.5), name, 0)
        manifest[name] = {"kind": "hit", "notes": [0], "file": cands[0]}
        print(name, cands[0])
    json.dump(manifest, open(os.path.join(KIT, "manifest.json"), "w"), indent=1)
