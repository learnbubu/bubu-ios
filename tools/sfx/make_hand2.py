"""Hand-made 'correct', round 2: the plucked and wooden sounds the owner liked best, played as
a clear success gesture - quick, rising, landing on the home note (A) - with a quiet bell on
the last note for sparkle.   ->  out/hand2/<inst>-<shape>.wav/.mp3
"""
import os

import numpy as np

from make_sfx import SR, bell, karplus, marimba, reverb, write

OUT = os.path.join(os.path.dirname(__file__), "out", "hand2")

INST = {
    "plucked": lambda m, v, d: karplus(m, d, v, bright=0.7, decay=0.9975),
    "wooden": lambda m, v, d: marimba(m, d, v),
}
# (start s, midi, velocity, length s); all end on A (81 = A5, 93 = A6)
SHAPES = {
    "fourth": [(0.0, 88, 0.75, 0.5), (0.07, 93, 1.0, 0.8)],           # E -> A
    "triad":  [(0.0, 85, 0.6, 0.4), (0.05, 88, 0.7, 0.4), (0.1, 93, 1.0, 0.8)],   # C# E A
    "octave": [(0.0, 81, 0.75, 0.5), (0.08, 93, 1.0, 0.8)],           # A -> A
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for inst, play in INST.items():
        for shape, notes in SHAPES.items():
            n = int((max(a + d for a, _, _, d in notes) + 0.6) * SR)
            mix = np.zeros(n)
            for at, m, v, d in notes:
                s = play(m, v, d)
                i = int(at * SR)
                mix[i:i + len(s)] += s[: n - i]
            # the sparkle: a quiet bell an octave over the last note
            at, m, _, _ = notes[-1]
            b = bell(m + 12, 0.6, 0.18)
            i = int(at * SR)
            mix[i:i + len(b)] += b[: n - i]
            mix = reverb(mix, wet=0.12, length=0.5)
            a = np.abs(mix)
            mix = mix[: min(np.nonzero(a > a.max() * 0.003)[0][-1] + 1, int(0.75 * SR))]
            fade = int(0.04 * SR)
            mix[-fade:] *= np.linspace(1, 0, fade)
            mix = mix / np.abs(mix).max() * 0.89
            p = os.path.join(OUT, f"{inst}-{shape}.wav")
            write(p, mix)
            os.system(f'ffmpeg -y -loglevel error -i "{p}" -b:a 160k "{p[:-4]}.mp3"')
            print(inst, shape)
