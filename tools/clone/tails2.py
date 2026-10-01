"""A faint sound after the last word (a breath, a murmur): after the last loud stretch, a quiet
gap, then 80 ms or more of quieter sound. Prints where to cut."""
import os, sys
import numpy as np
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tails, voice


def tail(e, loud=0.12, quiet=0.006, faint=0.014):
    idx = np.where(e > loud)[0]
    if len(idx) == 0:
        return None
    end = idx[-1]
    # where the last word dies away
    i = end
    while i < len(e) and e[i] > quiet:
        i += 1
    gap0 = i
    while i < len(e) and e[i] <= quiet:
        i += 1
    if i >= len(e) or i - gap0 < 5:
        return None
    rest = e[i:]
    n = int((rest > faint).sum())
    return (gap0, i, n) if n >= 8 else None


if __name__ == "__main__":
    texts = [t for v, t in voice.plan([1, 2, 3, 4, 5]) if v == "k"]
    for t in texts:
        p = os.path.join(voice.OUT, voice.name(t) + ".mp3")
        if not os.path.exists(p):
            continue
        e = tails.env(p)
        r = tail(e)
        if r:
            print(f"{t} | quiet from {r[0]*10} ms to {r[1]*10} ms, then {r[2]*10} ms of faint sound | length {len(e)*10} ms")
