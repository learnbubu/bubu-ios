"""Cuts a batch recording into one clip per syllable and puts them on a board to check.
The recording is split at pauses; a "重来" (redo) is spotted as a short two-syllable burst and
the take before it dropped. The pieces are matched to the script in order, so a batch whose
count doesn't come out right is flagged rather than guessed at.

    python tools/record/split.py batch01.m4a 1     # tools/record/out/batch01/*.mp3 + a board
"""
import base64, io, json, os, subprocess, sys, wave
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)


def load(path, sr=24000):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "s16le", "pipe:1"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32), sr


def pieces(x, sr, gap=0.6):
    """Stretches of sound separated by at least `gap` seconds of quiet: (start, end) in samples."""
    hop = sr // 100
    n = len(x) // hop
    rms = np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(axis=1) + 1e-9)
    env = np.convolve(rms, np.ones(5) / 5, mode="same")
    floor = np.percentile(env, 10)
    on = env > max(floor * 4, 0.04 * env.max())
    out, i, g = [], 0, int(gap * 100)
    while i < n:
        if on[i]:
            j = i
            while j < n and (on[j] or on[j:j + g].any()):
                j += 1
            if j - i >= 8:                                  # under 80 ms is a click, not speech
                out.append((i * hop, j * hop))
            i = j
        else:
            i += 1
    return out


def wav_bytes(x, sr):
    buf = io.BytesIO()
    w = wave.open(buf, "wb")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes(np.clip(x, -32768, 32767).astype(np.int16).tobytes())
    w.close()
    return buf.getvalue()


def to_mp3(data, path):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0", "-af", "loudnorm=I=-18:TP=-2",
                    "-ac", "1", "-b:a", "64k", path], input=data, check=True)


if __name__ == "__main__":
    src, batch = sys.argv[1], int(sys.argv[2])
    script = [l for l in json.load(open(os.path.join(HERE, "script.json"), encoding="utf-8")) if l["batch"] == batch]
    x, sr = load(src)
    ps = pieces(x, sr)
    # a redo: a piece noticeably longer than one syllable (重来 is two) removes the take before it
    lengths = np.array([(b - a) / sr for a, b in ps])
    typical = float(np.median(lengths)) if len(lengths) else 0.4
    kept = []
    for (a, b), secs in zip(ps, lengths):
        if secs > 1.7 * typical and kept:
            kept.pop()                                      # drop the take being redone
            continue
        kept.append((a, b))
    outdir = os.path.join(HERE, "out", f"batch{batch:02d}")
    os.makedirs(outdir, exist_ok=True)
    rows = []
    for i, line in enumerate(script):
        if i >= len(kept):
            break
        a, b = kept[i]
        a, b = max(0, a - int(0.05 * sr)), min(len(x), b + int(0.15 * sr))
        path = os.path.join(outdir, f'{line["n"]:03d}-{line["file"]}.mp3')
        to_mp3(wav_bytes(x[a:b], sr), path)
        rows.append({"id": f'rec-{line["file"]}', "voice": "Recorded", "hanzi": line["chars"][0], "pinyin": line["pinyin"],
                     "en": " ".join(line["chars"][1:4]), "kind": f'line {line["n"]} · {(b - a) / sr:.2f}s',
                     "audio": base64.b64encode(open(path, "rb").read()).decode()})
    ok = len(kept) == len(script)
    print(f"{len(ps)} pieces, {len(ps) - len(kept)} removed as redos, {len(kept)} kept; script has {len(script)} lines",
          "" if ok else " <-- COUNT DOESN'T MATCH: check the board, the pieces may have shifted")
    page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
    title = f"Recorded batch {batch}: {len(rows)} clips" + ("" if ok else f" (count off: {len(kept)} pieces for {len(script)} lines)")
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False)).replace("__TITLE__", title)
                .replace("__KEY__", f"rec-batch{batch:02d}").replace("__TICKS__", "false"))
    board = os.path.join(outdir, "board.html")
    open(board, "w", encoding="utf-8", newline="\n").write(html)
    print(board)
