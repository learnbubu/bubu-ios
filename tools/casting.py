"""A casting board: every voice on offer says the same line, and each character of the course
gets one chosen for them. The audio is inside the page, so the one file opens anywhere.

    python tools/casting.py          # tools/.voices/casting.html
"""
import base64, importlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import takes, tts

HERE = os.path.dirname(os.path.abspath(__file__))
COURSE_SRC = os.path.join(os.path.dirname(os.path.dirname(HERE)), "bubu-course")
LINE = "你好！很高兴认识你。我们一起学中文吧！"
DIR = os.path.join(HERE, ".voices", "casting")

# who's who, where the course's cast list doesn't say: f, m, or "" for either
GENDER = {"马克": "m", "小雨": "f", "林小雨": "f", "陈明": "m", "钱阿姨": "f", "许诺": "f", "老顾": "m", "顾建国": "m",
          "何佳": "f", "沈静": "f", "艾玛": "f", "由美": "f", "大卫": "m", "陈妈妈": "f", "陈爸爸": "m", "黄丽": "f",
          "林爸爸": "m", "林妈妈": "f", "唐悦": "f", "露西": "f", "王警官": "f", "朵朵": "f", "赵婷": "f", "田甜": "f",
          "周奶奶": "f", "周文": "m", "何国平": "m", "豆豆": "m", "陆伟": "m", "汤姆": "m", "吴川": "m", "许妈妈": "f"}
SAME = {"小雨": "林小雨", "老顾": "顾建国"}          # the name a line is said under -> the cast entry


def cast():
    """The course's speakers, most lines first: name, English name, about, lines, gender."""
    sys.path.insert(0, COURSE_SRC)
    about, count = {}, {}
    for f in sorted(os.listdir(os.path.join(COURSE_SRC, "content"))):
        if not f.endswith(".py") or f.startswith("_"):
            continue
        m = importlib.import_module("content." + f[:-3])
        for c in getattr(m, "CAST", []):
            about.setdefault(c["zh"], c)

        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k == "lines" and isinstance(v, (list, tuple)):
                        for l in v:
                            if isinstance(l, (tuple, list)) and len(l) >= 2 and isinstance(l[0], str):
                                count[l[0]] = count.get(l[0], 0) + 1
                    else:
                        walk(v)
            elif isinstance(o, (list, tuple)):
                for v in o:
                    walk(v)
        walk(getattr(m, "UNITS", []))
        walk(getattr(m, "STORY", {}))
    out = []
    for name, n in sorted(count.items(), key=lambda kv: -kv[1]):
        c = about.get(SAME.get(name, name), {})
        out.append({"zh": name, "en": c.get("en", ""), "about": c.get("about", ""), "lines": n,
                    "gender": GENDER.get(name, "")})
    return out


if __name__ == "__main__":
    os.makedirs(DIR, exist_ok=True)
    voices = []
    for v in tts.voices():
        if "Chirp3-HD" not in v["name"]:
            continue
        short = v["name"].split("-")[-1]
        path = os.path.join(DIR, short + ".mp3")
        if not os.path.exists(path):
            takes.mp3(takes.wav(LINE, v["name"]), path)
        voices.append({"name": short, "gender": "f" if v.get("ssmlGender") == "FEMALE" else "m",
                       "audio": base64.b64encode(open(path, "rb").read()).decode()})
        print(short, v.get("ssmlGender"))
    people = [{"zh": "步步", "en": "Bùbù, the teacher", "about": "Says every single word and phrase in the lessons.",
               "lines": 0, "gender": "", "preset": "Kore"}] + cast()
    page = open(os.path.join(HERE, "casting.html"), encoding="utf-8").read()
    html = page.replace("__VOICES__", json.dumps(voices)).replace("__PEOPLE__", json.dumps(people, ensure_ascii=False)) \
               .replace("__LINE__", LINE)
    out = os.path.join(HERE, ".voices", "casting.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, os.path.getsize(out) // 1024, "KB,", len(voices), "voices,", len(people), "characters")
