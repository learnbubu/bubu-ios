"""Ranks the takes of each word that pass both checks by how much they sound like the clips the
owner approved by ear (tools/clone/locked.json): their length per syllable, the pitch she speaks
at and how widely it moves, and the colour of the voice (MFCCs). Then a board of each word's best
three beside the clip the app has now, to choose from. Run with the CosyVoice venv's Python.

    venv/Scripts/python tools/clone/rank.py 1-5           # → bubu-voice/retake/choose-1-5.html
"""
import base64, json, os, sys
import numpy as np
import librosa, pyworld
HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path[:0] = [HERE, TOOLS]
import tonecheck
from hashlib import sha256

OUT = os.path.join(os.path.dirname(TOOLS), "native", "Bubu", "Resources", "Voice")
WORK = r"C:\Users\domch\bubu-voice\retake"
name = lambda t: "k_" + sha256(t.strip().encode("utf-8")).hexdigest()[:16]
han = lambda s: "".join(c for c in s if "\u4e00" <= c <= "\u9fff")


def features(path):
    x, sr = tonecheck.load(path)
    f0, rms = tonecheck.track(x, sr)
    on = rms > 0.05
    v = f0[f0 > 0]
    mf = librosa.feature.mfcc(y=x.astype(np.float32), sr=sr, n_mfcc=13)
    loud = mf[:, on[:mf.shape[1]]] if on[:mf.shape[1]].any() else mf
    return {"secs": float(on.sum()) / 100, "hz": float(np.median(v)) if len(v) else 0.0,
            "range": float(12 * np.log2(np.percentile(v, 95) / np.percentile(v, 5))) if len(v) > 5 else 0.0,
            "mfcc": loud.mean(axis=1).tolist()}


def main(chs):
    sys.path.insert(0, TOOLS)
    import importlib.util
    spec = importlib.util.spec_from_file_location("st", os.path.join(HERE, "spelltake.py"))
    st = importlib.util.module_from_spec(spec); sys.argv = ["x", "choose", "x"]; spec.loader.exec_module(st)
    locked = json.load(open(os.path.join(HERE, "locked.json"), encoding="utf-8"))["texts"]
    approved = [t for t in locked if 1 <= len(han(t)) <= 4 and os.path.exists(os.path.join(OUT, name(t) + ".mp3"))]
    ref = [(t, features(os.path.join(OUT, name(t) + ".mp3"))) for t in approved]
    per_syl = np.array([f["secs"] / len(han(t)) for t, f in ref])
    hz = np.array([f["hz"] for _, f in ref if f["hz"]])
    rng = np.array([f["range"] / len(han(t)) for t, f in ref])
    mf = np.array([f["mfcc"] for _, f in ref])
    centre = mf.mean(axis=0)
    typical = np.median(np.linalg.norm(mf - centre, axis=1))

    def distance(t, f):
        n = len(han(t))
        z = lambda a, ref: abs(a - ref.mean()) / (ref.std() + 1e-6)
        return (z(f["secs"] / n, per_syl) + z(np.log(f["hz"] or 1), np.log(hz)) + 0.5 * z(f["range"] / n, rng)
                + np.linalg.norm(np.array(f["mfcc"]) - centre) / typical)

    sc = json.load(open(os.path.join(WORK, "scores.json"), encoding="utf-8"))
    kinds = {}
    for f in os.listdir(os.path.join(WORK, "clean")):
        k = f[:-4].split("-", 1)
        kinds.setdefault(k[0], []).append(k[1])
    rows, chosen = [], {}
    for t in st.words(chs):
        if t in locked:
            continue
        cands = []
        for k in kinds.get(name(t), []):
            p = os.path.join(WORK, "clean", f"{name(t)}-{k}.mp3")
            r = sc.get(p)
            if r is None:
                continue
            if len(han(t)) == 1:
                r = dict(r, voiced=st.voiced(p))
            if st.passes(t, r):
                cands.append((distance(t, features(p)), k, p))
        if not cands:
            continue
        cands.sort()
        now = os.path.join(OUT, name(t) + ".mp3")
        before = os.path.join(WORK, "before", name(t) + ".mp3")
        opts = [("now", now)]
        if os.path.exists(before):
            opts.append(("as it was", before))
        opts += [(f"new {i + 1}", p) for i, (_, k, p) in enumerate(cands[:3])]
        chosen[t] = [(label, p) for label, p in opts]
        py = tonecheck.course_pinyin(t)
        for label, p in opts:
            rows.append({"id": f"rank-{name(t)}-{label}", "voice": label, "hanzi": t, "pinyin": py, "en": "",
                         "kind": label, "audio": base64.b64encode(open(p, "rb").read()).decode()})
    json.dump(chosen, open(os.path.join(WORK, f"choose-{sys_arg}.json"), "w", encoding="utf-8"), ensure_ascii=False)
    page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                .replace("__TITLE__", f"Choose each word's clip: what the app has now, how it was, and the best three new takes ({len(chosen)} words)")
                .replace("__KEY__", f"rank-{sys_arg}").replace("__TICKS__", "true"))
    out = os.path.join(WORK, f"choose-{sys_arg}.html")
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(chosen), "words,", len(rows), "clips")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys_arg = sys.argv[1]
    a, _, b = sys_arg.partition("-")
    main(list(range(int(a), int(b or a) + 1)))
