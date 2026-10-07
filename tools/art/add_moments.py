"""Bùbù's results moments (owner, 7 Oct 2026, after Duolingo's "Zoooom!" - but our own, and
different for different wins): a sticker of Bùbù doing something fun on a soft coloured blob,
shown big on the results screen. Plus the monthly quest badge. Jobs for Codex in the "moments"
group, saved as mo-*.
"""
import json

import make_prompts as mp

REFS = ["refs/ref-rig-idle.png", "refs/panda-celebrate.png"]
STICKER = ("The attached images are Bùbù, the app's panda (black and cream, pink cheeks, a red backpack). Draw Bùbù as a fun STICKER: "
           "{pose} Behind him, a soft rounded blob shape in {blob}, a little bigger than him, tilted, with a lighter rim - like a "
           "sticker backing. Lively and expressive, his face clear and big, the same character as the references. Square canvas, the "
           "sticker centred.\n\n")

MOMENTS = {
    "speedy": ("riding a small golden swirly cloud (the Monkey King's somersault cloud) leaning forward fast, ears and the tuft of "
               "hair blown back, a determined happy grin, three wind streaks behind him.", "warm yellow-gold"),
    "flawless": ("holding a big red seal stamp in both paws, pressing it down onto a sheet of paper, the seal print reading 满分 in "
                 "red (copy the characters exactly), eyes closed proudly.", "soft red-coral"),
    "kungfu": ("in a kung-fu pose: one leg kicked up high, one paw forward, one back, a fierce happy face, two motion swooshes.",
               "jade green"),
    "sweep": ("sweeping with a small bamboo broom, a little pile of red cross marks (x) being swept away, a cheerful wink.",
              "sky blue"),
    "nightowl": ("in blue pyjamas and a floppy nightcap, holding up a glowing paper lantern, sleepy but proud, a small crescent moon.",
                 "deep indigo with a few tiny stars"),
    "earlybird": ("holding a steaming cup of tea in both paws with a steamed bun beside him, cosy and smiling, a small rising sun.",
                  "soft peach-orange"),
    "brain": ("balancing a tall, wobbly stack of colourful books on his head, arms out for balance, eyes wide, tongue out a little in "
              "concentration.", "lilac purple"),
    "onfire": ("riding a big red firecracker like a rocket, sitting astride it, a trail of sparks and a small flame from its end, "
               "arms up whooping.", "fiery orange"),
}

if __name__ == "__main__":
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    jobs = [j for j in jobs if j.get("group") != "moments"]
    for k, (pose, blob) in MOMENTS.items():
        jobs.append({"file": f"out/raw/mo-{k}.png", "group": "moments", "size": "1024x1024", "refs": REFS,
                     "prompt": STICKER.format(pose=pose, blob=blob) + mp.STYLE + "\n\n" + mp.KEY})
    jobs.append({"file": "out/raw/mo-quest-badge.png", "group": "moments", "size": "1024x1024", "refs": REFS,
                 "prompt": ("The attached images are Bùbù, the app's panda. Draw a round BADGE: a warm gold ring with a red inner "
                            "border, and inside it Bùbù from the chest up, waving and smiling, with a tiny red lantern hanging at the "
                            "side. Simple and bold, like an achievement icon. Square canvas, the badge centred.\n\n" + mp.STYLE + "\n\n" + mp.KEY)})
    json.dump(jobs, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(sum(1 for j in jobs if j.get("group") == "moments"), "moments jobs")
