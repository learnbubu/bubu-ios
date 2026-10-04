"""Three 'correct' melodies of our own with the feel the owner likes in Duolingo's: bright,
quick, rising, a bouncy synth bell. Not copies (different notes, rhythm and timbre); they're
inputs for restyle.py.   ->  out/duo/<name>/correct.wav
"""
import os

import numpy as np

from make_sfx import SR, hz, reverb, t_axis, write

OUT = os.path.join(os.path.dirname(__file__), "out", "duo")


def synth_bell(midi, dur=0.45, vel=1.0):
    t = t_axis(dur)
    f = hz(midi)
    # a little scoop up into the note: the bounce
    glide = f * (1 - 0.012 * np.exp(-t / 0.012))
    ph = 2 * np.pi * np.cumsum(glide) / SR
    s = (1.0 * np.sin(ph) * np.exp(-t / 0.30)
         + 0.38 * np.sin(2 * ph) * np.exp(-t / 0.12)
         + 0.16 * np.sin(3 * ph) * np.exp(-t / 0.06)
         + 0.07 * np.sin(4.2 * ph) * np.exp(-t / 0.03))
    attack = np.minimum(1, t / 0.0015)
    click = np.random.default_rng(int(midi)).normal(0, 1, len(t)) * np.exp(-t / 0.0015) * 0.08
    return vel * (s * attack + click)


MELODIES = {
    # rising a fourth, the second note held a touch longer
    "fourth":  [(0.0, 88, 0.8, 0.3), (0.075, 93, 1.0, 0.45)],
    # rising a major third with a quiet octave sparkle on top of the second note
    "sparkle": [(0.0, 84, 0.8, 0.3), (0.08, 88, 1.0, 0.45), (0.08, 100, 0.22, 0.3)],
    # a quick grace-note lift into the top note
    "lift":    [(0.0, 79, 0.6, 0.2), (0.05, 81, 0.7, 0.2), (0.1, 86, 1.0, 0.45)],
}

if __name__ == "__main__":
    for name, notes in MELODIES.items():
        n = int(max(a + d for a, _, _, d in notes) * SR) + 1
        mix = np.zeros(n)
        for at, m, v, d in notes:
            s = synth_bell(m, d, v)
            i = int(at * SR)
            mix[i:i + len(s)] += s[: n - i]
        mix = reverb(mix, wet=0.1, length=0.4)
        a = np.abs(mix)
        mix = mix[: np.nonzero(a > a.max() * 0.003)[0][-1] + 1]
        fade = int(0.02 * SR)
        mix[-fade:] *= np.linspace(1, 0, fade)
        mix = mix / np.abs(mix).max() * 0.89
        d = os.path.join(OUT, name)
        os.makedirs(d, exist_ok=True)
        write(os.path.join(d, "correct.wav"), mix)
        os.system(f'ffmpeg -y -loglevel error -i "{os.path.join(d, "correct.wav")}" -b:a 160k "{os.path.join(d, "correct.mp3")}"')
        print(name, round(len(mix) / SR, 2), "s")
