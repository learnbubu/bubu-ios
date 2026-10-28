"""Hanging pieces that aren't branches.

The owner, 28 Oct 2026, on batch path3: "its just branches only.... for the hanging pieces. need more variation of
stuff". So these hang the way the Chinese knot does (kept in the review): from a cord tied to a carved wooden bracket
or the upturned corner of a roof's eave, coming in from the top-left; no branches and no leaves. Things from the
world of the app (a garden, a teahouse, a classroom, festivals), each one clear real object, with the same AVOID rules
as path3. Appends jobs (group "path4") to jobs.json; Codex makes only that group (PATH4.md).
"""
import json
import make_prompts as mp
from add_path3 import NOTE, HANG_AVOID, slug

HANG_SHAPE = ("It hangs from a short carved dark-wood bracket (or the upturned corner of a grey-tiled roof eave, where "
              "said) that comes in from the TOP-LEFT edge, on a red cord: NOT a branch, no leaves, no plants. Anchor it to "
              "the TOP-LEFT corner; it occupies the top-left area only (about the left half and the top two-thirds at "
              "most), with plenty of empty magenta. Portrait canvas, 4:5.")

# (not make_prompts' SIMPLE, which asks for a tree, rocks, leaves and flowers)
SIMPLE = ("Keep it SIMPLE, like the attached references: a few big simple shapes, each a flat fill with at most one soft "
          "lighter tone; no fine texture, no tiny repeated details; generous empty space.")

HANGS = [
    ("Eave with a bell", "the upturned corner of a grey-tiled temple roof eave, with one small bronze bell hanging from its tip"),
    ("Brass gong", "a small round brass gong hanging in a simple dark-wood frame, a padded red-tipped beater hanging beside it"),
    ("Steamer stack", "a stack of three round bamboo steamer baskets with a lid, hanging by a cord from a hook"),
    ("Brush rack", "a small wooden calligraphy brush rack with four brushes of different sizes hanging from it by their loops"),
    ("Straw hat", "a round woven straw hat hanging on a wooden peg by its chin cord"),
    ("Birdhouse", "a little wooden birdhouse with a curved Chinese-style roof and a round door, hanging on a cord"),
    ("Flag bunting", "a short string of five small triangular cloth flags in coral, jade and cream, swagging down from the bracket"),
    ("Rabbit lantern", "a white and coral paper rabbit lantern (the Mid-Autumn kind), hanging on a cord"),
    ("Butterfly kite", "a butterfly-shaped paper kite in coral, gold and jade hung up by its string, two short tail streamers"),
    ("Fishing basket", "a small woven bamboo fishing basket with a lid, hanging on a cord"),
    ("Lucky coins", "three round gold coins with square holes threaded on a red cord, hanging in a short vertical line"),
    ("Teapot on a hook", "a round clay teapot hanging by its handle from a small iron hook on a cord"),
]


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = []
    for t, d in HANGS:
        f = f"out/raw/hang-{slug(t)}.png"
        if f not in have:
            add.append({"file": f, "group": "path4", "size": "1024x1536",
                        "refs": ["refs/ref-hang-hanging-lanterns.png", "refs/ref-hang-chinese-knot.png"],
                        "prompt": f"{NOTE}\n\n{mp.STYLE}\n\n{SIMPLE}\n\nCreate a hanging decoration: {d}. {HANG_SHAPE}\n\n{HANG_AVOID}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs added;", len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
