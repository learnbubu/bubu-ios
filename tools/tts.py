"""Google Cloud Text-to-Speech for Bùbù's audio. The key is read from the GOOGLE_TTS_KEY
environment variable (or the user's environment in the registry); it is never printed.

    python tools/tts.py voices            # the Mandarin voices on offer
    python tools/tts.py samples           # one sentence in a few voices, into tools/.voices/
"""
import base64, json, os, sys, urllib.request, urllib.error

API = "https://texttospeech.googleapis.com/v1"
HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLE = "你好，我叫步步。很高兴认识你！"


def key():
    k = os.environ.get("GOOGLE_TTS_KEY")
    if not k and os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as h:
                k = winreg.QueryValueEx(h, "GOOGLE_TTS_KEY")[0]
        except OSError:
            k = None
    if not k:
        sys.exit("GOOGLE_TTS_KEY is not set")
    return k.strip()


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-Goog-Api-Key": key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        msg = e.read().decode("utf-8", "replace")
        try:
            msg = json.loads(msg)["error"]["message"]
        except Exception:
            pass
        sys.exit(f"HTTP {e.code}: {msg}")


def voices():
    vs = call("GET", "/voices?languageCode=cmn-CN").get("voices", [])
    return sorted(vs, key=lambda v: v["name"])


def speak(text, voice, path, rate=1.0):
    body = {"input": {"text": text},
            "voice": {"languageCode": "cmn-CN", "name": voice},
            "audioConfig": {"audioEncoding": "MP3", "speakingRate": rate}}
    audio = call("POST", "/text:synthesize", body)["audioContent"]
    with open(path, "wb") as f:
        f.write(base64.b64decode(audio))
    return os.path.getsize(path)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "check":
        print("key found,", len(key()), "characters")
    elif cmd == "voices":
        for v in voices():
            print(v["name"], v.get("ssmlGender", ""), v.get("naturalSampleRateHertz", ""))
    elif cmd == "samples":
        out = os.path.join(HERE, ".voices")
        os.makedirs(out, exist_ok=True)
        for v in sys.argv[2:]:
            n = speak(SAMPLE, v, os.path.join(out, v + ".mp3"))
            print(v, n, "bytes")
    else:
        print(__doc__)
