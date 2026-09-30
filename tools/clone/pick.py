"""For words made again (redo.py): each take's grade from the recogniser beside its pitch, the
app's present clip as take 0, and the take to use.
    python pick.py 的 八 …            # prints a table and the `redo.py use` arguments
"""
import io, json, os, re, subprocess, sys
import numpy as np
sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = r"C:\Users\domch\Documents\Projects\bubu-ios\tools"
sys.path.insert(0, TOOLS); sys.path.insert(0, HERE)
import voice, takes, citation, judge
from pypinyin import pinyin as pp, Style

heard = {}
for f in ("heard.json", "app.json"):
    p = os.path.join(HERE, f)
    if os.path.exists(p):
        heard.update({os.path.basename(k): v for k, v in json.load(open(p, encoding="utf-8")).items()})


def wav_of(path):
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "24000", "-f", "wav", "pipe:1"],
                          capture_output=True, check=True).stdout


def rows(word):
    name = voice.name(word)
    files = [(0, os.path.join(voice.OUT, name + ".mp3"))]
    files += sorted((int(re.search(r"-(\d+)\.mp3$", f).group(1)), os.path.join(HERE, f))
                    for f in os.listdir(HERE) if f.startswith(name + "-") and f.endswith(".mp3"))
    py = " ".join(x[0] for x in pp(word, style=Style.TONE))
    single = len(judge.han(word)) == 1
    ref = citation.refs().get(str(citation.tone(py))) if single else None
    out = []
    for n, path in files:
        if not os.path.exists(path) or os.path.getsize(path) < 1000:
            continue
        got = heard.get(os.path.basename(path))
        g = judge.grade(word, got) if got is not None else 9
        data = wav_of(path)
        c, secs = takes.contour(data, points=9)
        d = round(citation.distance(c, ref), 2) if ref and c else None
        out.append({"take": n, "grade": g, "heard": (got or "")[:14], "secs": secs, "dist": d, "shape": takes.tone_shape(c) if single else "",
                    "ok_len": (0.7 * ref["secs"] <= secs <= 1.7 * ref["secs"]) if ref else (0.12 * len(judge.han(word)) <= secs)})
    return py, out


if __name__ == "__main__":
    use = []
    for word in sys.argv[1:]:
        py, rs = rows(word)
        print("==", word, py)
        for r in rs:
            print(f"   {r['take']:>2} asr={r['grade']} {r['secs']:.2f}s dist={r['dist']} {r['shape']:8} {r['heard']}")
        now = next((r for r in rs if r["take"] == 0), None)
        good = [r for r in rs if r["take"] > 0 and r["grade"] <= 1 and r["ok_len"] and (r["dist"] is None or r["dist"] <= 2.2)]
        good.sort(key=lambda r: (r["dist"] if r["dist"] is not None else 0, r["grade"], r["take"]))
        if good:
            print("   ->", good[0]["take"], "| now:", now and (now["grade"], now["dist"]))
            use += [word, str(good[0]["take"])]
        else:
            print("   -> none passes; the present clip stays")
    print("\nredo.py use " + " ".join(use))
