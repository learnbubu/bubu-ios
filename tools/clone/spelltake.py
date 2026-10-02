"""Book 1's words made again with their tones spelled out (pinyin tokens, pinyin_tokens.py) by the
model tuned for fewer mistakes (llm.rl.pt), each take heard back and its tones measured
(score.py), and a word's clip replaced only when the present one fails and a new take passes.

    python tools/clone/spelltake.py make 1-5      # the takes (an hour or so on the GPU)
    python tools/clone/spelltake.py score 1-5     # finish them and score them, with the present clips
    python tools/clone/spelltake.py choose 1-5    # pick, list, and with `apply` put them in the app + a board
    ROUND=2 python tools/clone/spelltake.py make 1-5 对不起 学校 …   # more takes of some words
    python tools/clone/spelltake.py choose 1-5 all apply   # every word to its best passing take (the
                                                           # owner, 2 Oct 2026: "after is way better")

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


ROUND = os.environ.get("ROUND", "1")
SUFFIX = "" if ROUND == "1" else f"-r{ROUND}"


def lines(chs, only=None):
    out = []
    for t in words(chs):
        if only and t not in only:
            continue
        sp = spelled(t, pinyin(t))
        if not sp:
            continue
        n = ALONE if not only else 2 * ALONE
        out += [(sp, t, f"alone{SUFFIX}-{k}") for k in range(1, n + 1)]
        if len(judge.han(t)) == 1:
            out += [(c.format(sp), t, f"carried{SUFFIX}-{k}") for k, c in enumerate(CARRIERS, 1)]
    return out


REF_SECS = {int(k): v["secs"] for k, v in citation.refs().items()}


def voiced(p):
    """Seconds of sound in a clip (tools/clone/tails.py's stretches)."""
    import tails
    return sum(b - a for a, b in tails.stretches(tails.env(p))) / 100


def path(t, kind):
    return os.path.join(WORK, "clean", f"{voice.name(t)}-{kind}.mp3")


def passes(t, r):
    """Heard right (or, for one syllable, whose hearing is unreliable: not heard as some other
    sound) and every checked tone right."""
    if not r or r.get("tone") is None or r["tone"] < 1:
        return False
    g = judge.grade(t, r["heard"])
    if len(judge.han(t)) == 1:
        # long enough to finish its tone: the owner heard a clipped 你 (0.33 s of voice, 2 Oct 2026)
        if r.get("voiced") is not None and r["voiced"] < 0.8 * REF_SECS.get(citation.tone(pinyin(t)), 0.3):
            return False
        return g <= 3 or not judge.han(r["heard"])
    return g <= 1


if __name__ == "__main__":
    cmd, arg = sys.argv[1], sys.argv[2]
    chs = chapter.chapters_of(arg)
    os.makedirs(os.path.join(WORK, "clean"), exist_ok=True)
    only = [a for a in sys.argv[3:] if a not in ("all", "apply")]
    rounds = sorted(f[5:-5] for f in os.listdir(WORK) if f.startswith("lines") and f.endswith(".json"))   # "", "-r2", …

    def round_lines():
        for sfx in rounds:
            for n, x in enumerate(json.load(open(os.path.join(WORK, f"lines{sfx}.json"), encoding="utf-8")), 1):
                yield sfx, n, tuple(x)

    if cmd == "make":
        todo = lines(chs, only or None)
        open(os.path.join(WORK, f"lines{SUFFIX}.txt"), "w", encoding="utf-8").write("\n".join(s for s, _, _ in todo) + "\n")
        json.dump(todo, open(os.path.join(WORK, f"lines{SUFFIX}.json"), "w", encoding="utf-8"), ensure_ascii=False)
        env = dict(os.environ, PYTHONIOENCODING="utf-8")
        subprocess.run([VENV, os.path.join(HERE, "say.py"), chapter.PROMPT, chapter.PROMPT_TEXT, os.path.join(WORK, f"raw{SUFFIX}"),
                        os.path.join(WORK, f"lines{SUFFIX}.txt"), "rl"], check=True, env=env, stderr=subprocess.DEVNULL)
        print(len(todo), "takes made")
    elif cmd == "score":
        items = []
        for sfx, n, (say, t, kind) in round_lines():
            wav = os.path.join(WORK, f"raw{sfx}", f"{n:02d}.wav")
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
        every = "all" in sys.argv[3:]
        # chapter 1's clips were chosen by ear: never replaced here, even with `all` (the owner
        # heard 你 and 好 come out worse, 2 Oct 2026)
        owners = set(words([1]))
        kinds = {}
        for _, _, (_, t, kind) in round_lines():
            kinds.setdefault(t, []).append(kind)
        changed, kept, failing, listed = [], 0, [], []
        for t in words(chs):
            now = sc.get(os.path.join(voice.OUT, voice.name(t) + ".mp3"))
            # (a clip already replaced from these takes is one of them: nothing to do)
            if os.path.exists(os.path.join(WORK, "before", voice.name(t) + ".mp3")) and every and passes(t, now):
                kept += 1
                continue
            if passes(t, now) and not every:
                kept += 1
                continue
            cands = [(k, sc.get(path(t, k))) for k in kinds.get(t, [])]
            if len(judge.han(t)) == 1:
                for k, r in cands:
                    if r is not None and os.path.exists(path(t, k)):
                        r["voiced"] = voiced(path(t, k))
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
