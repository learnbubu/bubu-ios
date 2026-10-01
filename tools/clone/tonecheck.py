"""Does a clip say each syllable with the right tone? Its pitch (WORLD's harvest) is cut into as many
syllables as the text has, at the quietest moments, and each syllable's pitch shape is checked
against its tone, after the usual tone changes (3+3, 一, 不). Neutral tones aren't checked.
Run with the CosyVoice venv's Python (it has pyworld):

    venv/Scripts/python tools/clone/tonecheck.py 汉语 clip.mp3 …     # one text, some clips
    from tonecheck import check; check(text, path) → {"score": 0.8, "syllables": […]}
"""
import io, os, re, subprocess, sys, wave
import numpy as np
import pyworld
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from coursepy import pinyin as course_pinyin
from pinyin_tokens import syllables as split_syllables

MARKS = {**{c: 1 for c in "āēīōūǖ"}, **{c: 2 for c in "áéíóúǘ"}, **{c: 3 for c in "ǎěǐǒǔǚ"}, **{c: 4 for c in "àèìòùǜ"}}
GLOBAL_HZ = 181.0          # her speaking voice's middle (measured over chapter 1's clips)


def is_han(c):
    return "一" <= c <= "鿿"


def tone(s):
    return next((MARKS[c] for c in s if c in MARKS), 5)


def expected(text, py=None):
    """[(character, tone said)] with the tone changes applied; None when pinyin and text don't line up."""
    py = py or course_pinyin(text)
    chars = [c for c in text if is_han(c)]
    sy = [s for s in split_syllables(py) if s != "r"]
    if len(sy) == len(chars) - chars.count("儿"):
        chars = [c for c in chars if c != "儿"]
    if len(sy) != len(chars):
        return None
    t = [tone(s) for s in sy]
    # phrase breaks: punctuation in the text
    brk, k = set(), 0
    for c in text:
        if is_han(c) and c != "儿":
            k += 1
        elif not is_han(c) and k:
            brk.add(k - 1)
    out = list(t)
    for i in range(len(t) - 1):
        if i in brk:
            continue
        if t[i] == 3 and t[i + 1] == 3:
            out[i] = 2
        if chars[i] == "一" and t[i] == 1:
            out[i] = 2 if t[i + 1] == 4 else 4 if t[i + 1] in (1, 2, 3) else 1
        if chars[i] == "不" and t[i] == 4 and t[i + 1] == 4:
            out[i] = 2
    return list(zip(chars, out))


def load(path):
    data = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "16000", "-f", "wav", "pipe:1"],
                          capture_output=True, check=True).stdout
    w = wave.open(io.BytesIO(data))
    return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768, 16000


def track(x, sr):
    f0, t = pyworld.harvest(x, sr, f0_floor=90, f0_ceil=500, frame_period=10)
    hop = sr // 100
    n = len(f0)
    rms = np.array([np.sqrt((x[i * hop:(i + 1) * hop] ** 2).mean()) if i * hop < len(x) else 0 for i in range(n)])
    return f0, rms / (rms.max() + 1e-9)


