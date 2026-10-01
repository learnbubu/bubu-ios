"""Book 1's words made again with their tones spelled out (pinyin tokens, pinyin_tokens.py) by the
model tuned for fewer mistakes (llm.rl.pt), each take heard back and its tones measured
(score.py), and a word's clip replaced only when the present one fails and a new take passes.

    python tools/clone/spelltake.py make 1-5      # the takes (an hour or so on the GPU)
    python tools/clone/spelltake.py score 1-5     # finish them and score them, with the present clips
    python tools/clone/spelltake.py choose 1-5    # pick, list, and with `apply` put them in the app + a board

The 1 Oct 2026 pilot: of words said plainly 1 take in 24 passed both checks; spelled in pinyin,
8 in 23. Sentences spelled in pinyin came out worse, so only words (up to four characters) are
made again here.
"""
import base64, json, os, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path[:0] = [TOOLS, HERE]
import voice, chapter, citation, judge
from pinyin_tokens import spelled
from coursepy import pinyin

WORK = os.path.join(chapter.WORK, "retake")
VENV = chapter.PYTHON
ALONE, CARRIED = 3, 2
CARRIERS = ["请读：{}。", "这个字读：{}。"]
# Chapter 1's clips were chosen by the owner by ear: listed when they fail, never replaced
OWNERS = None


def words(chs):
    ts = [t for v, t in voice.plan(chs) if v == "k"]
    return [t for t in ts if 1 <= len(judge.han(t)) <= 4 and not any(p in t for p in "，。！？,.!?")]


def lines(chs):
    out = []
    for t in words(chs):
        sp = spelled(t, pinyin(t))
        if not sp:
            continue
        out += [(sp, t, f"alone-{k}") for k in range(1, ALONE + 1)]
        if len(judge.han(t)) == 1:
            out += [(c.format(sp), t, f"carried-{k}") for k, c in enumerate(CARRIERS, 1)]
    return out


def path(t, kind):
    return os.path.join(WORK, "clean", f"{voice.name(t)}-{kind}.mp3")


def passes(t, r):
    """Heard right (or, for one syllable, whose hearing is unreliable: not heard as some other
    sound) and every checked tone right."""
    if not r or r.get("tone") is None or r["tone"] < 1:
        return False
    g = judge.grade(t, r["heard"])
    if len(judge.han(t)) == 1:
        return g <= 3 or not judge.han(r["heard"])
    return g <= 1


if __name__ == "__main__":
    cmd, arg = sys.argv[1], sys.argv[2]
    chs = chapter.chapters_of(arg)
    os.makedirs(os.path.join(WORK, "clean"), exist_ok=True)
    todo = lines(chs)
    if cmd == "make":
        open(os.path.join(WORK, "lines.txt"), "w", encoding="utf-8").write("\n".join(s for s, _, _ in todo) + "\n")
        json.dump(todo, open(os.path.join(WORK, "lines.json"), "w", encoding="utf-8"), ensure_ascii=False)
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        subprocess.run([VENV, os.path.join(HERE, "say.py"), chapter.PROMPT, chapter.PROMPT_TEXT, os.path.join(WORK, "raw"),
                        os.path.join(WORK, "lines.txt"), "rl"], check=True, env=env, stderr=subprocess.DEVNULL)
        print(len(todo), "takes made")
    elif cmd == "score":
        todo = [tuple(x) for x in json.load(open(os.path.join(WORK, "lines.json"), encoding="utf-8"))]
        items = []
        for n, (say, t, kind) in enumerate(todo, 1):
            wav = os.path.join(WORK, "raw", f"{n:02d}.wav")
            out = path(t, kind)
            if os.path.exists(wav) and not os.path.exists(out):
                data = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", wav, "-ac", "1", "-ar", "24000", "-f", "wav", "pipe:1"],
                                      capture_output=True, check=True).stdout
                if kind.startswith("carried"):
                    data = citation.last_word(data)
                if data is None or not chapter.finish(data, out, True):
                    continue
            if os.path.exists(out):
                items.append({"text": t, "path": out})
        for t in words(chs):
            items.append({"text": t, "path": os.path.join(voice.OUT, voice.name(t) + ".mp3")})
        json.dump(items, open(os.path.join(WORK, "todo.json"), "w", encoding="utf-8"), ensure_ascii=False)
        subprocess.run([VENV, os.path.join(HERE, "score.py"), os.path.join(WORK, "todo.json"), os.path.join(WORK, "scores.json")],
                       check=True, env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    elif cmd == "choose":
        sc = json.load(open(os.path.join(WORK, "scores.json"), encoding="utf-8"))
        owners = set(words([1]))
        todo = [tuple(x) for x in json.load(open(os.path.join(WORK, "lines.json"), encoding="utf-8"))]
        kinds = {}
        for _, t, kind in todo:
            kinds.setdefault(t, []).append(kind)
        changed, kept, failing, listed = [], 0, [], []
        for t in words(chs):
            now = sc.get(os.path.join(voice.OUT, voice.name(t) + ".mp3"))
            if passes(t, now):
                kept += 1
                continue
            cands = [(k, sc.get(path(t, k))) for k in kinds.get(t, [])]
            good = [(k, r) for k, r in cands if passes(t, r)]
            # heard exactly first, then said alone before cut from a carrier
            good.sort(key=lambda kr: (judge.grade(t, kr[1]["heard"]), kr[0].startswith("carried"), kr[0]))
            if not good:
                failing.append(t)
                continue
            if t in owners:
                listed.append((t, good[0][0]))
                continue
            changed.append((t, good[0][0], now, good[0][1]))
        print(f"{kept} words pass as they are; {len(changed)} have a better take; {len(failing)} have none that passes:",
              " ".join(failing))
        print("chapter 1 (chosen by ear, left as they are) that fail with a passing take:", " ".join(f"{t}({k})" for t, k in listed))
        for t, k, now, new in changed:
            print(f"  {t}: {k}  now heard '{now and now['heard']}' tone {now and now['tone']} → '{new['heard']}' tone {new['tone']}")
        if "apply" in sys.argv[3:]:
            os.makedirs(os.path.join(WORK, "before"), exist_ok=True)
            rows = []
            info = __import__("board").details()
            for t, k, now, new in changed:
                dst = os.path.join(voice.OUT, voice.name(t) + ".mp3")
                before = os.path.join(WORK, "before", voice.name(t) + ".mp3")
                if os.path.exists(dst) and not os.path.exists(before):
                    shutil.copyfile(dst, before)
                shutil.copyfile(path(t, k), dst)
                py, en, _ = info.get(t, ("", "", ""))
                for label, src in (("before", before), ("after", dst)):
                    if os.path.exists(src):
                        rows.append({"id": f"retake-{voice.name(t)}-{label}", "voice": "Was" if label == "before" else "Now",
                                     "hanzi": t, "pinyin": py or pinyin(t), "en": en, "kind": label,
                                     "audio": base64.b64encode(open(src, "rb").read()).decode()})
            page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
            html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                        .replace("__TITLE__", f"Book 1 words made again with their tones spelled out: {len(changed)} changed, before and after")
                        .replace("__KEY__", "retake-book1").replace("__TICKS__", "true"))
            open(os.path.join(WORK, "board.html"), "w", encoding="utf-8", newline="\n").write(html)
            print("applied", len(changed), "→", os.path.join(WORK, "board.html"))
