"""The results moments split into layers for animating (owner, 7 Oct 2026: "need to separate parts,
build stuff in mind that they'll be animated"). Each layer is an EDIT of the finished sticker
(out/raw/mo-<k>.png) that keeps only one thing, in exactly the same size and place, so the layers
stack back into the sticker. Jobs for Codex in the "layers" group, saved as mo-<k>-<layer>.png.
Also: the rays again without the pink.
"""
import json

import make_prompts as mp

EDIT = ("The attached image is a finished sticker from the app. EDIT it to make ONE LAYER of it for animation: keep {keep} EXACTLY "
        "as it is - the same size, the same place on the canvas, the same shapes and colours - and remove everything else, leaving "
        "flat magenta (#FF00FF) where it was. Where something removed was covering part of what you keep, draw that hidden part in, "
        "continuing it naturally (e.g. a leg behind a prop). {extra}No text, no letters{chars}.")
EAR = "Bùbù has exactly two black ears: if there is a third ear or a stray black ear shape behind his head, remove it. "

LAYERS = {
    "speedy": {"blob": "ONLY the soft yellow blob backing (the sticker's background shape and its rim)",
               "bubu": "ONLY Bùbù himself (his whole body, head and backpack, in his pose), no cloud, no wind streaks",
               "cloud": "ONLY the golden swirly cloud he rides",
               "wind": "ONLY the white wind streaks"},
    "flawless": {"blob": "ONLY the coral blob backing",
                 "bubu": "ONLY Bùbù holding the red seal stamp (him and the stamp together), no paper",
                 "paper": "ONLY the sheet of paper WITH the red 满分 print on it",
                 "paper-blank": "ONLY the sheet of paper, with the red print removed so the paper is blank",
                 "lines": "ONLY the little yellow impact lines"},
    "kungfu": {"blob": "ONLY the green blob backing",
               "bubu": "ONLY Bùbù in his kung-fu pose",
               "swoosh": "ONLY the motion swooshes"},
    "sweep": {"blob": "ONLY the blue blob backing",
              "bubu": "ONLY Bùbù with his broom (him and the broom together)",
              "crosses": "ONLY the red crosses (x marks) and the little dust puffs"},
    "nightowl": {"blob": "ONLY the indigo blob backing, with no stars and no moon on it (plain indigo)",
                 "bubu": "ONLY Bùbù in his pyjamas holding the lantern",
                 "sky": "ONLY the crescent moon and the little stars",
                 "glow": "ONLY a soft warm golden glow where the lantern is (a round halo of light, no lantern)"},
    "earlybird": {"blob": "ONLY the peach blob backing, with no sun on it",
                  "bubu": "ONLY Bùbù holding the cup of tea (him and the cup), no steam, no bun",
                  "sun": "ONLY the small rising sun",
                  "steam": "ONLY the curls of steam above the cup",
                  "bun": "ONLY the steamed bun (and its basket)"},
    "brain": {"blob": "ONLY the lilac blob backing",
              "bubu": "ONLY Bùbù, with his arms out for balance, and NO books on his head (draw the top of his head and ears whole)",
              "books": "ONLY the stack of books"},
    "onfire": {"blob": "ONLY the orange blob backing",
               "bubu": "ONLY Bùbù riding the firecracker rocket (him and the rocket together), no flame or sparks",
               "trail": "ONLY the flame and the trail of sparks from the rocket's end"},
}

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "layers"]
    for k, layers in LAYERS.items():
        for name, keep in layers.items():
            extra = EAR if "Bùbù" in keep else ""
            chars = ", apart from the 满分 print copied exactly" if name == "paper" else ""
            jobs.append({"file": f"out/raw/mo-{k}-{name}.png", "group": "layers", "size": "1024x1024",
                         "refs": [f"out/raw/mo-{k}.png", "refs/ref-rig-idle.png"],
                         "prompt": EDIT.format(keep=keep, extra=extra, chars=chars) + "\n\n" + mp.STYLE})
    # the rays again: pale gold only (the first took pink from the magenta)
    jobs = [j for j in jobs if j["file"] != "out/raw/pk-rays.png"]
    jobs.append({"file": "out/raw/pk-rays.png", "group": "layers", "size": "1024x1024", "refs": ["refs/ref-pk-red.png"],
                 "prompt": ("The attached image is art from the same app, for the style. Draw ONLY a soft burst of warm light: about "
                            "twelve gentle rays fanning out evenly from the centre in a full circle, every ray PALE GOLD and cream only "
                            "(no pink, no red, no purple at all), soft-edged and fading toward their ends, nothing in the middle.\n\n"
                            + mp.STYLE + "\n\n" + mp.KEY)})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(1 for j in jobs if j.get("group") == "layers"), "layer jobs")
