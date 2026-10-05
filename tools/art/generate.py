"""Generates Bùbù's art unattended: every prompt in prompts.json goes to OpenAI's image API with
existing app art attached as style references, and each result is saved to out/raw/<name>.png.

    set OPENAI_API_KEY in your environment (never paste it anywhere), then:
    python generate.py                     # everything not made yet
    python generate.py pandas corners      # just these groups
    ONLY=panda-trophy python generate.py   # one image (by file name, no .png)
    DRY=1 python generate.py               # list what would be made, no API calls

It skips images that already exist, so it can be stopped and re-run. Model and quality can be
changed with IMAGE_MODEL (default gpt-image-1) and IMAGE_QUALITY (default high).
"""
import base64
import concurrent.futures as cf
import io
import json
import os
import re
import sys
import time

import requests
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")
RAW = os.path.join(HERE, "out", "raw")
MODEL = os.environ.get("IMAGE_MODEL", "gpt-image-1")
QUALITY = os.environ.get("IMAGE_QUALITY", "high")
URL = "https://api.openai.com/v1/images/edits"

# which existing art each group is shown as a style reference
REFS = {
    # scenery: the owner's simple examples (the first corners came out too detailed)
    "corners": ["ref-simple-blossom", "ref-simple-steps"],
    "hangers": ["ref-simple-blossom", "ref-simple-steps"],
    "scenes": ["ref-simple-steps", "land-pavilion-pond", "land-pagoda"],
    "pandas": ["panda-waving", "panda-celebrate", "panda-reading", "panda-teacher"],
    "sheets": ["panda-waving", "av-011b33dd86d4947f9f9a", "fol-blossom", "land-pavilion"],
}
SIZE = {"corners": "1024x1536", "hangers": "1024x1536", "scenes": "1536x1024", "pandas": "1024x1024", "sheets": "1024x1024"}
PREFIX = {"corners": "corner", "hangers": "hang", "scenes": "scene", "pandas": "panda", "sheets": "pictures"}
REF_NOTE = ("The attached images are existing art from the same app: match their illustration style, palette, texture and level of detail exactly. "
            "Do not copy their subjects or composition; draw only what is described below.\n\n")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def ref_png(name):
    """An existing asset, flattened onto the magenta background so the model sees the format too
    (or a reference already saved in refs/)."""
    saved = os.path.join(HERE, "refs", name + ".png")
    if name.startswith("ref-") and os.path.exists(saved):
        return open(saved, "rb").read()
    folder = os.path.join(ASSETS, name + ".imageset")
    png = next(f for f in os.listdir(folder) if f.lower().endswith(".png"))
    im = Image.open(os.path.join(folder, png)).convert("RGBA")
    im.thumbnail((768, 768))
    bg = Image.new("RGBA", im.size, (255, 0, 255, 255))
    bg.alpha_composite(im)
    buf = io.BytesIO()
    bg.convert("RGB").save(buf, "PNG")
    return buf.getvalue()


def make(job):
    group, item, out = job
    key = os.environ["OPENAI_API_KEY"]
    files = [("image[]", (f"ref{i}.png", ref_png(r), "image/png")) for i, r in enumerate(REFS[group])]
    data = {"model": MODEL, "prompt": REF_NOTE + item["p"], "size": SIZE[group], "quality": QUALITY, "n": "1"}
    for attempt in range(4):
        try:
            r = requests.post(URL, headers={"Authorization": f"Bearer {key}"}, data=data, files=files, timeout=300)
            if r.status_code == 200:
                b64 = r.json()["data"][0]["b64_json"]
                with open(out, "wb") as f:
                    f.write(base64.b64decode(b64))
                return f"made  {os.path.basename(out)}"
            if r.status_code in (429, 500, 502, 503):
                time.sleep(15 * (attempt + 1))
                continue
            return f"FAIL  {os.path.basename(out)}: {r.status_code} {r.text[:300]}"
        except requests.RequestException as e:
            time.sleep(10 * (attempt + 1))
            err = str(e)
    return f"FAIL  {os.path.basename(out)}: gave up ({err if 'err' in dir() else 'retries'})"


def main():
    prompts = json.load(open(os.path.join(HERE, "prompts.json"), encoding="utf-8"))
    groups = [g for g in sys.argv[1:] if g in prompts] or list(prompts)
    only = os.environ.get("ONLY")
    os.makedirs(RAW, exist_ok=True)
    jobs = []
    for g in groups:
        for item in prompts[g]:
            name = f"{PREFIX[g]}-{slug(item['t'])}"
            if only and name != only:
                continue
            out = os.path.join(RAW, name + ".png")
            if not os.path.exists(out):
                jobs.append((g, item, out))
    print(f"{len(jobs)} to make with {MODEL} ({QUALITY})")
    if os.environ.get("DRY"):
        for g, item, out in jobs:
            print("  ", os.path.basename(out))
        return
    if jobs and not os.environ.get("OPENAI_API_KEY"):
        sys.exit("Set OPENAI_API_KEY in your environment first.")
    with cf.ThreadPoolExecutor(int(os.environ.get("PARALLEL", 3))) as ex:
        for line in ex.map(make, jobs):
            print(line, flush=True)


if __name__ == "__main__":
    main()
