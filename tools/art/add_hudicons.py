"""New icons for the counters at the top of the path: the streak lantern (lit and unlit), the coin and the bun.

The owner, 28 Oct 2026, picking the "open strip" header (Duolingo's: no box, just bold icons and numbers in their
own colours): "think we just need to regen the icons to something better? all 3 of them. Lantern being the main one,
so there's not a piece hanging at the bottom." The old lantern had a cord and tassel hanging under it, which made it
tall and thin at 22 pt; these are drawn as icons first: one chunky, compact shape that reads at a glance beside a
number, nothing thin, nothing hanging. Appends jobs (group "hudicons") to jobs.json; Codex makes only that group
(HUDICONS.md).
"""
import json
import make_prompts as mp

NOTE = ("The attached image is existing art from the same app: match its illustration style, palette, texture and level "
        "of detail exactly. Do not copy its subject; draw only what is described below.")

ICON = ("This is an APP ICON shown very small (about 22 points, next to a number in a top bar, like Duolingo's flame and "
        "gem), so design it for that size: one bold, compact, chunky silhouette that fills about 80% of the canvas, "
        "centred, roughly as wide as it is tall; big flat shapes with one soft highlight and one soft shadow tone; no "
        "thin lines, no fine detail, no small parts, nothing sticking out, nothing hanging below it. Front-on, upright, "
        "no tilt, no cast shadow, no sparkles. Square canvas.")

LANTERN = ("A round red Chinese paper lantern, seen front-on: a plump, nearly round red body (slightly wider than tall) "
           "with three or four soft vertical rib lines, a short gold cap on top and a matching short gold band at the "
           "bottom, both sitting flush against the body. NO cord, NO hook, NO tassel and NO fringe: nothing above the top "
           "cap or below the bottom band. ")

JOBS = [
    ("hud-lantern-lit", LANTERN + "It is LIT: a warm golden glow from inside makes the centre of the red body brighter, "
     "glowing orange-gold in the middle and fading to deep coral-red at the edges.", ["refs/ref-pk-coin.png"]),
    # (unlit: drawn from the lit one, so it's the same lantern)
    ("hud-lantern-unlit", LANTERN + "Draw exactly the same lantern as the attached lit one, the same shape, size and "
     "place on the canvas, but UNLIT: no glow at all; the body a soft warm grey (#B9B5AA) with slightly darker grey ribs, "
     "the caps a muted grey-beige.", ["out/raw/hud-lantern-lit.png"]),
    ("hud-coin", "A thick round gold Chinese coin, front-on, with a square hole in the middle: a chunky raised rim, a "
     "flat face a shade lighter, a soft highlight on the upper left. No characters or marks on it.", ["refs/ref-pk-coin.png"]),
    ("hud-bun", "One plump steamed bao bun, seen from the front and a little above: a soft round cream-white dome, a bit "
     "wider than tall, with a neat swirl of pleats gathered at the top and a soft warm shadow along its base. No basket, "
     "no steam, no plate, no face.", ["refs/ref-pk-coin.png"]),
]


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = []
    for name, d, refs in JOBS:
        f = f"out/raw/{name}.png"
        if f not in have:
            add.append({"file": f, "group": "hudicons", "size": "1024x1024", "refs": refs,
                        "prompt": f"{NOTE}\n\n{mp.STYLE}\n\nCreate an icon: {d}\n\n{ICON}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs added;", len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
