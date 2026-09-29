"""A lone syllable said the way a teacher says it. Asked for by itself, the voice gives a
single character the clipped tone it has in the middle of a sentence (a third tone comes out
low and falling, with no rise). Asked for at the end of a short carrier sentence, a little
slower, it gives the full tone. This makes several such readings of each word, cuts the
word out, measures its pitch, and puts them on a board to choose between by ear.

    python tools/citation.py 你 我          # tools/.voices/citation.html
    python tools/citation.py use 你 3       # reading 3 of 你 becomes the app's clip
"""
import base64, io, json, os, shutil, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import takes, tts, voice, board

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, ".voices", "citation")
KORE = voice.VOICES["k"]
CARRIERS = ["这个字读：{}。", "跟我读：{}。", "请读：{}。", "这个字念：{}。"]
RATES = [0.8, 0.9, 0.7]
# what each tone should measure as (third: the full dip, or at least low and falling gently)
SHAPES = {1: ["level"], 2: ["rising"], 3: ["dipping"], 4: ["falling"], 5: ["level", "falling", "uneven"]}
MARKS = {"ā": 1, "á": 2, "ǎ": 3, "à": 4, "ē": 1, "é": 2, "ě": 3, "è": 4, "ī": 1, "í": 2, "ǐ": 3, "ì": 4,
         "ō": 1, "ó": 2, "ǒ": 3, "ò": 4, "ū": 1, "ú": 2, "ǔ": 3, "ù": 4, "ǖ": 1, "ǘ": 2, "ǚ": 3, "ǜ": 4}


REFS = os.path.join(HERE, "refs", "tones.json")     # the four tones chosen by ear (妈 麻 马 骂)


def refs():
    return json.load(open(REFS, encoding="utf-8")) if os.path.exists(REFS) else {}


def distance(c, ref):
    """How far a reading's pitch is from the reference for its tone, in semitones (root mean
    square over the nine points), and whether it's long enough beside it."""
    if len(c) != len(ref["contour"]):
        return 99.0
    return float(np.sqrt(np.mean((np.array(c) - np.array(ref["contour"])) ** 2)))


def tone(pinyin):
    return next((MARKS[ch] for ch in pinyin if ch in MARKS), 5)


def synth(text, rate):
    r = tts.call("POST", "/text:synthesize", {"input": {"text": text},
                 "voice": {"languageCode": "cmn-CN", "name": KORE},
                 "audioConfig": {"audioEncoding": "LINEAR16", "speakingRate": rate}})
    return base64.b64decode(r["audioContent"])


def last_word(data):
    """The last stretch of sound in a clip, after its last pause, as WAV: the word the
    carrier ends on. None when the clip has no pause to cut at."""
    w = wave.open(io.BytesIO(data))
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    hop = sr // 100
    n = len(x) // hop
    rms = np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(axis=1) + 1e-9)
    env = np.convolve(rms, np.ones(5) / 5, mode="same")
    on = env > 0.06 * env.max()
    segs, i = [], 0
    while i < n:
        if on[i]:
            j = i
            while j < n and (on[j] or on[j:j + 12].any()):      # a gap under 120 ms stays inside
                j += 1
            segs.append((i, j)); i = j
        else:
            i += 1
    if len(segs) < 2:
        return None
    a = max(0, segs[-1][0] * hop - int(0.05 * sr))
    b = min(len(x), segs[-1][1] * hop + int(0.12 * sr))
    buf = io.BytesIO()
    o = wave.open(buf, "wb")
    o.setnchannels(1); o.setsampwidth(2); o.setframerate(sr)
    o.writeframes(x[a:b].astype(np.int16).tobytes())
    o.close()
    return buf.getvalue()


def path(word, n):
    return os.path.join(DIR, f"{voice.name(word)}-{n}.mp3")


def readings(word, pinyin):
    """Up to eight readings of a word, the ones whose pitch has the right shape first."""
    want = SHAPES[tone(pinyin)]
    ref = refs().get(str(tone(pinyin)))
    found, seen = [], set()
    for rate in RATES:
        for car in CARRIERS:
            cutout = last_word(synth(car.format(word), rate))
            if cutout is None:
                continue
            c, secs = takes.contour(cutout, points=9)
            if not c or tuple(c) in seen:
                continue
            seen.add(tuple(c))
            if ref:
                # beside the tone chosen by ear: close in pitch, and not clipped short
                d = distance(c, ref)
                found.append({"wav": cutout, "secs": secs, "d": d, "right": d <= 1.2 and secs >= 0.7 * ref["secs"],
                              "shape": f"{d:.1f} from your {ref['word']}", "how": f"{car.format('…')} at {rate}×"})
            else:
                shape = takes.tone_shape(takes.contour(cutout)[0])
                found.append({"wav": cutout, "secs": secs, "d": 0.0, "right": shape in want, "shape": shape,
                              "how": f"{car.format('…')} at {rate}×"})
    found.sort(key=lambda f: (not f["right"], f["d"], abs(f["secs"] - 0.4)))
    return found[:int(os.environ.get("READINGS", "8"))]


if __name__ == "__main__":
    if sys.argv[1] == "use":
        word, n = sys.argv[2], int(sys.argv[3])
        shutil.copyfile(path(word, n), os.path.join(voice.OUT, voice.name(word) + ".mp3"))
        print(word, "reading", n, "is the app's clip now")
        sys.exit()
    os.makedirs(DIR, exist_ok=True)
    info = board.details()
    rows = []
    words = []
    for arg in sys.argv[1:]:                      # 你, or 妈:mā where the course hasn't the word
        word, _, given = arg.partition(":")
        words.append(word)
        if given:
            info[word] = (given, info.get(word, ("", "", ""))[1], "word")
    for word in words:
        py, en, _ = info.get(word, ("", "", ""))
        for n, f in enumerate(readings(word, py), 1):
            takes.mp3(f["wav"], path(word, n))
            rows.append({"id": f"cite-{voice.name(word)}-{n}", "voice": "Kore", "hanzi": word, "pinyin": py, "en": en,
                         "kind": f"reading {n} · pitch {f['shape']}{'' if f['right'] else ' (not a close match)'} · {f['secs']:.2f}s",
                         "audio": base64.b64encode(open(path(word, n), "rb").read()).decode()})
            print(word, n, f["shape"], f"{f['secs']:.2f}s", f["how"])
    page = open(os.path.join(HERE, "board.html"), encoding="utf-8").read()
    title = "Readings to choose between: tick every one that sounds right"
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False)).replace("__TITLE__", title)
                .replace("__KEY__", "citation-" + "-".join(voice.name(w) for w in words)).replace("__TICKS__", "true"))
    out = os.path.join(HERE, ".voices", "citation-" + "".join(words)[:12] + ".html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(rows), "readings")
