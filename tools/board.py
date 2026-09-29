"""A sound board for checking the recorded clips by ear: one page, every clip of the chapters
asked for with its characters, pinyin and meaning, a play button, and a tick or a cross.
The audio is inside the page, so the one file opens anywhere (a phone too).

    python tools/board.py 1          # tools/.voices/board-ch1.html
"""
import base64, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import voice
from pypinyin import pinyin as py, Style

HERE = os.path.dirname(os.path.abspath(__file__))


def details():
    """characters -> (pinyin, meaning), from the course's words and dialogue lines."""
    d = json.load(open(voice.COURSE, encoding="utf-8"))
    out = {}
    for dlg in d["dialogues"]:
        for t in dlg["turns"]:
            out.setdefault(t["hanzi"].strip(), (t["pinyin"], t["en"], "sentence"))
    for l in d["lessons"]:
        for w in l.get("words", []):
            out[w["hanzi"].strip()] = (w["pinyin"], w.get("short") or w["en"], "word")
    return out


def build(chapters):
    info = details()
    rows = []
    for v, t in voice.plan(chapters):
        path = os.path.join(voice.OUT, voice.name(t, v) + ".mp3")
        if not os.path.exists(path):
            continue
        guess = " ".join(s[0] for s in py(voice.han(t), style=Style.TONE))
        p, en, kind = info.get(t, (guess, "(a name)", "name"))
        rows.append({"id": voice.name(t, v), "voice": "Kore" if v == "k" else "Charon", "hanzi": t,
                     "pinyin": p, "en": en, "kind": kind,
                     "audio": base64.b64encode(open(path, "rb").read()).decode()})
    return rows


if __name__ == "__main__":
    chapters = [int(x) for x in sys.argv[1:]] or [1]
    rows = build(chapters)
    label = "Chapter " + ", ".join(str(c) for c in chapters)
    key = "ch" + "-".join(str(c) for c in chapters)
    page = open(os.path.join(HERE, "board.html"), encoding="utf-8").read()
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                .replace("__TITLE__", f"{label}: {len(rows)} clips").replace("__KEY__", key))
    os.makedirs(os.path.join(HERE, ".voices"), exist_ok=True)
    out = os.path.join(HERE, ".voices", f"board-{key}.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, os.path.getsize(out) // 1024, "KB,", len(rows), "clips")
