"""Makes the course's spoken audio with Google Cloud Text-to-Speech (tools/tts.py) and puts it
in the app: native/Bubu/Resources/Voice/<voice>_<hash>.mp3, where <voice> is k (Bùbù's voice,
which every character shares until they have their own: Speech.speakerCodes) and <hash> is the
first 16 hex digits of the SHA-256 of the text. The app looks a clip up by the same name (Speech.clipName)
and falls back to the phone's own voice when there isn't one. Clips already made are skipped.

    python tools/voice.py plan 1        # what chapter 1 needs, and how many characters
    python tools/voice.py make 1        # make it
"""
import hashlib, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tts, takes

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
    # the stones' practice sentences (bubu-course/drills.py), for the chapters asked
    chapter_of = {lid: ci for ci, ch in enumerate(d["chapters"], start=1) for lid in ch["lessons"]}
    out += [("k", x["hanzi"]) for x in d.get("drills", []) if chapter_of.get(x["lesson"]) in chapters]
    seen, uniq = set(), []
    for v, t in out:
        t = t.strip()
        if t and (v, t) not in seen:
            seen.add((v, t)); uniq.append((v, t))
    return uniq


def pick(text, voice, tries=4):
    """A take of the text. The voices read a little differently each time, so a short word
    (up to three characters) is taken up to `tries` times until one measures right: as many
    swells of sound as syllables, and no longer than a syllable should be."""
    n = len(han(text))
    data = takes.wav(text, voice)
    if n == 0 or n > 3:
        return data
    for _ in range(tries - 1):
        secs, humps, _, _ = takes.measure(data)
        if humps <= n and 0.15 * n <= secs <= 0.5 * n:
            return data
        data = takes.wav(text, voice)
    return data


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
        path = os.path.join(OUT, name(t, v) + ".mp3")
        best = pick(t, VOICES[v])
        takes.mp3(best, path)
        size += os.path.getsize(path)
        if i % 20 == 0:
            print(f"  {i}/{len(new)}")
    print(f"made {len(new)} clips, {size // 1024} KB")
