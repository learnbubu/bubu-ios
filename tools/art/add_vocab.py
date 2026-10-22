"""Codex jobs for the Classroom's Vocabulary (the owner, 22 Oct 2026: "can generate some art for the bits inside too"):
its two practice tiles that borrowed other tiles' pictures (Flashcards, Match; Quiz keeps its own), the garden's three
stages (they were emoji), a garden bed for the Today's words card's corner (as Home's Up next has its hills), and Bùbù
searching, for the search with nothing found. Group "vocab", saved as out/raw/vocab-*.png and panda-searching.png.

The tiles and the garden match the Classroom's tile pictures (class-vocab, class-quiz, class-chars): simple objects,
flat shapes with soft shading, no Bùbù.
"""
import json
import os

from PIL import Image

import make_prompts as mp

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")


def ref(name):
    """An app picture flattened onto the magenta backdrop, saved in refs/ (the model sees the format too)."""
    out = os.path.join(HERE, "refs", f"ref-{name}.png")
    if not os.path.exists(out):
        folder = os.path.join(ASSETS, name + ".imageset")
        png = next(f for f in os.listdir(folder) if f.lower().endswith(".png"))
        im = Image.open(os.path.join(folder, png)).convert("RGBA")
        im.thumbnail((768, 768))
        bg = Image.new("RGBA", (max(im.size) + 160,) * 2, (255, 0, 255, 255))
        bg.alpha_composite(im, ((bg.width - im.width) // 2, (bg.height - im.height) // 2))
        bg.convert("RGB").save(out)
    return f"refs/ref-{name}.png"


TILES = [ref("class-vocab"), ref("class-quiz"), ref("class-chars")]
ICON = ("The attached images are the app's practice tile pictures: match their style exactly (soft storybook vector, flat "
        "shapes with a little soft shading, warm cream cards with jade green and coral red, rounded corners, no outlines, "
        "simple and bold). Do not copy them; draw only what is described below. ")
END = ("\n\n" + mp.STYLE + "\n\nKeep it simple and bold like the attached pictures: a few big flat shapes, a soft sheen, no "
       "fine detail, no texture. It must read clearly small, about 70 points wide, on a pale blue, yellow or lilac tile."
       "\n\n" + mp.KEY)
POT = ("a small round terracotta flowerpot (soft coral-orange #E8955A with a darker rim band), seen from the front and a "
       "little above, the same pot in all three of the set")
GARDEN = ("\n\nIt is one of a set of three garden pictures for how well a word is learnt: a seedling, a growing plant and "
          "a plant in flower, all in the same pot, the same size and seen the same way.")

JOBS = [
    # the practice tiles (Quiz keeps class-quiz)
    ("vocab-flash", "1024x1024", TILES, ICON + "Draw ONLY one cream flashcard caught in the middle of being flipped over: "
     "tilted and turning, so its front and a sliver of its jade green back both show, with one soft curved jade arrow "
     "sweeping round it to show the turn. On its front, one simple jade leaf sprig (as on the first attached card). "
     "Centred, filling about 75% of the canvas." + END),
    ("vocab-match", "1024x1024", TILES, ICON + "Draw ONLY two cream cards side by side, tilted slightly towards each other, "
     "making a matching pair: each shows the same simple picture, one round coral red lantern, and a small soft gold "
     "sparkle sits where their edges touch, as if they just snapped together. Centred, filling about 80% of the width."
     + END),
    # the garden: how well a word is learnt (they were the emoji 🌱 🌿 🌸)
    ("vocab-seed", "1024x1024", TILES, ICON + "Draw ONLY " + POT + ", with a tiny seedling just come up from the soil: one "
     "short pale green stem and two small round jade leaves. Centred, filling about 70% of the canvas." + GARDEN + END),
    ("vocab-grow", "1024x1024", TILES, ICON + "Draw ONLY " + POT + ", with a young leafy plant growing in it: a few "
     "stems and six or seven rounded jade and sage green leaves, about twice as tall as the pot, no flowers yet. Centred, "
     "filling about 70% of the canvas." + GARDEN + END),
    ("vocab-bloom", "1024x1024", TILES, ICON + "Draw ONLY " + POT + ", with a full plant in flower: rounded jade and sage "
     "leaves and three simple open blossoms, soft coral red with cream centres (not pink, not magenta), about twice as "
     "tall as the pot. Centred, filling about 70% of the canvas." + GARDEN + END),
    # the Today's words card's corner, as Up next's hills: faded out towards the bottom over a pale green card
    ("vocab-bed", "1536x1024", [ref("home-hills"), ref("class-vocab")], "The attached images are the app's hills, drawn in "
     "the corner of a card, and a tile picture: match their style exactly. Draw ONLY a low wide garden bed seen from the "
     "front: a soft mound of earth edged with a few smooth grey stones, with a row of plants growing in it from left to "
     "right, getting bigger as they go: two tiny seedlings, then two leafy young plants, then one plant in flower with "
     "three soft coral red blossoms (not pink). Simple big shapes in jade and sage greens, very calm. It sits in the top "
     "right corner of a pale green card and is faded out towards the bottom, so keep it light and low in contrast. "
     "Centred, about four times as wide as tall, filling about 85% of the width.\n\n" + mp.STYLE + "\n\n" + mp.SIMPLE
     + "\n\n" + mp.KEY),
    # the search, when nothing's found: Bùbù looking hard
    ("panda-searching", "1024x1024", ["refs/panda-waving.png", "refs/panda-reading.png", "refs/panda-teacher.png"],
     "The attached images are Bùbù, the app's panda: draw him exactly as they do. Draw ONLY Bùbù sitting, leaning forward "
     "and peering through a big round magnifying glass (gold rim, jade handle) held up in one paw, his eye big behind the "
     "lens, his other paw holding a cream flashcard with one jade leaf on it. Curious and puzzled, mouth a small 'o'. "
     "Centred, filling about 75% of the canvas.\n\n" + mp.PANDA + "\n\n" + mp.STYLE + "\n\n" + mp.KEY),
]

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "vocab"]
    for name, size, refs, prompt in JOBS:
        jobs.append({"file": f"out/raw/{name}.png", "group": "vocab", "size": size, "refs": refs, "prompt": prompt})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(JOBS), "vocab jobs")
