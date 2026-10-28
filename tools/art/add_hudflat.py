"""The top-bar icons again, flat 2D: the lantern (lit and unlit), the coin and the bun.

The owner, 28 Oct 2026, comparing Codex's painted icons (add_hudicons.py) with a flat set drawn by hand in the
Duolingo manner: "think something like flat 2d, but lets generate, so they look better". So: the painted icons'
shapes (the owner's approved lantern with nothing hanging, the coin, the bun), redrawn flat, with the hand-drawn flat
sketch (refs/ref-hud-flat-sketch.png) for the look. Appends jobs (group "hudflat") to jobs.json; Codex makes only that
group (HUDFLAT.md).
"""
import json
import make_prompts as mp

NOTE = ("Attached: the first image shows the SHAPE and design to keep (an existing icon from this app, painted); the "
        "last image is a rough flat sketch showing the LOOK to draw it in. Keep the first image's shape, proportions and "
        "details; redraw it in the flat look, better made than the sketch.")

FLAT = ("Style: a crisp FLAT 2D vector icon, like the icons in Duolingo's top bar: solid flat colour fills with NO "
        "gradients, NO texture, NO paper grain and NO soft airbrushing; shading only as one or two hard-edged shapes in "
        "a slightly darker tone of the same colour (a crescent along the bottom or right side); one clean light "
        "highlight shape (a short rounded stroke or pill) near the top left; edges perfectly clean and smooth; no "
        "outlines. Warm, friendly palette matching the app: coral red (#E8553E) with deeper red (#C43E2D), gold "
        "(#F6C33B) with deeper gold (#D9961C), warm cream (#FBEACF) with tan (#E5C291).")

ICON = ("It is shown very small (about 22 points, beside a number), so one bold, compact, chunky silhouette filling "
        "about 80% of the canvas, centred, front-on and upright; no thin lines, no small parts, nothing sticking out, "
        "nothing hanging below it, no cast shadow, no sparkles. Square canvas.")

JOBS = [
    ("hud-flat-lantern-lit", "The round red Chinese lantern from the first image: plump body, a few vertical ribs, short "
     "gold caps top and bottom sitting flush. NO cord, hook, tassel or fringe. It is LIT: a flat, hard-edged glowing "
     "centre in orange-gold (two flat rings, lighter in the middle), not a gradient.",
     ["out/final/hud-lantern-lit.png", "refs/ref-hud-flat-sketch.png"]),
    ("hud-flat-lantern-unlit", "Exactly the same lantern as the first image (the flat lit one), the same shape, size and "
     "place on the canvas, but UNLIT: no glow; the body flat warm grey (#BDB8AC) with a darker grey (#A39E92) shadow "
     "shape and ribs, the caps a muted grey-beige.",
     ["out/raw/hud-flat-lantern-lit.png", "refs/ref-hud-flat-sketch.png"]),
    ("hud-flat-coin", "The thick round gold Chinese coin from the first image, with its square hole in the middle (the "
     "hole is empty: magenta shows through it): a raised rim, an inner ring, a flat darker shape along the bottom edge "
     "for thickness, a short darker strip inside the top of the hole for depth. No characters or marks.",
     ["out/final/hud-coin.png", "refs/ref-hud-flat-sketch.png"]),
    ("hud-flat-bun", "The plump steamed bao bun from the first image: a round cream dome, a little wider than tall, with "
     "a neat swirl of pleats gathered to a small knot at the top drawn as a few clean tan curves, and a flat tan "
     "crescent along its base. No basket, steam, plate or face.",
     ["out/final/hud-bun.png", "refs/ref-hud-flat-sketch.png"]),
]


def main():
    jobs = json.load(open("jobs.json", encoding="utf-8"))
    have = {j["file"] for j in jobs}
    add = []
    for name, d, refs in JOBS:
        f = f"out/raw/{name}.png"
        if f not in have:
            add.append({"file": f, "group": "hudflat", "size": "1024x1024", "refs": refs,
                        "prompt": f"{NOTE}\n\n{FLAT}\n\nCreate an icon: {d}\n\n{ICON}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "jobs added;", len(jobs) + len(add), "in all")


if __name__ == "__main__":
    main()
