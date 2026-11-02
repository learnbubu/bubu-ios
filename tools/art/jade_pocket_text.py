# The lucky pocket's words as pictures, for placing them in Studio (jade-text): the app draws them itself, so these are
# a guide only and stay out of the exported videos. Fonts as near as Windows has: Nunito, and YaHei for PingFang.
# From tools/art: ../sfx/.venv/Scripts/python -I jade_pocket_text.py
import os
from PIL import Image, ImageDraw, ImageFont

OUT = "C:/Users/domch/Documents/Projects/bubu-studio/projects/bubu/art/jade-text"
NUNITO = "C:/Users/domch/Documents/Projects/bubu-ios/native/Bubu/Resources/Fonts/"
HAN = "C:/Windows/Fonts/msyhbd.ttc"
K = 2220 / 852   # document units a point, on an iPhone 16
os.makedirs(OUT, exist_ok=True)


def nunito(style):
    for root, _, files in os.walk("C:/Users/domch/Documents/Projects/bubu-ios/native/Bubu"):
        if f"Nunito-{style}.ttf" in files:
            return os.path.join(root, f"Nunito-{style}.ttf")
    raise FileNotFoundError(style)


def draw(name, text, font_path, pt, colour, tracking=0, button=None):
    font = ImageFont.truetype(font_path, round(pt * K))
    gap = tracking * K
    widths = [font.getlength(c) for c in text]
    width = sum(widths) + gap * (len(text) - 1)
    asc, desc = font.getmetrics()
    w, h = (int(width) + 8, asc + desc + 8) if not button else button
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if button:
        d.rounded_rectangle((0, 0, w - 1, h - 1), radius=42, fill=(255, 255, 255, 255))
    x, y = (w - width) / 2, (h - asc - desc) / 2
    for c, cw in zip(text, widths):
        d.text((x, y), c, font=font, fill=colour)
        x += cw + gap
    im.save(os.path.join(OUT, name + ".png"))
    print(name, w, h)


GOLD = (255, 217, 138, 255)
draw("t-heading", "福袋", HAN, 64, GOLD, tracking=8)
draw("t-heading-en", "Lucky pocket", nunito("ExtraBold"), 16, GOLD)
draw("t-tap", "Tap to open!", nunito("Black"), 17, (255, 255, 255, 255))
draw("t-greeting", "恭喜恭喜", HAN, 46, GOLD, tracking=9)
draw("t-greeting-en", "Congratulations!", nunito("ExtraBold"), 17, (207, 232, 196, 255))
draw("t-amount", "You got 50 XP!", nunito("Black"), 24, (255, 255, 255, 255))
draw("t-reason", "A lucky pocket, full of XP", nunito("Bold"), 15.5, (196, 223, 187, 255))
draw("t-continue", "CONTINUE", nunito("Black"), 17, (31, 122, 58, 255), tracking=0.9, button=(930, 130))
