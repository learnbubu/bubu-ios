"""The recording script for Bùbù's own voice: every syllable the course's single-character words
use, in the order a learner meets them, in batches of 40. Writes script.json (what the splitter
matches against) and script.html (what's read from, on a phone or printed).

    python tools/record/make_script.py
"""
import json, os, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
COURSE = os.path.join(ROOT, "native", "Bubu", "Resources", "Data", "course.json")
BATCH = 40
MARKS = {"ā": ("a", 1), "á": ("a", 2), "ǎ": ("a", 3), "à": ("a", 4), "ē": ("e", 1), "é": ("e", 2), "ě": ("e", 3),
         "è": ("e", 4), "ī": ("i", 1), "í": ("i", 2), "ǐ": ("i", 3), "ì": ("i", 4), "ō": ("o", 1), "ó": ("o", 2),
         "ǒ": ("o", 3), "ò": ("o", 4), "ū": ("u", 1), "ú": ("u", 2), "ǔ": ("u", 3), "ù": ("u", 4), "ǖ": ("v", 1),
         "ǘ": ("v", 2), "ǚ": ("v", 3), "ǜ": ("v", 4), "ü": ("v", 0)}


def numbered(p):
    """nǐ -> ni3, lǜ -> lv4, ma -> ma5: a safe file name for a syllable."""
    out, tone = "", 5
    for ch in p:
        if ch in MARKS:
            base, t = MARKS[ch]
            out += base
            if t:
                tone = t
        else:
            out += ch
    return out + str(tone)


def han(s):
    return "".join(ch for ch in s if "一" <= ch <= "鿿")


if __name__ == "__main__":
    d = json.load(open(COURSE, encoding="utf-8"))
    chars = collections.OrderedDict()
    for l in d["lessons"]:
        for w in l.get("words", []):
            h = han(w["hanzi"])
            if len(h) == 1:
                p = w["pinyin"].strip().lower()
                chars.setdefault(p, [])
                if h not in chars[p]:
                    chars[p].append(h)
    lines = []
    for i, (p, hs) in enumerate(chars.items(), 1):
        lines.append({"n": i, "pinyin": p, "file": numbered(p), "chars": hs, "batch": (i - 1) // BATCH + 1})
    json.dump(lines, open(os.path.join(HERE, "script.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    batches = (len(lines) + BATCH - 1) // BATCH
    rows = []
    for b in range(1, batches + 1):
        part = [l for l in lines if l["batch"] == b]
        rows.append(f'<section><h2>Batch {b} <small>lines {part[0]["n"]}–{part[-1]["n"]} · save as batch{b:02d}</small></h2><ol start="{part[0]["n"]}">')
        for l in part:
            rows.append(f'<li><span class="hz">{l["chars"][0]}</span><span class="py">{l["pinyin"]}</span>'
                        f'<span class="also">{" ".join(l["chars"][1:4])}</span></li>')
        rows.append("</ol></section>")
    page = open(os.path.join(HERE, "script_template.html"), encoding="utf-8").read()
    page = page.replace("__ROWS__", "\n".join(rows)).replace("__COUNT__", str(len(lines))).replace("__BATCHES__", str(batches))
    open(os.path.join(HERE, "script.html"), "w", encoding="utf-8", newline="\n").write(page)
    print(len(lines), "syllables in", batches, "batches")
