"""The profile Overview's icons into the app (the owner, 1 Nov 2026): the gold bolt for XP, and Codex's practice paper
and speech bubble with the real 字 and 词 written on them here, in the stones' brush lettering, so they're always right.

    python make_stat_icons.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FINAL = os.path.join(HERE, "out", "final")
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")
FONT = os.path.join(HERE, "..", "..", "native", "Bubu", "Resources", "Fonts", "MaShanZheng-Bubu.ttf")
SIZE = 800
OUT = 132          # 22 points at 3x, twice over so it stays crisp if it's ever shown bigger


def square(name):
    im = Image.open(os.path.join(FINAL, name + ".png")).convert("RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    r = SIZE / max(im.size)
    im = im.resize((round(im.width * r), round(im.height * r)), Image.LANCZOS)
    c = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    c.paste(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
    return c


def write(im, ch, colour, cx, cy, size):
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(FONT, size)
    b = d.textbbox((0, 0), ch, font=font)
    d.text((cx - (b[0] + b[2]) / 2, cy - (b[1] + b[3]) / 2), ch, fill=colour, font=font)


def save(im, name):
    folder = os.path.join(ASSETS, name + ".imageset")
    os.makedirs(folder, exist_ok=True)
    im.resize((OUT * 2, OUT * 2), Image.LANCZOS).save(os.path.join(folder, name + ".png"), optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write('{\n  "images": [\n    {\n      "idiom": "universal",\n      "filename": "%s.png",\n      "scale": "3x"\n'
                '    }\n  ],\n  "info": {\n    "author": "xcode",\n    "version": 1\n  }\n}\n' % name)


def main():
    save(square("stat-xp-bolt"), "stat-xp")
    paper = square("stat-chars-paper")
    write(paper, "字", (38, 44, 50, 255), 400, 375, 500)
    save(paper, "stat-chars")
    bubble = square("stat-words-bubble")
    write(bubble, "词", (255, 250, 240, 255), 398, 338, 420)   # the middle of the bubble's face, not counting its tail
    save(bubble, "stat-words")


if __name__ == "__main__":
    main()
