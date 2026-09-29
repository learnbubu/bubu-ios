"""Makes the course's spoken audio with Google Cloud Text-to-Speech (tools/tts.py) and puts it
in the app: native/Bubu/Resources/Voice/<voice>_<hash>.mp3, where <voice> is k (Kore, the
default voice) or c (Charon, the other speaker in a dialogue) and <hash> is the first 16 hex
digits of the SHA-256 of the text. The app looks a clip up by the same name (Speech.clipName)
and falls back to the phone's own voice when there isn't one. Clips already made are skipped.

    python tools/voice.py plan 1        # what chapter 1 needs, and how many characters
    python tools/voice.py make 1        # make it
"""
import hashlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COURSE = os.path.join(ROOT, "native", "Bubu", "Resources", "Data", "course.json")
OUT = os.path.join(ROOT, "native", "Bubu", "Resources", "Voice")
VOICES = {"k": "cmn-CN-Chirp3-HD-Kore", "c": "cmn-CN-Chirp3-HD-Charon"}
PARTICLES = set("了吗呢吧啊哇呀嘛啦哦")


def han(s):
    return "".join(ch for ch in s if "\u4e00" <= ch <= "\u9fff")


def name(text, voice="k"):
    return voice + "_" + hashlib.sha256(text.strip().encode("utf-8")).hexdigest()[:16]


def plan(chapters):
    """The texts to say, as (voice, text) pairs, for the chapters given (1-based)."""
    d = json.load(open(COURSE, encoding="utf-8"))
    lessons = {l["id"]: l for l in d["lessons"]}
    names = sorted((han(n) for n in d["names"] if han(n)), key=len, reverse=True)
    words, known = [], set(PARTICLES)
    # every chapter up to the last one asked for counts as known; only the asked ones' words are said
    last = max(chapters)
    for ci, ch in enumerate(d["chapters"][:last], start=1):
        for lid in ch["lessons"]:
            for w in lessons[lid].get("words", []):
                known.update(han(w["hanzi"]))
                if ci in chapters:
                    words.append(w["hanzi"])
    out = [("k", w) for w in words]
    for dlg in d["dialogues"]:
        for t in dlg["turns"]:
            rest = han(t["hanzi"])
            used = [n for n in names if n in rest]
            for n in used:
                rest = rest.replace(n, "")
            if rest and all(ch in known for ch in rest):
                out.append(("k", t["hanzi"]))
                out += [("k", n) for n in used]
                if t["who"] != "you":
                    out.append(("c", t["hanzi"]))      # the other speaker, in Converse
    seen, uniq = set(), []
    for v, t in out:
        t = t.strip()
        if t and (v, t) not in seen:
            seen.add((v, t)); uniq.append((v, t))
    return uniq


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    chapters = [int(x) for x in sys.argv[2:]] or [1]
    if cmd not in ("plan", "make"):
        print(__doc__); sys.exit()
    todo = plan(chapters)
    new = [(v, t) for v, t in todo if not os.path.exists(os.path.join(OUT, name(t, v) + ".mp3"))]
    print(f"{len(todo)} clips for chapter(s) {chapters}: {sum(len(t) for _, t in todo)} characters; "
          f"{len(new)} still to make: {sum(len(t) for _, t in new)} characters")
    if cmd == "plan":
        for v, t in todo[:60]:
            print(" ", v, t)
        sys.exit()
    os.makedirs(OUT, exist_ok=True)
    size = 0
    for i, (v, t) in enumerate(new, 1):
        size += tts.speak(t, VOICES[v], os.path.join(OUT, name(t, v) + ".mp3"))
        if i % 20 == 0:
            print(f"  {i}/{len(new)}")
    print(f"made {len(new)} clips, {size // 1024} KB")
