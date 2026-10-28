"""More Bùbù poses and hanging pieces for the path, steered by the owner's art review (28 Oct 2026).

The owner kept 49 of the path's 66 pictures and crossed off 17 (chineseLearning/app/tools/path-editor/art-review.json).
What the crossed-off ones had in common, in their words:
  hanging pieces: "makes no sense and too complicated" (chillies and garlic, cloud swirls, the edge waterfall),
    "too complicated, doesn't match our style" (ink scroll), "too many firecrackers", "too small" (ivy pot),
    "could be made better" (ginkgo);
  Bùbù: a sign or speech bubble with nothing in it, a "?" you can't make out, a prop that makes no sense (the leaf
    when meditating, the hongbao), the embers the app no longer uses, a cluttered moon, and the plain idle and the
    two peeks (they need an edge to peek round).
What was kept: one clear, real thing a child would name at a glance, big and simple; for Bùbù, one action you can
read from his outline, with at most one prop that obviously belongs to it.

So each prompt here carries a short AVOID paragraph from that, and the two the owner liked but wanted better
(firecrackers, ginkgo) come back redone; speaking and puzzled come back without the bubble and the "?".
Appends jobs (group "path3") to jobs.json; Codex makes only that group (PATH3.md).
"""
import json
import make_prompts as mp

NOTE = ("The attached images are existing art from the same app: match their illustration style, palette, texture and level "
        "of detail exactly. Do not copy their subjects or composition; draw only what is described below.")

PANDA_AVOID = ("Avoid: no signs, boards, speech bubbles, thought bubbles, question marks, symbols, letters or numbers; no moon, "
               "stars, clouds, ground, scenery or extra objects around him; at most ONE prop, and only one that obviously belongs "
               "to the action. The action must read clearly from his outline alone at a small size. He is never just standing "
               "still: there is always something happening.")
PANDA_SHAPE = "Full body, centred, with generous margin all round. Square canvas."

HANG_AVOID = ("Avoid: nothing abstract or symbolic (no swirls, waves, waterfalls or patterns), no text or calligraphy, no "
              "jumbles of mixed objects. One clear, real thing a child would name at a glance, made of a few big simple shapes; "
              "if it repeats (lanterns, fruit, bells), no more than three to five of them. Make it BIG: it should fill most of "
              "the top-left area described below, not sit small in it.")
HANG_SHAPE = ("Like the attached hanging willow, anchor it to the TOP-LEFT corner and let it hang down and reach in, long and light: "
              "it occupies the top-left area only (about the left half and the top two-thirds at most), with plenty of empty "
              "magenta. Portrait canvas, 4:5.")

PANDAS = [
    ("Carrying bamboo", "Bùbù marching happily with a long green bamboo stalk resting over one shoulder"),
    ("Munching bamboo", "Bùbù sitting down, holding a short bamboo stalk in both paws and munching the leafy end, eyes closed with joy"),
    ("Watering", "Bùbù tipping a small terracotta watering can, a few water drops falling from its spout"),
    ("Book stack", "Bùbù walking carefully while hugging a tall wobbly stack of three or four plain coloured books, tongue poking out in concentration"),
    ("Drum", "Bùbù beating a small round red Chinese drum hung at his front, one drumstick raised high, mouth open in a cheer"),
    ("Fan", "Bùbù fanning himself with a round cream silk fan, relaxed and smiling, one foot kicked up"),
    ("Tai chi", "Bùbù doing a tai chi pose: balanced on one leg, the other knee raised, paws held out smoothly, calm closed eyes"),
    ("Mooncake", "Bùbù holding up a round golden mooncake in both paws, about to take a big bite, delighted"),
    ("Shuttlecock", "Bùbù kicking a Chinese feather shuttlecock (jianzi) up into the air with one foot, watching it, arms out for balance"),
    ("Ribbon dance", "Bùbù twirling a long coral-red ribbon on a short stick in a big loop around him, mid-spin"),
    ("Umbrella", "Bùbù strolling under a small coral-red oil-paper umbrella held over his shoulder"),
    ("Big stretch", "Bùbù in a big morning stretch, both arms straight up, up on tiptoes, eyes squeezed shut, no props"),
    ("Camera", "Bùbù holding a small cream camera up to his eye, taking a photo, one eye closed"),
    ("Pointing the way", "Bùbù pointing ahead with one arm outstretched, looking back over his shoulder with an excited 'this way!' face, no props"),
    ("Ping pong", "Bùbù swinging a small red ping-pong paddle, a white ball just in front of it, focused and happy"),
    ("Polite bow", "Bùbù giving a small polite bow, paws together in front of his chest, eyes closed and smiling, no props"),
    # the owner's two that nearly worked, without what spoiled them
    ("Explaining", "Bùbù talking and explaining something with enthusiasm: mouth open mid-word, one paw raised and open, eyebrows up; no speech bubble"),
    ("Head scratch", "Bùbù puzzled, head tilted, scratching his head with one paw, one eyebrow raised, small frown; no question mark or symbols"),
]

