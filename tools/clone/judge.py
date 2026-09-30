"""How well each clip was heard back (hear.py's heard.json) beside what it should say.
    python judge.py heard.json            # the redo takes, word by word
    python judge.py app.json app          # the app's own clips for chapters 1-5: the ones heard wrong
"""
import json, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import voice
from pypinyin import lazy_pinyin, Style

han = lambda s: "".join(c for c in s if "\u4e00" <= c <= "\u9fff")
T2S = str.maketrans("這個們說話學習會點兒語漢請問誰麼嗎見謝對沒關係氣認識興叫裡國來從飯館師設計醫學歲幾兩電話號碼聽樂書視覺現兒愛",
                    "这个们说话学习会点儿语汉请问谁么吗见谢对没关系气认识兴叫里国来从饭馆师设计医学岁几两电话号码听乐书视觉现儿爱")


def py(s, tones=True):
    return lazy_pinyin(han(s), style=Style.TONE3 if tones else Style.NORMAL, neutral_tone_with_five=True)


def grade(want, got):
    """0 the same characters; 1 the same sounds and tones; 2 the same but for neutral tones;
    3 the same sounds, a tone off; 4 something else."""
    got = got.translate(T2S)
    # erhua is heard or not: 一点儿 and 一点 count as the same
    want, got = (re.sub(r"(?<=.)儿", "", han(x)) for x in (want, got))
    if han(want) == han(got):
        return 0
    a, b = py(want), py(got)
    if a == b:
        return 1
    strip = lambda x: [re.sub(r"\d", "", s) for s in x]
    if strip(a) == strip(b):
        loose = all(x == y or x[-1] == "5" or y[-1] == "5" for x, y in zip(a, b))
        return 2 if loose else 3
    return 4


if __name__ == "__main__":
    heard = json.load(open(sys.argv[1], encoding="utf-8"))
    if len(sys.argv) > 2:
        texts = [t for v, t in voice.plan([1, 2, 3, 4, 5]) if v == "k"]
        by = {voice.name(t): t for t in texts}
        bad = []
        for p, got in heard.items():
            t = by.get(os.path.basename(p)[:-4])
            if t is None:
                continue
            g = grade(t, got)
            if g >= 2:
                bad.append((g, t, got))
        print(len(heard), "clips heard;", len(bad), "not heard as written:")
        for g, t, got in sorted(bad, reverse=True):
            print(f"  {g} {t}  →  {got}  [{' '.join(py(t))} / {' '.join(py(got.translate(T2S)))}]")
        sys.exit()
    names = {voice.name(w): w for w in ["这个", "再", "汉语", "成都", "只", "朋友", "请说慢一点儿", "和", "日本"]}
    out = {}
    for p, got in heard.items():
        m = re.match(r"(k_[0-9a-f]+)-(\d+)\.mp3", os.path.basename(p))
        if not m or m.group(1) not in names:
            continue
        w = names[m.group(1)]
        out.setdefault(w, []).append((int(m.group(2)), grade(w, got), got))
    for w, rows in out.items():
        print("==", w)
        for n, g, got in sorted(rows):
            print(f"  take {n:>2}: {g}  {got}")
    json.dump({w: sorted(r) for w, r in out.items()}, open(os.path.join(os.path.dirname(sys.argv[1]), "judged.json"), "w", encoding="utf-8"), ensure_ascii=False)
