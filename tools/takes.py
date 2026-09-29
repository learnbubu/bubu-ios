"""Several takes of a short text, measured: the voices give a different reading each time,
and a lone syllable sometimes comes out with an extra sound on the end. Takes are asked for
as WAV so they can be measured; the one chosen is turned into an MP3 with ffmpeg."""
import base64, io, os, subprocess, sys, wave
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tts


def wav(text, voice, pinyin=None):
    inp = {"text": text}
    if pinyin:
        inp["customPronunciations"] = {"pronunciations": [
            {"phrase": text, "phoneticEncoding": "PHONETIC_ENCODING_PINYIN", "pronunciation": pinyin}]}
    r = tts.call("POST", "/text:synthesize", {"input": inp,
                 "voice": {"languageCode": "cmn-CN", "name": voice},
                 "audioConfig": {"audioEncoding": "LINEAR16"}})
    return base64.b64decode(r["audioContent"])


def measure(data):
    """(voiced seconds, humps, samples, rate): the sound with the silence either side taken off,
    and how many separate swells of loudness it has (a syllable is one)."""
    w = wave.open(io.BytesIO(data))
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    hop = sr // 100                                      # 10 ms
    n = len(x) // hop
    rms = np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(axis=1) + 1e-9)
    env = np.convolve(rms, np.ones(5) / 5, mode="same")  # smoothed over 50 ms
    peak = env.max()
    loud = np.where(env > 0.06 * peak)[0]
    if len(loud) == 0:
        return 0.0, 0, x, sr
    a, b = loud[0], loud[-1]
    seg = env[a:b + 1]
    # a hump: a stretch above 35% of the peak, ended by a dip under 18%
    humps, up = 0, False
    for v in seg:
        if not up and v > 0.35 * peak:
            humps += 1; up = True
        elif up and v < 0.18 * peak:
            up = False
    return (b - a + 1) / 100.0, humps, x, sr


def mp3(data, path):
    """The take as an MP3, its silence trimmed to a short lead-in and tail."""
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0",
                    "-af", "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,"
                           "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse",
                    "-ac", "1", "-b:a", "48k", path], input=data, check=True)


if __name__ == "__main__":
    text = sys.argv[1]
    voice = "cmn-CN-Chirp3-HD-Kore"
    for i in range(int(sys.argv[2]) if len(sys.argv) > 2 else 6):
        d = wav(text, voice)
        secs, humps, _, _ = measure(d)
        print(f"take {i + 1}: {secs:.2f} s voiced, {humps} hump(s)")


# ---- machine listening: Google Speech-to-Text hears the clip, and what it heard is compared
# with what was meant, by sound (pinyin without tones). It can't judge tones.

def heard(wav_bytes, rate=24000):
    """What Speech-to-Text makes of a clip ('' when it hears nothing); None when the service
    isn't switched on for this key."""
    import json, urllib.request, urllib.error
    body = {"config": {"encoding": "LINEAR16", "sampleRateHertz": rate, "languageCode": "cmn-Hans-CN",
                       "maxAlternatives": 3},
            "audio": {"content": base64.b64encode(wav_bytes).decode()}}
    req = urllib.request.Request("https://speech.googleapis.com/v1/speech:recognize", method="POST",
                                 data=json.dumps(body).encode(),
                                 headers={"X-Goog-Api-Key": tts.key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            res = json.loads(r.read())
    except urllib.error.HTTPError as e:
        if e.code in (400, 403):
            return None
        raise
    alts = [a.get("transcript", "") for r_ in res.get("results", []) for a in r_.get("alternatives", [])]
    return alts


def sounds(text):
    """The syllables of a text without their tones."""
    from pypinyin import lazy_pinyin
    han = "".join(ch for ch in text if "\u4e00" <= ch <= "\u9fff")
    return [s.replace("ü", "v") for s in lazy_pinyin(han)]


def pcm16k(path):
    """A clip as 16 kHz mono WAV, for listening to."""
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "wav", "-ac", "1", "-ar", "16000", "pipe:1"],
                          capture_output=True, check=True).stdout


# ---- pitch: the shape of a syllable's tone, to check a lone word's tone without ears

def contour(data, points=5):
    """The pitch of the voiced part of a clip at `points` moments along it, in semitones
    relative to its own middle (so a rise reads +, a fall -), and its voiced length."""
    w = wave.open(io.BytesIO(data))
    sr = w.getframerate()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32)
    frame, hop = int(sr * 0.04), int(sr * 0.01)
    f0 = []
    peak = np.abs(x).max() + 1e-9
    for i in range(0, len(x) - frame, hop):
        s = x[i:i + frame]
        if np.sqrt((s ** 2).mean()) < 0.05 * peak:
            f0.append(0.0); continue
        s = s - s.mean()
        ac = np.correlate(s, s, mode="full")[frame - 1:]
        lo, hi = int(sr / 450), int(sr / 70)            # 70 to 450 Hz
        if ac[0] <= 0:
            f0.append(0.0); continue
        k = lo + int(np.argmax(ac[lo:hi]))
        f0.append(sr / k if ac[k] / ac[0] > 0.45 else 0.0)
    f0 = np.array(f0)
    voiced = np.where(f0 > 0)[0]
    if len(voiced) < 6:
        return [], 0.0
    v = f0[voiced[0]:voiced[-1] + 1]
    v = v[v > 0]
    semis = 12 * np.log2(v / np.median(v))
    idx = np.linspace(0, len(semis) - 1, points).astype(int)
    # each point the median of its neighbours, to ride over a stray octave jump
    out = [float(np.median(semis[max(0, i - 2):i + 3])) for i in idx]
    return [round(o, 1) for o in out], len(v) / 100.0


def tone_shape(c):
    """A rough name for a contour: level, rising, falling, dipping (falls then rises) or low."""
    if not c:
        return "unclear"
    start, low, end = c[0], min(c), c[-1]
    span = max(c) - min(c)
    if span < 2:
        return "level"
    if end - low >= 2 and start - low >= 1.5 and c.index(low) not in (0, len(c) - 1):
        return "dipping"
    if end - start >= 2:
        return "rising"
    if start - end >= 2:
        return "falling"
    return "uneven"
