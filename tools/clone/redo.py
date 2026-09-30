"""Words whose clips came out wrong, made again in the copied voice in many different ways, on a
board to choose from: said on its own, at the end of carrier sentences (cut out), and at the end
of natural phrases given for it (cut out; a particle like 呢 sounds right only in one).

    python tools/clone/redo.py 呢 再见 --phrase 呢=我很好，你呢？ --phrase 呢=小雨呢？
    python tools/clone/redo.py use 呢 7 再见 3      # the chosen takes become the app's clips
"""
import base64, json, os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
import voice, citation, chapter

WORK = os.path.join(chapter.WORK, "redo")
ALONE = 4                                    # takes of the word said by itself


def ways(word, phrases):
    """(what to say, how it's got): the word alone, in carriers, and in the given phrases."""
    out = [(word, "said on its own")] * ALONE
    out += [(c.format(word), "cut from " + c.format(word)) for c in chapter.CARRIERS]
    out += [(p, "cut from " + p) for p in phrases]
    return out


if __name__ == "__main__":
    if sys.argv[1] == "use":
        args = sys.argv[2:]
        for word, n in zip(args[::2], args[1::2]):
            shutil.copyfile(os.path.join(WORK, f"{voice.name(word)}-{n}.mp3"), os.path.join(voice.OUT, voice.name(word) + ".mp3"))
            print(word, "take", n, "is the app's clip now")
        sys.exit()
    words, phrases, args = [], {}, sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--phrase":
            w, p = args[i + 1].split("=", 1)
            phrases.setdefault(w, []).append(p)
            i += 2
        else:
            words.append(args[i]); i += 1
    os.makedirs(WORK, exist_ok=True)
    todo = [(say, how, w) for w in words for say, how in ways(w, phrases.get(w, []))]
    with open(os.path.join(WORK, "lines.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(say for say, _, _ in todo) + "\n")
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    raw = os.path.join(WORK, "raw")
    shutil.rmtree(raw, ignore_errors=True)
    subprocess.run([chapter.PYTHON, os.path.join(HERE, "say.py"), chapter.PROMPT, chapter.PROMPT_TEXT, raw,
                    os.path.join(WORK, "lines.txt")], check=True, env=env, stderr=subprocess.DEVNULL)
    info = __import__("board").details()
    rows, count = [], {}
    for n, (say, how, w) in enumerate(todo, 1):
        data = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", os.path.join(raw, f"{n:02d}.wav"),
                               "-ac", "1", "-ar", "24000", "-f", "wav", "pipe:1"], capture_output=True, check=True).stdout
        if say != w:
            data = citation.last_word(data)
            if data is None:
                continue
        k = count[w] = count.get(w, 0) + 1
        mp3 = os.path.join(WORK, f"{voice.name(w)}-{k}.mp3")
        if not chapter.finish(data, mp3, True):
            continue
        py, en, _ = info.get(w, ("", "", ""))
        rows.append({"id": f"redo-{voice.name(w)}-{k}", "voice": "Her voice", "hanzi": w, "pinyin": py, "en": en,
                     "kind": f"take {k} · {how}", "audio": base64.b64encode(open(mp3, "rb").read()).decode()})
    page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                .replace("__TITLE__", "Made again: " + " ".join(words) + f" ({len(rows)} takes)")
                .replace("__KEY__", "redo-" + "-".join(voice.name(w) for w in words)).replace("__TICKS__", "true"))
    out = os.path.join(WORK, "board.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(rows), "takes")