def segments(f0, rms, n):
    """n syllables as (start, end) frames: the speech span cut at the n-1 quietest dips."""
    on = np.where(rms > 0.05)[0]
    if len(on) == 0:
        return None
    a, b = on[0], on[-1] + 1
    if n == 1:
        return [(a, b)]
    sm = np.convolve(rms, np.ones(5) / 5, mode="same")
    # dip score: quiet, and unvoiced counts as quieter
    score = sm.copy()
    score[f0 == 0] *= 0.3
    cand = [i for i in range(a + 4, b - 4) if score[i] <= score[i - 1] and score[i] <= score[i + 1]]
    cand.sort(key=lambda i: score[i])
    least = max(5, int((b - a) / n * 0.4))
    cuts = []
    for i in cand:
        if all(abs(i - c) >= least for c in cuts) and i - a >= least and b - i >= least:
            cuts.append(i)
        if len(cuts) == n - 1:
            break
    if len(cuts) < n - 1:                     # too few dips: share out the rest evenly
        return [(a + (b - a) * k // n, a + (b - a) * (k + 1) // n) for k in range(n)]
    cuts.sort()
    edges = [a] + cuts + [b]
    return list(zip(edges, edges[1:]))


def shape(f0, seg, ref, into=None):
    """A syllable's pitch, in semitones from `ref`, measured on its core (its first fifth and
    last twentieth dropped: the glide in from the last syllable, a creak at the end). `into`
    extends it into the next syllable (a 2nd tone's rise carries on into a neutral one)."""
    s, e = seg
    if into:
        e = into
    v = f0[s:e]
    v = v[v > 0]
    if len(v) < 4:
        return None
    st = 12 * np.log2(v / ref)
    st = np.convolve(st, np.ones(3) / 3, mode="valid") if len(st) > 5 else st
    core = st[len(st) // 5: len(st) - max(1, len(st) // 20)] if len(st) > 8 else st
    q = max(1, len(core) // 4)
    lo = int(np.argmin(core))
    return {"start": float(np.median(core[:q])), "end": float(np.median(core[-q:])), "mean": float(np.mean(core)),
            "low": float(core[lo]), "lowat": lo / max(1, len(core) - 1),
            "spread": float(np.percentile(core, 90) - np.percentile(core, 10)),
            "rise": float(core[lo:].max() - core[lo]) if lo < len(core) - 1 else 0.0}


def fits(t, f, last, ref_shift):
    """Whether a syllable's pitch fits its tone (pitch in semitones from her middle, moved by
    the clip's own level)."""
    s, e, m, lo = f["start"] - ref_shift, f["end"] - ref_shift, f["mean"] - ref_shift, f["low"] - ref_shift
    if t == 1:
        return f["spread"] <= 3.0 and m >= -2.0
    if t == 2:
        return f["rise"] >= 2.0 and f["lowat"] < 0.75 and e - s >= 1.0
    if t == 3:
        dip = s - lo >= 1.0 and 0.1 < f["lowat"] < 0.95
        # low, or a dip; but not one that ends well above where it began (that's a 2nd tone)
        return (m <= -0.5 or dip) and e - s < 2.5
    if t == 4:
        return s - e >= 2.0
    return True


def check(text, path, py=None):
    exp = expected(text, py)
    if not exp:
        return None
    x, sr = load(path)
    f0, rms = track(x, sr)
    segs = segments(f0, rms, len(exp))
    if not segs:
        return {"score": 0.0, "syllables": [], "note": "silent"}
    feats = []
    for i, sg in enumerate(segs):
        nxt = segs[i + 1] if i + 1 < len(segs) else None
        into = (nxt[0] + nxt[1]) // 2 if nxt and exp[i][1] == 2 and exp[i + 1][1] == 5 else None
        feats.append(shape(f0, sg, GLOBAL_HZ, into))
    # the clip's own level: a whole line can sit higher or lower than her middle
    tone_mid = {1: 2.5, 2: 0.0, 3: -2.5, 4: 1.0}
    diffs = [f["mean"] - tone_mid[t] for (c, t), f in zip(exp, feats) if f and t in tone_mid]
    shift = float(np.median(diffs)) if len(diffs) >= 3 else 0.0
    out, good, counted = [], 0, 0
    for i, ((c, t), f) in enumerate(zip(exp, feats)):
        if t == 5:
            out.append((c, t, None)); continue
        counted += 1
        ok = bool(f) and fits(t, f, i == len(exp) - 1, shift)
        good += ok
        out.append((c, t, ok))
    return {"score": good / counted if counted else 1.0, "syllables": out, "shift": round(shift, 1)}


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    text = sys.argv[1]
    for p in sys.argv[2:]:
        r = check(text, p)
        print(os.path.basename(p), r and round(r["score"], 2), r and " ".join(f"{c}{t}{'' if ok is None else '✓' if ok else '✗'}" for c, t, ok in r["syllables"]))
