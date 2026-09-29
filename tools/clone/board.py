"""Puts cloned lines on a sound board, each next to the same line from any other sets, to
compare by ear.

    python tools/clone/board.py lines.txt out.html "Standard=dir_a" "Tuned=dir_b" ...

Each dir holds 01.wav, 02.wav ... (or .mp3), one per line of lines.txt.
"""
import base64, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)


def mp3_bytes(path):
    return subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-b:a", "64k", "-f", "mp3", "pipe:1"],
                          capture_output=True, check=True).stdout


if __name__ == "__main__":
    lines_path, out = sys.argv[1], sys.argv[2]
    sets = [a.split("=", 1) for a in sys.argv[3:]]
    lines = [l.strip() for l in open(lines_path, encoding="utf-8") if l.strip()]
    rows = []
    for n, line in enumerate(lines, 1):
        for label, d in sets:
            src = next((os.path.join(d, f"{n:02d}{ext}") for ext in (".wav", ".mp3")
                        if os.path.exists(os.path.join(d, f"{n:02d}{ext}"))), None)
            if not src:
                continue
            rows.append({"id": f"clone-{n:02d}-{label}", "voice": label, "hanzi": line, "pinyin": "", "en": "",
                         "kind": f"line {n} · {label}", "audio": base64.b64encode(mp3_bytes(src)).decode()})
    page = open(os.path.join(TOOLS, "board.html"), encoding="utf-8").read()
    html = (page.replace("__DATA__", json.dumps(rows, ensure_ascii=False))
                .replace("__TITLE__", f"CosyVoice 3 test: {len(lines)} lines, {len(sets)} versions each")
                .replace("__KEY__", "clone-" + os.path.basename(out)).replace("__TICKS__", "true"))
    open(out, "w", encoding="utf-8", newline="\n").write(html)
    print(out, len(rows), "clips")
