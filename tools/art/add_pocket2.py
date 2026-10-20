"""Codex jobs for the pocket opening at the chest's level (the owner, 20 Oct 2026, after Duolingo's chest video): the
pockets in parts that line up, so the app can pop the seal, swing the flap open and pour light and coins out of the
real opening, and a few pieces for the prize screen. Group "pocket2", saved as pk2-*. The older "pocket" group
(pk-*: the gold pocket, the open pockets, coins, ingot, lanterns, rays, swirl) stays as it is and is reused.

Every part is an EDIT of the whole pocket in the same place on the same canvas, so the parts stack back into it.
"""
import json
import os

from PIL import Image

import make_prompts as mp

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")


def ref(src, path):
    """A reference on a 1024 magenta square, the pocket 700x820 in the middle (as add_pocket.ref)."""
    im = Image.open(src).convert("RGBA")
    r0, g0, b0, _ = im.getpixel((2, 2))
    if r0 > 200 and b0 > 200 and g0 < 80:
        # a raw Codex picture already on magenta: cut the magenta out first
        px = im.load()
        for y in range(im.height):
            for x in range(im.width):
                r, g, b, a = px[x, y]
                if r > 200 and b > 200 and g < 80: px[x, y] = (0, 0, 0, 0)
        im = im.crop(im.getbbox())
    im.thumbnail((700, 820))
    c = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    c.alpha_composite(im, ((1024 - im.width) // 2, (1024 - im.height) // 2))
    c.convert("RGB").save(os.path.join(HERE, path))


SAME = ("The FIRST attached image is a lucky pocket (a Chinese red envelope) from the app. EDIT it. It is one layer of an "
        "animation, so it must line up EXACTLY with the original: keep the canvas, the pocket's size, position and outline "
        "exactly the same, and keep the style, colours and pattern exactly the same (copy any character on it stroke for "
        "stroke). ")
END = ("\n\nBackground: one flat, solid pure magenta (#FF00FF) everywhere outside what is drawn, no shadow, no glow, no halo. "
       "No text or letters apart from the character already on the pocket.")

# (name, colour words, inside colour)
POCKETS = [
    ("red", "red", "a deep shadowy crimson"),
    ("jade", "jade-green", "a deep shadowy green"),
    ("gold", "gold", "a deep warm amber"),
]


def parts(kind, colour, inside):
    r = f"refs/ref-pk2-{kind}.png"
    return [
        (f"pk2-{kind}-body", [r], SAME + "Draw ONLY the pocket's BODY with its top flap REMOVED and the round panda clasp "
         "REMOVED: the front of the pocket from the line where the flap's curved edge was, down to the bottom, exactly as it "
         "is (the big circle with its character, the corner swirls). Above that line, inside the original outline, show the "
         f"pocket's opening: the top edge of the back panel, a little lower than the old top, and between them {inside} "
         "inside with a soft shadow, as if you are looking slightly down into an empty open envelope." + END),
        (f"pk2-{kind}-flap", [r], SAME + "Draw ONLY the top FLAP of the pocket, exactly as it is on the closed pocket: the "
         "top of the pocket down to the flap's curved lower edge with its gold trim and the swirls on it, in exactly the same "
         "place. REMOVE the round panda clasp (leave plain flap where it was). Nothing below the flap's edge: the body "
         "is magenta." + END),
        (f"pk2-{kind}-flap-inside", [r], SAME + f"Draw ONLY the INSIDE of the top flap, as if the flap has been folded up "
         "and back and we see its underside: the same outline as the flap but flipped upside down, standing up ABOVE where the "
         f"pocket's top edge is, attached along that top edge. The underside is plain {colour} a shade darker than the front, "
         "with a thin gold edge along its curved rim and a soft shading toward the fold, no pattern, no clasp. Nothing else: "
         "the pocket's body is NOT drawn (magenta)." + END),
        (f"pk2-{kind}-seal", [r], SAME + "Draw ONLY the round panda clasp (the gold coin-shaped seal with the panda face at "
         "the flap's tip), exactly as it is, in exactly the same place and size. Nothing else: no flap, no pocket." + END),
    ]


JOBS = []
for k, c, i in POCKETS:
    JOBS += parts(k, c, i)

PIECE = "\n\n" + mp.STYLE + "\n\nKeep it simple and bold, like the attached coin: big flat shapes, a soft sheen, no fine detail.\n\n" + mp.KEY
JOBS += [
    ("pk2-coin-pile", ["refs/ref-pk-coin.png"], "The attached image is the app's gold coin. Draw ONLY a generous heap of these "
     "same gold coins (round, square hole), about fifteen, piled into a rounded mound, a few leaning up on their edges, one "
     "gold ingot (yuanbao) resting on top, and two small sparkles. Centred, seen from the front, filling about 80% of the width."
     + PIECE),
    ("pk2-xp-jade", ["refs/ref-pk-coin.png", "refs/ref-pk-jade.png"], "The attached images are the app's gold coin and jade "
     "pocket, for the style. Draw ONLY a lucky jade charm: a round jade-green disc (a bi) with a round hole in the middle, a "
     "soft inner glow, a red knotted cord and short red tassel hanging from its top, and two small sparkles. Centred, a simple "
     "icon. (It stands for bonus XP.)" + PIECE),
    ("pk2-blossom", ["refs/ref-pk-coin.png"], "The attached image is the app's gold coin, for the style. Draw ONLY one plum "
     "blossom flower seen from the front: five round soft-pink petals, a warm gold centre with a few short stamens. Centred, "
     "a simple icon." + PIECE),
    ("pk2-sparkle", ["refs/ref-pk-coin.png"], "The attached image is the app's gold coin, for the style. Draw ONLY one "
     "four-pointed sparkle star: long slim points up, down, left and right, pale warm gold with a near-white centre, soft "
     "edges. Centred, filling about 70% of the canvas." + PIECE),
    ("pk2-month-bubu", ["refs/panda-red-envelope.png", "refs/ref-pk-gold.png"], "The FIRST attached image is Bùbù the panda "
     "from the app; copy him exactly (face, ears, eye patches, blush, white tuft, coral-red backpack straps). Draw ONLY Bùbù "
     "from the chest up, beaming with his eyes happily closed, hugging the GOLD lucky pocket from the SECOND image to his "
     "chest with both paws (its character facing us, copied exactly), a few gold sparkles around him. He fills the canvas "
     "from the bottom edge up to near the top, centred, cut off flat at the bottom (it goes in a round medal)." + "\n\n"
     + mp.KEY),
]

if __name__ == "__main__":
    ref(os.path.join(ASSETS, "pocket-red.imageset", "pocket-red.png"), "refs/ref-pk2-red.png")
    ref(os.path.join(ASSETS, "pocket-jade.imageset", "pocket-jade.png"), "refs/ref-pk2-jade.png")
    ref(os.path.join(HERE, "out", "raw", "pk-pocket-gold.png"), "refs/ref-pk2-gold.png")
    ref(os.path.join(HERE, "out", "raw", "pk-pocket-gold.png"), "refs/ref-pk-gold.png")
    Image.open(os.path.join(ASSETS, "panda-red-envelope.imageset", "panda-red-envelope.png")).save(os.path.join(HERE, "refs", "panda-red-envelope.png"))
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "pocket2"]
    for name, refs, prompt in JOBS:
        jobs.append({"file": f"out/raw/{name}.png", "group": "pocket2", "size": "1024x1024", "refs": refs, "prompt": prompt})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(JOBS), "pocket2 jobs")
