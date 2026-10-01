"""Clips with something after the last word: a short burst of sound after a pause at the end
(or the start). Prints each clip's stretches of sound, longest gaps first.
    python tails.py [texts…]       # default: every 起步 1 text with a clip
"""
import io, os, subprocess, sys, wave
import numpy as np
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, r"C:\Users\domch\Documents\Projects\bubu-ios\tools")
import voice


def env(path):
    data = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-f", "wav", "pipe:1"],
                          capture_output=True, check=True).stdout
    w = wave.open(io.BytesIO(data))
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    hop = 160                                    # 10 ms
    n = len(x) // hop
    rms = np.array([np.sqrt((x[i * hop:(i + 1) * hop] ** 2).mean()) for i in range(n)])
    return rms / (rms.max() + 1e-9)


def stretches(e, on=0.06, gap=8):
    """(start, end) in 10 ms frames of sound louder than `on`, joining gaps shorter than `gap`."""
    loud = np.where(e > on)[0]
    if len(loud) == 0:
        return []
    out = [[loud[0], loud[0]]]
    for i in loud[1:]:
        if i - out[-1][1] <= gap:
            out[-1][1] = i
        else:
            out.append([i, i])
    return [(a, b + 1) for a, b in out]


def check(text):
    p = os.path.join(voice.OUT, voice.name(text) + ".mp3")
    if not os.path.exists(p):
        return None
    e = env(p)
    s = stretches(e)
    if not s:
        return "silent", s
    notes = []
    last, first = s[-1], s[0]
    if len(s) > 1:
        gap_end = last[0] - s[-2][1]
        if (last[1] - last[0]) <= 18 and gap_end >= 10:
            peak = e[last[0]:last[1]].max()
            notes.append(f"tail {(last[1]-last[0])*10}ms after {gap_end*10}ms quiet, peak {peak:.2f}")
        gap_start = s[1][0] - first[1]
        if (first[1] - first[0]) <= 18 and gap_start >= 10:
            notes.append(f"head {(first[1]-first[0])*10}ms then {gap_start*10}ms quiet")
    return "; ".join(notes), s


if __name__ == "__main__":
    texts = sys.argv[1:] or [t for v, t in voice.plan([1, 2, 3, 4, 5]) if v == "k"]
    for t in texts:
        r = check(t)
        if r is None:
            continue
        note, s = r
        if note or len(sys.argv) > 1:
            print(t, "|", note, "|", [(a * 10, b * 10) for a, b in s])
