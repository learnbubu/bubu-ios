"""Every clip in a list heard back (Whisper) and its tones measured (tonecheck), for choosing takes
without ears. Run with the CosyVoice venv's Python; results are kept, so a rerun only does what's new.

    venv/Scripts/python tools/clone/score.py todo.json scores.json
    todo.json: [{"text": "汉语", "path": "C:/…/take.mp3"}, …]
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tonecheck

todo_path, out_path = sys.argv[1], sys.argv[2]
todo = json.load(open(todo_path, encoding="utf-8"))
res = json.load(open(out_path, encoding="utf-8")) if os.path.exists(out_path) else {}
model = None
for n, item in enumerate(todo):
    p = item["path"]
    if p in res or not os.path.exists(p):
        continue
    r = {"text": item["text"]}
    if os.path.getsize(p) < 1000:
        r.update(heard="", tone=0.0, syllables=[])
    else:
        if model is None:
            import whisper
            model = whisper.load_model("medium")
        try:
            r["heard"] = model.transcribe(p, language="zh", temperature=0.0, condition_on_previous_text=False,
                                          initial_prompt="以下是普通话的词语。", fp16=True)["text"].strip()
        except Exception as e:
            r["heard"] = ""
        try:
            t = tonecheck.check(item["text"], p)
            r["tone"] = t["score"] if t else None
            r["syllables"] = [[c, k, ok] for c, k, ok in t["syllables"]] if t else []
        except Exception as e:
            r["tone"], r["syllables"] = None, []
    res[p] = r
    if n % 25 == 0:
        json.dump(res, open(out_path, "w", encoding="utf-8"), ensure_ascii=False)
        print(n, len(todo), flush=True)
json.dump(res, open(out_path, "w", encoding="utf-8"), ensure_ascii=False)
print("done", len(res))
