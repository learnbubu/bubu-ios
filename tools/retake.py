"""Several takes of words that sounded wrong, on a board to choose between by ear.

    python tools/retake.py 你:ni3 我:wo3        # tools/.voices/takes.html
    python tools/retake.py use 我 3             # take 3 of 我 becomes the app's clip
"""
import base64, json, os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import takes, voice, board

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, ".voices", "takes")
KORE = voice.VOICES["k"]


def path(word, n):
    return os.path.join(DIR, f"{voice.name(word)}-{n}.mp3")


if __name__ == "__main__":
    if sys.argv[1] == "use":
        word, n = sys.argv[2], int(sys.argv[3])
        shutil.copyfile(path(word, n), os.path.join(voice.OUT, voice.name(word) + ".mp3"))
        print(word, "take", n, "is the app's clip now")
        sys.exit()
    os.makedirs(DIR, exist_ok=True)
    info = board.details()
    rows = []
    for arg in sys.argv[1:]:
        word, pin = arg.split(":")
        ways = [("plain", word, None)] * 3 + [("pinyin given", word, pin)] * 3 + [("with a full stop", word + "。", None)] * 2
        for n, (how, text, p) in enumerate(ways, 1):
            data = takes.wav(text, KORE, p)
            secs, humps, _, _ = takes.measure(data)
            takes.mp3(data, path(word, n))
            py, en, _ = info.get(word, ("", "", ""))
            rows.append({"id": f"{voice.name(word)}-{n}", "voice": "Kore", "hanzi": word, "pinyin": py, "en": en,
                         "kind": f"take {n} · {how} · {secs:.2f}s",
                         "audio": base64.b64encode(open(path(word, n), "rb").read()).decode()})
            print(word, n, how, f"{secs:.2f}s", humps)
    page = open(os.path.join(HERE, "board.html"), encoding="utf-8").read()
    title = "Takes to choose between: tick every one that sounds right"
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False)).replace("__TITLE__", title)
                .replace("__KEY__", "takes-" + "-".join(a.split(":")[1] for a in sys.argv[1:])).replace("__TICKS__", "true"))
    out = os.path.join(HERE, ".voices", "takes.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(rows), "takes")
