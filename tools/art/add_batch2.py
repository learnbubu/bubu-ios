"""Batch 2 (owner, 5 Oct 2026): taller, slimmer corners like the bamboo-and-lantern piece ("work
really well"), and more hanging pieces like the willow fronds. Appends jobs to jobs.json; the
corners are named corner-tall-* so the pipeline treats them as corners (install.py and to_web.py
give them a narrower width on the path)."""
import json

import make_prompts as mp

TALL = [
    ("Pine and boulders", "a tall Chinese pine with a slender trunk and three cloud-shaped foliage pads stacked up its height, two smooth boulders and a few broad leaves at its foot"),
    ("Bamboo and stone pagoda", "tall bamboo stalks rising behind a small three-tier stone pagoda, rounded shrubs and a few cream flowers at the base"),
    ("Plum tree", "a tall, slim plum tree with coral-red and cream blossoms along its upper branches, a rock and low leaves at its foot"),
    ("Willow by the water", "a tall weeping willow with long fronds falling down its height, a small strip of water and a stepping stone at the bottom"),
    ("Lantern post", "a tall wooden post with a red paper lantern hanging from its top, climbing leaves, shrubs and a rock at the base"),
    ("Karst pillar", "a tall, narrow limestone karst pillar with a small pine growing near its top, soft mist and shrubs at its base"),
    ("Bamboo with a hanging lantern", "tall bamboo stalks with one red lantern hanging from a stalk partway up, shrubs and cream flowers below"),
    ("Ginkgo", "a tall, slim ginkgo tree with golden fan-shaped leaves, a few leaves falling, rocks at its foot"),
    ("Autumn maple", "a tall, slim Chinese maple with warm orange-red leaves, a boulder and low green leaves at its foot"),
    ("Pine over a trickle", "a tall pine on stacked rocks with a thin waterfall trickling down the rocks into a tiny pool at the bottom"),
    ("Magnolia", "a tall, slim magnolia tree with big cream flowers on bare upper branches, shrubs and a rock below"),
    ("Bamboo and wooden signpost", "tall bamboo stalks with a small blank wooden signpost at the base (no writing), shrubs and stones"),
    ("Osmanthus", "a tall, slim osmanthus tree with small golden-orange flower clusters, rounded shrubs and stones at the base"),
    ("Cypress and urn", "two tall slender cypress trees beside a glazed teal garden urn, low shrubs and stones"),
]
HANG = [
    ("Hanging plum branch", "a plum branch with coral-red and cream blossoms reaching in and hanging down from the top-left corner"),
    ("Pine branch", "a pine branch with two or three cloud-shaped needle pads reaching in from the top-left corner"),
    ("Paper lantern string", "a string of five small round paper lanterns, red and cream, swagging down from the top-left corner"),
    ("Hanging bamboo leaves", "sprays of bamboo leaves hanging down from the top-left corner"),
    ("Wind bells", "a branch from the top-left corner with three small bronze wind bells hanging on cords"),
    ("Ginkgo branch", "a ginkgo branch with golden fan-shaped leaves hanging from the top-left corner, one leaf falling"),
    ("Maple branch", "a maple branch with orange-red leaves reaching in from the top-left corner"),
    ("Flowering vine", "a trailing green vine with small cream flowers hanging down from the top-left corner"),
    ("Single long lantern", "one red lantern with a gold tassel hanging on a long cord from a branch in the top-left corner"),
    ("Osmanthus branch", "an osmanthus branch with small golden-orange flower clusters hanging from the top-left corner"),
]

TALL_SHAPE = ("Make it TALL AND SLIM, like the attached bamboo-and-lantern reference: the scenery is a narrow column anchored to the "
              "BOTTOM-LEFT corner, about 35-40% of the canvas width for most of its height and rising to about 95% of the height; "
              "only at the very bottom does it spread a little wider, with a few small stones or leaves trailing to the right "
              "(to about 60% of the width). Everything else stays empty magenta. Portrait canvas, 4:5.")
HANG_SHAPE = ("Like the attached hanging willow, anchor it to the TOP-LEFT corner and let it hang down and reach in, long and light: "
              "it occupies the top-left area only (about the left half and the top two-thirds at most), with plenty of empty magenta. "
              "Portrait canvas, 4:5.")


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    note = jobs[0]["prompt"].split("\n\n")[0]
    have = {j["file"] for j in jobs}
    add = []
    for t, d in TALL:
        f = f"out/raw/corner-tall-{mp_slug(t)}.png"
        if f not in have:
            add.append({"file": f, "group": "tall", "size": "1024x1536", "refs": ["refs/ref-tall-lantern.png", "refs/ref-simple-blossom.png"],
                        "prompt": f"{note}\n\n{mp.STYLE}\n\n{mp.SIMPLE}\n\nCreate a decorative scenery corner: {d}. {TALL_SHAPE}\n\n{mp.KEY}"})
    for t, d in HANG:
        f = f"out/raw/hang-{mp_slug(t)}.png"
        if f not in have:
            add.append({"file": f, "group": "hangers2", "size": "1024x1536",
                        "refs": ["refs/ref-hang-hanging-willow-fronds.png", "refs/ref-hang-hanging-lanterns.png"],
                        "prompt": f"{note}\n\n{mp.STYLE}\n\n{mp.SIMPLE}\n\nCreate a hanging decoration: {d}. {HANG_SHAPE}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs added;", len(jobs) + len(add), "in all")


def mp_slug(s):
    import re
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


if __name__ == "__main__":
    main()
