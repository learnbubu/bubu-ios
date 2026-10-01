"""The course's own pinyin for any text the app says (a word, a practice sentence, a dialogue line),
falling back to pypinyin for a name or anything else."""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
COURSE = os.path.join(os.path.dirname(os.path.dirname(HERE)), "native", "Bubu", "Resources", "Data", "course.json")
_py = None


def table():
    global _py
    if _py is None:
        d = json.load(open(COURSE, encoding="utf-8"))
        _py = {}
        for l in d["lessons"]:
            for w in l.get("words", []):
                _py.setdefault(w["hanzi"].strip(), w["pinyin"])
        for x in d.get("drills", []):
            _py.setdefault(x["hanzi"].strip(), x["pinyin"])
        for dl in d["dialogues"]:
            for t in dl["turns"]:
                _py.setdefault(t["hanzi"].strip(), t["pinyin"])
    return _py


def pinyin(text):
    t = text.strip()
    if t in table():
        return table()[t]
    from pypinyin import pinyin as pp, Style
    return " ".join(x[0] for x in pp(t, style=Style.TONE))
