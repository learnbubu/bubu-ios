"""Bùbù's clips for a chapter in a copied voice (CosyVoice 3, tools/clone/say.py), put on a board
to check before any reach the app. Short words get several takes to choose from.

    python tools/clone/chapter.py make 1            # C:/Users/domch/bubu-voice/chapter1/ + board.html
    python tools/clone/chapter.py board 1 compare   # the board again from what's made; compare: cleaned beside as made
    python tools/clone/chapter.py make 1 new        # only what the app hasn't a clip for (then: use 1 new …)
    python tools/clone/chapter.py use 1 你=2 我=1    # the chosen takes become the app's clips
    python tools/clone/chapter.py use 1 all         # take 1 of everything not named
    python tools/clone/chapter.py make 2-5 new      # several chapters in one run, a board for each
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


# the finish for a clip: silence trimmed, a low rumble and any clicks taken out, the hiss above
# her voice's range rolled off, a short fade at each end so a cut never pops, the same loudness
# for every clip, and a higher bitrate than the Google clips (compression adds its own crackle)
TRIM = ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,"
        "areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.12,areverse")
CLEAN = ("highpass=f=70,adeclick=w=20:o=75,lowpass=f=11000,"
         "afade=t=in:d=0.012,areverse,afade=t=in:d=0.04,areverse,loudnorm=I=-18:TP=-2:LRA=7")


def finish(data, path, clean=True):
    """The clip as an MP3, or False when there's nothing in it."""
    af = TRIM + ("," + CLEAN if clean else "")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "wav", "-i", "pipe:0", "-af", af, "-ar", "24000",
                    "-ac", "1", "-b:a", "96k" if clean else "48k", path], input=data, check=True)
    secs = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                          capture_output=True, text=True).stdout.strip()
    return bool(secs) and float(secs) > 0.1


# "new": only what the app has no clip for yet, each in several takes, in its own folder, so the
# clips already chosen stay as they are
NEW = "new" in sys.argv[3:]


def chapters_of(arg):
    """"3" → [3]; "2-5" → [2, 3, 4, 5]."""
    a, _, b = arg.partition("-")
    return list(range(int(a), int(b or a) + 1))


def texts(chapter):
    chs = chapter if isinstance(chapter, list) else [chapter]
    out = [t for v, t in voice.plan(chs) if v == "k"]
    if NEW:
        out = [t for t in out if not os.path.exists(os.path.join(voice.OUT, voice.name(t) + ".mp3"))]
    return out


def lines(chapter):
    """(what to say, the text it's for, take or carrier number) in the order they're made."""
    out = []
    for t in texts(chapter):
        if len(voice.han(t)) == 1:
            out += [(c.format(t), t, n) for n, c in enumerate(CARRIERS, 1)]
        else:
            # several takes of a short word; of a sentence too for a one-chapter redo (a few lines)
            many = len(voice.han(t)) <= 3 or (NEW and not isinstance(chapter, list))
            out += [(t, t, k) for k in range(1, (TAKES if many else 1) + 1)]
    return out


def pinyin(t, info):
    """The course's pinyin for a word, or pypinyin's for a name the course doesn't list."""
    py = info.get(t, ("", "", ""))[0]
    if py:
        return py
    from pypinyin import pinyin as pp
    return " ".join(p[0] for p in pp(t))


if __name__ == "__main__":
    cmd, arg = sys.argv[1], sys.argv[2]
    chapter = int(arg) if "-" not in arg else chapters_of(arg)
    work = os.path.join(WORK, f"chapter{arg}" + ("-new" if NEW else ""))
    todo = lines(chapter)
    if cmd == "make":
        os.makedirs(work, exist_ok=True)
        with open(os.path.join(work, "lines.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(say for say, _, _ in todo) + "\n")
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        subprocess.run([PYTHON, os.path.join(HERE, "say.py"), PROMPT, PROMPT_TEXT, os.path.join(work, "raw"),
                        os.path.join(work, "lines.txt")], check=True, env=env, stderr=subprocess.DEVNULL)
        cmd = "board"
    if cmd == "board":                              # board 1 [compare]: rebuilt from what's made, not made again
        compare = "compare" in sys.argv[3:]
        os.makedirs(os.path.join(work, "clean"), exist_ok=True)
        info = __import__("board").details()
        chosen, readings = [], {}
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
            chosen.append((t, k, data, f"take {k}"))
        for t, found in readings.items():
            found.sort(key=lambda f: (f[0], f[1]))
            for k, (bad, d, cut, note) in enumerate(found[:TAKES], 1):
                chosen.append((t, k, cut, f"take {k} · " + ("measures right" if not bad else "doesn't measure right")
                               + " · " + note))
        rows, empty = [], []
        for t, k, data, note in chosen:
            py, en, _ = info.get(t, ("", "", ""))
            versions = [("clean", True)] + ([("", False)] if compare else [])
            for sub, clean in versions:
                mp3 = os.path.join(work, sub, f"{voice.name(t)}-{k}.mp3")
                if not finish(data, mp3, clean):
                    empty.append(f"{t} take {k}")
                    break
                rows.append({"id": f"ch{chapter}-{voice.name(t)}-{k}" + ("" if clean else "-asmade"),
                             "voice": "Cleaned" if clean else "As made", "hanzi": t, "pinyin": py or pinyin(t, info),
                             "en": en, "kind": note,
                             "audio": base64.b64encode(open(mp3, "rb").read()).decode()})
        order = {t: i for i, t in enumerate(texts(chapter))}
        rows.sort(key=lambda r: (order[r["hanzi"]], r["kind"]))
        page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
        # a board a chapter: each text on the first of the chapters that uses it
        chs = chapter if isinstance(chapter, list) else [chapter]
        home = {}
        for c in chs:
            for t in texts(c):
                home.setdefault(t, c)
        for c in chs:
            mine = [r for r in rows if home.get(r["hanzi"], chs[0]) == c]
            title = f"Chapter {c} in her voice: {len({r['hanzi'] for r in mine})} clips, short words in {TAKES} takes"
            if compare:
                title += ", each as made and cleaned"
            html = (page.replace("__DATA__", json.dumps(mine, ensure_ascii=False)).replace("__TITLE__", title)
                        .replace("__KEY__", f"clone-ch{c}" + ("-new" if NEW else "") + ("-compare" if compare else ""))
                        .replace("__TICKS__", "true"))
            name = ("board-compare" if compare else "board") + (f"-ch{c}" if len(chs) > 1 else "") + ".html"
            out = os.path.join(work, name)
            open(out, "w", encoding="utf-8", newline="\n").write(html)
            print(out, len(mine), "takes")
        if empty:
            print("empty, left off:", ", ".join(empty))
    elif cmd == "use":
        chosen = dict(a.split("=") for a in sys.argv[3:] if "=" in a)
        chosen_texts = texts(chapter)
        used, missing = 0, []
        for t in chosen_texts:
            # the take chosen, else the first take there is (a take that came out silent is left off)
            want = [int(chosen[t])] if t in chosen else [1, 2, 3]
            src = next((p for k in want for p in [os.path.join(work, "clean", f"{voice.name(t)}-{k}.mp3")] if os.path.exists(p)), None)
            if src is None:
                missing.append(t); continue
            shutil.copyfile(src, os.path.join(voice.OUT, voice.name(t) + ".mp3"))
            used += 1
        print(used, "clips are her voice now")
        if missing:
            print(len(missing), "with nothing made for them (make … new again):", " | ".join(missing[:20]))
