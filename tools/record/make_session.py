"""The second recording session for Bùbù's voice: the course's own sentences, to train a voice on
hers (CosyVoice fine-tuning, or a longer prompt), and book 1's words read slowly, for the clips
that matter most. Writes session.json (what the splitter matches against) and session.html (what's
read from, on a phone or printed).

    python tools/record/make_session.py
"""
import json, os, random, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
COURSE = os.path.join(ROOT, "native", "Bubu", "Resources", "Data", "course.json")
SENT_BATCH, WORD_BATCH = 25, 40
CAST = ["马克", "小雨", "陈明", "陈妈妈", "陈爸爸", "朵朵"]


def han(s):
    return "".join(ch for ch in s if "一" <= ch <= "鿿")


def chapter_of(d):
    return {lid: ci for ci, ch in enumerate(d["chapters"], start=1) for lid in ch["lessons"]}


if __name__ == "__main__":
    d = json.load(open(COURSE, encoding="utf-8"))
    ch = chapter_of(d)
    random.seed(7)
    # every practice sentence of book 1, then dialogue lines of books 1-3 (chapters 1-13): short
    # enough to say in one breath, every one of the cast's names, questions and answers
    sents, seen = [], set()
    for x in d.get("drills", []):
        if x["hanzi"] not in seen:
            seen.add(x["hanzi"]); sents.append((x["hanzi"], x["pinyin"], x["en"], "practice"))
    lines = []
    for dl in d["dialogues"]:
        c = ch.get(dl.get("lesson_id", ""), None)
        for t in dl["turns"]:
            h = t["hanzi"].strip()
            n = len(han(h))
            if h in seen or not (4 <= n <= 22) or re.search(r"[0-9A-Za-z]", h):
                continue
            lines.append((dl, t))
    # books 1-3 only: their dialogues' lessons are named 起步1-3
    lines = [(dl, t) for dl, t in lines if re.match(r"起步[123]", dl["lesson"])]
    random.shuffle(lines)
    picked = []
    for name in CAST:                                     # each name said a few times
        picked += [x for x in lines if name in x[1]["hanzi"]][:4]
    picked += [x for x in lines if x[1]["hanzi"].endswith(("？", "?"))][:30]
    for x in lines:
        if len(picked) >= 110:
            break
        picked.append(x)
    for dl, t in picked:
        if t["hanzi"] not in seen:
            seen.add(t["hanzi"]); sents.append((t["hanzi"].strip(), t["pinyin"], t["en"], "dialogue"))
    # book 1's words, slowly
    words, wseen = [], set()
    for l in d["lessons"]:
        if not l["id"].startswith("qibu1"):
            continue
        for w in l.get("words", []):
            h = w["hanzi"].strip()
            if h not in wseen and 1 <= len(han(h)) <= 4:
                wseen.add(h); words.append((h, w["pinyin"], w.get("short") or w["en"]))
    out = []
    for i, (h, py, en, kind) in enumerate(sents, 1):
        out.append({"n": i, "part": "sentences", "hanzi": h, "pinyin": py, "en": en, "kind": kind,
                    "batch": f"s{(i - 1) // SENT_BATCH + 1:02d}"})
    for i, (h, py, en) in enumerate(words, 1):
        out.append({"n": i, "part": "words", "hanzi": h, "pinyin": py, "en": en,
                    "batch": f"w{(i - 1) // WORD_BATCH + 1:02d}"})
    json.dump(out, open(os.path.join(HERE, "session.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)

    rows = []
    for part, title in (("sentences", "Part 1 · Sentences"), ("words", "Part 2 · Words, slowly")):
        items = [x for x in out if x["part"] == part]
        rows.append(f'<h2 class="part">{title}</h2>')
        for b in sorted({x["batch"] for x in items}):
            bi = [x for x in items if x["batch"] == b]
            rows.append(f'<section><h3>Batch {b.upper()} <small>lines {bi[0]["n"]}–{bi[-1]["n"]} · save as '
                        f'<b>{b}</b></small></h3><ol start="{bi[0]["n"]}" class="{part}">')
            for x in bi:
                rows.append(f'<li><span class="hz">{x["hanzi"]}</span><span class="py">{x["pinyin"]}</span>'
                            f'<span class="en">{x["en"]}</span></li>')
            rows.append("</ol></section>")
    page = open(os.path.join(HERE, "session_template.html"), encoding="utf-8").read()
    n_s = sum(x["part"] == "sentences" for x in out)
    n_w = sum(x["part"] == "words" for x in out)
    page = (page.replace("__ROWS__", "\n".join(rows)).replace("__SENTS__", str(n_s)).replace("__WORDS__", str(n_w))
                .replace("__SB__", str((n_s + SENT_BATCH - 1) // SENT_BATCH)).replace("__WB__", str((n_w + WORD_BATCH - 1) // WORD_BATCH)))
    open(os.path.join(HERE, "session.html"), "w", encoding="utf-8", newline="\n").write(page)
    print(n_s, "sentences,", n_w, "words")
