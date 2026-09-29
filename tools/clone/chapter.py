"""Bùbù's clips for a chapter in a copied voice (CosyVoice 3, tools/clone/say.py), put on a board
to check before any reach the app. Short words get several takes to choose from.

    python tools/clone/chapter.py make 1            # C:/Users/domch/bubu-voice/chapter1/ + board.html
    python tools/clone/chapter.py use 1 你=2 我=1    # the chosen takes become the app's clips
    python tools/clone/chapter.py use 1 all         # take 1 of everything not named
"""
import base64, json, os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import voice, takes, citation

WORK = r"C:\Users\domch\bubu-voice"
PYTHON = os.path.join(WORK, "venv", "Scripts", "python.exe")
PROMPT = os.path.join(WORK, "partner", "clean", "teach1.wav")
PROMPT_TEXT = "你好，我是步步。今天我们一起学习中文。别着急，慢慢来，每天说一点儿，你会越来越好的。"
TAKES = 3                                   # for words of up to three characters
# a lone character said alone comes out clipped; said at the end of one of these and cut out, it
# gets its full tone (as with the Google voice: tools/citation.py)
CARRIERS = citation.CARRIERS


def texts(chapter):
    return [t for v, t in voice.plan([chapter]) if v == "k"]


def lines(chapter):
    """(what to say, the text it's for, take or carrier number) in the order they're made."""
    out = []
    for t in texts(chapter):
        if len(voice.han(t)) == 1:
            out += [(c.format(t), t, n) for n, c in enumerate(CARRIERS, 1)]
        else:
            out += [(t, t, k) for k in range(1, (TAKES if len(voice.han(t)) <= 3 else 1) + 1)]
    return out


def pinyin(t, info):
    """The course's pinyin for a word, or pypinyin's for a name the course doesn't list."""
    py = info.get(t, ("", "", ""))[0]
    if py:
        return py
    from pypinyin import pinyin as pp
    return " ".join(p[0] for p in pp(t))


if __name__ == "__main__":
    cmd, chapter = sys.argv[1], int(sys.argv[2])
    work = os.path.join(WORK, f"chapter{chapter}")
    todo = lines(chapter)
    if cmd == "make":
        os.makedirs(work, exist_ok=True)
        with open(os.path.join(work, "lines.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(say for say, _, _ in todo) + "\n")
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        subprocess.run([PYTHON, os.path.join(HERE, "say.py"), PROMPT, PROMPT_TEXT, os.path.join(work, "raw"),
                        os.path.join(work, "lines.txt")], check=True, env=env, stderr=subprocess.DEVNULL)
        info = __import__("board").details()
        rows, readings = [], {}
        for n, (say, t, k) in enumerate(todo, 1):
            data = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(work, "raw", f"{n:02d}.wav"),
                                   "-ac", "1", "-ar", "24000", "-f", "wav", "pipe:1"], capture_output=True, check=True).stdout
            if say != t:                                        # a carrier: cut the word out and score it
                cut = citation.last_word(data)
                if cut is None:
                    continue
                c, secs = takes.contour(cut, points=9)
                ref = citation.refs().get(str(citation.tone(pinyin(t, info))))
                d = citation.distance(c, ref) if ref and c else 99.0
                ok = bool(ref) and d <= 1.2 and 0.7 * ref["secs"] <= secs <= 1.6 * ref["secs"]
                readings.setdefault(t, []).append((not ok, d, cut, f"{secs:.2f}s · {d:.1f} from your reference tone · "
                                                   f"from {say}"))
                continue
            mp3 = os.path.join(work, f"{voice.name(t)}-{k}.mp3")
            takes.mp3(data, mp3)
            py, en, _ = info.get(t, ("", "", ""))
            rows.append({"id": f"ch{chapter}-{voice.name(t)}-{k}", "voice": "Her voice", "hanzi": t, "pinyin": py,
                         "en": en, "kind": f"take {k}", "audio": base64.b64encode(open(mp3, "rb").read()).decode()})
        for t, found in readings.items():
            found.sort(key=lambda f: (f[0], f[1]))
            py, en, _ = info.get(t, ("", "", ""))
            for k, (bad, d, cut, note) in enumerate(found[:TAKES], 1):
                mp3 = os.path.join(work, f"{voice.name(t)}-{k}.mp3")
                takes.mp3(cut, mp3)
                rows.append({"id": f"ch{chapter}-{voice.name(t)}-{k}", "voice": "Her voice", "hanzi": t,
                             "pinyin": py or pinyin(t, info), "en": en,
                             "kind": f"take {k} · " + ("measures right" if not bad else "doesn't measure right") + " · " + note,
                             "audio": base64.b64encode(open(mp3, "rb").read()).decode()})
        order = {t: i for i, t in enumerate(texts(chapter))}
        rows.sort(key=lambda r: (order[r["hanzi"]], r["kind"]))
        page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
        html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                    .replace("__TITLE__", f"Chapter {chapter} in her voice: {len(texts(chapter))} clips, short words in {TAKES} takes")
                    .replace("__KEY__", f"clone-ch{chapter}").replace("__TICKS__", "true"))
        out = os.path.join(work, "board.html")
        open(out, "w", encoding="utf-8", newline="\n").write(html)
        print(out, len(rows), "takes")
    elif cmd == "use":
        chosen = dict(a.split("=") for a in sys.argv[3:] if "=" in a)
        for t in texts(chapter):
            k = int(chosen.get(t, 1))
            shutil.copyfile(os.path.join(work, f"{voice.name(t)}-{k}.mp3"), os.path.join(voice.OUT, voice.name(t) + ".mp3"))
        print(len(texts(chapter)), "clips are her voice now")
