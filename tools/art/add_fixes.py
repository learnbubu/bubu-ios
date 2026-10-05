"""Single-icon redos for picture cards that came out wrong (owner's review, 5 Oct 2026): the meats
drawn as live animals, real banknotes, the Olympic logo. Each job saves out/raw/picfix-<n>.png;
process.py puts it in place of the word's sliced card."""
import json

FIXES = [
    ("牛肉", "a plate of sliced cooked beef"),
    ("猪肉", "a plate of sliced roast pork belly"),
    ("羊肉", "three lamb skewers (yangrou chuanr) on a small plate"),
    ("英镑", "a stylised pound coin next to a plain green banknote with a large £ sign (no portrait, no real banknote design)"),
    ("人民币", "a stylised plain red banknote with a large ¥ sign (no portrait, no real banknote design)"),
    ("奥运会", "a gold medal on a striped ribbon (no rings, no logos)"),
]

if __name__ == "__main__":
    import make_prompts as mp  # noqa: F401  (STYLE, KEY)
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if not j["file"].startswith("out/raw/picfix-")]
    sheet_refs = next(j["refs"] for j in jobs if j["group"] == "sheets")
    note = next(j["prompt"] for j in jobs if j["group"] == "sheets").split("\n\n")[0]  # the reference note
    for i, (w, d) in enumerate(FIXES, 1):
        jobs.append({"file": f"out/raw/picfix-{i}.png", "group": "picfix", "word": w, "size": "1024x1024", "refs": sheet_refs,
                     "prompt": f"{note}\n\n{mp.STYLE}\n\nCreate ONE small picture icon for a language-learning app: {d}. "
                               "Centred, simple and instantly recognisable, with plenty of empty space around it. Square canvas.\n\n" + mp.KEY})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    json.dump({f"picfix-{i}": w for i, (w, _) in enumerate(FIXES, 1)}, open("picfix.json", "w", encoding="utf-8"), ensure_ascii=False)
    print(len(jobs), "jobs")