HANGS = [
    ("Peach branch", "a branch with two or three round pink-blushed peaches and a few long leaves, hanging down from the top-left corner"),
    ("Pomegranate branch", "a branch with two round coral-red pomegranates and a few glossy leaves, hanging from the top-left corner"),
    ("Kumquat branch", "a small kumquat branch with four or five little round orange fruits and dark green leaves, hanging from the top-left corner"),
    ("Magnolia branch", "a bare grey branch with three large cream magnolia blossoms and one bud, reaching in from the top-left corner"),
    ("Camellia branch", "a camellia branch with two or three big coral-red flowers and glossy dark green leaves, hanging from the top-left corner"),
    ("Grape vine", "a curling grape vine with two hanging bunches of round purple-grey grapes and a few broad leaves, from the top-left corner"),
    ("Songbird on a branch", "a slim branch from the top-left corner with one small round songbird perched on it, a few leaves"),
    ("Paper cranes", "three folded paper cranes (cream, coral and jade) hanging on thin cords at different heights from a branch in the top-left corner"),
    ("Paper-cut flower", "one big round red paper-cut flower decoration (a simple petal pattern, no characters) with a red tassel, hanging on a cord from the top-left corner"),
    ("Swallow kite", "a swallow-shaped Chinese kite in coral and cream caught in a branch at the top-left corner, its tail streamers hanging down"),
    ("Flower basket", "a small round woven basket of pink peonies hanging on a cord from a branch in the top-left corner"),
    # the owner's two that nearly worked, redone
    ("Short firecracker string", "a SHORT string of just four or five red firecrackers with a gold knot at the top, hanging from the top-left corner"),
    ("Golden ginkgo branch", "a ginkgo branch with six to eight BIG golden fan-shaped leaves, bold and bright, one leaf drifting down, hanging from the top-left corner"),
]


def slug(s):
    import re
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = []
    for t, d in PANDAS:
        f = f"out/raw/panda-{slug(t)}.png"
        if f not in have:
            add.append({"file": f, "group": "path3", "size": "1024x1024",
                        "refs": ["refs/panda-waving.png", "refs/panda-celebrate.png", "refs/panda-reading.png", "refs/panda-teacher.png"],
                        "prompt": f"{NOTE}\n\n{mp.STYLE}\n\n{mp.PANDA}\n\nPose: {d}. {PANDA_SHAPE}\n\n{PANDA_AVOID}\n\n{mp.KEY}"})
    for t, d in HANGS:
        f = f"out/raw/hang-{slug(t)}.png"
        if f not in have:
            add.append({"file": f, "group": "path3", "size": "1024x1536",
                        "refs": ["refs/ref-hang-hanging-willow-fronds.png", "refs/ref-hang-hanging-lanterns.png"],
                        "prompt": f"{NOTE}\n\n{mp.STYLE}\n\n{mp.SIMPLE}\n\nCreate a hanging decoration: {d}. {HANG_SHAPE}\n\n{HANG_AVOID}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs added;", len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
