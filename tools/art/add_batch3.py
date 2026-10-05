"""Batch 3 (owner, 5 Oct 2026): pictures for the first chapters' words, so picture cards come up
from the first lessons, not only from stone 12 on. One more 4x4 sheet (sheet 14 in
picture_sheets.json), as a job for Codex in the same style as the other sheets."""
import json
import re

EARLY = [
    ("你好", "a cartoon kid waving hello with a big smile"),
    ("谢谢", "a cartoon kid giving a small polite bow with hands together, thankful"),
    ("再见", "a cartoon kid waving goodbye over their shoulder while walking away"),
    ("名字", "a name badge (a blank 'HELLO my name is' style sticker with no readable letters)"),
    ("高兴", "a beaming, happy cartoon face with sparkles"),
    ("认识", "two cartoon hands shaking"),
    ("对不起", "a cartoon kid looking apologetic with a hand behind their head"),
    ("慢", "a friendly tortoise walking slowly"),
    ("说", "a cartoon kid talking, with a speech bubble"),
    ("学", "a cartoon kid studying at a desk with an open book"),
    ("喝", "a cartoon kid drinking from a cup"),
    ("住", "a cartoon kid standing at the front door of their small house"),
    ("来", "a cartoon kid running happily towards you, arms open"),
    ("一起", "two cartoon kids walking hand in hand"),
]

if __name__ == "__main__":
    ps = json.load(open("picture_sheets.json", encoding="utf-8"))
    if not any(s and s[0]["w"] == EARLY[0][0] for s in ps["sheets"]):
        ps["sheets"].append([{"w": w, "d": d} for w, d in EARLY])
        json.dump(ps, open("picture_sheets.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    n = len(ps["sheets"])
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    f = f"out/raw/pictures-picture-sheet-{n}-early-words.png"
    if not any(j["file"] == f for j in jobs):
        tpl = next(j for j in jobs if j["group"] == "sheets")
        lines = "\n".join(f"{k + 1}. {d}" for k, (_, d) in enumerate(EARLY))
        p = re.sub(r"Create a sticker sheet of \d+ small picture icons.*?in exactly this order:\n.*?\n\n",
                   f"Create a sticker sheet of {len(EARLY)} small picture icons for a language-learning app, in a neat grid of 4 columns × 4 rows "
                   f"(the last row has only two), read left to right and top to bottom, in exactly this order:\n{lines}\n\n",
                   tpl["prompt"], flags=re.S)
        assert lines in p
        jobs.append({**tpl, "file": f, "prompt": p})
        json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("sheet", n, "job", f)
