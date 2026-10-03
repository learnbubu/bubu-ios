"""What a speech recogniser (Whisper, run here) makes of each take, to pick takes without ears.
    venv\\Scripts\\python redo\\hear.py out.json file1.mp3 file2.mp3 ...   (or a folder)
"""
import json, os, sys
import whisper

out, paths = sys.argv[1], []
for a in sys.argv[2:]:
    if os.path.isdir(a):
        paths += [os.path.join(a, f) for f in sorted(os.listdir(a)) if f.endswith(".mp3")]
    else:
        paths.append(a)
model = whisper.load_model("medium")
res = json.load(open(out, encoding="utf-8")) if os.path.exists(out) else {}
for n, p in enumerate(paths):
    key = os.path.abspath(p)
    if key in res:
        continue
    if os.path.getsize(p) < 1000:
        res[key] = ""
        continue
    try:
        r = model.transcribe(p, language="zh", temperature=0.0, condition_on_previous_text=False,
                             initial_prompt="以下是普通话的词语。", fp16=True)
        res[key] = r["text"].strip()
    except Exception as e:
        res[key] = ""
        print("failed", p, str(e)[:80], flush=True)
    if n % 20 == 0:
        json.dump(res, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        print(n, len(paths), flush=True)
json.dump(res, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
print("done", len(res))
