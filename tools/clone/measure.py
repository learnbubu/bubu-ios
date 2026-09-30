"""Each redo take measured: its length, and its pitch in two halves (a two-syllable word) or
against the reference tone (one syllable). Also the app's present clip, as take 0."""
import io, json, os, re, subprocess, sys, wave
import numpy as np
sys.stdout.reconfigure(encoding="utf-8")
TOOLS = r"C:\Users\domch\Documents\Projects\bubu-ios\tools"
sys.path.insert(0, TOOLS)
import voice, takes, citation

WORK = os.path.dirname(os.path.abspath(__file__))
WORDS = {"这个": "zhè ge", "再": "zài", "汉语": "hàn yǔ", "成都": "chéng dū", "只": "zhǐ", "朋友": "péng you",
         "请说慢一点儿": "qǐng shuō màn yī diǎnr", "和": "hé", "日本": "rì běn"}


def wav_of(path):
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "24000", "-f", "wav", "pipe:1"],
                          capture_output=True, check=True).stdout


def track(data):
    """(f0 per 10 ms, 0 where unvoiced; loudness per 10 ms)."""
    w = wave.open(io.BytesIO(data)); sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    frame, hop = int(sr * 0.04), int(sr * 0.01)
    peak = np.abs(x).max() + 1e-9
    f0, rms = [], []
    for i in range(0, len(x) - frame, hop):
        s = x[i:i + frame]
        r = np.sqrt((s ** 2).mean()); rms.append(r / peak)
        if r < 0.05 * peak:
            f0.append(0.0); continue
        s = s - s.mean()
        ac = np.correlate(s, s, mode="full")[frame - 1:]
        lo, hi = int(sr / 450), int(sr / 70)
        if ac[0] <= 0:
            f0.append(0.0); continue
        k = lo + int(np.argmax(ac[lo:hi]))
        f0.append(sr / k if ac[k] / ac[0] > 0.45 else 0.0)
    return np.array(f0), np.array(rms)


def semis(v, ref):
    return 12 * np.log2(v / ref)


def halves(f0, rms):
    """A two-syllable word's two syllables: the voiced stretch split at its quietest or unvoiced
    moment in the middle third."""
    voiced = np.where(f0 > 0)[0]
    if len(voiced) < 10:
        return None
    a, b = voiced[0], voiced[-1] + 1
    third = (b - a) // 3
    mid = range(a + third, b - third)
    if len(mid) == 0:
        return None
    cut = min(mid, key=lambda i: (f0[i] > 0, rms[i]))
    return f0[a:cut], f0[cut:b]


def shape(v, med):
    v = v[v > 0]
    if len(v) < 4:
        return None
    s = semis(v, med)
    k = max(1, len(s) // 4)
    return round(float(np.median(s[:k])), 1), round(float(np.median(s[len(s) // 2 - k // 2: len(s) // 2 + k // 2 + 1])), 1), round(float(np.median(s[-k:])), 1)


rows = {}
for word, py in WORDS.items():
    name = voice.name(word)
    files = [(0, os.path.join(voice.OUT, name + ".mp3"))]
    files += sorted(((int(re.search(r"-(\d+)\.mp3$", f).group(1)), os.path.join(WORK, f))
                     for f in os.listdir(WORK) if f.startswith(name + "-") and f.endswith(".mp3")))
    print("\n====", word, py)
    for n, path in files:
        if not os.path.exists(path):
            continue
        data = wav_of(path)
        f0, rms = track(data)
        v = f0[f0 > 0]
        if len(v) < 6:
            print(f"  take {n}: no voice"); continue
        med = float(np.median(v))
        secs = len(f0) / 100
        out = {"take": n, "secs": round(secs, 2), "voiced": round(len(v) / 100, 2), "hz": round(med)}
        syl = py.split()
        if len(syl) == 1:
            c, vs = takes.contour(data, points=9)
            ref = citation.refs().get(str(citation.tone(py)))
            out["dist"] = round(citation.distance(c, ref), 2) if ref and c else 99
            out["contour"] = c
            out["shape"] = takes.tone_shape(c)
        elif len(syl) == 2:
            h = halves(f0, rms)
            if h:
                out["s1"] = shape(h[0], med); out["s2"] = shape(h[1], med)
                out["len1"] = round(len(h[0]) / 100, 2); out["len2"] = round(len(h[1]) / 100, 2)
        else:
            c, vs = takes.contour(data, points=9)
            out["contour"] = c
        rows.setdefault(word, []).append(out)
        print("  ", json.dumps(out, ensure_ascii=False))
json.dump(rows, open(os.path.join(WORK, "measured.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
