"""The red pocket roll (owner, 7 Oct 2026, after Duolingo's chest upgrade at the end of a
lesson): tap a pocket and it may upgrade, red to gold to jade, then it bursts open with coins.
Everything here is an EDIT of art the app already has (pocket-red, pocket-jade, coin, the rig's
torso), so it matches. Jobs for Codex in the "pocket" group, saved as pk-*.
"""
import json
import os

from PIL import Image

import make_prompts as mp

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "..", "native", "Bubu", "Assets.xcassets")


def ref(asset, path):
    im = Image.open(os.path.join(ASSETS, asset + ".imageset", asset + ".png")).convert("RGBA")
    im.thumbnail((700, 820))
    c = Image.new("RGBA", (1024, 1024), (255, 0, 255, 255))
    c.alpha_composite(im, ((1024 - im.width) // 2, (1024 - im.height) // 2))
    c.convert("RGB").save(os.path.join(HERE, path))


END = "\n\nKeep the background flat solid magenta (#FF00FF), nothing else added. No text, no letters, except the character already on the pocket."
KEEP_POCKET = ("The FIRST attached image is a red envelope (red pocket) from the app. EDIT it: keep it EXACTLY the same shape, size, "
               "place, pattern, panda clasp and the character in the middle (copy that character exactly, stroke for stroke), and ")
OPEN = ("open its top flap: the flap folded up and back, and from inside the open pocket a warm golden glow spilling up, with the tops "
        "of two or three gold coins (round, with a square hole, like the coin in the second image) peeking out. The front with its "
        "character stays as it is.")

JOBS = [
    ("pk-pocket-gold", ["refs/ref-pk-red.png"], KEEP_POCKET + "change ONLY its colours: the red becomes rich shining gold (warm "
     "yellow-gold with a lighter gold sheen), and the gold patterns, rim and character become deep red. It should look precious, a step "
     "up from the red one." + END),
    ("pk-pocket-red-open", ["refs/ref-pk-red.png", "refs/ref-pk-coin.png"], KEEP_POCKET + OPEN + END),
    ("pk-pocket-jade-open", ["refs/ref-pk-jade.png", "refs/ref-pk-coin.png"], KEEP_POCKET.replace("a red envelope (red pocket)", "a jade-green envelope (lucky pocket)") + OPEN + END),
    ("pk-coins", ["refs/ref-pk-coin.png"], "The attached image is the app's gold coin. Draw ONLY three of these same coins tumbling "
     "through the air at different angles (one flat-on, one tilted, one almost edge-on), with a tiny sparkle by one, in a loose group. "
     "Same style and gold.\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-ingot", ["refs/ref-pk-coin.png"], "The attached image is the app's gold coin, for the style. Draw ONLY one Chinese gold ingot "
     "(yuanbao): the boat shape with raised ends and a rounded dome in the middle, shining gold with a lighter sheen, a tiny sparkle on "
     "it.\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-lantern-lit", ["refs/ref-pk-red.png"], "The attached image is art from the same app, for the style. Draw ONLY one small round "
     "red Chinese lantern, glowing warmly from inside, with gold top and bottom caps and a short gold tassel - a simple icon, centred."
     "\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-lantern-unlit", ["refs/ref-pk-red.png"], "The attached image is art from the same app, for the style. Draw ONLY one small round "
     "Chinese lantern that is NOT lit: muted dusty grey-brown paper, darker caps, no glow - the same shape as a lit red lantern icon, "
     "centred.\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-swirl", ["refs/ref-pk-red.png"], "The attached image is art from the same app, for the style. Draw ONLY a single sweeping "
     "white swoosh: a thick soft white curved streak that sweeps around in an open circle (like a quick spin around something), "
     "tapering at both ends, with two tiny white sparkles - nothing in the middle.\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-rays", ["refs/ref-pk-red.png"], "The attached image is art from the same app, for the style. Draw ONLY a soft burst of warm "
     "light: about twelve gentle pale-gold rays fanning out evenly from the centre in a full circle, soft-edged and fading toward their "
     "ends, nothing in the middle.\n\n" + mp.STYLE + "\n\n" + mp.KEY),
    ("pk-bubu-hold", ["refs/ref-rig5-torso.png", "refs/ref-pk-red.png"], "The FIRST attached image is Bùbù's body with his arms down. "
     "EDIT it: keep the torso, belly, legs, feet and the two red straps EXACTLY as they are, and change ONLY the arms: both arms bent, "
     "holding the red envelope from the SECOND image out in front of his belly with both paws, as if offering it (the envelope smaller, "
     "about half his body's width, its character facing us, copied exactly)." + END),
]

if __name__ == "__main__":
    ref("pocket-red", "refs/ref-pk-red.png")
    ref("pocket-jade", "refs/ref-pk-jade.png")
    ref("coin", "refs/ref-pk-coin.png")
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "pocket"]
    for name, refs, prompt in JOBS:
        jobs.append({"file": f"out/raw/{name}.png", "group": "pocket", "size": "1024x1024", "refs": refs, "prompt": prompt})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(JOBS), "pocket jobs")
