"""Gives a clip the pitch of a tone, keeping everything else about the voice: its pitch is
taken out and replaced with the tone's shape (Praat's PSOLA, through parselmouth). For a third
tone, which the voices won't say in full on a single syllable: falls, holds low, rises.

    python tools/reshape.py 你 in.mp3        # tools/.voices/reshape.html, several depths to choose from
    python tools/reshape.py use 你 2         # version 2 becomes the app's clip
"""
import base64, io, json, os, shutil, subprocess, sys
import numpy as np
import parselmouth
from parselmouth.praat import call
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import takes, voice, board

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, ".voices", "reshape")


def third(t, start, fall, rise):
    """A third tone's pitch at t (0 to 1 through the voiced part), in semitones from `start`:
    down `fall` by 45% of the way, held low to 65%, then up `rise`."""
    if t < 0.45:
        return start - fall * np.sin(t / 0.45 * np.pi / 2)
    if t < 0.65:
        return start - fall
    return start - fall + rise * np.sin((t - 0.65) / 0.35 * np.pi / 2)


def reshape(wav_path, fall, rise):
    snd = parselmouth.Sound(wav_path)
    pitch = snd.to_pitch(time_step=0.01, pitch_floor=75, pitch_ceiling=500)
    f = pitch.selected_array["frequency"]
    times = pitch.xs()
    voiced = np.where(f > 0)[0]
    if len(voiced) < 5:
        raise SystemExit("no clear pitch in that clip")
    t0, t1 = times[voiced[0]], times[voiced[-1]]
    start_hz = float(np.median(f[voiced[:4]]))
    manip = call(snd, "To Manipulation", 0.01, 75, 500)
    tier = call(manip, "Extract pitch tier")
    call(tier, "Remove points between", snd.xmin, snd.xmax)
    for t in np.linspace(t0, t1, 24):
        semis = third((t - t0) / max(t1 - t0, 1e-6), 0.0, fall, rise)
        call(tier, "Add point", t, start_hz * 2 ** (semis / 12))
    call([tier, manip], "Replace pitch tier")
    out = call(manip, "Get resynthesis (overlap-add)")
    buf = io.BytesIO()
    tmp = os.path.join(DIR, "_tmp.wav")
    out.save(tmp, "WAV")
    data = open(tmp, "rb").read()
    os.remove(tmp)
    return data


def path(word, n):
    return os.path.join(DIR, f"{voice.name(word)}-{n}.mp3")


if __name__ == "__main__":
    if sys.argv[1] == "use":
        word, n = sys.argv[2], int(sys.argv[3])
        shutil.copyfile(path(word, n), os.path.join(voice.OUT, voice.name(word) + ".mp3"))
        print(word, "version", n, "is the app's clip now")
        sys.exit()
    word, src = sys.argv[1], sys.argv[2]
    os.makedirs(DIR, exist_ok=True)
    wav = os.path.join(DIR, "_src.wav")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", src, "-ac", "1", "-ar", "24000", wav], check=True)
    info = board.details()
    py, en, _ = info.get(word, ("", "", ""))
    rows = []
    # (fall, rise) in semitones: from a gentle dip to a deep, clear one
    shapes = [(4, 3), (5, 4), (6, 5), (6, 7), (7, 6)]
    orig = open(wav, "rb").read()
    takes.mp3(orig, path(word, 0))
    rows.append({"id": f"reshape-{voice.name(word)}-0", "voice": "Kore", "hanzi": word, "pinyin": py, "en": en,
                 "kind": "version 0 · as it was, for comparison",
                 "audio": base64.b64encode(open(path(word, 0), "rb").read()).decode()})
    for n, (fall, rise) in enumerate(shapes, 1):
        data = reshape(wav, fall, rise)
        takes.mp3(data, path(word, n))
        c, secs = takes.contour(data, points=9)
        rows.append({"id": f"reshape-{voice.name(word)}-{n}", "voice": "Kore", "hanzi": word, "pinyin": py, "en": en,
                     "kind": f"version {n} · down {fall}, then up {rise} semitones · measured {c}",
                     "audio": base64.b64encode(open(path(word, n), "rb").read()).decode()})
        print(n, fall, rise, c, f"{secs:.2f}s")
    os.remove(wav)
    page = open(os.path.join(HERE, "board.html"), encoding="utf-8").read()
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                .replace("__TITLE__", f"{word}: its pitch reshaped to a full third tone")
                .replace("__KEY__", "reshape-" + voice.name(word)).replace("__TICKS__", "true"))
    out = os.path.join(HERE, ".voices", "reshape.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(rows), "versions")
