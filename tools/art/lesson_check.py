"""Every lesson re-scored, so a new rule never undoes an old one: cuts all Claude's parts again (lesson_fit.py), then compares each
with the owner's version in lessons/catalogue.json and with the best it has scored before (lessons/scores.json). A part that got worse
is flagged. Pictures of each pair go to out/lessons/check-<id>.png.

From tools/art: ../sfx/.venv/Scripts/python -I lesson_check.py [--save]   (--save keeps today's scores as the new best)
"""
import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # (run with -I, which leaves this folder off the path)
from lesson_compare import compare  # noqa: E402

subprocess.run([sys.executable, "-I", "lesson_fit.py"], check=True)
lessons = json.load(open("lessons/catalogue.json", encoding="utf-8"))
best = json.load(open("lessons/scores.json")) if os.path.exists("lessons/scores.json") else {}
os.makedirs("out/lessons", exist_ok=True)
worse = 0
for l in lessons:
    if not l.get("claude"):
        print(f"{l['id']:<10} (no Claude cut of this part yet)")
        continue
    r = compare(l["claude"], l["owner"], f"out/lessons/check-{l['id']}.png", l["box"])
    b = best.get(l["id"])
    flag = ""
    if b and (r["seen px"] > b["seen px"] * 1.15 + 20 or r["shape %"] > b["shape %"] + 2):
        flag, worse = "  << WORSE than before", worse + 1
    was = f"(best {b['shape %']}%, {b['seen px']} px)" if b else "(first score)"
    print(f"{l['id']:<10} differs from the owner's by {r['shape %']:>5}% of the shape, {r['seen px']:>5} px seen {was}{flag}")
    if "--save" in sys.argv and (not b or r["shape %"] <= b["shape %"]):
        best[l["id"]] = {"shape %": r["shape %"], "seen px": r["seen px"]}
if "--save" in sys.argv:
    json.dump(best, open("lessons/scores.json", "w"), indent=1)
sys.exit(1 if worse else 0)
