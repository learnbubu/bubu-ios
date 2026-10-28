"""Makes the new art placeable in the path editor (chineseLearning/app/tools/path-editor), which
takes its palette from the web app: each corner-*, scene-* and panda-* from out/final goes into
images/path/<name>.webp, with its size in ART and its painted strips in SLABS (app.js).

Idempotent: art already in ART is left alone. The web repo is committed locally only.
"""
import json
import os
import re

from PIL import Image

from install import slabs, chosen

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
WEB = os.path.join(HERE, "..", "..", "..", "chineseLearning", "app")
APPJS = os.path.join(WEB, "app.js")
SIZE = {"corner": (60, "left", 900), "scene": (65, "any", 900), "panda": (22, "any", 600), "hang": (45, "left", 900)}


def insert_before_close(src, name, lines):
    """Adds lines at the end of `const NAME = { ... };` (two-space indented closing brace)."""
    m = re.search(r"\n  const " + name + r" = \{\n", src)
    end = src.index("\n  };", m.end())
    body = src[m.end():end].rstrip()
    return src[:m.end()] + body + ",\n" + ",\n".join(lines) + src[end:]


def main():
    src = open(APPJS, encoding="utf-8").read()
    art_block = src[src.index("const ART = {"):src.index("\n  };", src.index("const ART = {"))]
    have = set(re.findall(r'"([a-z0-9-]+)":', art_block))
    art_lines, slab_lines = [], []
    for f in sorted(os.listdir(FINAL)):
        if not f.endswith(".png"):
            continue
        if f.endswith("-right.png") and f.startswith(("corner-", "hang-")):
            continue
        name = chosen(f[:-4], preview=True)
        if not name:
            continue
        kind = name.split("-")[0]
        if kind not in SIZE or name in have:
            continue
        w, side, longest = SIZE[kind]
        if "-tall-" in name:
            w = 48                      # the tall, slim corners take less of the screen's width
        if os.path.exists(os.path.join(FINAL, "obj-" + name[5:] + ".png")):
            w = 40                      # a hook piece (hang.py): all 520 wide, so its bracket matches the knot's
        im = Image.open(os.path.join(FINAL, f)).convert("RGBA")
        im.thumbnail((longest, longest), Image.LANCZOS)
        im.save(os.path.join(WEB, "images", "path", name + ".webp"), "WEBP", quality=88, method=6)
        art_lines.append(f'    "{name}": {{ w: {w}, ar: {im.height / im.width:.3f}, side: "{side}" }}')
        slab_lines.append(f"    \"{name}\": {json.dumps([[float(a), float(b)] for a, b in slabs(im)])}")
    if art_lines:
        src = insert_before_close(src, "ART", art_lines)
        src = insert_before_close(src, "SLABS", slab_lines)
        open(APPJS, "w", encoding="utf-8", newline="\n").write(src)
    print(f"{len(art_lines)} pieces added to the web app's ART and SLABS")
    css_vars()


def css_vars():
    """The web app draws each piece from a CSS variable named after it (index.html, in the light,
    dark and chosen-dark blocks): one for every new piece, the same picture in both themes."""
    html_p = os.path.join(WEB, "index.html")
    html = open(html_p, encoding="utf-8").read()
    ver = re.search(r'\?v=(\d+)"', html).group(1)
    names = sorted(f[:-5] for f in os.listdir(os.path.join(WEB, "images", "path"))
                   if f.endswith(".webp") and f.split("-")[0] in SIZE)
    missing = [n for n in names if f"--{n}:" not in html]
    if not missing:
        return
    block = [f'--{n}: url("images/path/{n}.webp?v={ver}");' for n in missing]
    out, n = [], 0
    for line in html.split(chr(10)):
        out.append(line)
        if "--panda-sleeping:" in line:
            indent = line[:len(line) - len(line.lstrip())]
            out.extend(indent + b for b in block)
            n += 1
    open(html_p, "w", encoding="utf-8", newline=chr(10)).write(chr(10).join(out))
    print(f"{len(missing)} CSS variables added in {n} theme blocks")


def refresh_hooks():
    """The hook pieces already in the palette, redrawn after the owner changes their rope or size (hooks.html): each
    picture, and its ar and strips in ART and SLABS, in place. Its width on the path stays as the owner set it."""
    jobs = json.load(open(os.path.join(HERE, "jobs.json"), encoding="utf-8"))
    src = open(APPJS, encoding="utf-8").read()
    n = 0
    for j in jobs:
        name = j.get("out")
        f = os.path.join(FINAL, (name or "") + ".png")
        if not j.get("mount") or not os.path.exists(f) or f'\n    "{name}": {{' not in src:
            continue
        im = Image.open(f).convert("RGBA")
        im.thumbnail((900, 900), Image.LANCZOS)
        im.save(os.path.join(WEB, "images", "path", name + ".webp"), "WEBP", quality=88, method=6)
        src = re.sub(r'(\n    "' + name + r'": \{ w: [\d.]+, ar: )[\d.]+', lambda m: m.group(1) + f"{im.height / im.width:.3f}", src)
        src = re.sub(r'(\n    "' + name + r'": )\[\[[^\n]*?\]\](?=,?\n)',
                     lambda m: m.group(1) + json.dumps([[float(a), float(b)] for a, b in slabs(im)]), src)
        n += 1
    open(APPJS, "w", encoding="utf-8", newline="\n").write(src)
    print(n, "hook pieces redrawn in the palette")


if __name__ == "__main__":
    main()
